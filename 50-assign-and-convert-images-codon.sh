source .env

# Script expects proposal files for assign and convert
# to be in ./proposals_to_convert
proposals_to_convert_dir=$pipeline_dir/proposals_to_convert
if [ -z "$(ls -A $proposals_to_convert_dir/*.yaml)" ]; then
    echo "Proposals to convert directory ($proposals_to_convert_dir) is empty. Exiting"
    return 1
fi

# TODO - check if 1st argument is workdir (with proposals dir containing proposals file)
if [ $# -lt 1 ]; then
    if [ ! -d $work_dir_base ]; then
        echo "work_dir_base is set to $work_dir_base but does not exist - please create and re-run script. Exiting"
        return 1
    fi
    echo "Creating working directory"
    work_dir_suffix=`date -Iseconds`
    work_dir="$work_dir_base/conversion-${work_dir_suffix}"
    command="mkdir $work_dir"
    echo $command
    eval $command
else
    work_dir=$1
    if [ ! -d $work_dir ]; then
        echo "$work_dir does not exist. Exiting"
        return 1
    fi
fi
echo "Using $work_dir as directory for conversion artefacts"

# Create list of studies to process
studies_for_assign_image_stage="${work_dir}/studies-for-assign-image-stage.txt"
grep accession_id $proposals_to_convert_dir/*.yaml | cut -d: -f2 | sed 's/ //g' | sort | uniq > $studies_for_assign_image_stage

if [ ! -f $studies_for_assign_image_stage ]; then
    echo "Did not find expected file for studies to assign images for ($studies_for_assign_image_stage). Exiting."
    return 1
elif ! grep -q . $studies_for_assign_image_stage; then
    echo "$studies_for_assign_image_stage does not have content to process - Exiting." 
    return 1
fi

# TODO assert that format of proposal files is accession_id-proposal-output.yaml
proposals_dir=$work_dir/proposals
if [ ! -d $proposals_dir ]; then
    command="mkdir $proposals_dir"
    echo $command
    eval $command
fi
command="cp $proposals_to_convert_dir/*.yaml $proposals_dir/"
echo $command
eval $command

# Use uv as package manager if on slurm. It was used to set up python env
if [[ $(hostname) == *slurm* ]]; then
    echo "Running conversion using slurm nodes"
    source 52_run_assign_and_convert_on_slurm.sh $work_dir $studies_for_assign_image_stage
else
    echo "Running conversion in cli"
    source 51_run_assign_and_convert_local.sh $work_dir $studies_for_assign_image_stage
fi

# Move proposals to attempted conversion directory
attempted_conversions_dir=$pipeline_dir/attempted_conversions
if [ ! -d $attempted_conversions_dir ]; then
    command="mkdir $attempted_conversions_dir"
    echo $command
    eval $command
fi
command="mv $proposals_to_convert_dir/* $attempted_conversions_dir/"
echo $command
eval $command