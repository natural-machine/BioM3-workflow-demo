# 2026-04-05: Mini Dataset and Finetuning Config Modernization

## Summary

Created a mini SH3 dataset and pipeline config for fast iteration, then modernized the finetuning config system to match BioM3-dev's new JSON config / CLI interface. Replaced the 63-arg shell arglist pattern with a `--config_path` JSON config + per-run CLI overrides.

## Pre-session state

```bash
git checkout 5c50286
```

All changes are uncommitted on `main`.

## Part 1: Mini Dataset for Fast Pipeline Runs

Created a 500-row random subset of the 25K SH3 training dataset for quick full-pipeline iteration.

### New files
- **`scripts/create_mini_dataset.py`** — Randomly samples N rows from a training CSV. Usage: `python scripts/create_mini_dataset.py <input.csv> -n 500 -o <output.csv> --seed 42`
- **`data/SH3_mini/FINAL_SH3_mini_all_dataset_with_prompts.csv`** — 500-row sample (gitignored under `data/`)
- **`configs/pipeline_SH3_mini.toml`** — Full pipeline config for mini dataset, outputs to `outputs/SH3_mini/`
- **`run_pipeline_SH3_mini.sh`** — Convenience wrapper for mini pipeline

## Part 2: Finetuning Config Modernization

BioM3-dev restructured its Stage 3 training CLI (`biom3_pretrain_stage3`):
- Shell arglists replaced by JSON configs (`--config_path` with `_base_configs` composition)
- Arg renames: `--tb_logger_path` → `--output_root`, `--version_name` → `--run_id`, etc.
- Several args removed entirely (no aliases): `--wandb_logging_dir`, `--output_hist_folder`, `--output_folder`, `--save_hist_path`
- New output structure: `{output_root}/checkpoints/{run_id}/` and `{output_root}/runs/{run_id}/`

### Design decisions
1. **Nested JSON configs mirroring BioM3-dev's pattern** — workflow-demo ships its own copy of the base model config and references it via `_base_configs`, keeping model architecture separate from training params.
2. **Same positional interface** — `02_finetune.sh` keeps `<hdf5_file> <output_dir> [epochs]` for consistency. Adds optional `--config <path>` flag.
3. **TOML gets `[finetuning]` section** — Parallel to existing `[blast]`, `[generation]` sections. Contains `config` key pointing to the JSON training config.

### New files
- **`configs/models/_base_ProteoScribe_1block.json`** — Model architecture config (copied from BioM3-dev `configs/stage3_training/models/`)
- **`configs/stage3_config_finetune.json`** — Finetuning config with `_base_configs` referencing model config. Spark-specific overrides: `gpu_devices: 1`, `num_workers: 16`, `wandb_project: "BioM3-workflow-demo"`. Runtime values (`primary_data_path`, `output_root`) set to null, overridden by CLI.

### Modified files
- **`pipeline/02_finetune.sh`** — Rewritten from 172 to 108 lines. Replaced `source configs/config_finetune.sh` + 63 individual `--flag value` args with `--config_path <json>` + 5 per-run overrides (`--primary_data_path`, `--output_root`, `--run_id`, `--device`, `--epochs`).
- **`run_pipeline.py`** — `build_step_args` case "2" updated to pass `--config` from TOML `[finetuning]` section.
- **`configs/pipeline_SH3.toml`**, **`pipeline_SH3_mini.toml`**, **`pipeline_CM.toml`** — Added `[finetuning]` section with `config` key.

### Deleted files
- **`configs/config_finetune.sh`** — Shell arglist fully superseded by JSON config.

## CLI arg mapping (old → new)

| Old (removed) | New |
|---|---|
| `--tb_logger_path` | `--output_root` |
| `--tb_logger_folder` | `--checkpoints_folder` (in JSON) |
| `--version_name` | `--run_id` |
| `--swissprot_data_root` | `--primary_data_path` |
| `--wandb_logging_dir` | Derived from runs path |
| `--output_hist_folder` | Removed (dead code) |
| `--output_folder` | Removed (dead code) |
| `--save_hist_path` | Removed (dead code) |

## Verification

`python run_pipeline.py configs/pipeline_SH3_mini.toml --dry-run` passes — Step 2 correctly receives HDF5 path, output dir, epochs, and `--config` flag. `auto_detect_weights()` in `run_pipeline.py` still works with new output structure (uses rglob).

## Notes

- The earlier session note `2026-04-04_mini-dataset-and-finetuning-sync.md` was written mid-session and is now superseded by this one.
- `epochs` remains in `[paths]` in TOML configs rather than moving to `[finetuning]` — avoids breaking existing configs for a cosmetic change.
- SYNC_LOG.md should be updated with the BioM3-dev commit range for the training CLI restructure when committing.
