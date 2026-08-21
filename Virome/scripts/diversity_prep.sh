#!/bin/bash
#SBATCH --time=2:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=16                     
#SBATCH --mem=32G
#SBATCH --job-name=metapop_prep
#SBATCH --array=0-30
#SBATCH --output=logs/8a_Diversity_MetaPop_Prep_%A_%a.out
#SBATCH --error=logs/8a_Diversity_MetaPop_Prep_%A_%a.err 

#~~~~~ Variables ~~~~~#
MAG_VERSION="metaspades"
SCRATCH_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
READ_LOC="$SCRATCH_ROOT/hostile_out"
SAMPLE_LOC="$SCRATCH_ROOT/${MAG_VERSION}_out"
REFERENCE_CONTIGS="$SCRATCH_ROOT/mmseqs2_out/all_samples_clusters_rep_seq_clean.fasta"
SAVE_LOC="$SCRATCH_ROOT/metapop_out/bam"
THREADS=$SLURM_CPUS_PER_TASK
#~~~~~~~~~~~~~~~~~~~~#

# Get list of unique sample names
mapfile -t FOLDERS < <(basename -a "$SAMPLE_LOC"/${MAG_VERSION}*)
# Select current sample
SAMPLE=${FOLDERS[$SLURM_ARRAY_TASK_ID]}
#SAMPLE=${FOLDERS[0]}
SAMPLE_ID=$(echo "$SAMPLE" | sed "s/^${MAG_VERSION}_//")

# Select current sample's cleaned reads
R1="$READ_LOC/${SAMPLE_ID}_R1_001.clean_1.fastq.gz"
R2="$READ_LOC/${SAMPLE_ID}_R2_001.clean_2.fastq.gz"

module load StdEnv/2023 minimap2/2.30 samtools

# set -euo pipefail
set -euo pipefail

date

# Create output directories
mkdir -p "$SAVE_LOC"

# Map reads to clustered contigs
minimap2 -ax sr -t $THREADS \
    "$REFERENCE_CONTIGS" \
    "$R1" "$R2" | \
    samtools sort -@ "$THREADS" -o "$SAVE_LOC/${SAMPLE}.bam"
samtools index "$SAVE_LOC/${SAMPLE}.bam"

echo "Finished processing sample: $SAMPLE"
echo "minimap2 output saved to: $SAVE_LOC/${SAMPLE}.bam"