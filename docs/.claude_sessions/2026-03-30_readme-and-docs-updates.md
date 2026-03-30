# Session: README and docs updates

**Date:** 2026-03-30

## Summary

Initial documentation pass on the BioM3 workflow demo repo. Updated the README and per-family demo pipeline docs to reflect the project's conventions and output directory structure.

## Changes

### README.md
- Updated `pip install` command to use `git+https://` syntax for installing BioM3-dev from GitHub
- Added shared weights setup instructions (symlink workflow) with per-machine paths for DGX Spark, Polaris, and Aurora
- Updated all usage examples and repo structure tree to use the new output directory layout
- Renamed "Step 3: Sequence Generation" to "Step 3: Inference"; updated the generate script signature to take separate `embeddings_dir` and `output_dir` arguments

### docs/demo_pipeline_SH3.md
- Replaced all `outputs/SH3/{embedding,finetuning,generation}` paths with `embeddings/SH3`, `finetuning/SH3`, `inference/SH3`
- Updated Step 3 expected outputs to show embeddings and generated sequences in their respective directories
- Added "Using pretrained SH3 weights" subsection showing how to generate sequences directly with `weights/ProteoScribe/ProteoScribe_SH3_epoch52.ckpt/single_model.pth`

### docs/demo_pipeline_CM.md
- Same output directory restructuring as SH3 (`outputs/` → `embeddings/`, `finetuning/`, `inference/`)

### .gitignore
- Replaced `outputs/` with `embeddings/`, `finetuning/`, `inference/`
