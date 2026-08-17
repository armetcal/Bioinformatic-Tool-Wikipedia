# Install hostile into your desired directory

# Hostile:
# Change to your desired directory
cd /home/armetcal/projects/def-bfinlay/armetcal/apptainer_images
# Load apptainer and supporting gcc module
module load gcc/14.3 apptainer/1.3.5
# Download the sif file and give it an appropriate name
apptainer pull hostile1.1.0.sif docker://quay.io/biocontainers/hostile:1.1.0--pyhdfd78af_0
# Change to the directory where you want to store the Hostile databases
cd /home/armetcal/scratch/cmmi/databases
# Set HOSTILE_LOC to the location of the Hostile .sif file
HOSTILE_LOC="/home/armetcal/projects/def-bfinlay/armetcal/apptainer_images/hostile1.1.0.sif"
# Use hostile's fetch command to download the desired reference database
apptainer exec "$HOSTILE_LOC" hostile fetch \
--name human-t2t-hla.argos-bacteria-985_rs-viral-202401_ml-phage-202401

# MultiQC:
# Change to your desired directory
cd /home/armetcal/projects/def-bfinlay/armetcal/apptainer_images
# Load apptainer and supporting gcc module
module load gcc/14.3 apptainer/1.3.5
# Download the sif file and give it an appropriate name
apptainer pull multiqc_latest.sif docker://multiqc/multiqc:latest
