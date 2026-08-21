#!/bin/bash
#SBATCH --time=01:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=1                     
#SBATCH --mem=4G
#SBATCH --job-name=multiqc
#SBATCH --output=logs/1b_preprocessing_%j.out
#SBATCH --error=logs/1b_preprocessing_%j.err

# Part 1: Run MultiQC on FastQC outputs

#~~~Variables~~~#
WORK_DIR="/home/armetcal/scratch/cmmi/virome/mgx/fastqc_out"
APP_LOC="/home/armetcal/projects/def-bfinlay/armetcal/apptainer_images/"
MULTIQC_LOC="$APP_LOC/multiqc_latest.sif"
#~~~~~~~~~~~~~~~#

# Load Apptainer
module load gcc/14.3 apptainer/1.3.5

# Run MultiQC on all FastQC zip/html files

# Raw
apptainer exec \
  --bind $WORK_DIR/raw:/data \
  --workdir /data \
  $MULTIQC_LOC \
  multiqc /data \
  -o /data

# CLean
apptainer exec \
  --bind $WORK_DIR/clean:/data \
  --workdir /data \
  $MULTIQC_LOC \
  multiqc /data \
  -o /data

echo "MultiQC report generated."

# Part 2: Generate library counts file

#~~~~~ Variables ~~~~#
SCRATCH_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
READ_LOC="$SCRATCH_ROOT/hostile_out"
COUNTS_FILE="$SCRATCH_ROOT/clean_read_counts.tsv"
#~~~~~~~~~~~~~~~~~~~~#

# Get list of unique sample names
# Mapfile should be a built-in bash command
mapfile -t FOLDERS < <(basename -a "$READ_LOC"/*)

# Create library counts file with actual read counts
# Each fastq entry has 4 lines, so count lines and divide by 4
  #   If you're worried about this at all, you can also extract read 
  #   counts non-programatically from the multiqc output.

echo -e "Sample_Name\tNumber_Reads" > "$COUNTS_FILE"

for SAMPLE in "${FOLDERS[@]}"; do
    SAMPLE=${FOLDERS[0]}
    echo ${SAMPLE}
    READ_COUNT=$(zcat "$SAMPLE" | wc -l | awk '{print int($1/4)}')
    echo -e "${SAMPLE}\t${READ_COUNT}" >> "$COUNTS_FILE"
    echo "Added read count for ${SAMPLE} with ${READ_COUNT} reads"
done

echo "All clean reads counted. Output saved to: $COUNTS_FILE"