#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/*
 * BioImage Archive Ingest Pipeline
 * Orchestrates the full ingest workflow from finding studies to converting images
 */

params.work_dir = "${params.work_dir_base}/${workflow.start.format('yyyy-MM-dd_HH-mm-ss')}"
params.max_items = 10
params.n_to_ingest = 1000
params.persistence_mode = "api"
params.api_target = "prod"
params.dryrun = false

log.info """\
    BIA INGEST PIPELINE
    ===================
    work_dir         : ${params.work_dir}
    api_target       : ${params.api_target}
    max_items        : ${params.max_items}
    n_to_ingest      : ${params.n_to_ingest}
    dryrun           : ${params.dryrun}
    """
    .stripIndent()

/*
 * Process 1: Find new studies from BioStudies
 */
process FIND_STUDIES {
    publishDir "${params.work_dir}", mode: 'copy'

    output:
    path "studies-for-ingest-stage.txt", emit: studies
    path "ingest-pipeline.log", emit: log

    script:
    """
    # Find new studies
    poetry --directory ${params.bia_integrator_dir}/bia-ingest run biaingest find new-biostudies-studies --output_file studies-for-ingest-stage.txt

    # Remove excluded studies
    sort studies-for-ingest-stage.txt > studies_sorted.txt
    sort ${params.pipeline_dir}/studies-to-exclude-from-ingest.txt > exclude_sorted.txt
    comm -23 studies_sorted.txt exclude_sorted.txt > studies-for-ingest-stage.txt

    # Log results
    n_studies=\$(wc -l < studies-for-ingest-stage.txt)
    echo "Found \${n_studies} studies to ingest: \$(cat studies-for-ingest-stage.txt | tr '\\n' ' ')" | tee ingest-pipeline.log
    """
}

/*
 * Process 2: Ingest individual study
 */
process INGEST_STUDY {
    tag "${accession_id}"
    publishDir "${params.work_dir}/ingest_report", mode: 'copy', pattern: "*-ingest-report.txt"

    input:
    val accession_id

    output:
    tuple val(accession_id), path("${accession_id}-ingest-report.txt"), emit: report

    script:
    """
    poetry --directory ${params.bia_integrator_dir}/bia-ingest run biaingest ingest \
        -pm ${params.persistence_mode} \
        --process-filelist always \
        ${accession_id} 2>&1 | tee ${accession_id}-ingest-report.txt
    """
}

/*
 * Process 3: Check ingest success
 */
process CHECK_INGEST_SUCCESS {
    tag "${accession_id}"

    input:
    tuple val(accession_id), path(report)

    output:
    path("success.txt"), emit: success, optional: true
    path("failed.txt"), emit: failed, optional: true

    script:
    """
    if grep -E "^│ ${accession_id}.*Success.* │[[:space:]]+│" ${report}; then
        echo "${accession_id}" > success.txt
    else
        echo "${accession_id}" > failed.txt
    fi
    """
}

/*
 * Process 4: Propose images for conversion
 */
process PROPOSE_IMAGES {
    tag "${accession_id}"
    publishDir "${params.work_dir}/proposals", mode: 'copy', pattern: "*.yaml"

    input:
    val accession_id

    output:
    tuple val(accession_id), path("${accession_id}-proposal-output.yaml"), emit: proposal

    script:
    """
    # Try images-and-annotations first
    poetry --directory ${params.bia_integrator_dir}/bia-assign-image run bia-assign-image \
        propose-images-and-annotations \
        --api ${params.api_target} \
        --max-items ${params.max_items} \
        --no-append \
        ${accession_id} \
        ${accession_id}-proposal-output.yaml

    # If no proposals, try regular images
    n_proposals=\$(grep -E "^- accession_id: ${accession_id}" ${accession_id}-proposal-output.yaml | wc -l | tr -d '[:space:]')
    if [ "\$n_proposals" = "0" ]; then
        poetry --directory ${params.bia_integrator_dir}/bia-assign-image run bia-assign-image \
            propose-images \
            --api ${params.api_target} \
            --max-items ${params.max_items} \
            --no-append \
            ${accession_id} \
            ${accession_id}-proposal-output.yaml
    fi

    # Verify proposals exist
    n_proposals=\$(grep -E "^- accession_id: ${accession_id}" ${accession_id}-proposal-output.yaml | wc -l | tr -d '[:space:]')
    if [ "\$n_proposals" = "0" ]; then
        echo "No proposals found for ${accession_id}"
        exit 1
    fi
    echo "Found \${n_proposals} proposals for ${accession_id}"
    """
}

