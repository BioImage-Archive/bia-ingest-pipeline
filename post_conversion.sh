# Run after convert.sh

source .env
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_REQUEST_CHECKSUM_CALCULATION=$AWS_REQUEST_CHECKSUM_CALCULATION
export AWS_RESPONSE_CHECKSUM_VALIDATION=$AWS_RESPONSE_CHECKSUM_VALIDATION

converted_image_uuids_file="${pipeline_dir}/converted-image-uuids.txt"
converter_dir="${bia_integrator_dir}/bia-converter"
images_with_static_display_file="images-with-static-display-uuids.txt"
for image_representation_uuid in `cat ${converted_image_uuids_file}`
do
    echo "Processing $image_representation_uuid"
    conversion_log_file="${image_representation_uuid}.post-conversion.log"
    command="poetry --directory ${converter_dir} run bia-converter create-thumbnail ${image_representation_uuid} 2>&1 | tee ${conversion_log_file}"
    #command='poetry --directory '"$bia_converter_dir"' run bia-converter convert '"$uploaded_by_submitter_uuid"' 2>&1 | tee '"$convert_to_interactive_display_output"'; echo exit_status=${PIPESTATUS[0]}'
    if [ "dryrun" == "true" ]; then
        echo "Dry run. Would have run '$command'"
    else
        echo $command
        #eval $command
        ## Get UUID of ImageRepresentation created
        #image_representation_uuid=$(grep -oP 'Creation of image representation \K[0-9a-fA-F-]+' ${conversion_log_file})
        #echo "ImageRepresentation UUID: ${image_representation_uuid}"
        ## Get UUID of ImageRepresentation created
        ##image_representation_uuid=$(grep -oP '[Storing|Updating] ImageRepresentation with UUID \K[0-9a-fA-F-]+ in API' ${conversion_log_file})
        #grep -oP '(?=.*\b(?:Storing|Updating)\b).* ImageRepresentation with UUID \K[0-9a-fA-F-]+(?= in API)' ${conversion_log_file} >> ${converted_image_uuids_file}
    fi

    # Create static display if n_convertered <=2
    # We create static displays for the first 2 converted images
    # To cater for proposal and annotation datasets
    # TODO: Only create 2 static displays if study has proposal
    #       and annotation datasets.
    command="poetry --directory ${converter_dir} run bia-converter create-static-display ${image_representation_uuid} 2>&1 | tee ${conversion_log_file}"
    #command='poetry --directory '"$bia_converter_dir"' run bia-converter convert '"$uploaded_by_submitter_uuid"' 2>&1 | tee '"$convert_to_interactive_display_output"'; echo exit_status=${PIPESTATUS[0]}'
    if [ "dryrun" == "true" ]; then
        echo "Dry run. Would have run '$command'"
    else
        echo $command
        #eval $command
        ## Get UUID of Image updated
        image_uuid=$(grep -oP 'Updating Image with UUID \K[0-9a-fA-F-]+(?= in API)' ${conversion_log_file})
        command="poetry --directory /home/kola/code/embl_projects/BioImageArchive/bia-integrator/bia-converter run python scripts/update_example_image_uri_for_dataset.py ${image_uuid}"
        eval $command
        fi
    fi
done