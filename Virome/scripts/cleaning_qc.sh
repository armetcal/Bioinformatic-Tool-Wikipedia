#!/bin/bash
#SBATCH --time=01:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=1                     
#SBATCH --mem=4G
#SBATCH --job-name=multiqc
#SBATCH --output=logs/1b_preprocessing_%j.out
#SBATCH --error=logs/1b_preprocessing_%j.err

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