#!/bin/bash
#SBATCH --job-name=cat
#SBATCH --output=logs/3d_Binning_CAT_%A_%a.out
#SBATCH --error=logs/3d_Binning_CAT_%A_%a.err
#SBATCH --time=06:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --array=0-30

#~~~Variables~~~#
PROJECT_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
SAMPLE_LOC="$PROJECT_ROOT/metaspades_out"
MAG_VERSION="metaspades"
CAND_DIR="$PROJECT_ROOT/vOTUs/candidates"
CLASS_DIR="$PROJECT_ROOT/vOTUs/classified"
OUT_DIR="$PROJECT_ROOT/vOTUs/cat"
CAT_BIN="$SCRATCH/CAT_pack/cat.py"
CAT_DB_DIR="$SCRATCH/20231120_CAT_gtdb"
#~~~~~~~~~~~~~~~#

module load seqkit

# Sample selection
mapfile -t FOLDERS < <(basename -a "$SAMPLE_LOC"/${MAG_VERSION}*)
SAMPLE=${FOLDERS[$SLURM_ARRAY_TASK_ID]}
# SAMPLE=${FOLDERS[0]}
SAMPLE_ID=$(echo "$SAMPLE" | sed "s/^${MAG_VERSION}_//")
echo "Processing sample: $SAMPLE_ID"

# Paths
SAMPLE_CAND_DIR="${CAND_DIR}/${SAMPLE}"
SAMPLE_CLASS_DIR="${CLASS_DIR}/${SAMPLE}"
AMBIG_FASTA="${SAMPLE_CLASS_DIR}/${SAMPLE}_ambiguous.fasta"
mkdir -p $OUT_DIR

if [[ ! -s "${AMBIG_FASTA}" ]]; then
  echo "No ambiguous FASTA found or file empty: ${AMBIG_FASTA}. Skipping."
  exit 0
fi

# Temporary working dir for CAT per sample
TMPDIR="$OUT_DIR/tmp"
mkdir -p "${TMPDIR}"

# names for CAT outputs 
CAT_PREFIX="$OUT_DIR/${SAMPLE}_ambiguous_cat"
CAT_PRODIGAL_GFF="${CAT_PREFIX}.prodigal.gff"
CAT_ANNOT="${CAT_PREFIX}.annotations"
CAT_SUM="${CAT_PREFIX}.summary.tsv"
CAT_DECISION_TSV="${CAT_PREFIX}.decision.tsv"
CAT_VIRAL_FASTA="${CAT_PREFIX}_viral.fasta"
CAT_NONVIRAL_FASTA="${CAT_PREFIX}_nonviral.fasta"

# Run CAT (gene calling + taxonomic annotation)
# Using CAT contig classification workflow: run CAT contigs with appropriate DBs.
export CAT_DATABASE_DIR="${CAT_DB_DIR}"
echo "Running CAT on ${AMBIG_FASTA}"
${CAT_BIN} contigs --processes ${SLURM_CPUS_PER_TASK} --output-dir "$OUT_DIR" --file-prefix "${SAMPLE}_ambiguous_cat" --fasta "${AMBIG_FASTA}" || { echo "CAT failed"; exit 1; }

# At this point CAT produces annotation files in the output dir. Parse gene-level taxonomy to apply 40% gene-host cutoff.
# Expected: a CAT gene table (annotations) listing contig, gene, taxon_classification.

ANNOT_FILE="$OUT_DIR/${SAMPLE}_ambiguous_cat.contigs2classification"
PRODIGAL_GFF="$OUT_DIR/${SAMPLE}_ambiguous_cat.prodigal.gff"

if [[ ! -s "${ANNOT_FILE}" ]]; then
  # Fallback: try other expected filenames
  ANNOT_FILE="$OUT_DIR/${SAMPLE}_ambiguous_cat.annotations"
fi

if [[ ! -s "${ANNOT_FILE}" ]]; then
  echo "CAT annotation file not found. Listing output dir:"
  ls -l "$OUT_DIR"
  exit 1
fi

# Parse annotations to compute per-contig gene counts and host-gene counts.
# Assumptions about ANNOT_FILE columns: gene_id, contig, best_taxon (or taxonomic lineage). Adjust awk field indices if needed.
# The parsing below treats any annotation containing "Bacteria"|"Archaea"|"Eukaryota" as host (non-viral).
awk -F"\t" '
{
  # Attempt to detect contig and taxon fields in a flexible way:
  # If file has >=3 cols, assume contig in $1 or $2 and taxon in last field.
  # Heuristic: find contig-like field containing ":" or "NODE" or "_" typical of contig names.
  # Here we assume contig in $1 and taxon in $NF if present; adjust if your CAT output differs.
  contig=$1
  tax=$NF
  gene_count[contig]++
  # classify as host if tax contains bacteria/archaea/eukaryota (case-insensitive)
  lc=tolower(tax)
  if(lc ~ /bacteria/ || lc ~ /archaea/ || lc ~ /eukaryota/ ) host_count[contig]++
}
END{
  for(c in gene_count){
    hc = (c in host_count) ? host_count[c] : 0
    pct = (hc / gene_count[c]) * 100
    high_host = (pct >= 40) ? "host_majority" : "viral_candidate"
    printf("%s\t%d\t%d\t%.1f\t%s\n", c, gene_count[c], hc, pct, high_host)
  }
}
' "${ANNOT_FILE}" > "${CAT_DECISION_TSV}.tmp"

# Split contigs into viral vs non-viral based on decision (pct_host < 40 => viral_candidate)
awk -F"\t" '$5=="viral_candidate"{print $1}' "${CAT_DECISION_TSV}" > "${CAT_PREFIX}.viral_names.txt"
awk -F"\t" '$5!="viral_candidate"{print $1}' "${CAT_DECISION_TSV}" > "${CAT_PREFIX}.nonviral_names.txt"

# Extract sequences
if [[ -s "${CAT_PREFIX}.viral_names.txt" ]]; then
  seqkit grep -n -f "${CAT_PREFIX}.viral_names.txt" "${AMBIG_FASTA}" -o "${CAT_VIRAL_FASTA}"
else
  touch "${CAT_VIRAL_FASTA}"
fi

if [[ -s "${CAT_PREFIX}.nonviral_names.txt" ]]; then
  seqkit grep -n -f "${CAT_PREFIX}.nonviral_names.txt" "${AMBIG_FASTA}" -o "${CAT_NONVIRAL_FASTA}"
else
  touch "${CAT_NONVIRAL_FASTA}"
fi

# Move final decision TSV into place
mv "${CAT_DECISION_TSV}.tmp" "${CAT_DECISION_TSV}"

# Summary log
echo "CAT classification completed for ${SAMPLE_ID}"
echo "Annotated file: ${ANNOT_FILE}"
echo "Decision TSV: ${CAT_DECISION_TSV}"
echo "Viral FASTA: ${CAT_VIRAL_FASTA}"
echo "Non-viral FASTA: ${CAT_NONVIRAL_FASTA}"
echo "Names: ${CAT_PREFIX}.viral_names.txt , ${CAT_PREFIX}.nonviral_names.txt"

# Cleanup temp
rm -rf "${TMPDIR}" || true
