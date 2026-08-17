#!/bin/bash
#SBATCH --time=6:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=4                     
#SBATCH --mem=32G
#SBATCH --job-name=deepvirfinder
#SBATCH --array=0-30 
#SBATCH --output=logs/3b_deepvirfinder_%A_%a.out   # Per-array task log
#SBATCH --error=logs/3b_deepvirfinder_%A_%a.err  # Per-array task error log

#~~~~~ Variables 1 ~~~~~#
MAG_VERSION="metaspades"
PROJECT_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
SAMPLE_LOC="$PROJECT_ROOT/${MAG_VERSION}_out"
#~~~~~~~~~~~~~~~~~~~~#

# Get list of unique sample names
mapfile -t FOLDERS < <(basename -a "$SAMPLE_LOC"/${MAG_VERSION}*)
# Select current sample
SAMPLE=${FOLDERS[$SLURM_ARRAY_TASK_ID]}
SAMPLE=${FOLDERS[14]}
SAMPLE_ID=$(echo "$SAMPLE" | sed "s/^${MAG_VERSION}_//")

#~~~~~~ Variables 2 ~~~~~#
SAVE_LOC="$PROJECT_ROOT/deepvirfinder_out/${SAMPLE}"
THREADS=$SLURM_CPUS_PER_TASK
# THREADS=1
IMAGE_LOC="/project/def-bfinlay/armetcal/cmmi/apptainer_images/deepvirfinder_1.0.sif"
CONTIG_LEN=1500
#~~~~~~~~~~~~~~~~~~~~#

# set -euo pipefail
set -euo pipefail

date

# Load module
module load StdEnv/2023 apptainer/1.4.5

echo "Running DeepVirFinder on sample: $SAMPLE"

# Run single job with isolated environment
# Have to remove previous caches, which can have a variety of names.
rm -rf ~/.theano
rm -rf /home/armetcal/.theano 
rm -rf /tmp/*theano*
rm -rf /tmp/dvf_*
rm -rf $SAVE_LOC/dvf_*
rm -rf $SAVE_LOC/theano_cache
rm -rf $SAVE_LOC/theano*
rm -rf $SAVE_LOC/.theano

# Create output directories
mkdir -p "$SAVE_LOC" "$SAVE_LOC/theano_cache"

apptainer exec \
  --bind "$SAMPLE_LOC/$SAMPLE/contigs.fasta:/input.fasta" \
  --bind "$SAVE_LOC:/output" \
  --bind "$SAVE_LOC/theano_cache:/theano_cache" \
  --env THEANO_FLAGS="base_compiledir=/theano_cache" \
  "$IMAGE_LOC" \
  dvf.py -i /input.fasta -o /output -l "$CONTIG_LEN" -c "$THREADS"

# Also remove the current caches here, for good measure.
rm -rf ~/.theano
rm -rf /home/armetcal/.theano 
rm -rf /tmp/*theano*
rm -rf /tmp/dvf_*
rm -rf $SAVE_LOC/dvf_*
rm -rf $SAVE_LOC/theano_cache
rm -rf $SAVE_LOC/theano*
rm -rf $SAVE_LOC/.theano

echo "Finished processing sample: $SAMPLE"
echo "DeepVirFinder output saved to: $SAVE_LOC"