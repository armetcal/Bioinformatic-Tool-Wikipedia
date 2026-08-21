PROJECT_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
SAVE_LOC="$PROJECT_ROOT/metaspades_out"

# Remove any previous runs
rm -f "$SAVE_LOC/contig_counts.tsv"

# Get list of unique sample prefixes
mapfile -t SAMPLES < <(basename -a "$SAVE_LOC"/*)

# Create an empty summary file
echo -e "Sample\tContig_Count" > "$SAVE_LOC/contig_counts.tsv"

# Log all the counts
for i in "${!SAMPLES[@]}"; do
    PREFIX=${SAMPLES[$i]}
    OUT_DIR="$SAVE_LOC/${PREFIX}"
    LOG="$OUT_DIR/quast_report/report.tsv"
    
    echo "Processing sample: ${PREFIX}"
    n=$(head -n 2 "$LOG" | awk '{print $6}' | tail -n 1)
    echo -e "${PREFIX}\t${n}" >> "$SAVE_LOC/contig_counts.tsv"
done