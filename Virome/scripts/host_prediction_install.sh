# Installation takes a long time, so I recommend doing it in a tmux session.
# You can detach from the session and come back to it later without interrupting the installation.
# see tmuxcheatsheet.com for all the commands

# Start new tmux session
tmux new -s iphop

# Create a new conda environment 
# (note that I keep my conda environments in a separate directory to avoid hitting the file limit in my home directory)
cd /home/armetcal/projects/def-bfinlay/armetcal/cmmi/conda_envs
conda create -n iphop_env python=3.8 mamba
conda activate iphop_env

# Install iPHoP from bioconda
mamba install -c conda-forge -c bioconda iphop

# test install
iphop -h

# Download databases
mkdir -p /home/armetcal/projects/def-bfinlay/armetcal/databases/iphop
iphop download --db_dir /home/armetcal/projects/def-bfinlay/armetcal/databases/iphop

# To verify if the database integrity (after having downloaded and extracted)
iphop download --db_dir /home/armetcal/projects/def-bfinlay/armetcal/databases/iphop --full_verify

# If you already downloaded the database and just need to extract it, just do it manually with the following code.
# I don't think you can run the --full_verify on it because the extraction won't have the md5s (?).
#tar -xzf /home/armetcal/projects/def-bfinlay/armetcal/databases/iphop/iPHoP_db_Jun25_rw.tar.gz -C /home/armetcal/scratch/cmmi/databases