#!/bin/bash
#SBATCH --time=18:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=16                     
#SBATCH --mem=90G
#SBATCH --job-name=MAG_metaspades
#SBATCH --array=0-30
#SBATCH --output=logs/2a_Assembly_metaspades_%A_%a.out   # Per-array task log
#SBATCH --error=logs/2a_Assembly_metaspades_%A_%a.err  # Per-array task error log

#~~~~~ Variables ~~~~~#
PROJECT_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
SAMPLE_LOC="$PROJECT_ROOT/hostile_out"
SAVE_LOC="$PROJECT_ROOT/metaspades_out"
LOG_DIR="$PROJECT_ROOT/logs"
THREADS=$SLURM_CPUS_PER_TASK
#~~~~~~~~~~~~~~~~~~~~#

set -euo pipefail

date

# Create output directories
mkdir -p "$SAVE_LOC" "$LOG_DIR"

# Load MetaSpades module
module load StdEnv/2023 spades/4.2.0

# Get list of unique sample prefixes
mapfile -t SAMPLES < <(basename -a "$SAMPLE_LOC"/*_R1_001.clean_1.fastq.gz | sed 's/_R1_001\.clean_1\.fastq\.gz$//')

# Select current sample
PREFIX=${SAMPLES[$SLURM_ARRAY_TASK_ID]}
R1="$SAMPLE_LOC/${PREFIX}_R1_001.clean_1.fastq.gz"
R2="$SAMPLE_LOC/${PREFIX}_R2_001.clean_2.fastq.gz"
OUT_DIR="$SAVE_LOC/metaspades_${PREFIX}"

echo "Running MetaSPAdes on sample: $PREFIX"

# Run SPADES
# Skip error correction and read assembly steps to save time, since we only care about the final contigs for downstream analysis
# Use a range of k-mer sizes to improve assembly quality, and set memory limit to prevent excessive usage
# Remove --only-assembler if you want to include error correction and read assembly steps, but be aware that it will take much longer to run
# Should be redundant, though, since I run bbduk before this step
spades.py \
    --meta \
    -1 "$R1" \
    -2 "$R2" \
    -t "$THREADS" \
    -o "$OUT_DIR" \
    -k 21,33,55,77 \
    --memory 250 \
    --only-assembler

date
echo "MetaSPAdes assembly completed for sample: $PREFIX"
echo "Running QUAST for assembly quality assessment..."

# Run QUAST on the resulting contigs - basic assembly metrics
module load StdEnv/2020 gcc/9.3.0 quast/5.2.0
metaquast.py "$OUT_DIR/contigs.fasta" -o "$OUT_DIR/quast_report"

date
echo "QUAST analysis completed for sample: $PREFIX"
echo "Identifying circular contigs with self-alignment..."

# Load MUMmer module
module load StdEnv/2023 gcc mummer seqkit

# Identify circular contigs by self-aligning the contigs and looking for end-to-start overlaps
nucmer --threads $THREADS "$OUT_DIR/contigs.fasta" "$OUT_DIR/contigs.fasta" -p "$OUT_DIR/self.${PREFIX}" >/dev/null 2>&1
show-coords -rcl "$OUT_DIR/self.${PREFIX}.delta" > "$OUT_DIR/self.${PREFIX}.coords"

# Identify circular contigs from self-alignment
CIRC_MIN_OVL=100      # minimum end-to-start overlap (bp)
CIRC_MIN_ID=95.0      # minimum percent identity for overlap

awk -v MINOVL=$CIRC_MIN_OVL -v MINID=$CIRC_MIN_ID 'NR>5 {
    start1=$1; end1=$2; start2=$3; end2=$4; len1=$5; len2=$6; id=$7;
    ref=$11; qry=$12;
    if(ref==qry) next;
    if( (start1 <= MINOVL && end2 >= (len2 - MINOVL + 1)) || (start2 <= MINOVL && end1 >= (len1 - MINOVL + 1)) ) {
        if(id+0 >= MINID) {
            print ref;
            print qry;
        }
    }
}' "$OUT_DIR/self.${PREFIX}.coords" | sort -u > "$OUT_DIR/${PREFIX}_circular_hits.txt"

# Create report: mark circular=1 for hits, 0 otherwise
echo -e "contig\tcircular" > "$OUT_DIR/${PREFIX}_circular.tsv"
seqkit seq -n "$OUT_DIR/contigs.fasta" | while read -r contig; do
    if grep -qx "$contig" "$OUT_DIR/${PREFIX}_circular_hits.txt"; then
        echo -e "${contig}\t1" >> "$OUT_DIR/${PREFIX}_circular.tsv"
    else
        echo -e "${contig}\t0" >> "$OUT_DIR/${PREFIX}_circular.tsv"
    fi
done

# Cleanup intermediates (optional)
rm -f "$OUT_DIR/self.${PREFIX}.delta" "$OUT_DIR/self.${PREFIX}.coords" "$OUT_DIR/${PREFIX}_circular_hits.txt" 2>/dev/null || true

date
echo "Finished processing sample: $PREFIX"

echo "MetaSPAdes output saved to: $OUT_DIR"
echo "QUAST report saved to: $OUT_DIR/quast_report"
echo "Circular contig report saved to: $OUT_DIR/${PREFIX}_circular.tsv"