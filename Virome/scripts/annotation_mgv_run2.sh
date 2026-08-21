#!/bin/bash
#SBATCH --time=4:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --job-name=mgv_proteinclust
#SBATCH --output=logs/5b_Annotation_Taxonomy_MGV_Protein.out
#SBATCH --error=logs/5b_Annotation_Taxonomy_MGV_Protein.err

set -euo pipefail

module load StdEnv/2023 cudacore/.12.6.3 mmseqs2/17-b804f prodigal/2.6.3

# User variables - for narval, adjust paths as needed
SCRATCH_DIR="/home/armetcal/scratch/cmmi/virome/mgx"
QUERY="$SCRATCH_DIR/mmseqs2_out/all_samples_clusters_rep_seq_clean_10kb.fasta"
OUTDIR="$SCRATCH_DIR/mgv_protein_out"
THREADS=$SLURM_CPUS_PER_TASK

MGV_DIR="/home/armetcal/projects/def-bfinlay/armetcal/databases/MGV_v1.0_2021_07_08"
MGV_PROTEINS="$MGV_DIR/mgv_proteins.faa"
MGV_PC_INFO="$MGV_DIR/mgv_pc_info.tsv"
MGV_PC_FUNCTIONS="$MGV_DIR/mgv_pc_functions.tsv"
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

mkdir -p "$OUTDIR"
cd "$OUTDIR"

echo "Predicting proteins from your vOTU representatives with Prodigal..."
prodigal -i "$QUERY" -a query_proteins.faa -p meta -q

echo "Creating MMseqs2 databases..."
mmseqs createdb query_proteins.faa queryProtDB
mmseqs createdb "$MGV_PROTEINS" mgvProtDB

echo "Running MMseqs2 search (your proteins vs MGV proteins)..."
mmseqs search queryProtDB mgvProtDB protSearchRes tmp_mmseqs --threads $THREADS --search-type 1

echo "Converting MMseqs2 results to tabular format..."
mmseqs convertalis queryProtDB mgvProtDB protSearchRes protSearchRes.m8 \
    --format-output "query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits"

# Get best hit per query protein (highest bitscore, then lowest evalue)
awk 'BEGIN{OFS="\t"}{if(!($1 in best) || $13>best[$1] || ($13==best[$1] && $11<e[$1])){best[$1]=$13; e[$1]=$11; line[$1]=$0}}END{for(q in line) print line[q]}' protSearchRes.m8 > prot_best_hits.tsv

echo "Joining with MGV protein cluster info..."

# Join prot_best_hits -> pc_id and pc_id -> function (robust to rep_id / gene_ids)
# It uses python - that's why it looks funny
python3 - <<PY
import sys
pc_info_file = "${MGV_PC_INFO}"
func_file = "${MGV_PC_FUNCTIONS}"
input_file = "prot_best_hits.tsv"
out_pc = "prot_best_hits_with_pc.tsv"
out_pc_func = "prot_best_hits_with_pc_func.tsv"

# build protein_id -> pc_id mapping from mgv_pc_info (rep_id and gene_ids)
protein_to_pc = {}
with open(pc_info_file, 'r') as f:
    header = next(f, None)
    for line in f:
        cols = line.rstrip('\n').split('\t')
        if not cols:
            continue
        pc = cols[0]
        # rep_id at col 6 (index 5) if present
        if len(cols) > 5 and cols[5]:
            protein_to_pc[cols[5]] = pc
        # gene_ids at col 7 (index 6) as comma-separated list
        if len(cols) > 6 and cols[6]:
            for gid in cols[6].split(','):
                protein_to_pc[gid] = pc

# build pc_id -> list of "db|id|description" mappings from mgv_pc_functions (col2 + col3)
pc_funcs = {}
with open(func_file, 'r') as f:
    header = next(f, None)
    for line in f:
        cols = line.rstrip('\n').split('\t')
        if len(cols) >= 3:
            pc = cols[0]
            db_id = cols[1].strip()
            desc = cols[2].strip()
            if not desc and not db_id:
                continue
            entry = db_id + '|' + desc if db_id else desc
            # initialize list if needed
            if pc not in pc_funcs:
                pc_funcs[pc] = []
            if entry not in pc_funcs[pc]:
                pc_funcs[pc].append(entry)

# read prot_best_hits.tsv and append pc_id and joined functions (all descriptions joined with '; ')
with open(input_file, 'r') as fin, open(out_pc, 'w') as fpc, open(out_pc_func, 'w') as fpf:
    for line in fin:
        line = line.rstrip('\n')
        if not line:
            continue
        cols = line.split('\t')
        target = cols[1] if len(cols) > 1 else ''
        pc = protein_to_pc.get(target, 'NA')
        if pc == 'NA':
            func = 'NA'
        else:
            func_list = pc_funcs.get(pc, [])
            func = '; '.join(func_list) if func_list else 'NA'
        fpc.write(line + '\t' + pc + '\n')
        fpf.write(line + '\t' + pc + '\t' + func + '\n')
PY

echo "Protein clustering and annotation complete."
echo "Results:"
echo "  - Raw MMseqs2 output: $OUTDIR/protSearchRes.m8"
echo "  - Best hits: $OUTDIR/prot_best_hits.tsv"
echo "  - With PC: $OUTDIR/prot_best_hits_with_pc.tsv"
echo "  - With PC and function: $OUTDIR/prot_best_hits_with_pc_func.tsv"

