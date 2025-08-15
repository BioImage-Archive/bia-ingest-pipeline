#!/bin/bash
#SBATCH --job-name=bia_ACCESSION_ID
#SBATCH --output=slurm_script_output/bia_ACCESSION_ID.out
#SBATCH --error=slurm_script_output/bia_ACCESSION_ID.error
#SBATCH --ntasks=1
#SBATCH --time=60:00:00
#SBATCH --mem=32GB

source set_local_env.sh

## Re-ingest
#poetry --directory $BIA_CONVERTER_DIR/../bia-ingest run biaingest ingest --persistence-mode api ACCESSION_ID
cd $BIA_CONVERTER_DIR/scripts
source assign_and_convert_images.sh ACCESSION_ID

#!/bin/bash

ACCESSION_ID=$1
submit_convert_fname="slurm_scripts/submit_convert_$ACCESSION_ID.sh"
command="cp submit_convert_template.sh $submit_convert_fname"
echo $command
eval $command
command="sed -i s/ACCESSION_ID/$ACCESSION_ID/g $submit_convert_fname"
echo $command
eval $command


#!/bin/bash

# Submit conversions so that at most n_max_conversion slurm jobs are running
n_max_conversions=3
check_interval=300

#for accession_id in $(cut -d',' -f1 accession_ids_to_process_20250215.txt)
#for accession_id in $(cut -d',' -f1 accession_ids_to_reingest_then_process_20250218.txt)
for accession_id in $(cut -d',' -f1 accession_ids_to_process_ome_zarr_zip.txt)
do
    while true; do
        n_conversions_running=$(squeue --noheader | grep bia_S | wc -l)
        if [[ "$n_conversions_running" -ge "$n_max_conversions" ]]; then
            echo "$n_conversions_running conversions running. Max is $n_max_conversions so sleeping for $check_interval seconds"
            sleep $check_interval
        else
            break
        fi
    done
    echo "processing $accession_id"
    source create_convert_script.sh $accession_id
    sbatch slurm_scripts/submit_convert_$accession_id.sh
done

