# DRAM-v Installation

# This is the base yaml, but it's a bit broken:
# wget https://raw.githubusercontent.com/WrightonLabCSU/DRAM/master/environment.yaml
# We can build our own instead. 
# Go to wherever you want to store a new .yaml file (the instructions to Conda for how to make the environment):
cd /home/armetcal/projects/def-bfinlay/armetcal/cmmi/conda_envs
# Open a new file:
nano DRAM_env.yaml
# Add the following to the file:
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.10
  - pandas=1.5.2
  - pytest=7.2.0
  - setuptools=69.5.1
  - scikit-bio=0.5.7
  - prodigal=2.6.3
  - mmseqs2==13.45111
  - hmmer=3.3.2
  - trnascan-se=2.0.11
  - numpy=1.23.5
  - scipy=1.8.1
  - sqlalchemy=1.4.46
  - barrnap=0.9
  - altair=4.2.0
  - openpyxl=3.0.10
  - networkx=2.8.8
  - ruby=3.1.2
  - parallel=20221122
  - pip
  - wheel
  - pip:
    - DRAM-bio==1.5.0

# Create the environment and install DRAM-v
CONDA_OVERRIDE_CHANNELS=1 conda env create -f DRAM_env.yaml -n DRAM

# Fix the DRAM-setup.py script
# First, go into the files of the new environment and open this one:
nano /project/def-bfinlay/armetcal/cmmi/conda_envs/DRAM/bin/DRAM-setup.py

# Step 1: 
# Change the code around line 124 - you should see that one of the help lines is split across 2 lines, 
# and one helper line was displaced into the next command. Fix these up.

# Step 2: 
# Change "prepare_dbs_parser.add_argument('--dbcan_fam_activities'" to "prepare_dbs_parser.add_argument('--dbcan_fam_activities_loc'"
# And add the missing dbcan_subfam_ec_loc argument:
# prepare_dbs_parser.add_argument('--dbcan_subfam_ec_loc', default=None, help="File path to dbCAN subfamily EC annotations, if already downloaded (CAZyDB.08062022.fam.subfam.ec.txt)")
# Also change "prepare_dbs_parser.add_argument('--vog_annotations'" to "prepare_dbs_parser.add_argument('--vog_annotations_loc'"

# Step 3:
# Make sure you can run the changed script by making it executable:
chmod +x /project/def-bfinlay/armetcal/cmmi/conda_envs/DRAM/bin/DRAM-setup.py

# Next, we need to edit the database processing file:
nano /lustre06/project/6003396/armetcal/cmmi/conda_envs/DRAM/lib/python3.10/site-packages/mag_annotator/database_processing.py
# Change 
dbcan_loc=None, dbcan_fam_activities:str=None, dbcan_subfam_ec:str=None, dbcan_version=DEFAULT_DBCAN_RELEASE, to 
# to
dbcan_loc=None, dbcan_fam_activities_loc:str=None, dbcan_subfam_ec_loc:str=None, dbcan_version=DEFAULT_DBCAN_RELEASE,
# and
vogdb_loc=None, vogdb_version=DEFAULT_VOGDB_VERSION, vog_annotations=None,
# to
vogdb_loc=None, vogdb_version=DEFAULT_VOGDB_VERSION, vog_annotations_loc=None,
# Make executable:
chmod +x /project/def-bfinlay/armetcal/cmmi/conda_envs/DRAM/lib/python3.10/site-packages/mag_annotator/database_processing.py

