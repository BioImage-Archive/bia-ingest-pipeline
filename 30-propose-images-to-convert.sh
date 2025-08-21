script_name="30-propose-images-to-convert.sh"
echo  && echo "Starting commands for $script_name" && echo 

if [ $# -lt 1 ]; then
    echo "$script_name: Need working directory as an argument. Exiting."
    return
fi

work_dir=$1
ingest_pipeline_log=${work_dir}/ingest-pipeline.log

source .env
# Check if there is a list of studies to generate proposals for
studies_for_propose_image_stage="${work_dir}/studies-for-propose-image-stage.txt"

if [ ! -f $studies_for_propose_image_stage ]; then
    echo
    echo "$script_name: Did not find expected file for studies to generate proposals for ($studies_for_propose_image_stage). Exiting."
    return
elif ! grep -q . $studies_for_propose_image_stage; then
    echo
    echo "$script_name: $studies_for_propose_image_stage does not have content to process - Exiting." 
    return
fi

# Ensure that output directory has no proposals
proposal_output_dir="${work_dir}/proposals"
echo
if [ -d $proposal_output_dir ]; then
    command="\rm -rf ${proposal_output_dir}/*"
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
else
    command="mkdir ${proposal_output_dir}"
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi

studies_for_assign_image_stage="${work_dir}/studies-for-assign-image-stage.txt"
studies_with_no_proposals="${work_dir}/studies-with-no-proposals.txt"
echo
if [ -f $studies_for_assign_image_stage ]; then
    command="\rm ${studies_for_assign_image_stage}"
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi
if [ -f $studies_with_no_proposals ]; then
    command="\rm ${studies_with_no_proposals}"
    if [ "$dryrun" = "true" ]; then
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo $command
        eval $command
    fi
fi
touch $studies_for_assign_image_stage
touch $studies_with_no_proposals

# For each study to generate proposals for
assign_image_dir="${bia_integrator_dir}/bia-assign-image"
for acc_id in `cat $studies_for_propose_image_stage`
do
    # TODO: Way of checking for annotation datasets
    # For now try studies and annotations first. If no proposals, then try normal way.
    proposal_output_file="${proposal_output_dir}/${acc_id}-proposal-output.yaml"
    command="poetry --directory $assign_image_dir run bia-assign-image propose-images-and-annotations --api ${api_target} --max-items ${max_items} --no-append ${acc_id} ${proposal_output_file}"
    if [ "$dryrun" = "true" ]; then
        echo 
        echo "$script_name: Dry run. Would have run '$command'"
    else
        echo 
        echo $command
        eval $command
        # Add check that command ran successfully
        #n_proposals=`grep -P  "^\- accession_id: ${acc_id}" $proposal_output_file | wc -l`
        n_proposals=`grep -E  "^\- accession_id: ${acc_id}" $proposal_output_file | wc -l | tr -d '[:space:]'`
        if [ "$n_proposals" = "0" ]; then
            echo "$script_name: No proposals found -> Try normal way"
            command="poetry --directory $assign_image_dir run bia-assign-image propose-images --api ${api_target} --max-items ${max_items} --no-append ${acc_id} ${proposal_output_file}"
            eval $command
            # Check if proposals were found
            n_proposals=`grep -E  "^\- accession_id: ${acc_id}" $proposal_output_file | wc -l | tr -d '[:space:]'`
            if [ "$n_proposals" = "0" ]; then
                echo "$script_name: No proposals found for ${acc_id} -> No further processing"
                echo "$acc_id" >> ${studies_with_no_proposals}
            else
                echo "$script_name: ${n_proposals} proposals found"
                echo "$script_name: Adding $acc_id to list for assign image stage"
                echo "$acc_id" >> ${studies_for_assign_image_stage}
            fi
        else
            echo "$script_name: ${n_proposals} proposals found"
            echo "$script_name: Adding $acc_id to list for assign image stage"
            echo "$acc_id" >> ${studies_for_assign_image_stage}
        fi
    fi
    break
done

# Write message to ingest-pipeline-log.
# TODO: Separate studies ingested to those with warnings and no warnings.
n_studies_with_proposals=`wc -l < $studies_for_assign_image_stage`
list_of_studies_with_proposals=`tr '\n' ' ' < $studies_for_assign_image_stage`
echo >> $ingest_pipeline_log
echo "$script_name: Generated proposals for $n_studies_with_proposals studies successfully: $list_of_studies_with_proposals" | tee -a $ingest_pipeline_log

n_studies_with_no_proposals=`wc -l < $studies_with_no_proposals`
list_of_studies_with_no_proposals=`tr '\n' ' ' < $studies_with_no_proposals`
echo >> $ingest_pipeline_log
echo "$script_name: Could not generate proposals for $n_studies_with_no_proposals studies: $list_of_studies_with_no_proposals" | tee -a $ingest_pipeline_log

echo && echo "Ending commands for $script_name" && echo ""
