#!/bin/bash
#SBATCH --time=02:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=40                     
#SBATCH --mem=90G
#SBATCH --array=0-30 # Change to the number of samples minus one
#SBATCH --job-name=Preprocessing
#SBATCH --output=logs/1a_preprocessing_%A_%a.out   # Per-array task log
#SBATCH --error=logs/1a_preprocessing_%A_%a.err  # Per-array task error log

#~~~Variables~~~#
SAMPLE_LOC="/home/armetcal/scratch/cmmi/mgx_data/sequences"
APP_LOC="/home/armetcal/projects/def-bfinlay/armetcal/apptainer_images"
HOSTILE_LOC="$APP_LOC/hostile1.1.0.sif"
WORK_DIR="/home/armetcal/scratch/cmmi/virome/mgx"
OUT_FASTP="$WORK_DIR/fastp_out"
OUT_HOSTILE="$WORK_DIR/hostile_out"
OUT_FASTQC="$WORK_DIR/fastqc_out"
#~~~~~~~~~~~~~~~#

# Load necessary modules
module load gcc/14.3 apptainer/1.3.5 fastp/1.0.1

# Make output folders
mkdir -p "$OUT_FASTP" "$OUT_HOSTILE" "$OUT_FASTQC/raw" "$OUT_FASTQC/clean"

# PART 1 - FASTP ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get list of R1 files
FILES=($SAMPLE_LOC/*_R1_001.fastq.gz)

# Select the correct file based on SLURM_ARRAY_TASK_ID
FILE=${FILES[$SLURM_ARRAY_TASK_ID]}
sample=$(basename "$FILE" "_R1_001.fastq.gz")

echo "Processing sample: $sample"

# Run fastp
fastp \
  -i $SAMPLE_LOC/"${sample}_R1_001.fastq.gz" \
  -I $SAMPLE_LOC/"${sample}_R2_001.fastq.gz" \
  -o "${OUT_FASTP}/${sample}_R1_001.fastq.gz" \
  -O "${OUT_FASTP}/${sample}_R2_001.fastq.gz" \
  --low_complexity_filter \
  --cut_front --cut_front_window_size=1 --cut_front_mean_quality=3 \
  --cut_tail --cut_tail_window_size=1 --cut_tail_mean_quality=3 \
  --cut_right --cut_right_window_size=4 --cut_right_mean_quality=15 \
  --length_required=36 \
  --thread $SLURM_CPUS_PER_TASK \
  --verbose

echo "Finished FASTP for $sample"

# PART 2 - HOSTILE ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Run hostile inside the SIF image using the correct arguments
apptainer exec "$HOSTILE_LOC" hostile clean \
    --fastq1 "${OUT_FASTP}/${sample}_R1_001.fastq.gz" \
    --fastq2 "${OUT_FASTP}/${sample}_R2_001.fastq.gz" \
    --index human-t2t-hla.argos-bacteria-985_rs-viral-202401_ml-phage-202401 \
    --out-dir "$OUT_HOSTILE" \
    --threads $SLURM_CPUS_PER_TASK

echo "Finished HOSTILE for $sample"

# PART 3 - FASTQC QUALITY CHECKS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

module load StdEnv/2023 fastqc/0.12.1

# Raw reads
fastqc \
  --outdir="${OUT_FASTQC}/raw" \
  --threads=$SLURM_CPUS_PER_TASK \
  $SAMPLE_LOC/"${sample}_R1_001.fastq.gz" \
  $SAMPLE_LOC/"${sample}_R2_001.fastq.gz"

  # Cleaned reads
fastqc \
  --outdir="${OUT_FASTQC}/clean" \
  --threads=$SLURM_CPUS_PER_TASK \
  "${OUT_HOSTILE}/${sample}_R1_001.clean_1.fastq.gz" \
  "${OUT_HOSTILE}/${sample}_R2_001.clean_2.fastq.gz"

echo "Finished FASTQC for $sample"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "ALL THREE STEPS COMPLETED FOR SAMPLE: $sample"