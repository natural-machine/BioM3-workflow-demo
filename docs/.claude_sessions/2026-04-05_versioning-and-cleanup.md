# Session: Versioning and final cleanup

**Date:** 2026-04-05
**Scope:** Add versioning system, log version in pipeline output, fix doc inconsistencies

## Changes

### 1. Versioning system

Added a `VERSION` file at the repo root (`0.1.0a1`, PEP 440 format) as the single source of truth, matching BioM3-dev's versioning scheme.

- **`run_pipeline.py`**: reads `VERSION`, supports `--version` flag, prints version in runner header (`BioM3 Pipeline Runner v0.1.0a1`)
- **`environment.sh`**: exports `BIOM3_WORKFLOW_VERSION` from `VERSION` file
- **Pipeline scripts**: all 9 step banners now include `(workflow v${BIOM3_WORKFLOW_VERSION:-unknown})`, falling back gracefully if `environment.sh` wasn't sourced

### 2. Doc fixes

- `README.md`: fixed inference config section header (`configs/*.json` → `configs/inference/*.json`), corrected `make_plots.py` step reference (Step 8 → Step 7)
- `CLAUDE.md`: removed stale `run_pipeline_SH3.sh` reference, added `VERSION` to repo layout, fixed TOML config path (`configs/pipeline_SH3.toml` → `configs/pipelines/SH3.toml`)
