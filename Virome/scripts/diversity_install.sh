# MetaPop Installation
# Note: They're currently doing a major rehaul of the MetaPop pipeline so that it can be run through NextFlow.
# The official installation creates a new conda environment; however, this does not currently seem to work as
# not all of the packages are still available/compatible. Feel free to try it out if you want.
# Therefore, this installation is based on a .sif container and will require some fixing to get it to work.
module load StdEnv/2023 apptainer/1.4.5
cd /home/armetcal/projects/def-bfinlay/armetcal/cmmi/apptainer_images
apptainer pull docker://jinlongru/metapop:latest

