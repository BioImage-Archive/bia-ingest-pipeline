#!/bin/bash
source .env

script_name="00-ingest-pipeline.sh"
dryrun=false
ingest_time=`date -Iseconds`
work_dir="$work_dir_base/$ingest_time"

for arg in "$@"; do
    case $arg in
        dryrun=true)
            dryrun=true
            ;;
        *)
            # Assume anything else is the working directory
            work_dir="$arg"
            ;;
    esac
done

if [ -d $work_dir ]; then
    # TODO: Discuss whether to delete all artefacts before run
    #command="rm -rf $work_dir/*"
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
else
    command="mkdir -p $work_dir"
    if [ "$dryrun" = "true" ]; then
        echo ".$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi

# TODO: For all subscripts below -> pass dryrun as an extra argument. Currently exported

# Create a new ingest log file for message to be emailed to slack
ingest_pipeline_log=$work_dir/ingest-pipeline.log
echo "Subject: Running ingest pipeline $ingest_time" > $ingest_pipeline_log
echo "From: $from" >> $ingest_pipeline_log
echo "To: $to" >> $ingest_pipeline_log
echo >> $ingest_pipeline_log

# Find studies to ingest
source $pipeline_dir/10-find-studies.sh $work_dir 

# For each study to ingest do ingest
source $pipeline_dir/20-ingest-studies.sh $work_dir 

# For each successfully ingested study propose images
source $pipeline_dir/30-propose-images-to-convert.sh $work_dir 

# Add message for conversion
day=$(date -Idate)
echo >> $ingest_pipeline_log
echo "Conversion to OME-Zarr scheduled for ${day}T20:00:00." >> $ingest_pipeline_log
echo "Manually move proposals (modifying if necessary) in $work_dir/proposals to $pipeline_dir/proposals_to_convert before this time." >> $ingest_pipeline_log

## Send message to Slack
if [ ! "$dryrun" = "true" ]; then
    source $pipeline_dir/90-send-message-to-slack.sh $ingest_pipeline_log
fi
