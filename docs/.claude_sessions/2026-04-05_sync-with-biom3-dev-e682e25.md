# Session: Sync with BioM3-dev (e682e25)

**Date:** 2026-04-05
**Scope:** Sync BioM3-workflow-demo with 21 BioM3-dev commits (f30d682..e682e25), remove Step 4, modernize inference configs

## Context

BioM3-dev had 21 commits since the last sync at `f30d682`. Key upstream changes:
- Inference configs migrated to lean `_base_configs` composition (`385f410`)
- Training output dirs restructured: `checkpoints/<run_id>/` + `runs/<run_id>/` (`4200fa4`)
- Old `config_finetune.sh` replaced by JSON training configs (`e46bef8`)
- `biom3_ProteoScribe_sample` gained `--fasta`, `--fasta_merge`, `--fasta_dir` flags

## Changes

### 1. Inference configs: flat → lean `_base_configs` composition

Replaced three flat inference configs (47/14/62 keys) with lean configs that use `_base_configs` composition, matching BioM3-dev's `configs/inference/` pattern.

Created two new base model configs:
- `configs/models/_base_PenCL.json` — 15 keys (ESM-2 + BioBERT + projection)
- `configs/models/_base_Facilitator.json` — 3 keys (emb_dim, hid_dim, dropout)
- `configs/models/_base_ProteoScribe_1block.json` — already existed, unchanged

Rewritten configs:
- `stage1_config_PenCL_inference.json` — 47 → 5 keys (+ 15 from base = 18 effective)
- `stage2_config_Facilitator_sample.json` — 14 → 2 keys (+ 3 from base = 3 effective)
- `stage3_config_ProteoScribe_sample.json` — 62 → 8 keys (+ 25 from base = 26 effective)

Requires BioM3-dev >= commit `385f410` (which introduced `load_json_config` with `_base_configs` support in `biom3.core.helpers`).

### 2. Removed Step 4, integrated FASTA output into Step 3

BioM3-dev's `biom3_ProteoScribe_sample` now has `--fasta`, `--fasta_merge`, `--fasta_dir` flags that produce FASTA output directly during generation. This makes the standalone `04_samples_to_fasta.sh` / `samples_to_fasta.py` step redundant in the automated pipeline.

**FASTA naming convention change:**
- Old (Step 4): `{prefix}_prompt_1_samples.fasta`, `generated_seqs_allprompts.fasta` (1-indexed)
- New (Step 3): `prompt_0.fasta`, `prompt_1.fasta`, `all_sequences.fasta` (0-indexed)

**Files changed:**
- `pipeline/03_generate.sh` — added `--fasta`, `--fasta_merge`, `--fasta_dir` flag parsing and forwarding
- `pipeline/05_colabfold.sh` — changed from 3-arg to 2-arg interface (`<fasta_dir> <output_dir>`), updated file discovery glob to `prompt_*.fasta`
- `pipeline/06_blast_search.sh` — updated example filenames in header comments
- `run_pipeline.py`:
  - Removed Step 4 from `STEPS`, `STEP_ORDER`, `STEP_NAMES`
  - Step 3 now always passes `--fasta --fasta_merge --fasta_dir {samples_dir}`
  - Step 5 args reduced from 3 to 2 (dropped `pt_prefix`)
  - `d["fasta_file"]` changed to `all_sequences.fasta`
  - Removed `pt_prefix` derivation from `derive_paths`

**Retained as standalone utilities:** `04_samples_to_fasta.sh` and `scripts/samples_to_fasta.py` are unchanged — still usable for manual `.pt`-to-FASTA conversion.

### 3. Added Step 9 (Web App) to pipeline runner

- Added `"9": ("pipeline/09_webapp.sh", "biom3")` to `STEPS` dict
- Kept Step 9 **out of** `STEP_ORDER` (interactive/blocking — use `--steps 9` explicitly)
- Fixed step ordering to support extras not in `STEP_ORDER`
- Added case "9" in `build_step_args` with optional `--port` forwarding from `[webapp]` TOML section

### 4. Forwarded remaining generation options

`run_pipeline.py` Step 3 now forwards all generation/animation options from the TOML `[generation]` section:
- `animation_dir`, `animation_style`, `animation_metrics`, `store_probabilities`
- (Previously only `unmasking_order`, `token_strategy`, `animate_prompts`, `animate_replicas` were forwarded)

### 5. Documentation updates

Updated all user-facing docs to reflect:
- `configs/config_finetune.sh` → `configs/stage3_config_finetune.json` (deleted shell config)
- New finetuning output structure: `checkpoints/<run_id>/` + `runs/<run_id>/` (no more `lightning_logs/`)
- Step 4 removal and FASTA output from Step 3
- Step 5 two-arg interface
- `all_sequences.fasta` filename

Files: `README.md`, `CLAUDE.md`, `docs/demo_pipeline_SH3.md`, `docs/demo_pipeline_CM.md`

### 6. TOML and legacy script updates

- All 4 pipeline TOMLs: removed step 4 from `steps` lists
- `pipeline_SH3_analysis.toml`: starts at Step 5, added note about requiring prior `--fasta` run
- `run_pipeline_SH3.sh`: removed Step 4 block, updated Step 5/6 args

## Verification

- `python run_pipeline.py configs/pipeline_SH3.toml --dry-run` — Step 4 gone, Step 3 passes `--fasta` flags, Step 5 gets 2 args
- `python run_pipeline.py configs/pipeline_SH3.toml --steps 9 --dry-run` — Step 9 works when explicitly requested
- `python run_pipeline.py configs/pipeline_SH3_analysis.toml --dry-run` — analysis starts at Step 5
- `_base_configs` resolution verified: Stage 1 (18 keys), Stage 2 (3 keys), Stage 3 (26 keys)

## Sync status

SYNC_LOG.md updated with new row: `e682e25` (BioM3-dev HEAD as of 2026-04-05).
