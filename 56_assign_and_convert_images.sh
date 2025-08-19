#!/bin/bash
# Given an accession ID and a working dir, propose images, assign and convert
#   e.g. source assign_and_convert_images.sh S-BIAD686 /home/temp/work_dir
# Optionally, to skip propose images step also give path to proposal file
#   e.g. source assign_and_convert_images.sh S-BIAD686  /home/temp/work_dir /home/bia_svc/temp/propose_images_S-BIAD686.yaml
# Assumes script being run in this dir and vars in ./env are set (see .env_template)

source .env
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

# For aws cli to prevent error to do with verifying checksums
export AWS_REQUEST_CHECKSUM_CALCULATION=$AWS_REQUEST_CHECKSUM_CALCULATION
export AWS_RESPONSE_CHECKSUM_VALIDATION=$AWS_RESPONSE_CHECKSUM_VALIDATION

# TODO - check if 1st argument is accession ID
accession_id=$1

# TODO - check if 2nd argument is workdir (with proposals dir containing proposals file)
work_dir=$2
propose_images_output=""
if [ $# -gt 2 ]; then
    propose_images_output=$3
fi

# Use uv as package manager on slurm as it was used to set up python env
if [[ $(hostname) == *slurm* ]]; then
    echo "Using uv as package manager"
    pm="uv"
else
    echo "Using poetry as package manager"
    poetry_or_uv="poetry"
fi

artefact_dir_base=$work_dir/assign_and_convert
if [ ! -d $artefact_dir_base ]; then
    mkdir -p $artefact_dir_base
    mkdir -p $artefact_dir_base/logs
fi

# Directory to store log outputs from conversion. Used to get uuids for next stage
logs_dir_base="$artefact_dir_base/logs/$accession_id"
if [ ! -d $logs_dir_base ]; then
    mkdir -p $logs_dir_base
fi

bia_assign_image_dir=$bia_integrator_dir/bia-assign-image
bia_converter_dir=$bia_integrator_dir/bia-converter
update_example_image_uri_script_path=$bia_converter_dir/scripts/update_example_image_uri_for_dataset.py
# Create proposals if the location of a proposals file was not specified
if [ -z "$propose_images_output" ]; then
    propose_images_output="$artefact_dir_base/propose_$accession_id.yaml"
    command="$poetry_or_uv --directory $bia_assign_image_dir run bia-assign-image propose-images --api $api_target --no-append --max-items $max_items $accession_id $propose_images_output"

    echo $command
    eval $command
fi

# Assign Images from proposals
assign_from_proposals_output="$logs_dir_base/assign_from_proposal_output.txt"
command="$poetry_or_uv --directory $bia_assign_image_dir run bia-assign-image assign-from-proposal --api $api_target $propose_images_output 2>&1 | tee $assign_from_proposals_output"
echo $command
eval $command

# Convert images
uploaded_by_submitter_uuids=$(grep "Persisted image_representation" $assign_from_proposals_output | cut -d' ' -f3)
n_images_converted=0
# TODO - check if annotations (i.e. has source_image_uuid in proposals - need two static images in this case)
for uploaded_by_submitter_uuid in $uploaded_by_submitter_uuids
do
    # Create interactive display representation
    convert_to_interactive_display_output="$logs_dir_base/convert_to_interactive_display_output_$uploaded_by_submitter_uuid.txt"
    command='$poetry_or_uv --directory '"$bia_converter_dir"' run bia-converter convert '"$uploaded_by_submitter_uuid"' 2>&1 | tee '"$convert_to_interactive_display_output"'; echo exit_status=${PIPESTATUS[0]}'
    echo $command;
    eval_output=$(eval "$command")
    echo $eval_output
    exit_status=$(echo $eval_output | grep -oP 'exit_status=\K[0-9]+')

    if [ "$exit_status" = "0" ]; then
        ((n_images_converted++))
        interactive_display_uuid=$(grep -oP 'Created image representation for converted image with uuid: \K[0-9a-fA-F-]+' $convert_to_interactive_display_output)
        # Create static display representation and update example image uri if this is first image converted
        # TODO - check if annotations (i.e. has source_image_uuid in proposals - need two static images in this case)
        if [ "$n_images_converted" -eq 1 ]; then
            convert_to_static_display_output="$logs_dir_base/convert_to_static_display_output_$interactive_display_uuid.txt"
            command="$poetry_or_uv --directory $bia_converter_dir run bia-converter create-static-display  $interactive_display_uuid 2>&1 | tee $convert_to_static_display_output"
            echo $command
            eval $command

            image_uuid=$(grep -oP 'COMPLETE.*bia_data_model.Image \K[0-9a-fA-F-]+' $assign_from_proposals_output | head -n 1)
            command="$poetry_or_uv --directory $bia_converter_dir run python $update_example_image_uri_script_path --update-mode replace $image_uuid"
            echo $command
            eval $command
        fi

        # Create thumbnail representation
        convert_to_thumbnail_output="$logs_dir_base/convert_to_thumbnail_output_$interactive_display_uuid.txt"
        command="$poetry_or_uv --directory $bia_converter_dir run bia-converter create-thumbnail $interactive_display_uuid 2>&1 | tee $convert_to_thumbnail_output"
        echo $command
        eval $command
    fi
done
