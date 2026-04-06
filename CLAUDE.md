# CLAUDE.md

## Practices

Store session notes in docs/.claude_sessions/

## Project overview

BioM3-workflow-demo demonstrates the BioM3 finetuning and sequence generation workflow. It provides an 8-step pipeline: embedding, finetuning, generation (with FASTA output), structure prediction (ColabFold), BLAST search, structure fetching, structure comparison, result plotting, and an interactive web app. Depends on the BioM3-dev Python package for core functionality.

## Versioning

Version is defined in the `VERSION` file at the repo root (PEP 440 format, e.g. `0.1.0a1`). This is the single source of truth — read by `run_pipeline.py` and exported as `BIOM3_WORKFLOW_VERSION` by `environment.sh`. Cross-repo compatibility with BioM3-dev is tracked in `SYNC_LOG.md`.

## Ecosystem context

BioM3-workflow-demo is a demonstration repo in the BioM3 multi-repo ecosystem. See [docs/biom3_ecosystem.md](docs/biom3_ecosystem.md) for full details.

Related repositories:
- **BioM3-dev** — core Python library (installed via pip)
- **BioM3-data-share** — shared model weights, datasets, and reference databases
- **BioM3-workspace-template** — *(planned)* workspace configuration template

Machine-specific repo paths are in `.claude/repo_paths.json` (gitignored, not version controlled). This file maps repo names to absolute paths on the current machine.

Version compatibility with BioM3-dev is tracked in [SYNC_LOG.md](SYNC_LOG.md).

## Repository layout

```
pipeline/           # Step scripts (01_embedding.sh through 08_webapp.sh)
scripts/            # Helper scripts (sync, setup)
configs/            # JSON model/training configs + TOML pipeline configs
data/               # Input CSVs and intermediate data (gitignored)
weights/            # Symlinked model weights from BioM3-data-share (gitignored)
outputs/            # Pipeline outputs per step (gitignored)
logs/               # Training and pipeline logs (gitignored)
docs/               # Demo walkthroughs (SH3, CM) and session notes
run_pipeline.py     # Pipeline runner (executes steps sequentially)
run_pipeline_SH3.sh # Convenience wrapper for SH3 demo
environment.sh      # Environment variables (source before running)
```

## Building and running

Requires BioM3-dev installed (`pip install git+https://github.com/addison-nm/BioM3-dev.git` or `pip install -e /path/to/BioM3-dev`). Source `environment.sh` before running pipeline steps.

```bash
source environment.sh
python run_pipeline.py configs/pipeline_SH3.toml   # full pipeline
./pipeline/01_embedding.sh                          # individual step
```

Steps 4-7 require separate conda environments (colabfold, blast-env). The pipeline runner handles environment activation.

Weights and databases are symlinked from BioM3-data-share. See README.md for per-machine paths and sync instructions.

## Commit style

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <short summary>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

Keep the summary under 72 characters.
