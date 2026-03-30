#=============================================================================
# BioM3 Workflow Demo — Finetuning configuration
#
# This config is sourced by the finetuning script. It defines all
# hyperparameters and paths needed to finetune ProteoScribe on a
# user-provided dataset, starting from pretrained base model weights.
#=============================================================================

# --- Data ---
export swissprot_data_root="OVERRIDE_ME"  # Set by 02_finetune.sh per family
export pfam_data_root="None"
export sequence_keyname="sequence"
export num_classes=29
export num_y_class_labels=6

# --- Finetuning ---
export finetune=True
export pretrained_weights="./weights/ProteoScribe/ProteoScribe_epoch200.pth"
export finetune_last_n_blocks=1
export finetune_last_n_layers=1

# --- Logging ---
export wandb_entity="thenaturalmachine"
export wandb_project="BioM3-workflow-demo"
export wandb_logging_dir="./logs"
export wandb_tags="finetuning"

# --- Optimizer ---
export choose_optim="AdamW"
export lr=1e-4
export scale_learning_rate=False
export weight_decay=1e-6
export scheduler_gamma="coswarmup"

# --- Training ---
export seed=0
export epochs=20
export valid_size=0.2
export enter_eval=1000
export resume_from_checkpoint=None
export batch_size=32
export output_folder=None
export model_option=transformer
export diffusion_steps=1024
export warmup_steps=500
export image_size=32
export ema_inv_gamma=1.0
export ema_power=0.75
export ema_max_value=0.95
export task=proteins
export max_steps=3000000

# --- Hardware (DGX Spark: single GPU) ---
export device=cuda
export precision=bf16
export gpu_devices=1
export num_nodes=1
export acc_grad_batches=1

# --- Validation ---
export val_check_interval=20
export limit_val_batches=0.05

# --- Misc ---
export log_every_n_steps=100
export start_pfam_trainer=False
export num_workers=16

# --- Flow params ---
export num_steps=1
export actnorm=False
export perm_channel=none
export perm_length=reverse
export input_dp_rate=0.0

# --- Transformer architecture ---
export transformer_dim=512
export transformer_heads=16
export transformer_depth=16
export transformer_blocks=1
export transformer_dropout=0.1
export transformer_reversible=False
export transformer_local_heads=8
export transformer_local_size=128

export text_emb_dim=512
export facilitator=MMD

# --- Output paths ---
export version_name=None
export output_hist_folder=./logs/history/Stage3_history
export tb_logger_path=./logs/history
export tb_logger_folder=Stage3_history
export save_hist_path=None
export traindata_len=None
