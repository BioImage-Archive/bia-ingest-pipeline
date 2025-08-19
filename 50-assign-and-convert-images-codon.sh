source .env

# TODO - check if 1st argument is workdir (with proposals dir containing proposals file)
work_dir=$1

# Check if there is a list of studies to assign image for
studies_for_assign_image_stage="${work_dir}/studies-for-assign-image-stage.txt"

if [ ! -f $studies_for_assign_image_stage ]; then
    echo "Did not find expected file for studies to assign images for ($studies_for_assign_image_stage). Exiting."
    return
elif ! grep -q . "$$studies_for_assign_image_stage; then
    echo "$studies_for_assign_image_stage does not have content to process - Exiting." 
    return
fi

# Use uv as package manager if on slurm. It was used to set up python env
if [[ $(hostname) == *slurm* ]]; then
    echo "Running conversion using slurm nodes"
    source 52_run_assign_and_convert_on_slurm.sh $work_dir $studies_for_assign_image_stage
else
    echo "Running conversion in cli"
    source 51_run_assign_and_convert_local.sh $work_dir $studies_for_assign_image_stage
fi