/*
 * Process 5: Assign and convert images (main conversion logic)
 */
process ASSIGN_AND_CONVERT {
    tag "${accession_id}"
    publishDir "${params.work_dir}/assign_and_convert/logs/${accession_id}", mode: 'copy', pattern: "*.txt"

    // Use more resources for conversion
    label 'conversion'

    input:
    tuple val(accession_id), path(proposal)

    output:
    path "*.txt", emit: logs

    script:
    """
    # Export environment variables for conversion
    export BIA_API_BASEPATH=${params.bia_api_basepath}
    export BIA_API_USERNAME=${params.bia_api_username}
    export BIA_API_PASSWORD=${params.bia_api_password}
    export cache_root_dirpath=${params.cache_root_dirpath}
    export bioformats2raw_bin=${params.bioformats2raw_bin}
    export bioformats2raw_java_home=${params.bioformats2raw_java_home}
    export EMBASSY_S3=${params.embassy_s3}
    export bucket_name=${params.bucket_name}
    export AWS_ACCESS_KEY_ID=${params.aws_access_key_id}
    export AWS_SECRET_ACCESS_KEY=${params.aws_secret_access_key}
    export AWS_REQUEST_CHECKSUM_CALCULATION=${params.aws_request_checksum_calculation}
    export AWS_RESPONSE_CHECKSUM_VALIDATION=${params.aws_response_checksum_validation}

    # Assign images from proposal
    poetry --directory ${params.bia_integrator_dir}/bia-assign-image run bia-assign-image \
        assign-from-proposal \
        --api ${params.api_target} \
        ${proposal} 2>&1 | tee assign_from_proposal_output.txt

    # Convert each image representation
    uploaded_by_submitter_uuids=\$(grep "Persisted image_representation" assign_from_proposal_output.txt | cut -d' ' -f3)
    n_images_converted=0

    for uploaded_by_submitter_uuid in \$uploaded_by_submitter_uuids; do
        # Determine conversion function based on format
        image_format=\$(curl "${params.bia_api_basepath}/v2/image_representation/\$uploaded_by_submitter_uuid" | grep -o '"image_format":"[^"]*"')

        if [[ "\$image_format" == '"image_format":".ome.zarr.zip"' ]]; then
            conversion_function="convert_zipped_ome_zarr_archive"
        else
            conversion_function="convert_uploaded_by_submitter_to_interactive_display"
        fi

        # Convert to interactive display
        poetry --directory ${params.bia_integrator_dir}/bia-converter run bia-converter convert \
            --api ${params.api_target} \
            \$uploaded_by_submitter_uuid \
            \$conversion_function 2>&1 | tee convert_to_interactive_display_output_\${uploaded_by_submitter_uuid}.txt

        if [ \${PIPESTATUS[0]} -eq 0 ]; then
            ((n_images_converted++))

            # Extract interactive display UUID
            interactive_display_uuid=\$(grep -oP 'Created image representation for converted image with uuid: \\K[0-9a-fA-F-]+' convert_to_interactive_display_output_\${uploaded_by_submitter_uuid}.txt)
            if [ -z \$interactive_display_uuid ]; then
                interactive_display_uuid=\$(grep -oP '/\\K[0-9a-fA-F-]+\\.ome' convert_to_interactive_display_output_\${uploaded_by_submitter_uuid}.txt | uniq | sed 's/\\.ome//')
            fi

            # For first image, create static display and update example image URI
            if [ "\$n_images_converted" -eq 1 ]; then
                poetry --directory ${params.bia_integrator_dir}/bia-converter run bia-converter create-static-display \
                    --api ${params.api_target} \
                    \$interactive_display_uuid 2>&1 | tee convert_to_static_display_output_\${interactive_display_uuid}.txt

                image_uuid=\$(grep -oP 'COMPLETE.*bia_data_model.Image \\K[0-9a-fA-F-]+' assign_from_proposal_output.txt | head -n 1)
                poetry --directory ${params.bia_integrator_dir}/bia-converter run python \
                    ${params.bia_integrator_dir}/bia-converter/scripts/update_example_image_uri_for_dataset.py \
                    --api ${params.api_target} \
                    --update-mode replace \
                    \$image_uuid
            fi

            # Create thumbnail
            poetry --directory ${params.bia_integrator_dir}/bia-converter run bia-converter create-thumbnail \
                --api ${params.api_target} \
                \$interactive_display_uuid 2>&1 | tee convert_to_thumbnail_output_\${interactive_display_uuid}.txt
        fi
    done

    echo "Converted \${n_images_converted} images for ${accession_id}"
    """
}

