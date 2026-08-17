# VirSorter2:
module load apptainer
cd /project/def-bfinlay/armetcal/cmmi/apptainer_images
apptainer pull docker://jiarong/virsorter:latest

# Test it out (optional)
module load StdEnv/2023 apptainer/1.4.5
# fetch testing data
wget -O test.fa https://raw.githubusercontent.com/jiarong/VirSorter2/master/test/8seq.fa
# run classification with 4 threads (-j) and test-out as output diretory (-w)
apptainer exec \
  --bind /home/armetcal/scratch/cmmi/pilot_g4h/virome:/data \
  /project/rrg-bfinlay/armetcal/apptainer_images/virsorter_latest.sif \
virsorter run -w test.out -i test.fa --min-length 1500 -j 4 all
head test.out

#~~~~~~~~~~~~~~~~~~~

# DeepVirFinder:
module load apptainer
cd /project/def-bfinlay/armetcal/cmmi/apptainer_images
# FYI: this isn't an official image, but it works.
apptainer pull docker://mmbumcu/deepvirfinder:1.0

#~~~~~~~~~~~~~~~~~~~

# CheckV:
module load apptainer
cd /project/def-bfinlay/armetcal/cmmi/apptainer_images
apptainer pull docker://antoniopcamargo/checkv:latest

#~~~~~~~~~~~~~~~~~~~

# CAT:
# Feel free to install this somewhere better, just remember to update the paths
cd $SCRATCH
git clone https://github.com/MGXlab/CAT_pack.git
wget https://tbb.bio.uu.nl/tina/CAT_pack_prepare/20231120_CAT_gtdb.tar.gz --no-check-certificate
tar -xvzf 20231120_CAT_gtdb.tar.gz