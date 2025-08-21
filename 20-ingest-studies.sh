script_name="20-ingest-studies.sh"
echo "" && echo "Starting commands for $script_name" && echo ""

if [ $# -lt 1 ]; then
    echo "$script_name: Need working directory as an argument. Exiting."
    return
fi

work_dir=$1
ingest_pipeline_log=${work_dir}/ingest-pipeline.log

source .env
# Check if there is a list of studies to ingest
ingest_dir="${bia_integrator_dir}/bia-ingest"
studies_for_ingest_stage="${work_dir}/studies-for-ingest-stage.txt"
studies_for_propose_image_stage="${work_dir}/studies-for-propose-image-stage.txt"
studies_not_ingested_due_to_errors="${work_dir}/studies-not-ingested-due-to-errors.txt"

if [ ! -f $studies_for_ingest_stage ]; then
    echo "$script_name: Did not find expected file for studies to ingest ($studies_for_ingest_stage). Exiting."
    return
elif ! grep -q . $studies_for_ingest_stage; then
    echo "$script_name: $studies_for_ingest_stage does not have content to process - Exiting." 
    return
fi

# For each study to ingest do ingest
# For each study ingested check output for errors. If errors message and
# exclude from next stage
if [ -f $studies_for_propose_image_stage ]; then
    command="\rm $studies_for_propose_image_stage"
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi
if [ -f $studies_not_ingested_due_to_errors ]; then
    command="\rm $studies_not_ingested_due_to_errors"
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi

touch $studies_for_propose_image_stage
touch $studies_not_ingested_due_to_errors

ingest_report_dir="${work_dir}/ingest_report"
if [ ! -d $ingest_report_dir ]; then
    command="mkdir $ingest_report_dir"
    echo
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi
for acc_id in `cat $studies_for_ingest_stage`
do
    ingest_report="${ingest_report_dir}/${acc_id}-ingest-report.txt"
    command="poetry --directory $ingest_dir run biaingest ingest -pm ${persistence_mode} --process-filelist always $acc_id 2>&1 | tee $ingest_report"
    echo
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
        # Add check that command ran successfully
        # Can't use exit code because of piping to tee.
        # grep -P "^│ ${acc_id}.*Success.* │\s+│" $ingest_report 
        grep -E "^│ ${acc_id}.*Success.* │[[:space:]]+│" $ingest_report
        has_errors=`echo $?`
        # What do we do in case of error?
        if [ "$has_errors" = "0" ]; then
            echo "$script_name: Adding $acc_id to list for proposal generation"
            echo "$acc_id" >> ${studies_for_propose_image_stage}
        else
            echo "$script_name: Ingest of $acc_id has errors -> No further processing"
            echo "$acc_id" >> ${studies_not_ingested_due_to_errors}
        fi
    fi
    # TODO: Remove this once pipeline is complete.
    break
done

# Write message to ingest-pipeline-log.
# TODO: Separate studies ingested to those with warnings and no warnings.
n_studies_ingested=`wc -l < $studies_for_propose_image_stage`
list_of_studies_ingested=`tr '\n' ' ' < $studies_for_propose_image_stage`
echo >> $ingest_pipeline_log
echo "$script_name: Ingested $n_studies_ingested studies successfully: $list_of_studies_ingested" | tee -a $ingest_pipeline_log

n_studies_not_ingested=`wc -l < $studies_not_ingested_due_to_errors`
list_of_studies_not_ingested=`tr '\n' ' ' < $studies_not_ingested_due_to_errors`
echo >> $ingest_pipeline_log
echo "$script_name: $n_studies_not_ingested studies not ingested: $list_of_studies_not_ingested" | tee -a $ingest_pipeline_log

echo && echo "Ending commands for $script_name" && echo ""