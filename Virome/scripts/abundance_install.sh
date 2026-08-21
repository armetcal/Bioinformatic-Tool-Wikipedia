# CoverM installation:

# Create and activate a new conda environment
conda create -n coverm
conda activate coverm

# add the standard bioinformatics channels
# (Otherwise there are conflicts)
conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge
conda config --set channel_priority strict

# install CoverM
conda install coverm