# 2026-03-29: Initial workflow demo setup

## Summary

Set up the BioM3 workflow demo repository with a 3-step pipeline: embedding, finetuning, and sequence generation. Targeting the DGX Spark (single NVIDIA GPU).

## What was done

### Explored BioM3-dev
- Read through the full BioM3-dev repo to understand the 3-stage pipeline (PenCL → Facilitator → ProteoScribe)
- Studied Spark job templates, finetuning configs, embedding pipeline, and generation scripts
- Identified the `biom3_embedding_pipeline` entrypoint as the single command for Stage 1 + Stage 2 + HDF5 compilation

### Created config files (`configs/`)
- `stage1_config_PenCL_inference.json` — copied from BioM3-dev, seed changed to 0
- `stage2_config_Facilitator_sample.json` — copied from BioM3-dev
- `stage3_config_ProteoScribe_sample.json` — copied from BioM3-dev
- `config_finetune.sh` — finetuning arglist adapted for Spark (1 node, 1 GPU, bf16), pointing at `ProteoScribe_epoch200.pth`

### Created workflow scripts (`scripts/`)
- `01_embedding.sh` — takes `<input_csv> <output_dir>`, calls `biom3_embedding_pipeline`
- `02_finetune.sh` — takes `<hdf5_file> <output_dir> [epochs]`, sources config_finetune.sh, calls `biom3_pretrain_stage3`
- `03_generate.sh` — takes `<model_weights> <input_csv> <output_dir>`, embeds then generates

Scripts are generic (input path + output dir), not family-specific.

### Copied data
- `data/SH3/FINAL_SH3_all_dataset_with_prompts.csv` (25,030 rows)
- `data/CM/FINAL_CM_all_dataset_with_prompts.csv` (8,319 rows)

### Created documentation
- `README.md` — full readme with install, setup, usage, repo structure, config reference
- `docs/demo_pipeline_SH3.md` — step-by-step walkthrough for SH3 family
- `docs/demo_pipeline_CM.md` — step-by-step walkthrough for CM family

## In progress / not yet done

- Renaming `embedding/` → `embeddings/` in output paths was started in scripts but rejected for docs/README — needs to be completed consistently
- The README install section has a `<TODO>` placeholder for the BioM3-dev pip install command (user edited this manually)
- User also manually changed batch_size from 256 to 32 and added `--device cuda` in 01_embedding.sh
- `data/SH3/SH3_prompts.csv` was opened by the user — may be a separate prompts file for generation (distinct from the full training dataset)

## Key design decisions

- Scripts take explicit input/output paths rather than family names — keeps them generic
- `biom3_embedding_pipeline` used as a single entrypoint for embedding (not separate PenCL + Facilitator calls), except in 03_generate.sh which also uses it
- Base model for finetuning is `ProteoScribe_epoch200.pth` (not the older `BioM3_ProteoScribe_pfam_epoch20_v1.bin`)
- PenCL and Facilitator weights use `.ckpt` format (`PenCL_V09152023_last.ckpt`, `Facilitator_MMD15.ckpt/last.ckpt`)
- All weights are symlinked from `/data/data-share/BioM3-data-share/data/models/`

## Weight paths used

| Stage | Weight file |
| ----- | ----------- |
| LLMs | `weights/LLMs/esm2_t33_650M_UR50D.pt` |
| LLMs | `weights/LLMs/BiomedNLP-BiomedBERT-base-uncased-abstract-fulltext/` |
| Stage 1 | `weights/PenCL/PenCL_V09152023_last.ckpt` |
| Stage 2 | `weights/Facilitator/Facilitator_MMD15.ckpt/last.ckpt` |
| Stage 3 | `weights/ProteoScribe/ProteoScribe_epoch200.pth` |
