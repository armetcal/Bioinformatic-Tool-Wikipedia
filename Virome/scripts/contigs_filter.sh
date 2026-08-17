#!/bin/bash
#SBATCH --time=3:00:00 
#SBATCH --nodes=1
#SBATCH --ntasks=1                    
#SBATCH --cpus-per-task=8                     
#SBATCH --mem=8G
#SBATCH --job-name=3c_filtering
#SBATCH --output=logs/3c_vOTU_Filtering.out
#SBATCH --error=logs/3c_vOTU_Filtering.err

echo "Starting Step 1: Candidate Selection for viral contigs"

# Step 1: apply candidate-selection filters
# Requirement per contig:
# length >= 5 kb OR length >= 1.5 kb AND circular

# set -euo pipefail

# ---- Config ----
MAG_VERSION="metaspades"
PROJECT_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
ASSEMBLY_DIR="$PROJECT_ROOT/${MAG_VERSION}_out"
VIRSORTER_DIR="$PROJECT_ROOT/virsorter2_out/"
DVF_DIR="$PROJECT_ROOT/deepvirfinder_out/"
SAVE_LOC="$PROJECT_ROOT/vOTUs/candidates"
THREADS=$SLURM_CPUS_PER_TASK

mkdir -p "$SAVE_LOC"
module load StdEnv/2023 seqkit seqtk

# thresholds
MIN_LEN_LONG=5000
MIN_LEN_CIRC=1500
DVF_HIGH_SCORE=0.9
DVF_MED_SCORE=0.7
DVF_P=0.05
VS2_HIGH_SCORE=0.9

