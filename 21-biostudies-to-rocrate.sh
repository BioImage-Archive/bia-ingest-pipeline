source bash_funcs.sh

script_name="21-biostudies-to-ro-crate.sh"
echo "" && echo "Starting commands for $script_name" && echo ""

if [ $# -lt 1 ]; then
    echo "$script_name: Need working directory as an argument. Exiting."
    return
fi

work_dir=$1

# Create biostudies-to-ro-crate directory if it doesn't exist
biostudies_to_roc_dir="${work_dir}/biostudies-to-ro-crate"
if [ ! -d $biostudies_to_rocrate_dir ]; then
    command="mkdir $biostudies_to_rocrate_dir"
    echo $command  
    eval $command
fi

source .env
# Check if there is a list of studies to ingest
roc_ingest_dir="${bia_integrator_dir}/ro-crate-ingest"
studies_for_biostudies_to_roc_stage="${work_dir}/studies-for-biostudies-to-roc-stage.txt"
studies_for_roc_to_api_stage="${work_dir}/studies-for-roc-to-api-stage.txt"
studies_not_converted_to_roc_due_to_errors="${work_dir}/studies-not-converted-to-roc-due-to-errors.txt"

if [ ! -f $studies_for_biostudies_to_roc_stage ]; then
    echo "$script_name: Did not find expected file for studies to convert to ro-crate ($studies_for_biostudies_to_roc_stage). Exiting."
    return
elif ! grep -q . $studies_for_biostudies_to_roc_stage; then
    echo "$script_name: $studies_for_biostudies_to_roc_stage does not have content to process - Exiting." 
    return
fi

# For each study do biostudies to ro crate conversion
# For each attempted conversion check output for errors.
# If errors add message to log and exclude from next stage
if [ -f $studies_for_roc_to_api_stage ]; then
    command="\rm $studies_for_roc_to_api_stage"
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi
if [ -f $studies_not_converted_to_roc_due_to_errors ]; then
    command="\rm $studies_not_converted_to_roc_due_to_errors"
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi

touch $studies_for_roc_to_api_stage
touch $studies_not_converted_to_roc_due_to_errors

biostudies_to_roc_dir="${work_dir}/biostudies_to_roc"
if [ ! -d $biostudies_to_roc_dir ]; then
    command="mkdir $biostudies_to_roc_dir"
    echo
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi

# Ingest studies (if N_TO_INGEST set restrict to these)
# TODO: Set N_TO_INGEST in .env
# If N_TO_INGEST not set default to 10000 - hopefully all studies
: "${N_TO_INGEST:=10000}"

for acc_id in `cat $studies_for_biostudies_to_roc_stage | head -n $N_TO_INGEST`
do
    study_roc_dir="${biostudies_to_roc_dir}/${acc_id}"
    biostudies_to_roc_stdout="${study_roc_dir}/biostudies-to-roc-stdout.txt"
    biostudies_to_roc_stderr="${study_roc_dir}/biostudies-to-roc-stderr.txt"
    command="run $biostudies_to_roc_stdout $biostudies_to_roc_stderr poetry --directory $roc_ingest_dir run ro-crate-ingest biostudies-to-roc -c $study_roc_dir $acc_id"
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        if [ ! -d $study_roc_dir ]; then
            mkdir_command="mkdir $study_roc_dir"
            echo $mkdir_command
            eval $mkdir_command
        fi
        echo $command
        eval $command
        
        # Check that command ran successfully
        # Can't use exit code directly because of piping to tee.
        exit_code=`echo ${PIPESTATUS[0]}`
        echo "exit code is $exit_code"
        
        # TODO: Check for warnings and errors

        # Check if RO Crate was created

        # Check if RO Crate is valid
    fi
done