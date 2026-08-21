#!/bin/bash
#SBATCH --time=2:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=8                     
#SBATCH --mem=1G
#SBATCH --job-name=metapop_norm
#SBATCH --output=logs/8b_Diversity_MetaPop_%j.out
#SBATCH --error=logs/8b_Diversity_MetaPop_%j.err

#~~~~~ Variables ~~~~~#
MAG_VERSION="metaspades"
SCRATCH_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
READ_LOC="$SCRATCH_ROOT/hostile_out"
SAMPLE_LOC="$SCRATCH_ROOT/${MAG_VERSION}_out"
REFERENCE_CONTIGS="$SCRATCH_ROOT/mmseqs2_out/all_samples_clusters_rep_seq_clean.fasta"
THREADS=$SLURM_CPUS_PER_TASK
#~~~~~~~~~~~~~~~~~~~~#

# Get list of unique sample names
# Mapfile should be a built-in bash command
mapfile -t FOLDERS < <(basename -a "$SAMPLE_LOC"/${MAG_VERSION}*)

# Create a library counts file for MetaPop ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  Can't use the original clean reads count file - MetaPop has special naming requirements
COUNTS_FILE="$SCRATCH_ROOT/metapop_out/library_counts.tsv"
echo -e "Sample_Name\tNumber_Reads" > "$COUNTS_FILE"

for SAMPLE in "${FOLDERS[@]}"; do
    SAMPLE_ID=$(echo "$SAMPLE" | sed "s/^${MAG_VERSION}_//")
    R1="$READ_LOC/${SAMPLE_ID}_R1_001.clean_1.fastq.gz"

    if [ -f "$R1" ]; then
        # Count reads in R1 file (divide by 4 for FASTQ format)
        READ_COUNT=$(zcat "$R1" | wc -l | awk '{print int($1/4)}')
        # Use the full SAMPLE name (with MAG_VERSION_ prefix) so it matches BAM basenames
        echo -e "${SAMPLE}\t${READ_COUNT}" >> "$COUNTS_FILE"
        echo "Added sample ${SAMPLE} with ${READ_COUNT} reads"
    else
        echo "Warning: Read file not found for sample ${SAMPLE} (expected $R1)"
    fi
done
echo "Output saved to: $COUNTS_FILE"

# Split the clustered contigs into individual files ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Create directory for individual reference FASTAs
REFERENCE_DIR="$SCRATCH_ROOT/metapop_out/metapop_references"
mkdir -p "$REFERENCE_DIR"

# Check for duplicate contig IDs in the reference FASTA
# (There shouldn't be, but checking just in case)
echo "Checking for duplicate contig IDs in reference FASTA..."
grep '^>' "$REFERENCE_CONTIGS" | sed 's/^>//; s/[[:space:]]*$//' | sort | uniq -c | awk '$1>1'

# Split FASTA file into individual sequences using awk
awk -v dir="$REFERENCE_DIR" '
  /^>/ {
    line=$0
    sub(/^>/,"",line)
    split(line, a, /[[:space:]]+/)
    id=a[1]
    # get rest of header after the first token
    rest = substr($0, index($0, a[1]) + length(a[1]))
    # trim leading/trailing whitespace from rest
    sub(/^[[:space:]]+/, "", rest)
    sub(/[[:space:]]+$/, "", rest)
    if (fname) close(fname)
    fname = dir "/" id ".fasta"
    if (rest == "") {
      print ">" id > fname
    } else {
      print ">" id " " rest > fname
    }
    next
  }
  { print >> fname }' "$REFERENCE_CONTIGS"

echo "Split $(grep -c "^>" "$REFERENCE_CONTIGS") contigs into individual FASTA files"

echo "First 5 files in $REFERENCE_DIR:"
ls -la "$REFERENCE_DIR" | head -5



