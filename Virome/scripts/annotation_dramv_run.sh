#!/bin/bash
#SBATCH --time=48:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=16                     
#SBATCH --mem=200G
#SBATCH --job-name=dramv
#SBATCH --output=logs/7_Annotation_Functions_DRAMv.out
#SBATCH --error=logs/7_Annotation_Functions_DRAMv.err

set -euo pipefail

# all executed commands are printed to the terminal
set -x

# Step 1: Run VirSorter2 prep-for-dramv ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Variables
SCRATCH_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
INPUT_FASTA="$SCRATCH_ROOT/mmseqs2_out/all_samples_clusters_rep_seq_clean_10kb.fasta"
VIR_SORTER2_OUT="$SCRATCH_ROOT/virsorter2_prep_dramv"
IMAGE_LOC="/project/def-bfinlay/armetcal/cmmi/apptainer_images/virsorter_latest.sif"
THREADS=$SLURM_CPUS_PER_TASK

mkdir -p "$VIR_SORTER2_OUT"

module load StdEnv/2023 apptainer/1.4.5

date
echo "Running VirSorter2 prep-for-dramv on all vOTUs..."

apptainer exec $IMAGE_LOC \
virsorter run \
    --prep-for-dramv \
    --seqname-suffix-off \
    --viral-gene-enrich-off \
    --provirus-off \
    --include-groups dsDNAphage,ssDNA \
    --min-length 10000 \
    --min-score 0.5 \
    -i "$INPUT_FASTA" \
    -w "$VIR_SORTER2_OUT" \
    -j "$THREADS" \
    all \
    --verbose

echo "VirSorter2 prep-for-dramv complete."
echo "Output saved to: $VIR_SORTER2_OUT"

# Step 2: Run DRAM-v globally ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#~~~~~ Variables 1 ~~~~~#
MAG_VERSION="metaspades"
SAVE_LOC="$SCRATCH_ROOT/dramv_out"

date

# DON'T CREATE OUTPUT DIRECTORIES IN ADVANCE - WILL CAUSE AN ERROR

source /home/armetcal/miniconda3/etc/profile.d/conda.sh
conda activate DRAM

echo "Running global DRAM-v on all representative sequences..."

# Remove any previous attempts (if applicable), otherwise it fails
rm -rf $SAVE_LOC

DRAM-v.py annotate \
  -i "$VIR_SORTER2_OUT/for-dramv/final-viral-combined-for-dramv.fa" \
  -v "$VIR_SORTER2_OUT/for-dramv/viral-affi-contigs-for-dramv.tab" \
  -o "$SAVE_LOC" \
  --min_contig_size 1000 \
  --threads $THREADS

# Step 3: Distill DRAM-v output ~~~~~~~~~~~~~~~~~~~~~~~~~~
date
echo "Distilling DRAM-v output..."
DRAM-v.py distill \
    -i "$SAVE_LOC/annotations.tsv" \
    -o "$SAVE_LOC/distill"

date
echo "DRAM-v annotation and distillation complete."
echo "Output saved to: $SAVE_LOC"
