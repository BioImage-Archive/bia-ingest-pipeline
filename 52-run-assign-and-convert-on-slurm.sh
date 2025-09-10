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

# Submit conversions so that at most n_max_conversion slurm jobs are running.
# See .env to modify associated env variables. Below are defaults if not set.
: "${n_max_conversions:=3}"
: "${check_interval:=300}"

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
    source 53-create-slurm-convert-script.sh $accession_id $work_dir $slurm_jobname_suffix
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

# Pause for 10s to allow files to be sync???
sleep 10
for accession_id in $(cat $accession_ids_to_process)
do
    proposal_file=$work_dir/proposals/$accession_id-proposal-output.yaml
    n_attempted_conversion=$(grep accession_id $proposal_file | wc -l)

    log_dir="$work_dir/assign_and_convert/logs/$accession_id/convert_to_interactive_display*"
    had_errors_during_conversion_log=$(grep -il "error" $log_dir | wc -l)

    slurm_output="${work_dir}/slurm_script_output/bia_${accession_id}*"
    had_errors_during_conversion_slurm=$(grep -il "error" $slurm_output | wc -l)

    had_errors_during_conversion=$(expr $had_errors_during_conversion_log + $had_errors_during_conversion_slurm)

    if [[ "$had_errors_during_conversion" -gt "0" ]]; then
        echo "Attempted $n_attempted_conversions conversions for $accession_id. Had some errors during conversion. See files in log dir ($log_dir). Also see Slurm output and error files (${slurm_output})." >> $slack_message
    else
        echo "Attempted $n_attempted_conversions conversions for $accession_id. No errors detected. Output in $log_dir. Also see Slurm output and error files (${slurm_output})." >> $slack_message
    fi
done

subject="Subject: Running assign and convert pipeline on slurm cluster. $date_time_of_run"
command="source $pipeline_dir/90-send-message-to-slack.sh '$subject' $to '$slack_message'"
echo $command
eval $command