# Next, fix the process_vogdb() function in database_processing.py because it expects the wrong file type:
nano /lustre06/project/6003396/armetcal/cmmi/conda_envs/DRAM/lib/python3.10/site-packages/mag_annotator/database_processing.py
# Replace the whole function with the following:
def process_vogdb(vog_hmm_targz, output_dir='.', logger=LOGGER, version=DEFAULT_VOGDB_VERSION, threads=1, verbose=True):
    hmm_dir = path.join(output_dir, 'vogdb_hmms')
    mkdir(hmm_dir)

    with tarfile.open(vog_hmm_targz, mode='r:*') as vogdb_targz:
        vogdb_targz.extractall(hmm_dir)

    vog_hmms = path.join(output_dir, f'vog_{version}_hmms.txt')
    hmm_files = glob(path.join(hmm_dir, '**', '*.hmm'), recursive=True)

    if len(hmm_files) == 0:
        raise ValueError(
            f'No VOG HMM files were found after extracting {vog_hmm_targz} into {hmm_dir}'
        )

    merge_files(sorted(hmm_files), vog_hmms)
    run_process(['hmmpress', '-f', vog_hmms], logger, verbose=verbose)
    LOGGER.info('VOGdb database processed')
    return {'vogdb': vog_hmms}


# FINAL PART: Setting up the databases

# Theoretically DRAM-v comes with a database setup function that'll download all the necessary files, but 
#  a) it didn't work properly for me and 
#  b) lots of compute nodes don't have internet access.
# Therefore, I strongly recommend that you just download the database files yourself: 
#    https://pro.unl.edu/dbCAN2/browse_download.php?path=Databases/V11
# Move the files into the DRAM_data/database_files/ directory, as seen in the file paths below. 
# Edit the paths if needed, and double check that all of the listed files show up.

# IMPORTANT: if the prepare-databases function fails, it will delete the dbCAN-HMMdb-V11.txt file. Super annoying, I know. 
# You will need to redownload it before re-running the script:
# wget dbCAN-HMMdb-V11.txt https://pro.unl.edu/dbCAN2/download_file.php?file=Databases/V11/dbCAN-HMMdb-V11.txt

#~~~

# Do the next part within an interactive session, within a tmux screen - it can take a long time.
# Remember to change the account name
tmux new -s dram
cd ../databases
salloc --time=5:0:0 --ntasks=1 --cpus-per-task=64 --mem-per-cpu=1G --account=def-bfinlay
conda activate DRAM

# Reset before running the prepare_databases function
rm -rf DRAM_data/compiled_database_files/

# Run the prepare_databases function. This will take a long time.
# Note that we're skipping the uniref database because it is huge - read the official docs if you want to use it.
PYTHONNOUSERSITE=1 DRAM-setup.py prepare_databases \
  --output_dir DRAM_data/compiled_database_files \
  --kofam_ko_list_loc DRAM_data/database_files/kofam_ko_list.tsv.gz \
  --kofam_hmm_loc DRAM_data/database_files/kofam_profiles.tar.gz \
  --pfam_loc DRAM_data/database_files/Pfam-A.full.gz \
  --pfam_hmm_loc DRAM_data/database_files/Pfam-A.hmm.dat.gz \
  --dbcan_loc DRAM_data/database_files/dbCAN-HMMdb-V11.txt \
  --dbcan_fam_activities_loc DRAM_data/database_files/CAZyDB.08062022.fam-activities.txt \
  --dbcan_subfam_ec_loc DRAM_data/database_files/CAZyDB.08062022.fam.subfam.ec.txt \
  --viral_loc DRAM_data/database_files/viral.1.protein.faa.gz \
  --module_step_form_loc DRAM_data/database_files/module_step_form.20260501.tsv \
  --etc_module_database_loc DRAM_data/database_files/etc_mdoule_database.20260501.tsv \
  --function_heatmap_form_loc DRAM_data/database_files/function_heatmap_form.20260501.tsv \
  --genome_summary_form_loc DRAM_data/database_files/genome_summary_form.20260501.tsv \
  --peptidase_loc DRAM_data/database_files/pepunit.lib \
  --amg_database_loc DRAM_data/database_files/amg_database.20260501.tsv \
  --vogdb_loc DRAM_data/database_files/vog.hmm.tar.gz \
  --vog_annotations_loc DRAM_data/database_files/vog_annotations_latest.tsv.gz \
  --skip_uniref \
  --threads 64