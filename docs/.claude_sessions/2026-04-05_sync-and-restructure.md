# Session: Sync with BioM3-dev and repo restructure

**Date:** 2026-04-05
**Scope:** Sync with BioM3-dev (e682e25), remove Step 4, restructure configs and pipeline to mirror BioM3-dev layout

## Summary

Brought BioM3-workflow-demo up to parity with BioM3-dev HEAD (`e682e25`, 21 commits behind) and restructured the repository for consistency with BioM3-dev's directory layout.

## Changes

### 1. Sync with BioM3-dev (`6197429`)

- **Inference configs → lean `_base_configs` composition**: Replaced three flat inference configs (47/14/62 keys) with lean configs using BioM3-dev's `_base_configs` composition pattern. Created base model configs for PenCL (15 keys) and Facilitator (3 keys).
- **Removed Step 4 from automated pipeline**: `biom3_ProteoScribe_sample` now has `--fasta`, `--fasta_merge`, `--fasta_dir` flags. Added these to `03_generate.sh`; `run_pipeline.py` Step 3 always passes them. Old `04_samples_to_fasta.sh` retained as a standalone utility.
- **Updated Step 5 (ColabFold)**: Changed from 3-arg to 2-arg interface to match new FASTA naming (`prompt_0.fasta` instead of `{prefix}_prompt_1_samples.fasta`).
- **Added Step 9 (webapp) to runner**: Available via `--steps 9`, excluded from default `STEP_ORDER` (interactive/blocking).
- **Forwarded all generation options**: `animation_dir`, `animation_style`, `animation_metrics`, `store_probabilities` now forwarded from TOML `[generation]` section.
- **Updated docs**: Config refs (`config_finetune.sh` → JSON), checkpoint paths (`lightning_logs/` → `<run_id>/`), FASTA filename (`all_sequences.fasta`).

### 2. Pipeline renumbering (`e3921fd`)

Moved `pipeline/04_samples_to_fasta.sh` to `scripts/samples_to_fasta.sh` and renumbered all subsequent scripts to close the gap:

| Old | New | Step |
|-----|-----|------|
| 05_colabfold.sh | 04_colabfold.sh | ColabFold |
| 06_blast_search.sh | 05_blast_search.sh | BLAST |
| 06b_fetch_hit_structures.sh | 05b_fetch_hit_structures.sh | Fetch structures |
| 07_compare_structures.sh | 06_compare_structures.sh | TMalign |
| 08_plot_results.sh | 07_plot_results.sh | Plot results |
| 09_webapp.sh | 08_webapp.sh | Web app |

Updated all references in `run_pipeline.py`, TOML configs, and docs.

### 3. Config restructure (`3a45577`, `f72c8f7`)

Reorganized `configs/` to mirror BioM3-dev's layout:

```
configs/
├── pipelines/              # TOML pipeline configs (was configs/pipeline_*.toml)
│   ├── SH3.toml
│   ├── SH3_analysis.toml
│   ├── SH3_mini.toml
│   └── CM.toml
├── inference/              # Inference configs (was configs/stage*_config_*.json)
│   ├── stage1_PenCL.json
│   ├── stage2_Facilitator.json
│   ├── stage3_ProteoScribe_sample.json
│   └── models/
│       ├── _base_PenCL.json
│       └── _base_Facilitator.json
├── stage3_training/        # Training configs (was configs/stage3_config_finetune.json)
│   ├── finetune.json
│   └── models/
│       └── _base_ProteoScribe_1block.json
└── app_settings.json       # Web app config (was app_data_dirs.json)
```

### 4. Legacy cleanup

Removed:
- `run_pipeline_SH3.sh` — deprecated, superseded by `python run_pipeline.py configs/pipelines/SH3_analysis.toml`
- `run_pipeline_SH3_mini.sh` — superseded by `python run_pipeline.py configs/pipelines/SH3_mini.toml`

### 5. Requirements directory (`d24e0a5`)

Moved `requirements_spark.txt` → `requirements/spark.txt` and added `polaris.txt`, `aurora.txt` from BioM3-dev.

## Verification

- `python run_pipeline.py configs/pipelines/SH3.toml --dry-run` — all steps use correct script paths and new config paths
- `_base_configs` resolution verified for all four config files (inference + training)
- SYNC_LOG updated to `e682e25`
