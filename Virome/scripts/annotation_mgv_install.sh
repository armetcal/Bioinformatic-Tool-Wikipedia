cd /home/armetcal/projects/def-bfinlay/armetcal/databases
mkdir -p MGV_v1.0_2021_07_08
cd MGV_v1.0_2021_07_08

# Taxonomic approach:
wget https://portal.nersc.gov/MGV/MGV_v1.0_2021_07_08/mgv_votu_representatives.fna
wget https://portal.nersc.gov/MGV/MGV_v1.0_2021_07_08/mgv_contig_info.tsv

# Functional approach:
wget https://portal.nersc.gov/MGV/MGV_v1.0_2021_07_08/mgv_proteins.faa
wget https://portal.nersc.gov/MGV/MGV_v1.0_2021_07_08/mgv_pc_info.tsv
wget https://portal.nersc.gov/MGV/MGV_v1.0_2021_07_08/mgv_pc_functions.tsv