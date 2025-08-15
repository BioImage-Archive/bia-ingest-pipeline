script_name="10-find-studies.sh"
echo "" && echo "Starting commands for $script_name" && echo ""

if [ $# -lt 1 ]; then
    echo "Need working directory as an argument. Exiting."
    return
elif [ ! -d $1 ]; then
    echo "$script_name: Directory $1 does not exist.Exiting."
    return
fi

work_dir=$1
ingest_pipeline_log=${work_dir}/ingest-pipeline.log
source .env
# Find studies to ingest
ingest_dir="${bia_integrator_dir}/bia-ingest"
studies_for_ingest_stage="${work_dir}/studies-for-ingest-stage.txt"

command="touch $studies_for_ingest_stage"
command="$command && poetry --directory $ingest_dir run biaingest find new-biostudies-studies --output_file $studies_for_ingest_stage"
if [ -f $studies_for_ingest_stage ]; then
    command="\rm $studies_for_ingest_stage && ${command}"
fi


if [ "$dryrun" = "true" ]; then
    echo "Dry run. Would have run '$command'"
else
    echo $command
    eval $command
    # Add check that command ran successfully
    if [ ! "$?" = "0" ]; then
        echo "$script_name: Error running $command." | tee --append $ingest_pipeline_log
        return
    elif ! grep -q . $studies_for_ingest_stage; then
        echo "$script_name: Found 0 studies to ingest." | tee --append $ingest_pipeline_log
        return
    fi
    # Remove exclude list from studies-to-ingest
    studies_for_ingest_stage_sorted="${studies_for_ingest_stage}_sorted"
    studies_to_exclude_from_ingest="${pipeline_dir}/studies-to-exclude-from-ingest.txt"
    command="sort $studies_for_ingest_stage > $studies_for_ingest_stage_sorted"
    echo ""
    echo $command
    eval $command
    
    command="comm -23 $studies_for_ingest_stage_sorted $studies_to_exclude_from_ingest > $studies_for_ingest_stage"
    echo ""
    echo $command
    eval $command

    command="\rm $studies_for_ingest_stage_sorted"
    echo ""
    echo $command
    eval $command

    # Write message to ingest-pipeline-log
    n_studies_to_ingest=`wc -l < $studies_for_ingest_stage`
    list_of_studies_to_ingest=`tr '\n' ' ' < $studies_for_ingest_stage`
    echo "$script_name: Found $n_studies_to_ingest studies to ingest: $list_of_studies_to_ingest" | tee --append $ingest_pipeline_log

fi

echo "" && echo "Ending commands for $script_name" && echo ""