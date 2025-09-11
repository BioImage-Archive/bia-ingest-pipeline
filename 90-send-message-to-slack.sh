script_name="90-send-message-to-slack.sh"
echo "" && echo "Starting commands for $script_name" && echo ""

if [ $# -lt 1 ]; then
    echo "$script_name: Need subject as first argument. Exiting."
    return
fi
subject=$1

if [ $# -lt 2 ]; then
    echo "$script_name: Need recipient as second argument. Exiting."
    return
fi
recipient=$2

if [ $# -lt 3 ]; then
    echo "$script_name: Need file containing message as third argument. Exiting."
    return
fi

email_file=$3
echo "Email file = $email_file"
tmp_file=$(mktemp)
if [ ! -f $email_file ]; then
    echo
    echo "$script_name: Could not find file ($email_file) containing message to email. Sending error as mail body."
    echo "$script_name: Could not find file ($email_file) containing message to email." > $tmp_file
    echo
else
    \cp $email_file $tmp_file
fi

# Send using mail
command="cat $tmp_file | mail -s '$subject' $recipient"
echo $command
eval $command

echo && echo "Ending commands for $script_name" && echo ""
