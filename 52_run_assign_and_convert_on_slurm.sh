source .env

if [ $# -lt 1 ]; then
    echo "Need working directory as an argument. Exiting."
    return
fi

if [ $# -lt 2 ]; then
    echo "Need File with list of accession ids to process as an argument. Exiting."
    return
fi

work_dir=$1
accession_ids_to_process=$2
slurm_jobname_suffix=$RANDOM

# Submit conversions so that at most n_max_conversion slurm jobs are running
# TODO move these to .env
n_max_conversions=3
check_interval=300

for accession_id in $(cat $accession_ids_to_process)
do
    while true; do
        n_conversions_running=$(squeue --noheader | grep bia_${slurm_jobname_suffix} | wc -l)
        if [[ "$n_conversions_running" -ge "$n_max_conversions" ]]; then
            echo "$n_conversions_running conversions running. Max is $n_max_conversions so sleeping for $check_interval seconds"
            sleep $check_interval
        else
            break
        fi
    done
    echo "processing $accession_id"
    source 53_create_slurm_convert_script.sh $accession_id $work_dir $slurm_jobname_suffix
    sbatch $work_dir/slurm_scripts/submit_convert_$accession_id.sh
done

        
# When all conversions processed create file for message to slack
while true; do
    n_conversions_running=$(squeue --noheader | grep bia_${slurm_jobname_suffix} | wc -l)
    if [[ "$n_conversions_running" -gt "0" ]]; then
        echo "$n_conversions_running conversions running so sleeping for $check_interval seconds"
        sleep $check_interval
    else
        break
    fi
done

slack_message=$work_dir/assign-and-convert-on-slurm-slack-message.txt
for accession_id in $(cat $accession_ids_to_process)
do
    n_attempted_conversion="0"
    had_errors_during_conversion=0
    if [[ "$had_errors_during_conversion" -gt "0" ]]; then
        echo "$n_attempted_conversions for $accession_id. Had some errors during conversion. See $slurm_output_file and $slurm_error_file" >> $slack_message
    else
        echo "$n_attempted_conversions for $accession_id. No errors detected. Output in $slurm_output_file and $slurm_error_file" >> $slack_message
    fi
done

source $pipeline_dir/90-send-message-to-slack.sh $slack_message