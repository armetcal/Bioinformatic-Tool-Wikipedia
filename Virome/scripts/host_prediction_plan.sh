# Desired number of rep-seqs analyzed per array job:
SEQS_PER_JOB=500

# Variables
SCRATCH_ROOT=/home/armetcal/scratch/cmmi/virome/mgx
VIRAL_SEQS=$SCRATCH_ROOT/mmseqs2_out/all_samples_clusters_rep_seq_clean_10kb.fasta
DB_LOC=/home/armetcal/scratch/cmmi/databases/Jun_2025_pub_rw

# Calculate the number of sequences in the input FASTA:
NUM_SEQS=$(grep -c '^>' "$VIRAL_SEQS")

NUM_JOBS=$(( (NUM_SEQS + SEQS_PER_JOB - 1) / SEQS_PER_JOB ))
echo "Total sequences: $NUM_SEQS"
echo "Sequences per job: $SEQS_PER_JOB"
echo "Number of jobs required: $NUM_JOBS"
echo "Use --array=0-$((NUM_JOBS-1)) within the iPHoP script to process all sequences."