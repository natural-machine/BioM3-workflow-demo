# BioM3-dev Sync Log

Tracks synchronization points between this repository (BioM3-workflow-demo) and
the core [BioM3-dev](https://github.com/addison-nm/BioM3-dev) library.

| Date | BioM3-dev commit | workflow-demo commit | Summary |
| ---- | ---------------- | -------------------- | ------- |
| 2026-04-05 | `e682e25` | *(pending)* | Migrate inference configs to `_base_configs` composition; remove Step 4 (Step 3 produces FASTA with `--fasta --fasta_merge`); update Step 5 to 2-arg interface; add Step 9 to pipeline runner; forward all generation/animation options; update docs for new output dir structure |
| 2026-04-04 | `f30d682` | *(pending)* | Add `confidence_no_pad` unmasking order, `--store_probabilities`, `--animation_style`, `--animation_metrics` CLI flags to `03_generate.sh`; add Step 9 web app launcher and `app_data_dirs.json` config; update README, SH3, and CM docs |
| 2026-04-04 | `844f2d1` | `d8c4cd8` | Add `unmasking_order`, `token_strategy` config fields; add `--unmasking_order`, `--token_strategy`, `--animate_prompts`, `--animate_replicas`, `--animation_dir` CLI flags to `03_generate.sh`; update README, SH3, and CM docs |
| 2026-04-03 | `340de4b` | `eb0a931` | Wire 14 missing config exports in `02_finetune.sh`, add `--device` to `03_generate.sh`, document `build_manifest.json` outputs |

## How to use this log

After syncing with BioM3-dev changes:
1. Add a new row at the top of the table
2. Record the BioM3-dev commit hash you synced up to
3. Record the resulting workflow-demo commit hash (fill in after committing)
4. Write a brief summary of what changed

## Checking for upstream changes

```bash
cd /path/to/BioM3-dev
git log --oneline <last-synced-commit>..HEAD
```
