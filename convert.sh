source .env
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_REQUEST_CHECKSUM_CALCULATION=$AWS_REQUEST_CHECKSUM_CALCULATION
export AWS_RESPONSE_CHECKSUM_VALIDATION=$AWS_RESPONSE_CHECKSUM_VALIDATION

converter_dir="${bia_integrator_dir}/bia-converter"
converted_image_uuids_file="converted-image-uuids.txt"
for study_to_convert in `ls -1 *uploaded-by-submitter-uuids.txt`
do
    echo "Processing $study_to_convert"
    for uploaded_by_submitter_uuid in `cat $study_to_convert`
    do
        conversion_log_file="${uploaded_by_submitter_uuid}.convert.log"
        command="poetry --directory ${converter_dir} run bia-converter convert ${uploaded_by_submitter_uuid} 2>&1 | tee ${conversion_log_file}"
        #command='poetry --directory '"$bia_converter_dir"' run bia-converter convert '"$uploaded_by_submitter_uuid"' 2>&1 | tee '"$convert_to_interactive_display_output"'; echo exit_status=${PIPESTATUS[0]}'
        if [ "dryrun" == "true" ]; then
            echo "Dry run. Would have run '$command'"
        else
            echo $command
            eval $command
            # Get UUID of ImageRepresentation created
            image_representation_uuid=$(grep -oP 'Creation of image representation \K[0-9a-fA-F-]+' ${conversion_log_file})
            echo "ImageRepresentation UUID: ${image_representation_uuid}"
            # Get UUID of ImageRepresentation created
            #image_representation_uuid=$(grep -oP '[Storing|Updating] ImageRepresentation with UUID \K[0-9a-fA-F-]+ in API' ${conversion_log_file})
            grep -oP '(?=.*\b(?:Storing|Updating)\b).* ImageRepresentation with UUID \K[0-9a-fA-F-]+(?= in API)' ${conversion_log_file} >> ${converted_image_uuids_file}
        fi
    done
done