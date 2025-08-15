script_name="90-send-message-to-slack.sh"
echo "" && echo "Starting commands for $script_name" && echo ""

if [ $# -lt 1 ]; then
    echo "$script_name: File containing message as argument. Exiting."
    return
fi

email_file=$1
if [ ! -f $email_file ]; then
    echo "$script_name: Could not find file ($email_file) containing message to email. Exiting."
    return
fi
# Send using curl
command="curl --url 'smtp://$smtp_server:$smtp_port' \
     --ssl-reqd \
     --mail-from '$from' \
     --mail-rcpt '$to' \
     --upload-file '$email_file' \
     --user '$mail_username:$mail_password' \
     --connect-timeout 300 \
     --max-time 600"
echo $command
eval $command
#curl --url "smtp://$smtp_server:$smtp_port" \
#     --ssl-reqd \
#     --mail-from "$from" \
#     --mail-rcpt "$to" \
#     --upload-file "$email_file" \
#     --user "$mail_username:$mail_password" \
#     --connect-timeout 300 \
#     --max-time 600

echo && echo "Ending commands for $script_name" && echo ""