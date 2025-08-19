#!/bin/bash
#SBATCH --job-name=bia_JOB_NAME_SUFFIX_ACCESSION_ID
#SBATCH --output=WORK_DIR/slurm_script_output/bia_ACCESSION_ID.out
#SBATCH --error=WORK_DIR/slurm_script_output/bia_ACCESSION_ID.error
#SBATCH --ntasks=1
#SBATCH --time=60:00:00
#SBATCH --mem=32GB

source assign_and_convert_images.sh ACCESSION_ID WORK_DIR WORK_DIR/proposals/ACCESSION_ID-proposal-output.yaml