MAG_VERSION="metaspades"
SCRATCH_ROOT="/home/armetcal/scratch/cmmi/virome/mgx"
SAMPLE_LOC="$SCRATCH_ROOT/${MAG_VERSION}_out"
SAVE_LOC="$SCRATCH_ROOT/vOTUs"

# Get list of unique sample prefixes
mapfile -t FOLDERS < <(basename -a "$SAMPLE_LOC"/${MAG_VERSION}*)
# Create an empty summary file
echo -e "Sample\tvOTU_Count" > "$SAVE_LOC/vOTU_counts.tsv"

for SAMPLE in "${FOLDERS[@]}"; do
    # SAMPLE=${FOLDERS[0]}
    CONTIG_FILE="$SCRATCH_ROOT/vOTUs/checkv_out/$SAMPLE/highconf/${SAMPLE}_highconf_checkv_retained.fasta"
    # Calculate the total number of vOTUs
    n=$(awk '/^>/{sub(/^>/,""); print}' "$CONTIG_FILE" | wc -l)
    echo -e "$SAMPLE\t$n" >> "$SAVE_LOC/vOTU_counts.tsv"
done

echo "vOTU counts saved to: $SAVE_LOC/vOTU_counts.tsv"