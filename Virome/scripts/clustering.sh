#!/bin/bash
#SBATCH --time=2:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=16                     
#SBATCH --mem=32G  
#SBATCH --job-name=mmseqs2
#SBATCH --output=logs/4_Clustering_mmseqs2_%j.out
#SBATCH --error=logs/4_Clustering_mmseqs2_%j.err

module load StdEnv/2023 cudacore/.12.6.3 mmseqs2/17-b804f

#~~~~~ Variables ~~~~~#
MAG_VERSION="metaspades"
SCRATCH_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
SAMPLE_LOC="$SCRATCH_ROOT/${MAG_VERSION}_out"
#~~~~~~~~~~~~~~~~~~~~#

date

# Create directories
SAVE_LOC="$SCRATCH_ROOT/mmseqs2_out"
mkdir -p "$SAVE_LOC"

echo "Collecting viral contigs from all samples..."

# Collect all viral contigs from CheckV output
ALL_CONTIGS="$SAVE_LOC/ALL_VIRAL_CONTIGS.fasta"
> "$ALL_CONTIGS"  # Clear file

# Get list of sample names
mapfile -t FOLDERS < <(basename -a "$SAMPLE_LOC"/${MAG_VERSION}*)

for SAMPLE in "${FOLDERS[@]}"; do
    CONTIG_FILE="$SCRATCH_ROOT/vOTUs/checkv_out/$SAMPLE/${SAMPLE}_all_highqual_viral.fasta"
    if [ -f "$CONTIG_FILE" ]; then
        echo "Adding contigs from $SAMPLE"
        awk -v prefix="${SAMPLE}_" '/^>/ {$0=">"prefix substr($0,2)} 1' "$CONTIG_FILE" >> "$ALL_CONTIGS"
    else
        echo "Warning: No contig file found for $SAMPLE"
    fi
done

echo "Total contigs collected:"
grep -c "^>" "$ALL_CONTIGS"

echo "Running MMseqs2 clustering on the representative sequences..."

# Run regular clustering (95% identity, 80% coverage)
mmseqs easy-cluster "$ALL_CONTIGS" \
                   "$SAVE_LOC/all_samples_clusters" \
                   "$SAVE_LOC/mmseqs_tmp" \
                   --min-seq-id 0.95 \
                   -c 0.8 \
                   --cov-mode 1 \
                   --threads $SLURM_CPUS_PER_TASK

# Clean up temporary files
rm -rf "$SAVE_LOC/mmseqs_tmp"

# Remove whitespace in headers of clustered representative sequences
awk '/^>/ {$1=$1}1' "$SAVE_LOC/all_samples_clusters_rep_seq.fasta" > "$SAVE_LOC/all_samples_clusters_rep_seq_clean.fasta"

echo "Clustering complete!"
echo "Results saved to: $SAVE_LOC"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Run CheckV on clustered representative sequences to assess quality of clusters

# Path to cleaned cluster representatives
CLUSTER_REP_CLEAN="$SAVE_LOC/all_samples_clusters_rep_seq_clean.fasta"
CHECKV_OUT="$SAVE_LOC/checkv_on_clusters"
mkdir -p "$CHECKV_OUT"

# Path to your CheckV Apptainer image (edit as needed)
CHECKV_IMAGE="/project/def-bfinlay/armetcal/cmmi/apptainer_images/checkv.sif"

echo "Running CheckV on clustered representative sequences..."

apptainer exec "$CHECKV_IMAGE" \
    checkv end_to_end "$CLUSTER_REP_CLEAN" "$CHECKV_OUT" -t $SLURM_CPUS_PER_TASK

# Check for CheckV results
if [[ -s "$CHECKV_OUT/checkv_results.tsv" ]]; then
    echo "CheckV completed successfully on cluster representatives."
    echo "Results in: $CHECKV_OUT"
else
    echo "ERROR: CheckV did not produce expected results in $CHECKV_OUT" >&2
fi

echo "CheckV run complete!"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "Separating contigs by size for downstream taxonomy..."

module load StdEnv/2023 cudacore/.12.6.3 seqkit

# 10k or above
seqkit seq -m 10000 $SAVE_LOC/all_samples_clusters_rep_seq_clean.fasta > $SAVE_LOC/all_samples_clusters_rep_seq_clean_10kb.fasta
# Below 10k
seqkit seq -M 9999 $SAVE_LOC/all_samples_clusters_rep_seq_clean.fasta > $SAVE_LOC/all_samples_clusters_rep_seq_clean_below10kb.fasta

# Print number of contigs in each category
echo "Contigs in total:"
grep -c "^>" $SAVE_LOC/all_samples_clusters_rep_seq_clean.fasta
echo "Contigs 10kb or above:"
grep -c "^>" $SAVE_LOC/all_samples_clusters_rep_seq_clean_10kb.fasta
echo "Contigs below 10kb:"
grep -c "^>" $SAVE_LOC/all_samples_clusters_rep_seq_clean_below10kb.fasta

# Show summary
echo "Cluster summary:"
ls -la "$SAVE_LOC/"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "Pipeline complete!"