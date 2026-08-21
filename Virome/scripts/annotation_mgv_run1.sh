#!/bin/bash
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --job-name=mgv_mmseqs2
#SBATCH --output=logs/5a_Annotation_Taxonomy_MGV_MMSeqs2.out
#SBATCH --error=logs/5a_Annotation_Taxonomy_MGV_MMSeqs2.err

set -euo pipefail

module load StdEnv/2023 cudacore/.12.6.3 mmseqs2/17-b804f

# User variables - for narval, adjust paths as needed
SCRATCH_DIR="/home/armetcal/scratch/cmmi/virome/mgx"
MGV_DIR="/home/armetcal/projects/def-bfinlay/armetcal/databases/MGV_v1.0_2021_07_08"
QUERY="$SCRATCH_DIR/mmseqs2_out/all_samples_clusters_rep_seq_clean_10kb.fasta"
MGV_REPS="$MGV_DIR/mgv_votu_representatives.fna"
MGV_META="$MGV_DIR/mgv_contig_info.tsv"
OUTDIR="$SCRATCH_DIR/mgv_repseqs_out"
THREADS=$SLURM_CPUS_PER_TASK

mkdir -p "$OUTDIR"
cd "$OUTDIR"

echo "Creating MMseqs2 databases..."
mmseqs createdb "$QUERY" queryDB
mmseqs createdb "$MGV_REPS" mgvDB

echo "Running MMseqs2 search..."
mmseqs search queryDB mgvDB searchRes tmp_mmseqs --threads $THREADS --search-type 3

echo "Converting MMseqs2 results to tabular format..."
mmseqs convertalis queryDB mgvDB searchRes searchRes.m8 \
    --format-output "query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits"

# Get best hit per query (highest bitscore, then lowest evalue)
awk 'BEGIN{OFS="\t"}{if(!($1 in best) || $13>best[$1] || ($13==best[$1] && $11<e[$1])){best[$1]=$13; e[$1]=$11; line[$1]=$0}}END{for(q in line) print line[q]}' searchRes.m8 > best_hits.tsv

echo "Joining with MGV metadata..."

# Join best hits with MGV metadata (requires query, target, then metadata)
awk 'NR==FNR{meta[$1]=$0; next} {print $0, (meta[$2] ? meta[$2] : "NA")}' "$MGV_META" best_hits.tsv > best_hits_annotated.tsv

echo "Annotation complete."
echo "Results:"
echo "  - Raw MMseqs2 output: $OUTDIR/searchRes.m8"
echo "  - Best hits: $OUTDIR/best_hits.tsv"
echo "  - Best hits with MGV metadata: $OUTDIR/best_hits_annotated.tsv"