# TODO: Check inputs!
ACCESSION_ID=$1
WORK_DIR=$2
JOB_NAME_SUFFIX=$3

slurm_script_dir="$WORK_DIR/slurm_scripts"

if [ ! -d $slurm_script_dir ]; then
    command="mkdir $slurm_script_dir"
    echo $command
    eval $command
fi

submit_convert_fname="$slurm_script_dir/submit_convert_$ACCESSION_ID.sh"
command="\cp 54-submit-slurm-convert-script-template.sh $submit_convert_fname"
echo $command
eval $command

command="sed -i s/ACCESSION_ID/$ACCESSION_ID/g $submit_convert_fname"
echo $command
eval $command

command="sed -i s/JOB_NAME_SUFFIX/$JOB_NAME_SUFFIX/g $submit_convert_fname"
echo $command
eval $command

command="sed -i s#WORK_DIR#${WORK_DIR}#g $submit_convert_fname"
echo $command
eval $command
