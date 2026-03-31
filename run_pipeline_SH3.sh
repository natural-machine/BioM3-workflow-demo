#!/bin/bash
#=============================================================================
# Analysis Pipeline — SH3 Example
#
# Runs the post-generation analysis pipeline (Steps 4-8) starting from a
# ProteoScribe .pt output file. Copy this script, edit the variables below,
# and run it for your own protein family.
#
# Environment requirements:
#   - biom3-env:  Step 4 (FASTA conversion)
#   - colabfold:  Step 5 (structure prediction)
#   - blast-env:  Step 6 (homology search)
#   - TMalign on PATH: Step 7
#   - matplotlib/seaborn: Step 8
#
# To skip steps you have already completed, comment out the corresponding
# section below.
#=============================================================================

set -euo pipefail

# ========================== USER CONFIGURATION ==============================

# --- Input ---
PT_FILE="outputs/SH3/generation/SH3_prompts.ProteoScribe_output.pt"

# --- Output directories ---
OUTDIR="outputs/SH3"
SAMPLES_DIR="${OUTDIR}/samples"
STRUCTURES_DIR="${OUTDIR}/structures"
BLAST_DIR="${OUTDIR}/blast"
COMPARISON_DIR="${OUTDIR}/comparison"
IMAGES_DIR="${OUTDIR}/images"

# --- BLAST options ---
BLAST_DB="pdbaa"           # "pdbaa" for PDB search, or path to local DB (e.g. /path/to/nr)
BLAST_THREADS=16           # threads for local searches

# ============================================================================

# Derive prefix from the .pt filename
fname=$(basename "${PT_FILE}")
if [[ "${fname}" == *.ProteoScribe_output.pt ]]; then
    PREFIX="${fname%.ProteoScribe_output.pt}"
else
    PREFIX="${fname%.pt}"
fi

# ---------- Step 4: Convert to FASTA ----------
echo ""
echo ">>> Step 4: Convert to FASTA"
./scripts/04_samples_to_fasta.sh "${PT_FILE}" "${SAMPLES_DIR}"

# ---------- Step 5: ColabFold Structure Prediction ----------
echo ""
echo ">>> Step 5: ColabFold Structure Prediction"
./scripts/05_colabfold.sh "${SAMPLES_DIR}" "${STRUCTURES_DIR}" "${PREFIX}"

# ---------- Step 6: BLAST Search ----------
echo ""
echo ">>> Step 6: BLAST Search"
FASTA_FILE="${SAMPLES_DIR}/generated_seqs_allprompts.fasta"
./scripts/06_blast_search.sh "${FASTA_FILE}" "${BLAST_DIR}" \
    --db "${BLAST_DB}" --threads "${BLAST_THREADS}"

# ---------- Step 7: Structure Comparison (TMalign) ----------
echo ""
echo ">>> Step 7: Structure Comparison"
./scripts/07_compare_structures.sh \
    "${STRUCTURES_DIR}/colabfold_results.csv" \
    "${BLAST_DIR}/blast_hit_results.tsv" \
    "${STRUCTURES_DIR}" \
    "${BLAST_DIR}/reference_structures" \
    "${COMPARISON_DIR}"

# ---------- Step 8: Plot Results ----------
echo ""
echo ">>> Step 8: Plot Results"
./scripts/08_plot_results.sh \
    "${COMPARISON_DIR}/results.csv" \
    "${IMAGES_DIR}" \
    --colabfold-csv "${STRUCTURES_DIR}/colabfold_results.csv"

echo ""
echo "========================================="
echo "Analysis pipeline complete!"
echo "Results: ${OUTDIR}/"
echo "========================================="
