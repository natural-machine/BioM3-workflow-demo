#!/bin/bash
#=============================================================================
# Step 3: Generate Protein Sequences
#
# Uses a finetuned (or pretrained) ProteoScribe model to generate novel
# protein sequences from text prompts. First embeds the input through
# PenCL and Facilitator, then runs ProteoScribe diffusion sampling.
#
# USAGE:
#   ./scripts/03_generate.sh <model_weights> <input_csv> <output_dir>
#
# EXAMPLE:
#   ./scripts/03_generate.sh \
#       outputs/SH3/finetuning/checkpoints/.../state_dict.best.pth \
#       data/SH3/SH3_prompts.csv \
#       outputs/SH3/generation
#
# INPUT:
#   - model_weights: Path to finetuned ProteoScribe weights (.pth, .bin, or .ckpt)
#   - input_csv: CSV with text prompts (same format as Step 1)
#   - output_dir: Directory for generated output
#
# OUTPUT:
#   <output_dir>/<prefix>.ProteoScribe_output.pt
#=============================================================================

set -euo pipefail

# --- Validate args ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <model_weights> <input_csv> <output_dir>"
    echo "Example: $0 outputs/SH3/finetuning/.../state_dict.best.pth data/SH3/prompts.csv outputs/SH3/generation"
    exit 1
fi

model_weights=$1
input_csv=$2
outdir=$3

if [ ! -e "${model_weights}" ]; then
    echo "Error: Model weights not found: ${model_weights}"
    exit 1
fi

if [ ! -f "${input_csv}" ]; then
    echo "Error: Input CSV not found: ${input_csv}"
    exit 1
fi

# --- Paths ---
projdir=$(cd "$(dirname "$0")/.." && pwd)
cd ${projdir}

embed_dir="${outdir}/embeddings"
pencl_weights=weights/PenCL/PenCL_V09152023_last.ckpt
facilitator_weights=weights/Facilitator/Facilitator_MMD15.ckpt/last.ckpt
config1=configs/stage1_config_PenCL_inference.json
config2=configs/stage2_config_Facilitator_sample.json
config3=configs/stage3_config_ProteoScribe_sample.json

prefix=$(basename "${input_csv}" .csv)

export TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1

mkdir -p ${embed_dir} ${outdir}

echo "============================================="
echo "Step 3: Generate Protein Sequences"
echo "============================================="
echo "Model weights: ${model_weights}"
echo "Input CSV:     ${input_csv}"
echo "Output dir:    ${outdir}"
echo ""

# --- Embed input prompts (Stage 1 + Stage 2) ---
echo "[1/2] Embedding input prompts..."
biom3_embedding_pipeline \
    -i ${input_csv} \
    -o ${embed_dir} \
    --pencl_weights ${pencl_weights} \
    --facilitator_weights ${facilitator_weights} \
    --pencl_config ${config1} \
    --facilitator_config ${config2} \
    --prefix ${prefix} \
    --batch_size 256 \
    --dataset_key MMD_data

echo "[1/2] Done."
echo ""

# --- ProteoScribe generation ---
echo "[2/2] Generating sequences with ProteoScribe..."
biom3_ProteoScribe_sample \
    -i ${embed_dir}/${prefix}.Facilitator_emb.pt \
    -c ${config3} \
    -m ${model_weights} \
    -o ${outdir}/${prefix}.ProteoScribe_output.pt

echo "[2/2] Done."
echo ""
echo "============================================="
echo "Sequence generation complete."
echo "Output: ${outdir}/${prefix}.ProteoScribe_output.pt"
echo "============================================="
