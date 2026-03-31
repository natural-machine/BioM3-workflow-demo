# Session: Analysis pipeline integration

**Date:** 2026-03-31

## Summary

Integrated post-generation analysis capabilities from the `../generation-comparison` repo into BioM3-workflow-demo. Added five new pipeline steps (Steps 4-8) for FASTA conversion, ColabFold structure prediction, BLAST homology search, TMalign structural comparison, and plotting. All scripts are generalized (not family-specific) and follow existing conventions. Also fixed stale documentation from the previous session.

## New scripts

### Step 4: `scripts/04_samples_to_fasta.sh` + `scripts/samples_to_fasta.py`
- Converts ProteoScribe `.pt` output into per-prompt FASTA files and a concatenated FASTA
- Python helper ported from `generation-comparison/scripts/samples_to_fasta.py` with debug prints removed and `weights_only=False` added
- Auto-detects number of prompts and replicas from the `.pt` file (no hardcoding)

### Step 5: `scripts/05_colabfold.sh`
- Runs `colabfold_batch` on each per-prompt FASTA file
- Inlines the ColabFold log parsing logic (previously a separate `parse_colabfold_logfile.sh`)
- Discovers FASTA files and prompt directories via glob instead of hardcoded counts
- Produces `colabfold_results.csv` with pLDDT, pTM, and PDB filename per structure

### Step 6: `scripts/06_blast_search.sh`
- Unified script combining PDB remote search and local NR search from the original repo
- Flags: `--db`, `--remote`, `--threads`, `--max-targets`, `--no-download-pdbs`
- Defaults to local `pdbaa` search; auto-downloads reference PDB files for PDB hits
- Tracks download failures in `not_found.txt`

### Step 7: `scripts/07_compare_structures.sh`
- Generalized from `compare_structures_DEMO.sh` / `compare_structures_SH3.sh` (which differed only by a `subdir=` variable)
- Takes all paths as explicit arguments
- Runs TMalign for each (ColabFold structure, BLAST reference) pair
- Outputs `results.csv` with TM-score, RMSD, chain lengths, aligned length, sequence identity

### Step 8: `scripts/08_plot_results.sh` + `scripts/make_plots.py`
- Python plotting script refactored to accept explicit file paths instead of deriving from a name
- Auto-detects prompts and replicas from data (removed hardcoded `{"DEMO": 3, "SH3": 5}` dictionary)
- Removed `appdata` section (specific to generation-comparison web app comparison)
- Removed `plt.show()` calls
- Optional `--colabfold-csv` flag adds a pLDDT plot

### `run_pipeline_SH3.sh`
- Top-level analysis pipeline script running Steps 4-8 for SH3
- All paths defined as variables at the top for easy customization
- Uses local BLAST by default

## Key generalizations vs. generation-comparison repo

| Original (hardcoded) | New (generalized) |
|---|---|
| `nprompts=5`, `nreplicates=5` | Auto-detect from data or glob |
| `subdir=DEMO` / `subdir=SH3` | Explicit path arguments |
| `for i in {1..5}` | `ls ... \| sort -V` dynamic discovery |
| Separate per-family scripts | Single script per step |
| `{"DEMO": 3, "SH3": 5}` in plots | `df["prompt"].unique()` |

## Files modified

### `.gitignore`
- Replaced stale `embeddings/`, `finetuning/`, `inference/` entries with `outputs/`

### `environment.sh`
- Added commented `BLAST_DB_PATH` variable for DGX Spark

### `README.md`
- Extended pipeline diagram from 3 to 8 steps
- Added optional prerequisites (ColabFold, BLAST+, TMalign)
- Added installation instructions for ColabFold and BLAST conda environments
- Added usage sections for Steps 4-8
- Updated repo structure tree with new scripts and output directories
- Fixed Step 3 heading: "Inference" → "Generation"
- Added `run_pipeline_SH3.sh` to repo structure tree

### `docs/demo_pipeline_SH3.md`
- Fixed all output paths from old layout (`embeddings/SH3`, `finetuning/SH3`, `inference/SH3`) to `outputs/SH3/...`
- Fixed `03_generate.sh` from 4-arg to 3-arg signature
- Fixed default epochs: 100 → 20
- Fixed checkpoint path to include `lightning_logs/` subdirectory
- Added Steps 4-8 with examples
- Added reference to `run_pipeline_SH3.sh`
- Updated "Full pipeline" section with all 8 steps

### `docs/demo_pipeline_CM.md`
- Same fixes as SH3: output paths, generate signature, epochs default, checkpoint paths
- Added Steps 4-8 with CM-specific examples
- Updated "Full pipeline" section with all 8 steps

### `scripts/sync_weights.sh` + `scripts/sync_databases.sh`
- Copied from `BioM3-dev/scripts/` to replace the old manual `ln -s` symlink approach in the README
- Creates physical subdirectories (e.g. `weights/LLMs/`) and symlinks individual files within them, rather than symlinking the directories themselves
- This allows local files to coexist alongside shared symlinks
- `sync_databases.sh` additionally handles top-level files (e.g. `provenance.tsv`)
- Both support `--dry-run` to preview changes and md5sum verification for existing files

### `environment.sh`
- Updated `BLAST_DB_PATH` comment to reference `data/databases/nr_blast/nr` (the conventional location after running `sync_databases.sh`)

### `README.md`
- Replaced manual `ln -s` symlink instructions with `sync_weights.sh` / `sync_databases.sh` usage
- Added shared database paths table alongside weights paths
- Added `data/databases/` and sync scripts to repo structure tree

## Design decisions

- **No automatic conda switching**: Scripts check for required binaries (`colabfold_batch`, `blastp`, `TMalign`) and emit clear error messages suggesting which environment to activate. This avoids fragile `conda activate` calls inside scripts.
- **BLAST unified**: Combined PDB remote and local NR search into one script with flags, since the only differences were `--remote`, database path, and thread count.
- **ColabFold log parsing inlined**: Rather than a separate script, the awk parsing block is embedded in `05_colabfold.sh` as a second phase, since it logically belongs to the same step.
- **PDB download bundled with BLAST**: The `pull_top_blast_pdb_hits` functionality is integrated into `06_blast_search.sh` (controlled by `--no-download-pdbs` flag) since downloading reference PDBs is only meaningful right after a BLAST search.
- **File-level symlinks over directory symlinks**: Sync scripts create real directories and symlink files within them. This lets users add local files (e.g. custom finetuned weights) alongside shared ones without breaking the symlink structure.