/*
 * Process 6: Send Slack notification
 */
process SEND_SLACK_NOTIFICATION {
    input:
    path log_file
    val subject

    script:
    """
    cat ${log_file} | mail -s "${subject}" ${params.slack_recipient}
    """
}

/*
 * Main workflow
 */
workflow {
    // Stage 1: Find studies
    FIND_STUDIES()

    // Parse studies file into channel
    studies_ch = FIND_STUDIES.out.studies
        .splitText()
        .map { it.trim() }
        .filter { it.length() > 0 }
        .take(params.n_to_ingest)

    // Stage 2: Ingest studies in parallel
    INGEST_STUDY(studies_ch)

    // Stage 3: Check ingest results
    CHECK_INGEST_SUCCESS(INGEST_STUDY.out.report)

    // Collect successful ingests
    successful_studies = CHECK_INGEST_SUCCESS.out.success
        .splitText()
        .map { it.trim() }
        .filter { it.length() > 0 }

    // Stage 4: Propose images for successful studies
    PROPOSE_IMAGES(successful_studies)

    // Filter out failed proposals
    successful_proposals = PROPOSE_IMAGES.out.proposal

    // Stage 5: Manual approval gate
    // In practice, you'd pause here and manually review proposals
    // For now, we'll just log a message
    successful_proposals
        .collect()
        .subscribe {
            log.info """

            ========================================
            MANUAL REVIEW REQUIRED
            ========================================
            Proposals have been generated in: ${params.work_dir}/proposals

            Review and modify proposals as needed, then run:

            nextflow run main.nf -entry CONVERSION_WORKFLOW --proposals_dir ${params.work_dir}/proposals

            ========================================
            """
        }

    // Stage 6: Send Slack notification about ingest completion
    SEND_SLACK_NOTIFICATION(
        FIND_STUDIES.out.log,
        "BIA Ingest Pipeline completed - ${workflow.start.format('yyyy-MM-dd HH:mm:ss')}"
    )
}

/*
 * Separate workflow for conversion (run after manual approval)
 */
workflow CONVERSION_WORKFLOW {
    // Get approved proposals from directory
    proposals_ch = Channel
        .fromPath("${params.proposals_dir}/*.yaml")
        .map { file ->
            def accession = file.name.replaceAll(/-proposal-output\.yaml$/, '')
            tuple(accession, file)
        }

    // Run conversion
    ASSIGN_AND_CONVERT(proposals_ch)
}
