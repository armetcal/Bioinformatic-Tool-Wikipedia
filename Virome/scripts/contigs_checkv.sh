#!/bin/bash
#SBATCH --job-name=checkv
#SBATCH --output=logs/3e_vOTU_CheckV_%A_%a.out
#SBATCH --error=logs/3e_vOTU_CheckV_%A_%a.err
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --array=0-30

set -euo pipefail

# Important: checkv_results.tsv needs to have these exact header columns:
#     contig<TAB>length<TAB>n_viral_genes<TAB>n_host_genes<TAB>pct_unknown_genes
# because these columns are used to apply the last filtering step.
# Filtering, saved contigs have any one of:
#     (i) n_viral_genes > 0
#     (ii) n_viral_genes == 0 AND n_host_genes == 0
#     (iii) length >= 1000
#     (iv) pct_unknown_genes >= 75

module load apptainer

# User-editable variables (set before submit)
WORK_DIR="/home/armetcal/scratch/cmmi/virome/mgx"
IMAGE_LOC="/project/def-bfinlay/armetcal/cmmi/apptainer_images/checkv.sif"
SAMPLE_LOC="$WORK_DIR/metaspades_out"
MAG_VERSION="metaspades"
CLASSIFIED_DIR="$WORK_DIR/vOTUs/classified"
SAVE_ROOT="$WORK_DIR/vOTUs/checkv_out"
THREADS=$SLURM_CPUS_PER_TASK

# Build sample list
mapfile -t FOLDERS < <(basename -a "$SAMPLE_LOC"/${MAG_VERSION}*)
SAMPLE=${FOLDERS[$SLURM_ARRAY_TASK_ID]}
SAMPLE_ID=$(echo "$SAMPLE" | sed "s/^${MAG_VERSION}_//")
echo "Processing sample: ${SAMPLE_ID}"

# Input FASTAs
HIGHCONF_FA="${CLASSIFIED_DIR}/${SAMPLE}/${SAMPLE}_viral_highconf.fasta"
CAT_VIRAL_FA="${CLASSIFIED_DIR}/${SAMPLE}/cat/${SAMPLE}_ambiguous_cat_viral.fasta"

# Output root per sample
OUT_DIR="${SAVE_ROOT}/${SAMPLE}"
mkdir -p "${OUT_DIR}"

# Run CheckV end_to_end on a single input (strict)
run_checkv_strict() {
  local IN_FA="$1"
  local PREFIX="$2"
  local DEST_DIR="${OUT_DIR}/${PREFIX}"
  mkdir -p "${DEST_DIR}"

  if [[ ! -s "${IN_FA}" ]]; then
    echo "ERROR: expected input FASTA not found or empty: ${IN_FA}. Skipping ${PREFIX}." >&2
    return 0
  fi

  echo "Running CheckV (end_to_end) on ${IN_FA} -> ${DEST_DIR}"
  apptainer exec "${IMAGE_LOC}" \
    checkv end_to_end "${IN_FA}" "${DEST_DIR}" -t "${THREADS}"

  # Verify expected CheckV result file exists
  local RES_TSV="${DEST_DIR}/quality_summary.tsv"
  if [[ ! -s "${RES_TSV}" ]]; then
    echo "ERROR: Expected CheckV results file not found: ${RES_TSV}" >&2
    exit 1
  fi

  # Verify required columns exist (exact header)
  head -n 1 "${RES_TSV}"

  # Prepare lists
  local RETAIN_LIST="${DEST_DIR}/${SAMPLE}_${PREFIX}_checkv_retain.txt"
  local DISCARD_LIST="${DEST_DIR}/${SAMPLE}_${PREFIX}_checkv_discard.txt"
  : > "${RETAIN_LIST}"
  : > "${DISCARD_LIST}"

  # Apply rescue rules strictly using the exact columns
  awk -F"\t" 'NR>1{
    cont=$1; len=$2+0; n_viral=$6+0; n_host=$7+0; pct_unknown=(($5 - (n_viral + n_host)) * 100)/$5;
    retain=0;
    if(n_viral > 0) retain=1;
    else if(n_viral==0 && n_host==0) retain=1;
    else if(len >= 1000) retain=1;
    else if(pct_unknown >= 75) retain=1;
    if(retain==1) print cont >> "'"${RETAIN_LIST}"'";
    else print cont >> "'"${DISCARD_LIST}"'";
  }' "${RES_TSV}"

  # Combine viruses.fna and proviruses.fna if they exist
  local COMBINED_FA="${DEST_DIR}/combined_viruses_proviruses.fna"
  : > "${COMBINED_FA}"
  for fa in "${DEST_DIR}/viruses.fna" "${DEST_DIR}/proviruses.fna"; do
    [ -s "$fa" ] && cat "$fa" >> "${COMBINED_FA}"
  done

  local RET_FA="${DEST_DIR}/${SAMPLE}_${PREFIX}_checkv_retained.fasta"
  local DIS_FA="${DEST_DIR}/${SAMPLE}_${PREFIX}_checkv_discarded.fasta"

  if [[ -s "${RETAIN_LIST}" ]]; then
    seqtk subseq "${COMBINED_FA}" "${RETAIN_LIST}" > "${RET_FA}"
  else
    : > "${RET_FA}"
  fi

  if [[ -s "${DISCARD_LIST}" ]]; then
    seqtk subseq "${COMBINED_FA}" "${DISCARD_LIST}" > "${DIS_FA}"
  else
    : > "${DIS_FA}"
  fi

  # Write a strict summary line
  local IN_COUNT RET_COUNT DIS_COUNT
  IN_COUNT=$(grep -c "^>" "${IN_FA}" || true)
  RET_COUNT=$(grep -c "^>" "${RET_FA}" || true)
  DIS_COUNT=$(grep -c "^>" "${DIS_FA}" || true)
  echo -e "${SAMPLE}\t${PREFIX}\t${IN_COUNT}\t${RET_COUNT}\t${DIS_COUNT}" >> "${OUT_DIR}/${SAMPLE}_checkv_summary.tsv"

  echo "CheckV strict processing complete for ${SAMPLE} ${PREFIX}"
  echo "Results: ${DEST_DIR} (retained fasta: ${RET_FA}, discarded fasta: ${DIS_FA})"
}

# Run on high-confidence set
run_checkv_strict "${HIGHCONF_FA}" "highconf"

# Run on CAT-viral ambiguous set
run_checkv_strict "${CAT_VIRAL_FA}" "catviral"

echo "CheckV complete for ${SAMPLE_ID}. Per-sample outputs are in ${OUT_DIR}."

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "N retained contigs for high-confidence set for ${SAMPLE_ID}:"
wc -l "${OUT_DIR}/highconf/${SAMPLE}_highconf_checkv_retained.fasta"
echo "N retained contigs for CAT-viral set for ${SAMPLE_ID}:"
wc -l "${OUT_DIR}/catviral/${SAMPLE}_catviral_checkv_retained.fasta"

echo "Combining the highconf and ambiguous catviral contigs that passed CheckV rescue rules into a single FASTA for ${SAMPLE_ID}."
cat "${OUT_DIR}/highconf/${SAMPLE}_highconf_checkv_retained.fasta" "${OUT_DIR}/catviral/${SAMPLE}_catviral_checkv_retained.fasta" > "${OUT_DIR}/${SAMPLE}_all_highqual_viral.fasta"

echo "High-quality viral FASTA for ${SAMPLE_ID} saved to: ${OUT_DIR}/${SAMPLE}_all_highqual_viral.fasta"
echo "All done for ${SAMPLE_ID}."