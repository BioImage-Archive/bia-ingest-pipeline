source bash_funcs.sh

script_name="23-validate-roc.sh"
echo "" && echo "Starting commands for $script_name" && echo ""

if [ $# -lt 1 ]; then    
    echo "$script_name: Need working directory as an argument. Exiting."
    quit
fi  

work_dir=$1
biostudies_to_roc_dir="${work_dir}/biostudies-to-roc"
studies_for_roc_validation_stage="${biostudies_to_roc_dir}/studies-for-roc-validation-stage.txt"

if [ ! -f $studies_for_roc_validation_stage ]; then
    echo "$script_name: Did not find expected file for studies to validate ($studies_for_roc_validation_stage). Exiting."
    quit
fi 

roc_validation_dir="${work_dir}/roc-validation"
if [ ! -d $roc_validation_dir ]; then
    command="mkdir $roc_validation_dir"
    echo $command
    eval $command
fi

source .env
roc_ingest_command_dir="${bia_integrator_dir}/ro-crate-ingest"
studies_passed_roc_validation="${work_dir}/studies-passed-roc-validation.txt"
studies_failed_roc_validation="${work_dir}/studies-failed-roc-validation.txt"

# For each study to validate do validate
for acc_id in `cat $studies_for_roc_validation_stage`; do
    # Note that roc_path must be absolute path to top level dir containing ro-crate-metadata.json
    roc_path="${biostudies_to_roc_dir}/${acc_id}"
    roc_validation_stdout="${biostudies_to_roc_dir}/roc-validation-stdout.txt"
    roc_validation_stderr="${biostudies_to_roc_dir}/roc-validation-stderr.txt"
    command="run $roc_validation_stdout $roc_validation_stderr poetry --directory $roc_ingest_command_dir run ro-crate-ingest validate $roc_path"
    if [ "$dryrun" = "true" ]; then
        echo ""
        echo "$script_name: Dry run. Would have run '$command'"
        echo ""
    else
        echo ""
        echo $command
        echo ""
        eval $command

        # Check that command ran successfully
        # Can't use exit code directly because of piping to tee.
        exit_code=${PIPESTATUS[0]}
        if [ "$exit_code" -eq 0 ]; then
            # Validation command ran to completion - still need to check for warnings/errors in stdout
            exit_code_message="$script_name: validation exited successfully with exit code 0 for study $acc_id"
        else
            # Validation failed
            exit_code_message="$script_name: validation exited due to error(s) for study $acc_id. Exit code: $exit_code"
        fi
        echo ""
        echo $exit_code_message
        echo ""
      
        # TODO: Check for errors in stderr
        n_lines_in_stderr=`wc -l < $roc_validation_stderr`
        if [ $n_lines_in_stderr -gt 0 ] || [ $exit_code -ne 0 ]; then
            error_log_message="$script_name: Error log ($roc_validation_stderr) of validation for $acc_id has content. Last 3 lines: $(tail -n 3 $roc_validation_stderr)"
        else
            error_log_message="$script_name: Error log ($roc_validation_stderr) of validation for $acc_id is empty."
        fi
        echo ""
        echo $error_log_message
        echo ""

        # Check for errors/warnings in stdout
        errors_warnings_in_output=`grep -i -E "error|warning" $roc_validation_stdout | tail -n 3`
        if [ ! -z "$errors_warnings_in_output" ]; then
            output_log_message="$script_name: Errors/warnings found in output log ($roc_validation_stdout) of validation for $acc_id. Last 3 Errors/Warnings: $errors_warnings_in_output" 
        else
            # No errors/warnings - add to next stage
            output_log_message="$script_name: No errors/warnings found in output log ($roc_validation_stdout) of validation for $acc_id. last 3 lines: $(tail -n 3 $roc_validation_stdout)." 
        fi
        echo ""
        echo $output_log_message
        echo ""

        # Decide if study is added to next stage or to failed validation list
        if [ $exit_code -eq 0 ] && [ $n_lines_in_stderr -eq 0 ] && [ -z "$errors_warnings_in_output" ] && [ -f $expected_roc_metadata_file ]; then
            echo "$script_name: Adding $acc_id to list for ROC to API stage"
            echo "$acc_id" >> ${studies_passed_roc_validation}
        else
            echo "$script_name: RO Crate of $acc_id did not pass validation -> No further processing"
            echo "$acc_id" >> ${studies_failed_roc_validation}
        fi
    fi
done

# Write message to roc-validation-log.
n_studies_presented_for_roc_validation=`wc -l < $studies_for_roc_validation_stage`
n_studies_passed_roc_validation=`wc -l < $studies_passed_roc_validation`
n_studies_failed_roc_validation=`wc -l < $studies_failed_roc_validation`

roc_validation_log="${roc_validation_dir}/roc-validation-log.txt"
echo "commands for $script_name summary." | tee $roc_validation_log
echo "" | tee -a $roc_validation_log

echo "Attempted validation of $n_studies_presented_for_roc_validation studies." | tee -a $roc_validation_log
echo "Studies passed validation: $n_studies_passed_roc_validation" | tee -a $roc_validation_log
echo "Studies failed validation: $n_studies_failed_roc_validation" | tee -a $roc_validation_log
echo "" | tee -a $roc_validation_log

echo "Further details of errors/warnings can be found in the respective study directories under $roc_validation_dir." | tee -a $roc_validation_log
echo "" | tee -a $roc_validation_log

echo "Passed validation studies ($studies_passed_roc_validation):" | tee -a $roc_validation_log
echo "" | tee -a $roc_validation_log
cat $studies_passed_roc_validation | tee -a $roc_validation_log
echo "" | tee -a $roc_validation_log

echo "Failed validation studies ($studies_failed_roc_validation):" | tee -a $roc_validation_log
echo "" | tee -a $roc_validation_log
cat $studies_failed_roc_validation | tee -a $roc_validation_log
echo "" | tee -a $roc_validation_log

echo "Ending commands for $script_name" | tee -a $roc_validation_log
echo "-------------------------------------------------------------"