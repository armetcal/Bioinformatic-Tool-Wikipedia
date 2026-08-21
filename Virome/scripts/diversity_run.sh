#!/bin/bash
#SBATCH --time=30:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=31                     
#SBATCH --mem=64G
#SBATCH --job-name=metapop
#SBATCH --output=logs/8c_Diversity_MetaPop_%j.out
#SBATCH --error=logs/8c_Diversity_MetaPop_%j.err

#~~~~~ Variables ~~~~~#
# Pre-existing
MAG_VERSION="metaspades"
SCRATCH_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
IMAGE_LOC="/home/armetcal/projects/def-bfinlay/armetcal/cmmi/apptainer_images/metapop_latest.sif"
REFERENCE_FASTA="$SCRATCH_ROOT/mmseqs2_out/all_samples_clusters_rep_seq_clean.fasta"
THREADS=$SLURM_CPUS_PER_TASK

# From previous diversity steps
METAPOP_LOC="$SCRATCH_ROOT/metapop_out"
COUNTS_FILE="$METAPOP_LOC/library_counts.tsv"
BAM_DIR="$METAPOP_LOC/bam"
REFERENCE_DIR="$METAPOP_LOC/metapop_references/"

# Newly created
GENES_LOC="$REFERENCE_DIR/genes"
SAVE_LOC="$METAPOP_LOC/diversity_out"
#~~~~~~~~~~~~~~~~~~~~#

# Move the rep-seq FASTA to its own directoy - otherwise MetaPop fails
mkdir -p $METAPOP_LOC/rep_seqs
cp $REFERENCE_FASTA $METAPOP_LOC/rep_seqs/all_samples_clusters_rep_seq_clean.fasta

# Create output directories
mkdir -p "$SAVE_LOC" "$GENES_LOC"

# Load required modules
module load StdEnv/2023 apptainer/1.4.5 prodigal/2.6.3


# Generate gene calls for each reference FASTA ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# USES A FLAG SYSTEM TO AVOID RE-RUNNING THIS STEP UNNECESSARILY
# DELETE THE FLAG FILE IF YOU WANT TO RE-RUN THIS STEP!!!!
FLAG_COMPLETION_FILE="$SCRATCH_ROOT/metapop_out/flag_completion.txt"

# Only run the gene calling step if the flag file does not exist
if [ -f "$FLAG_COMPLETION_FILE" ]; then
    echo "Gene calling has already been completed. Skipping this step."
else
    echo "Starting gene calling for each reference FASTA..."
    for fasta_file in "$REFERENCE_DIR"/*.fasta; do
        if [ -f "$fasta_file" ]; then
            base_name=$(basename "$fasta_file" .fasta)
            echo "Processing $base_name..."

            prodigal -i "$fasta_file" -d "$GENES_LOC/${base_name}.fasta" -p meta > /dev/null 2>&1
        fi
    done
    echo "Gene calling complete!"
    # Mark the completion of gene calling to avoid re-running it unnecessarily
    touch "$FLAG_COMPLETION_FILE"
fi

# Combine all gene calls into a single file
find "$GENES_LOC" -maxdepth 1 -type f -name '*.fasta' -print0 | sort -z | xargs -0 cat > "$GENES_LOC/all_genes.fasta"


# Run MetaPop on all samples together ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "Running MetaPop on all samples together..."

# Variables are defaults, except for min_cov.
apptainer exec \
    --bind /project,/home,/scratch \
    "$IMAGE_LOC" \
    metapop \
    --input_samples "$BAM_DIR" \
    --reference "$METAPOP_LOC/rep_seqs" \
    --norm "$COUNTS_FILE" \
    --genes "$GENES_LOC/all_genes.fasta" \
    --output "$SAVE_LOC" \
    --threads $THREADS \
    --id_min 95 \
    --min_len 30 \
    --min_cov 50 \
    --min_dep 10 \
    --min_obs 4 \
    --min_pct 1 \
    --min_qual 20 \
    --subsample_size 10 \
    --no_viz

echo "MetaPop analysis complete!"
echo "Results saved to: $SAVE_LOC"