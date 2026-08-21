#!/bin/bash
#SBATCH --time=36:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=60 
#SBATCH --mem=90G
#SBATCH --job-name=iphop
#SBATCH --array=0-16
#SBATCH --output=logs/9b_Hosts_iPHoP_compute_%A_%a.out
#SBATCH --error=logs/9b_Hosts_iPHoP_compute_%A_%a.err

# Activate conda environment
source /home/armetcal/miniconda3/etc/profile.d/conda.sh
conda activate iphop_env

SCRATCH_ROOT=/home/armetcal/scratch/cmmi/virome/mgx
VIRAL_SEQS=$SCRATCH_ROOT/mmseqs2_out/all_samples_clusters_rep_seq_clean_10kb.fasta
SAVE_LOC=$SCRATCH_ROOT/iphop_out/chunk_${SLURM_ARRAY_TASK_ID}
DB_LOC=/home/armetcal/scratch/cmmi/databases/Jun_2025_pub_rw

SEQS_PER_JOB=500

mkdir -p $SAVE_LOC

# Select the chunk of sequences for this array task:
echo "Processing array task ID: $SLURM_ARRAY_TASK_ID"
START_SEQ=$(( (SLURM_ARRAY_TASK_ID) * SEQS_PER_JOB + 1 ))
END_SEQ=$(( $START_SEQ + SEQS_PER_JOB - 1 ))
if [ $END_SEQ -gt $NUM_SEQS ]; then
    END_SEQ=$NUM_SEQS
fi
echo "Processing sequences $START_SEQ to $END_SEQ"

# Extract the chunk of sequences into a temporary FASTA file:
CHUNK_LOC=$SCRATCH_ROOT/mmseqs2_out/chunks_500seqs
mkdir -p $CHUNK_LOC
CHUNK_FASTA="$CHUNK_LOC/chunk_${SLURM_ARRAY_TASK_ID}.fasta"
awk -v start="$START_SEQ" -v end="$END_SEQ" 'BEGIN {seq_count=0; print_seq=0} /^>/ {seq_count++; print_seq=(seq_count >= start && seq_count <= end)} print_seq' "$VIRAL_SEQS" > "$CHUNK_FASTA"

# Then run the first step of iPHoP (compute)
iphop predict --fa_file $CHUNK_FASTA \
    --out_dir $SAVE_LOC \
    --db_dir $DB_LOC \
    --num_threads $SLURM_CPUS_PER_TASK \
    --step compute \
    --single_thread_wish \
    --debug

echo "Raw iPHoP host predictions computed for chunk ${SLURM_ARRAY_TASK_ID}. Results saved to: $SAVE_LOC"
