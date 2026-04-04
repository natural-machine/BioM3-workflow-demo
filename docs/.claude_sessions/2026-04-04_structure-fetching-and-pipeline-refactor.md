# Session: Structure Fetching for SwissProt Hits & Pipeline Refactor

**Date:** 2026-04-04
**Pre-session state:** `git checkout 58f24c4`

## Summary

Two major additions in this session:

1. **Step 6b: Fetch reference structures for SwissProt BLAST hits.** Created a new pipeline step that resolves 3D structures for UniProt accessions from BLAST results. Downloads experimental PDB structures from RCSB (best resolution) with AlphaFold DB fallback. Supports offline PDB cross-reference lookup via local `uniprot_sprot.dat.gz`. Tested against SH3 results: 88 accessions -> 13 experimental, 71 AlphaFold, 4 not found.

2. **Pipeline refactor: `scripts/` -> `pipeline/` + config-driven runner.** Separated pipeline step scripts (01-08 + 06b) into `pipeline/` and kept helpers/utilities in `scripts/`. Created `run_pipeline.py`, a TOML-config-driven runner that executes any combination of steps with automatic conda/venv environment switching. Added example configs for SH3 (full and analysis-only) and CM.

## Changes

### New files

- **`pipeline/06b_fetch_hit_structures.sh`** — Bash wrapper for Step 6b. Auto-detects local `uniprot_sprot.dat.gz` at `../BioM3-data-share/databases/swissprot/`. Options: `--swissprot-dat`, `--no-local-dat`, `--alphafold-only`, `--experimental-only`.

- **`scripts/fetch_hit_structures.py`** — Python helper (stdlib only). Parses BLAST TSV for UniProt accessions, resolves PDB cross-references from local DAT file or UniProt REST API, downloads structures from RCSB/AlphaFold DB (queries API for current version URL, currently v6), writes `structure_manifest.tsv`.

- **`run_pipeline.py`** — Config-driven pipeline runner (~270 lines, stdlib only via `tomllib`). Features:
  - TOML config loading with step registry
  - Path derivation from `output_dir` + input file prefixes (all overridable)
  - Automatic conda/venv environment activation per step
  - Auto-detection of model weights from Step 2 output for Step 3
  - Conditional Step 6b (skipped for pdbaa databases)
  - `--steps` CLI override and `--dry-run` mode
  - All step IDs normalized to strings internally; TOML configs accept mixed int/string

- **`configs/pipeline_SH3.toml`** — Full pipeline config (Steps 1-8) for SH3
- **`configs/pipeline_SH3_analysis.toml`** — Analysis-only config (Steps 4-8) for SH3
- **`configs/pipeline_CM.toml`** — Full pipeline config for CM

### Moved files (git mv)

All 9 step scripts moved from `scripts/` to `pipeline/`:
- `01_embedding.sh`, `02_finetune.sh`, `03_generate.sh`, `04_samples_to_fasta.sh`, `05_colabfold.sh`, `06_blast_search.sh`, `06b_fetch_hit_structures.sh`, `07_compare_structures.sh`, `08_plot_results.sh`

Python helpers (`samples_to_fasta.py`, `fetch_hit_structures.py`, `make_plots.py`) and sync utilities stayed in `scripts/`. The `projdir=$(dirname "$0")/..` pattern in step scripts works from either location.

### Modified files

- **`run_pipeline_SH3.sh`** — Updated paths from `./scripts/` to `./pipeline/`. Added deprecation note pointing to `run_pipeline.py`. Added `activate_env()` helper supporting both conda and venv. Changed default `BLAST_DB` from `pdbaa` to `swissprot`. Added Step 6b (conditional on non-pdbaa).

- **`README.md`** — Added "Running the Pipeline" section with `run_pipeline.py` usage. Added Step 6b documentation. Updated workflow diagram to show 6b. Updated repo structure to show `pipeline/` and `scripts/` split with TOML configs. Updated all step example paths from `./scripts/` to `./pipeline/`.

- **`docs/demo_pipeline_SH3.md`** — Added Step 6b section. Updated all paths. Updated analysis pipeline intro to reference `run_pipeline.py`.

- **`docs/demo_pipeline_CM.md`** — Same updates as SH3 doc.

- **`.gitignore`** — Added `.claude/` directory.

- **`pipeline/*.sh`** — Updated USAGE/EXAMPLE header comments from `./scripts/` to `./pipeline/`.

## Design decisions

- **AlphaFold version URL**: AlphaFold DB moved to v6; hardcoding version URLs breaks. The script queries the AlphaFold API (`/api/prediction/{accession}`) to get the current `pdbUrl` dynamically.

- **Python helpers stay in `scripts/`**: Step scripts reference helpers as `python scripts/samples_to_fasta.py` (relative to projdir). Keeping helpers in `scripts/` means zero path changes in the step scripts themselves.

- **TOML for pipeline configs**: Uses `tomllib` (stdlib since Python 3.11). Supports comments (unlike JSON), no implicit type coercion footguns (unlike YAML), zero dependencies.

- **Step IDs as strings**: All step keys in `run_pipeline.py` are strings (`"1"` through `"8"`, plus `"6b"`). TOML configs can use ints or strings — `normalize_step_id()` handles both.

## Not implemented / future work

- **Steps 5 and 6 parallelism**: These steps are independent and could run concurrently. The runner keeps them serial for simplicity. A future `parallel = true` option could be added.

- **Step 2->3 checkpoint path**: Step 2 output includes a timestamp in the directory name. The runner auto-detects `state_dict.best.pth` via glob, but for fully automated 1-8 runs the user may want to verify the detected path.
