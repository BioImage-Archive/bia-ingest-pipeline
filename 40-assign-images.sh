if [ $# -lt 2 ]; then
    echo "Need working directory as an argument. Exiting."
    return
fi

work_dir=$1

source .env

# Check if there is a list of studies to assign image for
studies_for_assign_image_stage="${work_dir}/studies-for-assign-image-stage.txt"

if [ ! -f $studies_for_assign_image_stage ]; then
    echo "Did not find expected file for studies to assign images for ($studies_for_assign_image_stage). Exiting."
    return
elif ! grep -q . "$$studies_for_assign_image_stage; then
    echo "$studies_for_assign_image_stage does not have content to process - Exiting." 
    return
fi

studies_for_convert_image_stage="${work_dir}/studies-for-convert-image-stage.txt"
if [ -f $studies_for_convert_image_stage ]; then
    command="\rm ${studies_for_convert_image_stage}"
    if [ "$dryrun" = "true" ]; then
        echo "Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi

# For each proposal file assign images
#dryrun="true"
api_to_use="local"
assign_image_dir="${bia_integrator_dir}/bia-assign-image"

# TODO: Check number of proposal files match number of studies to assign images for
#proposal_files=`ls -1 *.yaml`

# For each proposal file assign images and convert to bia-convert format
for proposal_file in $proposal_files
do
    echo "Processing $proposal_file"
    # Assign images and convert to bia-convert format
    assign_from_proposal_output_file="${proposal_file}-assign-from-proposal-output.txt"
    command="poetry --directory $assign_image_dir run bia-assign-image assign-from-proposal --api ${api_to_use} ${pipeline_dir}/${proposal_file} 2>&1 | tee $assign_from_proposal_output_file"
    if [ "$dryrun" = "true" ]; then
        echo "Dry run. Would have run '$command'"
    else
        echo $command
        eval $command

        # TODO: Modify assign from proposal to write out json of UUIDs images and image representations created
        # For now get UUIDs of uploaded_by_submitter rep using grep
        uploaded_by_submitter_uuids_file="${proposal_file}-uploaded-by-submitter-uuids.txt"
        command="grep -oP 'Creation of image representation \K[0-9a-fA-F-]+' $assign_from_proposal_output_file > $uploaded_by_submitter_uuids_file"
        echo $command
        eval $command
    fi
done