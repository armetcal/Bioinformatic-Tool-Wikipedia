# VContact3 Installation

# Download the software
module load apptainer
cd /home/armetcal/projects/def-bfinlay/armetcal/apptainer_images
apptainer pull vcontact3.sif docker://upnihimbb/vcontact:3.0

# Download the database
cd /home/armetcal/projects/def-bfinlay/armetcal/databases
wget https://zenodo.org/records/19198397/files/v232.tar.xz?download=1
mv v232.tar.xz?download=1 v232.tar.xz
tar -xf v232.tar.xz

# OPTIONAL ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# If the .sif file isn't working correctly, try running it within a conda environment. 
# You'll need to lightly edit the run script if you do this.

# Set it up in a new conda environment
# You can try using conda instead of mamba, but I couldn't get it to work
# FYI: if your home environment has limited space (like in Compute Canada), 
# it's possible to install new environments into a specified folder - look it up for the details
conda install mamba
mamba create --name vcontact3 python=3.10
mamba activate vcontact3
mamba install -c bioconda vcontact3 --channel-priority flexible