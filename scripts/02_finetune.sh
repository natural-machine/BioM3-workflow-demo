#!/bin/bash
#=============================================================================
# Step 2: Finetune ProteoScribe
#
# Finetunes the pretrained ProteoScribe base model on the HDF5 dataset
# produced by Step 1. Loads ProteoScribe_epoch200.pth, freezes most of
# the network, and trains the last N transformer blocks/layers.
#
# USAGE:
#   ./scripts/02_finetune.sh <hdf5_file> <output_dir> [epochs]
#
# EXAMPLE:
#   ./scripts/02_finetune.sh outputs/SH3/embeddings/SH3_dataset.compiled_emb.hdf5 outputs/SH3/finetuning
#   ./scripts/02_finetune.sh outputs/CM/embeddings/CM_dataset.compiled_emb.hdf5 outputs/CM/finetuning 50
#
# INPUT:
#   <hdf5_file>: compiled embeddings from Step 1
#
# OUTPUT:
#   Checkpoints and logs in <output_dir>/
#=============================================================================

set -euo pipefail

# --- Validate args ---
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <hdf5_file> <output_dir> [epochs]"
    echo "Example: $0 outputs/SH3/embeddings/SH3_dataset.compiled_emb.hdf5 outputs/SH3/finetuning 50"
    exit 1
fi

hdf5_file=$1
outdir=$2

if [ ! -f "${hdf5_file}" ]; then
    echo "Error: HDF5 file not found: ${hdf5_file}"
    exit 1
fi

# --- Paths ---
projdir=$(cd "$(dirname "$0")/.." && pwd)
cd ${projdir}

# Source finetuning config (provides defaults for all hyperparameters)
source configs/config_finetune.sh

# Override training data with the specified HDF5 file
swissprot_data_root="${hdf5_file}"

# Override epochs if provided
epochs=${3:-${epochs}}

# --- Spark hardware settings ---
num_nodes=1
gpu_devices=1
device=cuda

# --- Finetuning settings ---
pretrained_weights="./weights/ProteoScribe/ProteoScribe_epoch200.pth"
finetune_last_n_blocks=1
finetune_last_n_layers=1
resume_from_checkpoint=None

# --- Output paths ---
output_hist_folder="${outdir}"
tb_logger_path="${outdir}"
tb_logger_folder="checkpoints"

# --- Version name ---
datetime=$(date +%Y%m%d_%H%M%S)
version_name="finetune_n${num_nodes}_d${gpu_devices}_e${epochs}_V${datetime}"

export TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1

# --- Logging setup ---
mkdir -p "${outdir}/logs"
log_fpath="${outdir}/logs/${version_name}.o"

echo "============================================="
echo "Step 2: Finetune ProteoScribe"
echo "============================================="
echo "Base model:       ${pretrained_weights}"
echo "Training data:    ${swissprot_data_root}"
echo "Output dir:       ${outdir}"
echo "Epochs:           ${epochs}"
echo "Unfreeze blocks:  ${finetune_last_n_blocks}"
echo "Unfreeze layers:  ${finetune_last_n_layers}"
echo "Device:           ${device}"
echo "Version:          ${version_name}"
echo "Log file:         ${log_fpath}"
echo ""
echo "Starting finetuning..."
echo ""

biom3_pretrain_stage3 \
    --output_hist_folder ${output_hist_folder} \
    --output_folder ${output_folder} \
    --save_hist_path ${save_hist_path} \
    --model_option ${model_option} \
    --swissprot_data_root ${swissprot_data_root} \
    --pfam_data_root ${pfam_data_root} \
    --diffusion_steps ${diffusion_steps} \
    --seed ${seed} \
    --batch-size ${batch_size} \
    --warmup-steps ${warmup_steps} \
    --image-size ${image_size} \
    --lr ${lr} \
    --scale_learning_rate ${scale_learning_rate} \
    --weight-decay ${weight_decay} \
    --ema_inv_gamma ${ema_inv_gamma} \
    --ema_max_value ${ema_max_value} \
    --precision ${precision} \
    --device ${device} \
    --transformer_dim ${transformer_dim} \
    --transformer_heads ${transformer_heads} \
    --num_classes ${num_classes} \
    --task ${task} \
    --num_y_class_labels ${num_y_class_labels} \
    --enter_eval ${enter_eval} \
    --transformer_depth ${transformer_depth} \
    --choose_optim ${choose_optim} \
    --epochs ${epochs} \
    --acc_grad_batches ${acc_grad_batches} \
    --gpu_devices ${gpu_devices} \
    --num_nodes ${num_nodes} \
    --version_name ${version_name} \
    --scheduler_gamma ${scheduler_gamma} \
    --text_emb_dim ${text_emb_dim} \
    --sequence_keyname ${sequence_keyname} \
    --facilitator ${facilitator} \
    --tb_logger_path ${tb_logger_path} \
    --tb_logger_folder ${tb_logger_folder} \
    --resume_from_checkpoint ${resume_from_checkpoint} \
    --valid_size ${valid_size} \
    --max_steps ${max_steps} \
    --log_every_n_steps ${log_every_n_steps} \
    --val_check_interval ${val_check_interval} \
    --limit_val_batches ${limit_val_batches} \
    --start_pfam_trainer ${start_pfam_trainer} \
    --num_workers ${num_workers} \
    --wandb_entity ${wandb_entity} \
    --wandb_project "${wandb_project}" \
    --wandb_name ${version_name} \
    --finetune True \
    --pretrained_weights ${pretrained_weights} \
    --finetune_last_n_blocks ${finetune_last_n_blocks} \
    --finetune_last_n_layers ${finetune_last_n_layers} \
2>&1 | tee ${log_fpath}

echo ""
echo "============================================="
echo "Finetuning complete."
echo "Log:         ${log_fpath}"
echo "Checkpoints: ${tb_logger_path}/${tb_logger_folder}/${version_name}/"
echo "============================================="
