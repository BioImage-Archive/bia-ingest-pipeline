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
slack_message=$work_dir/assign-and-convert-slack-message.txt
echo "Subject: Running assign and convert pipeline $date_time_of_run" > $slack_message
echo "From: $from" >> $slack_message
echo "To: $to" >> $slack_message
echo >> $slack_message




for accession_id in $(cat $accession_ids_to_process)
do
    echo "processing $accession_id"
    proposal_file=$work_dir/proposals/$accession_id-proposal-output.yaml
    source 56_assign_and_convert_images.sh $accession_id $work_dir $proposal_file
    n_attempted_conversions=$(grep accession_id $proposal_file | wc -l)
    
    log_dir="$work_dir/assign_and_convert/logs/$accession_id/convert_to_interactive_display*"
    had_errors_during_conversion=$(grep -il "error" $log_dir | wc -l)
    if [[ "$had_errors_during_conversion" -gt "0" ]]; then
        echo "Attempted $n_attempted_conversions conversions for $accession_id. Had some errors during conversion. See files in $log_dir" >> $slack_message
    else
        echo "Attempted $n_attempted_conversions conversions for $accession_id. No errors detected. Output in $log_dir" >> $slack_message
    fi
done

source $pipeline_dir/90-send-message-to-slack.sh $slack_message