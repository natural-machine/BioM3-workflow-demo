#!/bin/bash
#=============================================================================
# Step 5: Structure Prediction with ColabFold
#
# Runs ColabFold (AlphaFold2) structure prediction on per-prompt FASTA files
# from Step 4. After all predictions complete, parses the ColabFold log files
# to extract pLDDT and pTM scores into a summary CSV.
#
# Requires the `colabfold` conda environment to be active.
#
# USAGE:
#   ./scripts/05_colabfold.sh <samples_dir> <output_dir> <prefix>
#
# EXAMPLE:
#   ./scripts/05_colabfold.sh outputs/SH3/samples outputs/SH3/structures SH3_prompts
#   ./scripts/05_colabfold.sh outputs/CM/samples outputs/CM/structures CM_prompts
#
# INPUT:
#   <samples_dir>: directory containing per-prompt FASTA files from Step 4
#   <output_dir>:  directory for ColabFold output (PDBs and logs)
#   <prefix>:      filename prefix used in Step 4 (e.g. SH3_prompts)
#
# OUTPUT:
#   <output_dir>/prompt_<i>/          (ColabFold PDB files and logs per prompt)
#   <output_dir>/colabfold_results.csv (summary: structure,pLDDT,pTM,pdbfilename)
#=============================================================================

set -euo pipefail

# --- Validate args ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <samples_dir> <output_dir> <prefix>"
    echo "Example: $0 outputs/SH3/samples outputs/SH3/structures SH3_prompts"
    exit 1
fi

samples_dir=$1
outdir=$2
prefix=$3

if [ ! -d "${samples_dir}" ]; then
    echo "Error: Samples directory not found: ${samples_dir}"
    exit 1
fi

# --- Check dependencies ---
if ! command -v colabfold_batch &> /dev/null; then
    echo "Error: colabfold_batch not found on PATH."
    echo "Please activate the colabfold conda environment:"
    echo "  conda activate colabfold"
    exit 1
fi

# --- Paths ---
projdir=$(cd "$(dirname "$0")/.." && pwd)
cd ${projdir}

mkdir -p "${outdir}"

echo "============================================="
echo "Step 5: Structure Prediction with ColabFold"
echo "============================================="
echo "Samples dir: ${samples_dir}"
echo "Output dir:  ${outdir}"
echo "Prefix:      ${prefix}"
echo ""

# --- Discover FASTA files ---
fasta_files=$(ls "${samples_dir}/${prefix}_prompt_"*"_samples.fasta" 2>/dev/null | sort -V)
nfasta=$(echo "${fasta_files}" | wc -l)

if [ -z "${fasta_files}" ]; then
    echo "Error: No FASTA files found matching: ${samples_dir}/${prefix}_prompt_*_samples.fasta"
    exit 1
fi

echo "Found ${nfasta} FASTA files to process."
echo ""

# --- Run ColabFold on each FASTA ---
echo "[1/2] Running ColabFold structure prediction..."
count=0
for fasta in ${fasta_files}; do
    count=$((count + 1))
    # Extract prompt index from filename (e.g. prefix_prompt_3_samples.fasta → 3)
    fname=$(basename "${fasta}")
    prompt_idx=$(echo "${fname}" | sed -E "s/${prefix}_prompt_([0-9]+)_samples\.fasta/\1/")
    prompt_outdir="${outdir}/prompt_${prompt_idx}"
    mkdir -p "${prompt_outdir}"

    echo "  [${count}/${nfasta}] Predicting structures for prompt_${prompt_idx}..."
    colabfold_batch "${fasta}" "${prompt_outdir}"
done
echo "[1/2] Done."
echo ""

# --- Parse ColabFold log files ---
echo "[2/2] Parsing ColabFold results..."
results_csv="${outdir}/colabfold_results.csv"
echo "structure,pLDDT,pTM,pdbfilename" > "${results_csv}"

for prompt_dir in $(ls -d "${outdir}/prompt_"*/ 2>/dev/null | sort -V); do
    logfile="${prompt_dir}log.txt"
    if [ ! -f "${logfile}" ]; then
        echo "  Warning: No log.txt found in ${prompt_dir}, skipping."
        continue
    fi

    awk '
        /Query [0-9]+\/[0-9]+:/ {
            match($0, /Query [0-9]+\/[0-9]+: ([^ ]+)/, m)
            query = m[1]
        }
        /rank_001_/ {
            match($0, /(rank_001_[^ ]+)/, r)
            match($0, /pLDDT=([0-9.]+)/, a)
            match($0, /pTM=([0-9.]+)/, b)
            pdbfilename = query "_unrelaxed_" r[1]
            printf "%s,%s,%s,%s\n", query, a[1], b[1], pdbfilename
        }
    ' "${logfile}" >> "${results_csv}"
done

nresults=$(($(wc -l < "${results_csv}") - 1))
echo "[2/2] Done. Parsed ${nresults} structure results."
echo ""

echo "============================================="
echo "ColabFold prediction complete."
echo "Structures: ${outdir}/prompt_*/"
echo "Results:    ${results_csv}"
echo "============================================="
