#!/bin/bash
#SBATCH --time=2:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=64                     
#SBATCH --mem=16G
#SBATCH --job-name=vcontact3
#SBATCH --output=logs/5c_Annotation_VContact3.out
#SBATCH --error=logs/5c_Annotation_VContact3.err 

#~~~~~ Variables 1 ~~~~~#
MAG_VERSION="metaspades"
SCRATCH_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
IMAGE_LOC="/home/armetcal/projects/def-bfinlay/armetcal/apptainer_images"
VCONTACT_LOC="$IMAGE_LOC/vcontact3.sif"
CONTIG_LIST="$SCRATCH_ROOT/mmseqs2_out/all_samples_clusters_rep_seq_clean_10kb.fasta"
SAVE_LOC="$SCRATCH_ROOT/vcontact3_out"
#~~~~~~~~~~~~~~~~~~~~#

set -euo pipefail
date

# Use VContact3 through a conda environment, if desired ~~~~~~~~~~~~
# source /home/armetcal/miniconda3/etc/profile.d/conda.sh
# conda activate vcontact3
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Run all this, otherwise there's a package conflict with python:
module purge
module load apptainer/1.4.5
# Set PYTHONPATH to prioritize container's packages
export PYTHONPATH=/opt/conda/lib/python3.11/site-packages
# Set environment variable to disable SSL verification
export PYTHONHTTPSVERIFY=0

echo "Running VContact3..."

# FYI: reduce-memory saves ~50% of required memory, but is a bit less precise
apptainer exec $VCONTACT_LOC vcontact3 run \
    --nucleotide $CONTIG_LIST \
    --db-path /home/armetcal/projects/def-bfinlay/armetcal/databases/232.json \
    --db-version 232 \
    --db-domain "prokaryotes" \
    --force-overwrite \
    --output $SAVE_LOC \
    --exports cytoscape

echo "VContact3 complete."
echo "Outputs saved to $SAVE_LOC"

apptainer exec $VCONTACT_LOC vcontact3 db_info