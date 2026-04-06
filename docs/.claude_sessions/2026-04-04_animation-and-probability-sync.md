# Session: Sync animation visualization and probability storage from BioM3-dev

**Date:** 2026-04-04
**BioM3-dev range:** `844f2d1..f30d682` (8 commits)

## Summary

Synced BioM3-workflow-demo with new Stage 3 features added in BioM3-dev:
`confidence_no_pad` unmasking order, `--store_probabilities` flag, colored grid
animation styles (`--animation_style`), and per-position metric annotations
(`--animation_metrics`). Added Step 9: a web app launcher (`09_webapp.sh`) and
data directory config (`app_data_dirs.json`) for the new `biom3.app` Streamlit
application.

## Pre-session state

```bash
git log --oneline -1  # 5c50286 docs: add ecosystem documentation and CLAUDE.md
```

## Changes

### 1. `pipeline/03_generate.sh`
- Updated `--unmasking_order` choices: `{random,confidence}` -> `{random,confidence,confidence_no_pad}`
- Added `--animation_style {brightness,colorbar,logo}` flag (string, default: brightness)
- Added `--animation_metrics NAME [NAME ...]` flag (multi-value, same pattern as `--animate_prompts`)
- Added `--store_probabilities` flag (boolean, no argument)
- Updated header comments, usage block, echo status lines, and completion message
- Added `probabilities/` to output documentation

### 2. `README.md`
- Added `confidence_no_pad` to `--unmasking_order` values in sampling options table
- Added `--store_probabilities` row to sampling options table
- Added `--animation_style` and `--animation_metrics` rows to animation options table
- Updated `unmasking_order` description in Configuration section

### 3. `docs/demo_pipeline_SH3.md`
- Added `confidence_no_pad` to `unmasking_order` in config parameters section
- Added colored animation example with `--store_probabilities`, `--animation_style`, `--animation_metrics`
- Added `probabilities/` directory to expected outputs

### 4. `docs/demo_pipeline_CM.md`
- Same changes as SH3 doc, adapted for CM paths

### 5. `configs/app_data_dirs.json` (new)
- Data directory config for the BioM3 web app
- Exposes `outputs/`, `data/`, and `weights/` as browsable directories

### 6. `pipeline/09_webapp.sh` (new)
- Launcher script for the BioM3 Streamlit web app (`biom3.app`)
- Copies `app_data_dirs.json` to the installed biom3 package's config location before launch
- Restores original config on exit via trap
- Supports `--port` flag for custom port
- Six app pages: View Structure, Align Structures, Highlight Residues, Color by Values, Unmasking Order, BLAST Search

### 7. `README.md`
- Updated workflow diagram to include Step 9
- Added Step 9 section with page descriptions table
- Added `09_webapp.sh` to repo structure listing
- Added `app_data_dirs.json` to repo structure listing
- Added Streamlit/py3Dmol to prerequisites

### 8. `docs/demo_pipeline_SH3.md` and `docs/demo_pipeline_CM.md`
- Added Step 9 section
- Added Step 9 to "Full pipeline" command blocks

### 9. `SYNC_LOG.md`
- Updated sync row to include webapp additions

### Not modified
- `configs/stage3_config_ProteoScribe_sample.json` -- no new config fields in BioM3-dev; all new features are CLI-only with argparse defaults

## BioM3-dev commits covered

| Commit | Type | Description | Demo impact |
| --- | --- | --- | --- |
| `f30d682` | docs | Session note for probability storage and confidence_no_pad | None |
| `c90a224` | feat | Probability visualization and metric annotations in animations | `--animation_style`, `--animation_metrics` flags |
| `f06bfba` | feat | Data directory browser for web app | `app_data_dirs.json` config + `09_webapp.sh` launcher |
| `d310388` | docs | Sequence generation strategies guide | None (BioM3-dev docs only) |
| `3e8c433` | feat | biom3.viz visualization library and biom3.app web interface | `09_webapp.sh` launcher wraps `biom3.app` |
| `846dc15` | feat | confidence_no_pad unmasking order | `--unmasking_order` choice update |
| `5f34ba8` | feat | --store_probabilities flag | `--store_probabilities` flag |
| `5e988b6` | feat | Colored grid animation for denoising | Covered by `--animation_style` |

## Config divergences (intentional)

| Field | BioM3-dev | workflow-demo | Reason |
| --- | --- | --- | --- |
| `seed` | `42` | `0` | Demo uses different seed |
| `num_replicas` | `5` | `10` | Demo generates more replicas |
| `batch_size_sample` | `32` | `64` | Demo uses larger sampling batch |
| `unmasking_order` | `"random"` | `"confidence"` | Demo defaults to confidence ordering |

## Not implemented / deferred

- **`docs/sequence_generation_strategies.md`**: BioM3-dev strategies guide not copied into workflow-demo; the README and demo docs cover usage for the demo context.