# Loop samples (based on assemblies)
for sample_dir in "$ASSEMBLY_DIR"/*; do
    # sample_dir="/home/armetcal/scratch/cmmi/virome/mgx/metaspades_out/metaspades_22240981101172_UDIY003_S310_L006"
    SAMPLE=$(basename "$sample_dir")
    CONTIGS="$sample_dir/contigs.fasta"
    CIRC_TSV="$sample_dir/${SAMPLE}_circular.tsv"
    VS2_SAMPLE_DIR="$VIRSORTER_DIR/${SAMPLE}"
    DVF_SAMPLE_DIR="$DVF_DIR/${SAMPLE}"
    OUT_DIR="$SAVE_LOC/${SAMPLE}"
    mkdir -p "$OUT_DIR"

    # output lists
    CAND_LIST="$OUT_DIR/${SAMPLE}_candidate_names.txt"
    CAND_FASTA="$OUT_DIR/${SAMPLE}_candidates.fasta"
    echo "# sample: $SAMPLE" > "$OUT_DIR/run.info"

    # Check inputs
    if [ ! -f "$CONTIGS" ]; then
        echo "Missing contigs.fasta for $SAMPLE" >> "$OUT_DIR/run.info"
        continue
    fi
    if [ ! -f "$CIRC_TSV" ]; then
        echo "Missing circular TSV ($CIRC_TSV) — assuming no circular contigs" >> "$OUT_DIR/run.info"
        # create empty circular file with zeros
        seqkit seq -n "$CONTIGS" | awk -v sample="$SAMPLE" '{print $0 "\t0"}' > "$CIRC_TSV"
    fi
    if [ ! -f "$DVF_SAMPLE_DIR/input.fasta_gt1500bp_dvfpred.txt" ]; then
        echo "Missing DVF file for $SAMPLE" >> "$OUT_DIR/run.info"
    fi
    if [ ! -f "$VS2_SAMPLE_DIR/final-viral-score.tsv" ]; then
        echo "Missing VirSorter2 file for $SAMPLE" >> "$OUT_DIR/run.info"
    fi

    # Prepare contig lengths
    seqkit fx2tab -l -n "$CONTIGS" | awk -F '\t' '{print $1 "\t" $2}' > "$OUT_DIR/contig_lengths.tsv"
    # contig_lengths.tsv: contig<TAB>length

    # Read circular flags into a tempfile (contig<TAB>0/1)
    cp "$CIRC_TSV" "$OUT_DIR/contig_circular.tsv"

    # Parse DeepVirFinder outputs into a lookup: name -> score,p
    # expected format: header + rows; adjust if your columns differ. Here we assume: name <tab> score <tab> p ...
    if [ -f "$DVF_SAMPLE_DIR/input.fasta_gt1500bp_dvfpred.txt" ]; then
        awk 'NR>1 {print $1 "\t" $2 "\t" $3}' "$DVF_SAMPLE_DIR/input.fasta_gt1500bp_dvfpred.txt" > "$OUT_DIR/dvf_parsed.tsv"
    else
        touch "$OUT_DIR/dvf_parsed.tsv"
    fi

    # Parse VirSorter2 into lookup: name -> score (col1 name, col4 score as specified)
    if [ -f "$VS2_SAMPLE_DIR/final-viral-score.tsv" ]; then
        awk 'NR>1 {gsub(/\|\|.*$/, "", $1); print $1 "\t" $4}' "$VS2_SAMPLE_DIR/final-viral-score.tsv" > "$OUT_DIR/vs2_parsed.tsv"
    else
        touch "$OUT_DIR/vs2_parsed.tsv"
    fi

    # Build candidate list by evaluating rules per contig
    # Join length, circular, DVF, VS2 info and test criteria.
    awk -v MIN_LONG=$MIN_LEN_LONG -v MIN_CIRC=$MIN_LEN_CIRC -v DVF_H=$DVF_HIGH_SCORE -v DVF_M=$DVF_MED_SCORE -v DVF_P=$DVF_P -v VS2_H=$VS2_HIGH_SCORE \
    'BEGIN {
        OFS="\t"
        # load DVF into array
        while((getline < "'$OUT_DIR'/dvf_parsed.tsv") > 0) {
            dvf[$1]=$2; dvf_p[$1]=$3
        }
        close("'"$OUT_DIR"'/dvf_parsed.tsv")
        # load VS2 into array
        while((getline < "'$OUT_DIR'/vs2_parsed.tsv") > 0) {
            vs2[$1]=$2
        }
        close("'"$OUT_DIR"'/vs2_parsed.tsv")
        # load circular flags
        while((getline < "'$OUT_DIR'/contig_circular.tsv") > 0) {
            circ[$1]=$2
        }
        close("'"$OUT_DIR"'/contig_circular.tsv")
    }
    {
        name=$1; len=$2
        is_circ = (name in circ) ? circ[name] : 0
        # length criterion
        if(len >= MIN_LONG || (len >= MIN_CIRC && is_circ==1)) {
            # criterion 2: any of the three sub-conditions
            c1=(name in dvf && dvf[name]+0 >= DVF_H && dvf_p[name]+0 < DVF_P) ? 1 : 0
            c2=(name in vs2 && vs2[name]+0 >= VS2_H) ? 1 : 0
            c3=(name in vs2 && (name in dvf) && dvf[name]+0 >= DVF_M && dvf_p[name]+0 < DVF_P) ? 1 : 0
            if(c1==1 || c2==1 || c3==1) {
                print name
            }
        }
    }' "$OUT_DIR/contig_lengths.tsv" > "$CAND_LIST"

    # Extract FASTA sequences for candidate contigs
    if [ -s "$CAND_LIST" ]; then
        seqtk subseq "$CONTIGS" "$CAND_LIST" > "$CAND_FASTA"
        echo "Extracted $(grep -c '^>' "$CAND_FASTA") candidate contigs for $SAMPLE" >> "$OUT_DIR/run.info"
    else
        echo "No candidates for $SAMPLE" >> "$OUT_DIR/run.info"
        touch "$CAND_FASTA"
    fi

    echo "Candidate list saved: $CAND_LIST"
    echo "Candidate fasta saved: $CAND_FASTA"
done

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "Starting Step 2: Classify candidates into high-confidence vs ambiguous"

# Step 2 — classify candidate contigs into high-confidence viral vs ambiguous
# High-confidence rules (any one):
#  A) DeepVirFinder score >= 0.9 AND p < 0.05
#  B) VirSorter2 score >= 0.9
#  C) Present in VirSorter2 AND DeepVirFinder score >= 0.7 AND p < 0.05
#
# Ambiguous = candidates that pass length/circular candidate requirements (already enforced in Step1)
#           AND do NOT meet any high-confidence rule BUT are present in candidate list (i.e., were selected by Step1).


# ---- Config ----
MAG_VERSION="metaspades"
PROJECT_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
CAND_DIR="$PROJECT_ROOT/vOTUs/candidates"
OUT_DIR_ROOT="$PROJECT_ROOT/vOTUs/classified"
THREADS=$SLURM_CPUS_PER_TASK

DVF_HIGH=0.9
DVF_MED=0.7
DVF_P=0.05
VS2_HIGH=0.9

mkdir -p "$OUT_DIR_ROOT"
module load StdEnv/2023 seqkit seqtk

for sample_dir in "$CAND_DIR"/*; do
    # sample_dir="/home/armetcal/scratch/cmmi/virome/mgx/vOTUs/candidates/metaspades_22240981101172_UDIY003_S310_L006"
    [ -d "$sample_dir" ] || continue
    SAMPLE=$(basename "$sample_dir")
    SAMPLE_OUT="$OUT_DIR_ROOT/$SAMPLE"
    mkdir -p "$SAMPLE_OUT"

    CAND_FASTA="$sample_dir/${SAMPLE}_candidates.fasta"
    CAND_NAMES="$sample_dir/${SAMPLE}_candidate_names.txt"
    DVF_PARSED="$sample_dir/dvf_parsed.tsv"
    VS2_PARSED="$sample_dir/vs2_parsed.tsv"
    LENGTHS="$sample_dir/contig_lengths.tsv"
    CIRC="$sample_dir/contig_circular.tsv"

    HIGH_NAMES="$SAMPLE_OUT/${SAMPLE}_viral_highconf.txt"
    HIGH_FASTA="$SAMPLE_OUT/${SAMPLE}_viral_highconf.fasta"
    AMBIG_NAMES="$SAMPLE_OUT/${SAMPLE}_ambiguous.txt"
    AMBIG_FASTA="$SAMPLE_OUT/${SAMPLE}_ambiguous.fasta"
    INFO_TSV="$SAMPLE_OUT/${SAMPLE}_highconf_and_ambig_info.tsv"

    # Ensure files exist (create empty placeholders if missing)
    : > "$HIGH_NAMES"
    : > "$AMBIG_NAMES"
    : > "$INFO_TSV"

    # Load DVF and VS2 lookups into awk-friendly temp files (safe if missing)
    [ -f "$DVF_PARSED" ] || touch "$DVF_PARSED"
    [ -f "$VS2_PARSED" ] || touch "$VS2_PARSED"
    [ -f "$LENGTHS" ] || touch "$LENGTHS"
    [ -f "$CIRC" ] || touch "$CIRC"

    # Build info table: for each candidate, report dvf_score, dvf_p, vs2_score, length, circular, highconf_flag
    # Candidates are those listed in CAND_NAMES
    awk -v DVF_H=$DVF_HIGH -v DVF_M=$DVF_MED -v DVF_P=$DVF_P -v VS2_H=$VS2_HIGH \
    'BEGIN{
        FS="\t"; OFS="\t";
        # load dvf
        while((getline < "'"$DVF_PARSED"'") > 0) { dvf[$1]=$2; dvf_p[$1]=$3 }
        close("'"$DVF_PARSED"'");
        # load vs2
        while((getline < "'"$VS2_PARSED"'") > 0) { vs2[$1]=$2 }
        close("'"$VS2_PARSED"'");
        # load lengths
        while((getline < "'"$LENGTHS"'") > 0) { len[$1]=$2 }
        close("'"$LENGTHS"'");
        # load circular
        while((getline < "'"$CIRC"'") > 0) { circ[$1]=$2 }
        close("'"$CIRC"'");
        print "contig","dvf_score","dvf_p","vs2_score","length","circular","highconf" > "'"$INFO_TSV"'"
    }
    {
        name=$1;
        s = (name in dvf) ? dvf[name] : "NA";
        p = (name in dvf_p) ? dvf_p[name] : "NA";
        v = (name in vs2) ? vs2[name] : "NA";
        l = (name in len) ? len[name] : "NA";
        c = (name in circ) ? circ[name] : "0";
        # Evaluate high-confidence rules
        hc=0
        if(s!="NA" && p!="NA" && s+0 >= DVF_H && p+0 < DVF_P) hc=1;
        if(v!="NA" && v+0 >= VS2_H) hc=1;
        if(v!="NA" && s!="NA" && p!="NA" && s+0 >= DVF_M && p+0 < DVF_P) hc=1;
        print name, s, p, v, l, c, hc >> "'"$INFO_TSV"'"
        # Also print to name lists
        if(hc==1) print name >> "'"$HIGH_NAMES"'"; else print name >> "'"$AMBIG_NAMES"'"
    }' "$CAND_NAMES"

    # Extract FASTAs
    if [ -s "$HIGH_NAMES" ]; then
        seqtk subseq "$CAND_FASTA" "$HIGH_NAMES" > "$HIGH_FASTA"
    else
        : > "$HIGH_FASTA"
    fi

    if [ -s "$AMBIG_NAMES" ]; then
        seqtk subseq "$CAND_FASTA" "$AMBIG_NAMES" > "$AMBIG_FASTA"
    else
        : > "$AMBIG_FASTA"
    fi

    # Summaries
    echo "Sample: $SAMPLE" > "$SAMPLE_OUT/summary.txt"
    echo "High-confidence contigs: $(wc -l < "$HIGH_NAMES" 2>/dev/null || echo 0)" >> "$SAMPLE_OUT/summary.txt"
    echo "Ambiguous contigs: $(wc -l < "$AMBIG_NAMES" 2>/dev/null || echo 0)" >> "$SAMPLE_OUT/summary.txt"
    echo "Info table: $INFO_TSV" >> "$SAMPLE_OUT/summary.txt"

    echo "Wrote high-confidence and ambiguous splits for $SAMPLE"
done

echo "Binning and filtering complete for all samples. Classified outputs saved to: $OUT_DIR_ROOT"