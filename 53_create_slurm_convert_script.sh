# TODO: Check inputs!
ACCESSION_ID=$1
WORK_DIR=$2
JOB_NAME_SUFFIX=$3

submit_convert_fname="$WORK_DIR/slurm_scripts/submit_convert_$ACCESSION_ID.sh"

command="\cp 54_submit_slurm_convert_script_template.sh $submit_convert_fname"
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
