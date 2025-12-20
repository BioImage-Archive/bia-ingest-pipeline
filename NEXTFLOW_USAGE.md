# Nextflow Pipeline Usage Guide

## Overview

This Nextflow implementation replaces the bash scripts with a modern workflow orchestration system that provides:
- Automatic parallelization
- Resume capability on failure
- SLURM integration
- Better error handling
- Provenance tracking
- Execution reports

## Installation

```bash
# Install Nextflow
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/

# Or via conda
conda install -c bioconda nextflow
```

## Quick Start

### 1. Run the full ingest pipeline (local)

```bash
nextflow run main.nf
```

### 2. Run on SLURM (Codon)

```bash
nextflow run main.nf -profile codon
```

### 3. Run in development mode (limited studies)

```bash
nextflow run main.nf -profile dev
```

### 4. Resume a failed run

```bash
nextflow run main.nf -resume
```

### 5. Run only the conversion workflow

After manually reviewing proposals:

```bash
nextflow run main.nf -entry CONVERSION_WORKFLOW \
    --proposals_dir /path/to/proposals
```

## Execution Profiles

### `standard` (default)
- Local execution
- Limited parallelism (4 concurrent tasks)
- Good for testing

### `slurm`
- Generic SLURM cluster
- Adjust `clusterOptions` in `nextflow.config`

### `codon`
- Configured for your Codon HPC environment
- Automatically loads required modules
- Optimized resource allocation

### `dev`
- Development/testing mode
- Processes only 2 studies
- Reduced parallelism

## Configuration

### Override parameters from command line

```bash
nextflow run main.nf \
    --n_to_ingest 50 \
    --max_items 20 \
    --api_target dev \
    --work_dir /custom/work/dir
```

### Environment variables

The pipeline reads from your existing `.env` file automatically. Key variables:
- `BIA_API_BASEPATH`, `BIA_API_USERNAME`, `BIA_API_PASSWORD`
- `bia_integrator_dir`, `pipeline_dir`
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- All other existing variables

## Workflow Stages

### Stage 1: Find Studies
- Queries BioStudies for new accessions
- Applies exclusion list
- Output: `studies-for-ingest-stage.txt`

### Stage 2: Ingest Studies (Parallel)
- Runs `biaingest` for each study
- Parallel execution (up to 10 concurrent)
- Checks for success/failure
- Output: Ingest reports per study

### Stage 3: Propose Images (Parallel)
- Generates conversion proposals
- Tries annotations first, then regular images
- Parallel execution (up to 20 concurrent)
- Output: Proposal YAML files

### Stage 4: Manual Review
- Pipeline pauses with instructions
- Review proposals in `{work_dir}/proposals`
- Move approved proposals to `proposals_to_convert/`

### Stage 5: Conversion (Parallel)
- Run separately after approval
- Assigns images, converts to multiple formats
- Uploads to S3, creates thumbnails
- Parallel but resource-limited (5 concurrent)

## Key Features

### Automatic Resume
If a run fails, Nextflow caches completed tasks:
```bash
nextflow run main.nf -resume
```

### Reports and Monitoring
After each run, check:
- `{work_dir}/reports/execution_report.html` - Resource usage, timing
- `{work_dir}/reports/timeline.html` - Visual timeline
- `{work_dir}/reports/dag.html` - Workflow graph
- `{work_dir}/reports/trace.txt` - Detailed task log

### Error Handling
- Automatic retry on failure (up to 2 times)
- Failed tasks logged but don't stop entire workflow
- Clear error messages in process logs

### Resource Management
Resources auto-scaled based on process:
- Find studies: 2 GB RAM, 30 min
- Ingest: 8 GB RAM, 4 hours
- Conversion: 16-32 GB RAM, 8-12 hours

## Comparison with Bash Scripts

| Feature | Bash Scripts | Nextflow |
|---------|-------------|----------|
| Parallelization | Manual with loops | Automatic |
| Resume on failure | None | Built-in with `-resume` |
| Resource management | Manual SLURM scripts | Declarative config |
| Progress tracking | Log files only | Web reports + logs |
| Error handling | Exit on first error | Retry + continue |
| Dependency tracking | Script ordering | Automatic DAG |
| Reproducibility | Manual documentation | Automatic provenance |

## Migration from Bash

Your existing bash scripts map to Nextflow processes:

- `10-find-studies.sh` → `FIND_STUDIES` process
- `20-ingest-studies.sh` → `INGEST_STUDY` + `CHECK_INGEST_SUCCESS` processes
- `30-propose-images-to-convert.sh` → `PROPOSE_IMAGES` process
- `56-assign-and-convert-images.sh` → `ASSIGN_AND_CONVERT` process
- `90-send-message-to-slack.sh` → `SEND_SLACK_NOTIFICATION` process

## Examples

### Process only specific studies

```bash
# Create custom study list
echo "S-BIAD123" > custom_studies.txt
echo "S-BIAD456" >> custom_studies.txt

# Modify workflow to read from this file
nextflow run main.nf --studies_file custom_studies.txt
```

### Adjust SLURM queue and resources

Edit `nextflow.config`:
```groovy
process {
    withLabel: 'conversion' {
        queue = 'gpu-queue'  // Use GPU queue
        cpus = 16
        memory = '64 GB'
        time = '24h'
    }
}
```

### Dry run / What-if analysis

```bash
# Preview what would be executed
nextflow run main.nf -preview
```

## Troubleshooting

### View logs for failed process
```bash
# Find work directory of failed process in error message
cat work/ab/cd1234.../. command.log
```

### Clean work directory
```bash
# Remove all cached work (forces fresh run)
nextflow clean -f
rm -rf work/
```

### Test single process
```bash
# Run just the find studies step
nextflow run main.nf -process FIND_STUDIES
```

## Advanced Usage

### Run scheduled conversion at 8pm

```bash
# In crontab
0 20 * * * cd /path/to/pipeline && nextflow run main.nf -entry CONVERSION_WORKFLOW
```

### Integration with existing bash scripts

You can gradually migrate - run Nextflow for ingest, bash for conversion:

```bash
# Nextflow ingest
nextflow run main.nf -profile codon

# Then run existing bash conversion
source 50-run-assign-and-convert-images.sh
```

## Next Steps

1. Review and customize `nextflow.config` for your environment
2. Test with `dev` profile on small dataset
3. Run full pipeline with `codon` profile
4. Set up scheduled conversion workflow
5. Monitor with HTML reports

## Support

- Nextflow docs: https://www.nextflow.io/docs/latest/
- nf-core best practices: https://nf-co.re/
