# 2026-04-04: Mini Dataset and Finetuning Output Sync

## Summary

Created a mini SH3 dataset (500 rows) and pipeline config for fast iteration on the full pipeline. Fixed wandb log directory placement. Identified and scoped out a sync needed with BioM3-dev's training CLI restructure — that sync is the main TODO for next session.

## Changes Made (uncommitted, on `main` at 5c50286)

### New files
- **`scripts/create_mini_dataset.py`** — Randomly samples N rows from a training CSV. Usage: `python scripts/create_mini_dataset.py <input.csv> -n 500 -o <output.csv> --seed 42`
- **`data/SH3_mini/FINAL_SH3_mini_all_dataset_with_prompts.csv`** — 500-row sample from the 25K SH3 dataset (gitignored under `data/`)
- **`configs/pipeline_SH3_mini.toml`** — Full pipeline config using mini dataset, outputs to `outputs/SH3_mini/`, epochs=10. Shares `data/SH3/SH3_prompts.csv` with the full pipeline.
- **`run_pipeline_SH3_mini.sh`** — Convenience wrapper: `./run_pipeline_SH3_mini.sh [--dry-run] [--steps 1 2 ...]`

### Modified files
- **`pipeline/02_finetune.sh`** — Added `wandb_logging_dir="${outdir}"` override (line 69) so wandb logs go to the run output directory instead of the shared `logs/` directory.

## Pre-session state

```bash
git checkout 5c50286
```

## Next Steps: Sync `02_finetune.sh` with BioM3-dev Training CLI Restructure

BioM3-dev has made major breaking changes to `biom3_pretrain_stage3`. The workflow-demo finetuning script is now outdated. Key changes needed:

### CLI arg renames
| Old (workflow-demo uses) | New (BioM3-dev) |
|---|---|
| `--tb_logger_path` | `--output_root` |
| `--tb_logger_folder` | `--checkpoints_folder` |
| `--version_name` | `--run_id` |
| `--swissprot_data_root` | `--primary_data_path` |
| `--pfam_data_root` | `--secondary_data_paths` |
| `--start_pfam_trainer` | `--start_secondary` |

### Removed args (workflow-demo still passes them)
- `--wandb_logging_dir` — now derived from runs path
- `--output_hist_folder`, `--output_folder`, `--save_hist_path` — dead code removed

### New config system
BioM3-dev now uses JSON training configs (`--config_path`) with nested composition (`_base_configs`, `_overwrite_configs`). The shell arglist `configs/config_finetune.sh` can be replaced with a JSON config + CLI overrides.

### Approach options
1. **Minimal**: Update arg names in `02_finetune.sh`, keep shell config
2. **Full adoption**: Replace `config_finetune.sh` with a JSON config, simplify `02_finetune.sh` to pass `--config_path` + overrides for data/output paths

### The `checkpoints/checkpoints/` nesting issue
This is already fixed in BioM3-dev. The new output structure is:
```
{output_root}/
  checkpoints/{run_id}/     ← weights, .ckpt dirs
  runs/{run_id}/             ← logs (wandb, tensorboard), artifacts (args.json, build_manifest)
```

`auto_detect_weights()` in `run_pipeline.py` searches `finetuning_dir / "checkpoints"` which still works with the new structure.

### Also check
- `run_pipeline.py` `build_step_args` for Step 2 — currently constructs args for the old CLI
- Whether deprecated aliases (e.g. `--swissprot_data_root`) still work in BioM3-dev or if they're hard renames
