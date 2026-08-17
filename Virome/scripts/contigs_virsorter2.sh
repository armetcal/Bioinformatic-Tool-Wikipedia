#!/bin/bash
#SBATCH --time=12:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=16                     
#SBATCH --mem=60G
#SBATCH --job-name=virsorter2
#SBATCH --array=0-30
#SBATCH --output=logs/3a_virsorter2_%A_%a.out   # Per-array task log
#SBATCH --error=logs/3a_virsorter2_%A_%a.err  # Per-array task error log

#~~~~~ Variables 1 ~~~~~#
MAG_VERSION="metaspades"
PROJECT_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
SAMPLE_LOC="$PROJECT_ROOT/${MAG_VERSION}_out"
#~~~~~~~~~~~~~~~~~~~~#

# Get list of unique sample names
mapfile -t FOLDERS < <(basename -a "$SAMPLE_LOC"/${MAG_VERSION}*)
# Select current sample
SAMPLE=${FOLDERS[$SLURM_ARRAY_TASK_ID]}
# SAMPLE=${FOLDERS[0]}
SAMPLE_ID=$(echo "$SAMPLE" | sed "s/^${MAG_VERSION}_//")

#~~~~~~ Variables 3 ~~~~~#
SAVE_LOC="$PROJECT_ROOT/virsorter2_out/${SAMPLE}"
THREADS=$SLURM_CPUS_PER_TASK
# THREADS=1
IMAGE_LOC="/project/def-bfinlay/armetcal/cmmi/apptainer_images/virsorter_latest.sif"
#~~~~~~~~~~~~~~~~~~~~#

# set -euo pipefail
set -euo pipefail

date

# Create output directories
mkdir -p "$SAVE_LOC"

# Load module
module load StdEnv/2023 apptainer/1.4.5

echo "Running VirSorter2 on sample: $SAMPLE"

apptainer exec $IMAGE_LOC \
virsorter run \
    -w "$SAVE_LOC" \
    -i "$SAMPLE_LOC/$SAMPLE/contigs.fasta" \
    --include-groups dsDNAphage,ssDNA \
    -j "$THREADS" \
    --min-score 0.5 \
    --min-length 1500 \
    --keep-original-seq \
    all \
    --verbose

echo "Finished processing sample: $SAMPLE"
echo "VirSorter2 output saved to: $SAVE_LOC"