#!/bin/bash
#SBATCH --time=2:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=4                     
#SBATCH --mem=32G
#SBATCH --job-name=coverm
#SBATCH --array=0-30  
#SBATCH --output=logs/6_Abundance_CoverM_%A_%a.out
#SBATCH --error=logs/6_Abundance_CoverM_%A_%a.err

#~~~~~ Variables ~~~~~#
MAG_VERSION="metaspades"
SCRATCH_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
READ_LOC="$SCRATCH_ROOT/hostile_out"
SAMPLE_LOC="$SCRATCH_ROOT/${MAG_VERSION}_out"
SAVE_LOC="$SCRATCH_ROOT/coverm_out"
#~~~~~~~~~~~~~~~~~~~~#

# Get list of all samples
mapfile -t FOLDERS < <(basename -a "$SAMPLE_LOC"/${MAG_VERSION}*)

# Select current sample
SAMPLE=${FOLDERS[$SLURM_ARRAY_TASK_ID]}
SAMPLE_ID=$(echo "$SAMPLE" | sed "s/^${MAG_VERSION}_//")

date

# Create output directories
mkdir -p "$SAVE_LOC"

# Activate the conda environment
source /home/armetcal/miniconda3/etc/profile.d/conda.sh
conda activate coverm

echo "Processing sample: $SAMPLE_ID"

# Define read files
R1="$READ_LOC/${SAMPLE_ID}_R1_001.clean_1.fastq.gz"
R2="$READ_LOC/${SAMPLE_ID}_R2_001.clean_2.fastq.gz"

# Use all clustered contigs as reference
REFERENCE_CONTIGS="$SCRATCH_ROOT/mmseqs2_out/all_samples_clusters_rep_seq_clean.fasta"

if [ ! -f "$REFERENCE_CONTIGS" ]; then
    echo "ERROR: Clustered reference contigs not found!"
    exit 1
fi

# Run CoverM for this sample
rm -rf $SAVE_LOC/bam_cache_$SAMPLE_ID "$SAVE_LOC/${SAMPLE_ID}_abundance.tsv"
coverm contig \
    --coupled "$R1" "$R2" \
    --reference "$REFERENCE_CONTIGS" \
    --min-read-percent-identity 0.95 \
    --min-read-aligned-percent 0.75 \
    --min-covered-fraction 0.7 \
    -m trimmed_mean \
    --bam-file-cache-directory "$SAVE_LOC/bam_cache_$SAMPLE_ID" \
    --discard-unmapped \
    -t $SLURM_CPUS_PER_TASK > "$SAVE_LOC/${SAMPLE_ID}_abundance.tsv"

echo "Completed sample: $SAMPLE_ID"
echo "Results saved to: $SAVE_LOC/${SAMPLE_ID}_abundance.tsv"