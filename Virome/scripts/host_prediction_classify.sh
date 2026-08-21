#!/bin/bash
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=60 
#SBATCH --mem=90G
#SBATCH --job-name=iphop
#SBATCH --array=0-16
#SBATCH --output=logs/9c_Hosts_iPHoP_classify_%A_%a.out
#SBATCH --error=logs/9c_Hosts_iPHoP_classify_%A_%a.err

SCRATCH_ROOT=/home/armetcal/scratch/cmmi/virome/mgx
VIRAL_SEQS=$SCRATCH_ROOT/mmseqs2_out/all_samples_clusters_rep_seq_clean_10kb.fasta
SAVE_LOC=$SCRATCH_ROOT/iphop_out/chunk_${SLURM_ARRAY_TASK_ID}
DB_LOC=/home/armetcal/scratch/cmmi/databases/Jun_2025_pub_rw

# Activate conda environment
source /home/armetcal/miniconda3/etc/profile.d/conda.sh
conda activate iphop_env

echo "Processing array task ID: $SLURM_ARRAY_TASK_ID"

# Use the same chunk of sequences as in the compute step
CHUNK_LOC=$SCRATCH_ROOT/mmseqs2_out/chunks_500seqs
CHUNK_FASTA="$CHUNK_LOC/chunk_${SLURM_ARRAY_TASK_ID}.fasta"

# Run the second step of iPHoP (classify)
iphop predict --fa_file $CHUNK_FASTA \
    --out_dir $SAVE_LOC \
    --db_dir $DB_LOC \
    --num_threads $SLURM_CPUS_PER_TASK \
    --step classify \
    --single_thread_wish \
    --debug

echo "iPHoP host classification completed for chunk ${SLURM_ARRAY_TASK_ID}. Results saved to: $SAVE_LOC"
echo "Once all array jobs are complete, combine the final host predictions in R."
