#!/bin/bash
#=============================================================================
# DEPRECATED — Use the config-driven runner instead:
#   python run_pipeline.py configs/pipeline_SH3_analysis.toml
#
# Analysis Pipeline — SH3 Example
#
# Runs the post-generation analysis pipeline (Steps 5-8). FASTA files must
# already exist in SAMPLES_DIR from a prior Step 3 run with --fasta
# --fasta_merge --fasta_dir, or from the standalone 04_samples_to_fasta.sh
# utility.
#
# Environments are activated automatically for each step. Set the
# environment names (conda) or paths (venv) in the USER CONFIGURATION
# section below. TMalign must also be on PATH (Step 7).
#
# To skip steps you have already completed, comment out the corresponding
# section below.
#=============================================================================

set -euo pipefail

# ========================== USER CONFIGURATION ==============================

# --- Output directories ---
OUTDIR="outputs/SH3_v2"
SAMPLES_DIR="${OUTDIR}/samples"
STRUCTURES_DIR="${OUTDIR}/structures"
BLAST_DIR="${OUTDIR}/blast"
COMPARISON_DIR="${OUTDIR}/comparison"
IMAGES_DIR="${OUTDIR}/images"

# --- BLAST options ---
BLAST_DB="swissprot"       # "swissprot" (default), "pdbaa", or path to local DB
BLAST_THREADS=16           # threads for local searches

# --- Environments (conda env name or path to venv) ---
ENV_BIOM3="biom3-env"      # Step 8  (e.g. "biom3-env" or "/path/to/biom3-venv")
ENV_COLABFOLD="colabfold"  # Step 5
ENV_BLAST="blast-env"      # Step 6

# ============================================================================

# Initialize conda if available (not needed for venv-only setups)
if command -v conda &> /dev/null; then
    eval "$(conda shell.bash hook)"
fi

activate_env() {
    local env="$1"
    if [ -f "${env}/bin/activate" ]; then
        source "${env}/bin/activate"
    else
        conda activate "${env}"
    fi
}

# ---------- Step 5: ColabFold Structure Prediction ----------
activate_env "${ENV_COLABFOLD}"
echo ""
echo ">>> Step 5: ColabFold Structure Prediction (env: ${ENV_COLABFOLD})"
./pipeline/05_colabfold.sh "${SAMPLES_DIR}" "${STRUCTURES_DIR}"

# ---------- Step 6: BLAST Search ----------
activate_env "${ENV_BLAST}"
echo ""
echo ">>> Step 6: BLAST Search (env: ${ENV_BLAST})"
FASTA_FILE="${SAMPLES_DIR}/all_sequences.fasta"
./pipeline/06_blast_search.sh "${FASTA_FILE}" "${BLAST_DIR}" \
    --db "${BLAST_DB}" --threads "${BLAST_THREADS}"

# ---------- Step 6b: Fetch Reference Structures (non-pdbaa databases) ----------
if [ "${BLAST_DB}" != "pdbaa" ]; then
    echo ""
    echo ">>> Step 6b: Fetch Reference Structures"
    ./pipeline/06b_fetch_hit_structures.sh \
        "${BLAST_DIR}/blast_hit_results.tsv" \
        "${BLAST_DIR}"
fi

# ---------- Step 7: Structure Comparison (TMalign) ----------
activate_env "${ENV_BIOM3}"
echo ""
echo ">>> Step 7: Structure Comparison"
./pipeline/07_compare_structures.sh \
    "${STRUCTURES_DIR}/colabfold_results.csv" \
    "${BLAST_DIR}/blast_hit_results.tsv" \
    "${STRUCTURES_DIR}" \
    "${BLAST_DIR}/reference_structures" \
    "${COMPARISON_DIR}"

# ---------- Step 8: Plot Results ----------
echo ""
echo ">>> Step 8: Plot Results (env: ${ENV_BIOM3})"
./pipeline/08_plot_results.sh \
    "${COMPARISON_DIR}/results.csv" \
    "${IMAGES_DIR}" \
    --colabfold-csv "${STRUCTURES_DIR}/colabfold_results.csv"

echo ""
echo "========================================="
echo "Analysis pipeline complete!"
echo "Results: ${OUTDIR}/"
echo "========================================="
