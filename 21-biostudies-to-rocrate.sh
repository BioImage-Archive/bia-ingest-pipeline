source bash_funcs.sh

script_name="21-biostudies-to-ro-crate.sh"
echo "" && echo "Starting commands for $script_name" && echo ""

if [ $# -lt 1 ]; then
    echo "$script_name: Need working directory as an argument. Exiting."
    quit
fi

work_dir=$1

# Check if there is a list of studies to ingest
studies_for_biostudies_to_roc_stage="${work_dir}/studies-for-biostudies-to-roc-stage.txt"
if [ ! -f $studies_for_biostudies_to_roc_stage ]; then
    echo "$script_name: Did not find expected file for studies to convert to ro-crate ($studies_for_biostudies_to_roc_stage). Exiting."
    quit
elif ! grep -q . $studies_for_biostudies_to_roc_stage; then
    echo "$script_name: $studies_for_biostudies_to_roc_stage does not have content to process - Exiting." 
    quit
fi

# Create biostudies-to-ro-crate directory if it doesn't exist
biostudies_to_roc_dir="${work_dir}/biostudies-to-roc"
if [ ! -d $biostudies_to_roc_dir ]; then
    command="mkdir $biostudies_to_roc_dir"
    echo $command  
    eval $command
fi

source .env
roc_ingest_dir="${bia_integrator_dir}/ro-crate-ingest"
studies_for_roc_validation_stage="${biostudies_to_roc_dir}/studies-for-roc-validation-stage.txt"
studies_for_roc_manual_curation="${biostudies_to_roc_dir}/studies-for-roc-manual-curation.txt"
studies_not_converted_to_roc_due_to_errors="${biostudies_to_roc_dir}/studies-not-converted-to-roc-due-to-errors.txt"


# For each study do biostudies to ro crate conversion
# For each attempted conversion check output for errors.
# If errors add message to log and exclude from next stage
if [ -f $studies_for_roc_validation_stage ]; then
    command="\rm $studies_for_roc_validation_stage"
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
if [ -f $studies_for_roc_manual_curation ]; then
    command="\rm $studies_for_roc_manual_curation"
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi

touch $studies_for_roc_validation_stage
touch $studies_not_converted_to_roc_due_to_errors
touch $studies_for_roc_manual_curation

# Ingest studies (if N_TO_INGEST set, restrict to these)
# If N_TO_INGEST not set default to 10000 - hopefully all studies
: "${N_TO_INGEST:=10000}"

for acc_id in `cat $studies_for_biostudies_to_roc_stage | head -n $N_TO_INGEST`
do
    study_roc_dir="${biostudies_to_roc_dir}/${acc_id}"
    biostudies_to_roc_stdout="${study_roc_dir}/biostudies-to-roc-stdout.txt"
    biostudies_to_roc_stderr="${study_roc_dir}/biostudies-to-roc-stderr.txt"
    command="run $biostudies_to_roc_stdout $biostudies_to_roc_stderr poetry --directory $roc_ingest_dir run ro-crate-ingest biostudies-to-roc -c $study_roc_dir $acc_id"
    if [ "$dryrun" = "true" ]; then
        echo ""
        echo "$script_name: Dry run. Would have run '$command'"
        echo ""
    else
        if [ ! -d $study_roc_dir ]; then
            mkdir_command="mkdir $study_roc_dir"
            echo ""
            echo $mkdir_command
            echo ""
            eval $mkdir_command
        fi
        echo ""
        echo $command
        echo ""
        eval $command
        
        # Check that command ran successfully
        # Can't use exit code directly because of piping to tee.
        exit_code=${PIPESTATUS[0]}
        if [ "$exit_code" -eq 0 ]; then
            # Successful conversion - add to list for next stage
            exit_code_message="$script_name: biostudies-to-roc exited successfully with exit code 0 for study $acc_id"
        else
            # Failed conversion - log error
            exit_code_message="$script_name: biostudies-to-roc exited due to error(s) for study $acc_id. Exit code: $exit_code"
        fi
        echo ""
        echo $exit_code_message
        echo ""
        
        # TODO: Check for warnings and errors
        n_lines_in_stderr=`wc -l < $biostudies_to_roc_stderr`
        if [ $n_lines_in_stderr -gt 0 ] || [ $exit_code -ne 0 ]; then
            error_log_message="$script_name: Error log ($biostudies_to_roc_stderr) of biostudies-to-roc for $acc_id has content. Last 3 lines: $(tail -n 3 $biostudies_to_roc_stderr)"
        else
            error_log_message="$script_name: Error log ($biostudies_to_roc_stderr) of biostudies-to-roc for $acc_id is empty."
        fi
        echo ""
        echo $error_log_message
        echo ""

        errors_warnings_in_output=`grep -i -E "error|warning" $biostudies_to_roc_stdout | tail -n 3`
        if [ ! -z "$errors_warnings_in_output" ]; then
            output_log_message="$script_name: Errors/warnings found in output log ($biostudies_to_roc_stdout) of biostudies-to-roc for $acc_id. Last 3 Errors/Warnings: $errors_warnings_in_output" 
        else
            # No errors/warnings - add to next stage
            output_log_message="$script_name: No errors/warnings found in output log ($biostudies_to_roc_stdout) of biostudies-to-roc for $acc_id. last 3 lines: $(tail -n 3 $biostudies_to_roc_stdout)." 
        fi
        echo ""
        echo $output_log_message
        echo ""

        # Check if RO Crate was created
        expected_roc_metadata_file="${study_roc_dir}/ro-crate-metadata.json"
        if [ -f $expected_roc_metadata_file ]; then
            roc_created_message="$script_name: RO Crate metadata file found for $acc_id at expected location: $expected_roc_metadata_file."
        else
            roc_created_message="$script_name: RO Crate metadata file NOT found for $acc_id at expected location: $expected_roc_metadata_file."
        fi
        echo $roc_created_message

        # Decide if study is added to next stage or to error list
        if [ $exit_code -eq 0 ] && [ $n_lines_in_stderr -eq 0 ] && [ -z "$errors_warnings_in_output" ] && [ -f $expected_roc_metadata_file ]; then
            echo "$script_name: Adding $acc_id to list for ROC validation stage"
            echo "$acc_id" >> ${studies_for_roc_validation_stage}
        elif [ -f $expected_roc_metadata_file ]; then
            echo "$script_name: Despite warnings/errors RO Crate created for $acc_id. Adding to list for ROC manual curation"          echo "$script_name: Adding $acc_id to list for assign image stage"
            echo "$acc_id" >> ${studies_for_roc_manual_curation}
        else
            echo "$script_name: Conversion of $acc_id to RO Crate has errors/warnings -> No further processing"
            echo "$acc_id" >> ${studies_not_converted_to_roc_due_to_errors}
        fi
    fi
done

# Write message to biostudies-to-roc-log.
n_studies_converted_to_roc_no_errors=`wc -l < $studies_for_roc_validation_stage`
n_studies_for_manual_curation=`wc -l < $studies_for_roc_manual_curation`
n_studies_not_converted_to_roc=`wc -l < $studies_not_converted_to_roc_due_to_errors`

biostudies_to_roc_log="${biostudies_to_roc_dir}/biostudies-to-roc-log.txt"
echo ""
echo "-------------------------------------------------------------"
echo "Commands for $script_name summary." | tee $biostudies_to_roc_log
echo "" | tee -a $biostudies_to_roc_log


n_studies_attempted=`head -n $N_TO_INGEST $studies_for_biostudies_to_roc_stage | wc -l`
echo "Attempted conversion of $n_studies_attempted studies to RO Crate." | tee -a $biostudies_to_roc_log
echo "Converted $n_studies_converted_to_roc_no_errors studies to RO Crate without errors/warnings." | tee $biostudies_to_roc_log
echo "Converted $n_studies_for_manual_curation studies to RO Crate with warnings/errors - need manual curation." | tee -a $biostudies_to_roc_log
echo "Failed to convert $n_studies_not_converted_to_roc studies to RO Crate due to errors." | tee -a $biostudies_to_roc_log
echo "" | tee -a $biostudies_to_roc_log

echo "Further details of errors/warnings can be found in the respective study directories under $biostudies_to_roc_dir." | tee -a $biostudies_to_roc_log
echo "" | tee -a $biostudies_to_roc_log

echo "Summary of studies processed:" | tee -a $biostudies_to_roc_log
echo "Studies converted to RO Crate without errors/warnings:" | tee -a $biostudies_to_roc_log
cat $studies_for_roc_validation_stage | tee -a $biostudies_to_roc_log
echo "" | tee -a $biostudies_to_roc_log

echo "Studies converted to RO Crate with warnings/errors - need manual curation:" | tee -a $biostudies_to_roc_log
cat $studies_for_roc_manual_curation | tee -a $biostudies_to_roc_log
echo "" | tee -a $biostudies_to_roc_log

echo "Studies failed to convert to RO Crate due to errors:" | tee -a $biostudies_to_roc_log
cat $studies_not_converted_to_roc_due_to_errors | tee -a $biostudies_to_roc_log
echo "" | tee -a $biostudies_to_roc_log
echo "Ending commands for $script_name" | tee -a $biostudies_to_roc_log
echo "-------------------------------------------------------------"