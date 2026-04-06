# BioM3 Workflow Demo

A demonstration of the [BioM3 framework](https://openreview.net/forum?id=L1MyyRCAjX) (NeurIPS 2024) finetuning and sequence generation workflow. This repo shows how to take a pretrained ProteoScribe model and finetune it on a protein family dataset, generate novel protein sequences guided by natural language prompts, and evaluate the results with structure prediction and homology search.

## BioM3 Ecosystem

This demo is part of a multi-repo ecosystem:

| Repository | Role | Description |
|------------|------|-------------|
| [BioM3-dev](https://github.com/addison-nm/BioM3-dev) | Core library | Python package: 3-stage pipeline, dataset construction, training |
| [BioM3-data-share](https://github.com/natural-machine/BioM3-data-share) | Shared data | Model weights, datasets, and reference databases synced across clusters |
| **BioM3-workflow-demo** (this repo) | Demo workflows | End-to-end finetuning and generation demonstration pipeline |
| BioM3-workspace-template | Workspace setup | *(Planned)* Standardized workspace template for new research projects |

See [docs/biom3_ecosystem.md](./docs/biom3_ecosystem.md) for cross-repo workflows, version compatibility, and shared data architecture.

## Overview

The workflow consists of eight steps:

```txt
Input CSV (protein sequences + text descriptions)
        │
        ▼
01_embedding.sh            → Embed sequences and text (PenCL → Facilitator → HDF5)
        │
        ▼
02_finetune.sh             → Finetune ProteoScribe on embedded data
        │
        ▼
03_generate.sh             → Generate novel protein sequences from text prompts
        │                    (produces FASTA output with --fasta --fasta_merge)
        │
        ├──────────────────────────────┐
        ▼                              ▼
04_colabfold.sh            05_blast_search.sh
  Structure prediction       BLAST homology search
  (ColabFold/AlphaFold2)     + download reference PDBs (pdbaa only)
        │                              │
        │                      05b_fetch_hit_structures.sh
        │                        Fetch reference structures
        │                        for SwissProt/other hits
        │                        (experimental PDB + AlphaFold)
        │                              │
        └──────────┬───────────────────┘
                   ▼
        06_compare_structures.sh  → TMalign structural comparison
                   │
                   ▼
        07_plot_results.sh        → Visualization (TM-score, RMSD, pLDDT)
                   │
                   ▼
        08_webapp.sh              → Interactive web app (structure viewer,
                                    alignment, unmasking order, BLAST)
```

Each step is a standalone script in `pipeline/` that wraps BioM3 CLI entrypoints or external tools. Inputs and outputs are explicit — you control where data is read from and written to. Steps 4 and 5 can run in parallel. Step 5b is needed when searching non-PDB databases (SwissProt, NR, etc.) to resolve reference structures for BLAST hits. Step 8 launches an interactive web app for exploring outputs.

## Prerequisites

**Required (Steps 1-3):**

- A working installation of the [BioM3-dev](https://github.com/addison-nm/BioM3-dev) package
- Pretrained model weights in the `weights/` directory
- An NVIDIA GPU (tested on DGX Spark)

**Optional (Steps 4-7):**

- [ColabFold](https://github.com/sokrypton/ColabFold) — for structure prediction (Step 4)
- [BLAST+](https://blast.ncbi.nlm.nih.gov/doc/blast-help/downloadblastdata.html) — for homology search (Step 5)
- [TMalign](https://zhanggroup.org/TM-align/) — for structural comparison (Step 6)
- matplotlib, seaborn, pandas — for plotting (Step 7)
- [Streamlit](https://streamlit.io/), [py3Dmol](https://github.com/arichardsmith/py3Dmol) — for the web app (Step 8, included with BioM3-dev)

## Installation and setup

### 1. Clone this repository

```bash
git clone <repo-url> && cd BioM3-workflow-demo
```

### 2. Create environment and install BioM3

Follow the setup instructions for your machine in the BioM3-dev repository. Machine-specific requirements are in `requirements/`:

```bash
conda create -n biom3-env python=3.12
conda activate biom3-env
python -m pip install torch==2.8 torchvision --index-url https://download.pytorch.org/whl/cu129
python -m pip install -r requirements/spark.txt    # or polaris.txt, aurora.txt
python -m pip install git+https://github.com/addison-nm/BioM3-dev.git
```

### 3. Optional: ColabFold and BLAST environments

ColabFold and BLAST each require their own conda environment:

```bash
# ColabFold (Step 4)
conda create -n colabfold -c conda-forge -c bioconda python=3.13 kalign2=2.04 hhsuite=3.3.0 mmseqs2=18.8cc5c
conda activate colabfold
pip install "colabfold[alphafold,openmm]" "jax[cuda]==0.6.2" "openmm[cuda12]"

# BLAST (Step 5)
conda create -n blast-env
conda activate blast-env
conda install -c bioconda blast
```

TMalign (Step 6) must be compiled from source or downloaded as a binary from [https://zhanggroup.org/TM-align/](https://zhanggroup.org/TM-align/) and placed on your PATH.

### 4. Weights and databases

Pretrained model weights and reference databases are stored in a shared `BioM3-data-share` directory on each machine. The sync scripts create local directories with symlinks to individual files (not directory-level symlinks), which allows adding local files alongside shared ones.

#### Shared data locations

| Machine | Weights path | Databases path |
|---------|-------------|---------------|
| DGX Spark | `/data/data-share/BioM3-data-share/data/weights` | `/data/data-share/BioM3-data-share/databases` |
| Polaris (ALCF) | `/grand/NLDesignProtein/sharepoint/BioM3-data-share/data/weights` | `/grand/NLDesignProtein/sharepoint/BioM3-data-share/databases` |
| Aurora (ALCF) | `/flare/NLDesignProtein/sharepoint/BioM3-data-share/data/weights` | `/flare/NLDesignProtein/sharepoint/BioM3-data-share/databases` |

#### Syncing weights

```bash
# Preview what will be linked
./scripts/sync_weights.sh /data/data-share/BioM3-data-share/data/weights weights --dry-run

# Apply symlinks
./scripts/sync_weights.sh /data/data-share/BioM3-data-share/data/weights weights
```

This creates the `weights/` subdirectories (LLMs, PenCL, Facilitator, ProteoScribe) and symlinks each file inside them to the shared source.

#### Syncing databases (optional, for local BLAST)

```bash
# Preview
./scripts/sync_databases.sh /data/data-share/BioM3-data-share/databases data/databases --dry-run

# Apply symlinks
./scripts/sync_databases.sh /data/data-share/BioM3-data-share/databases data/databases
```

This is only needed if you plan to run local BLAST searches (Step 5 with `--db <path>`).

#### Required weight files

The pipeline expects the following files under `weights/`:

| Directory | File | Description |
| --------- | ---- | ----------- |
| `weights/LLMs/` | `esm2_t33_650M_UR50D.pt` | ESM-2 protein language model |
| `weights/LLMs/` | `BiomedNLP-BiomedBERT-base-uncased-abstract-fulltext/` | BiomedBERT text encoder |
| `weights/PenCL/` | `PenCL_V09152023_last.ckpt` | PenCL encoder (Stage 1) |
| `weights/Facilitator/` | `Facilitator_MMD15.ckpt/last.ckpt` | Facilitator model (Stage 2) |
| `weights/ProteoScribe/` | `ProteoScribe_epoch200.pth` | Pretrained ProteoScribe base model |

### 5. Data

Place your protein family datasets under `data/`. Each family gets its own subdirectory:

```
data/
  SH3/
    SH3_dataset.csv
  CM/
    CM_dataset.csv
```

Input CSV files should contain at minimum:
- `protein_sequence` — amino acid sequences
- `primary_Accession` — unique identifier per entry
- A text description column with natural language prompts

## Usage

### Running the pipeline

The recommended way to run the pipeline is with the config-driven runner. Create a TOML config file specifying your inputs, outputs, environments, and which steps to run:

```bash
# Full pipeline (Steps 1-7)
python run_pipeline.py configs/pipelines/SH3.toml

# Analysis only (Steps 4-7)
python run_pipeline.py configs/pipelines/SH3_analysis.toml

# Override steps on the CLI
python run_pipeline.py configs/pipelines/SH3.toml --steps 5 5b 6 7

# Preview what would run
python run_pipeline.py configs/pipelines/SH3.toml --dry-run
```

The runner activates the correct conda/venv environment for each step automatically. See `configs/pipelines/SH3.toml` for a full example config.

Each step can also be run individually — see the sections below for standalone usage.

### Step 1: Embedding

Process a CSV through the BioM3 embedding pipeline (PenCL → Facilitator → HDF5 compilation):

```bash
./pipeline/01_embedding.sh <input_csv> <output_dir>
```

Example:

```bash
./pipeline/01_embedding.sh data/SH3/SH3_dataset.csv outputs/SH3/embeddings
```

This produces `outputs/SH3/embeddings/SH3_dataset.compiled_emb.hdf5`, ready for finetuning.

### Step 2: Finetuning

Finetune the pretrained ProteoScribe base model on the embedded dataset:

```bash
./pipeline/02_finetune.sh <hdf5_file> <output_dir> [epochs]
```

Example:

```bash
./pipeline/02_finetune.sh \
    outputs/SH3/embeddings/SH3_dataset.compiled_emb.hdf5 \
    outputs/SH3/finetuning \
    50
```

This loads `weights/ProteoScribe/ProteoScribe_epoch200.pth`, freezes most of the network, and trains the last transformer block. Checkpoints and logs are saved under the specified output directory.

Finetuning hyperparameters are defined in `configs/stage3_training/finetune.json`. The defaults are tuned for the DGX Spark (single GPU, bf16 precision).

### Step 3: Generation

Generate novel protein sequences using the finetuned model:

```bash
./pipeline/03_generate.sh <model_weights> <input_csv> <output_dir>
```

Example:

```bash
./pipeline/03_generate.sh \
    outputs/SH3/finetuning/checkpoints/.../state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation
```

This embeds the input prompts through PenCL and Facilitator (writing to `<output_dir>/embeddings/`), then runs ProteoScribe diffusion sampling to generate sequences. Generated sequences are saved as a `.pt` file in the output directory.

#### Sampling options

Two strategies control how ProteoScribe generates sequences and can be set via CLI flags or in `configs/inference/stage3_ProteoScribe_sample.json`:

| Option | Values | Default | Description |
| ------ | ------ | ------- | ----------- |
| `--unmasking_order` | `random`, `confidence`, `confidence_no_pad` | `random` | Order in which masked positions are revealed |
| `--token_strategy` | `sample`, `argmax` | `sample` | Token selection: stochastic (Gumbel-max) or deterministic |
| `--store_probabilities` | *(flag)* | off | Store per-step conditional probability distributions as `.npz` files. Memory-intensive for long sequences or many replicas |

Example with deterministic generation:

```bash
./pipeline/03_generate.sh \
    outputs/SH3/finetuning/checkpoints/.../state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation \
    --token_strategy argmax --unmasking_order confidence
```

#### Animation

Visualise the diffusion denoising process as GIF animations:

```bash
./pipeline/03_generate.sh \
    outputs/SH3/finetuning/checkpoints/.../state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation \
    --animate_prompts 0 1 2
```

| Option | Values | Default | Description |
| ------ | ------ | ------- | ----------- |
| `--animate_prompts` | indices, `all`, `none` | *(disabled)* | Which prompts to animate |
| `--animate_replicas` | integer, `all`, `none` | `1` | How many replicas per prompt |
| `--animation_dir` | path | `<output_dir>/animations/` | Where to write GIFs |
| `--animation_style` | `brightness`, `colorbar`, `logo` | `brightness` | Probability visualization style. `colorbar` and `logo` require `--store_probabilities` |
| `--animation_metrics` | metric names | *(none)* | Per-position metric annotation boxes (e.g. `confidence`). Requires `--store_probabilities` |

Animations are disabled by default and add negligible overhead when enabled.

### Convert to FASTA (standalone utility)

> **Note:** This is no longer part of the automated pipeline — Step 3 now produces FASTA directly with `--fasta --fasta_merge`. This script is kept as a standalone utility for manual `.pt`-to-FASTA conversion.

```bash
./scripts/samples_to_fasta.sh <input_pt> <output_dir>
```

### Step 4: Structure Prediction (ColabFold)

Predict 3D structures for generated sequences using ColabFold:

```bash
conda activate colabfold
./pipeline/04_colabfold.sh <fasta_dir> <output_dir>
```

Example:

```bash
./pipeline/04_colabfold.sh \
    outputs/SH3/samples \
    outputs/SH3/structures
```

This runs `colabfold_batch` on each per-prompt FASTA file and produces PDB structures and a summary CSV with pLDDT and pTM scores.

### Step 5: BLAST Search

Search for homologous sequences (can run in parallel with Step 4):

```bash
conda activate blast-env
./pipeline/05_blast_search.sh <fasta_file> <output_dir> [options]
```

The `--db` flag accepts any known NCBI database name or a path to a local database. Known names default to remote search; paths always use local search.

| Database | `--db` value | Description |
|----------|-------------|-------------|
| SwissProt | `swissprot` (default) | Curated UniProt sequences |
| PDB | `pdbaa` | Protein structures in PDB (enables PDB file download) |
| NR | `nr` | Non-redundant protein sequences |
| RefSeq Protein | `refseq_protein` | NCBI reference protein sequences |
| Environmental NR | `env_nr` | Metagenomic protein sequences |
| TSA NR | `tsa_nr` | Transcriptome shotgun assembly proteins |
| Patent | `pat` | Patent protein sequences |

Example (remote SwissProt search, default):

```bash
./pipeline/05_blast_search.sh \
    outputs/SH3/samples/all_sequences.fasta \
    outputs/SH3/blast
```

Example (remote PDB search with structure downloads):

```bash
./pipeline/05_blast_search.sh \
    outputs/SH3/samples/all_sequences.fasta \
    outputs/SH3/blast \
    --db pdbaa
```

Example (local SwissProt or NR search):

```bash
./pipeline/05_blast_search.sh \
    outputs/SH3/samples/all_sequences.fasta \
    outputs/SH3/blast \
    --db /path/to/BioM3-data-share/databases/swissprot_blast/swissprot --threads 16

./pipeline/05_blast_search.sh \
    outputs/SH3/samples/all_sequences.fasta \
    outputs/SH3/blast \
    --db /path/to/BioM3-data-share/databases/nr_blast/nr --threads 16
```

By default, known database names run as NCBI remote searches. Use `--local` to force a local search (requires the database files on disk or in `BLASTDB`). Local copies of SwissProt and NR are available under `BioM3-data-share/databases/` (`swissprot_blast/` and `nr_blast/`). PDB file download only occurs for `pdbaa` hits — for SwissProt or other databases, use Step 5b to fetch reference structures. Options: `--db`, `--remote`, `--local`, `--threads`, `--max-targets`, `--no-download-pdbs`.

### Step 5b: Fetch Reference Structures

Fetch 3D structures for BLAST hits from non-PDB databases (SwissProt, NR, etc.). For each UniProt accession, downloads the best experimental structure from RCSB when available, falling back to AlphaFold DB predicted structures. PDB cross-references are resolved from a local `uniprot_sprot.dat.gz` (auto-detected at `../BioM3-data-share/databases/swissprot/`) or via the UniProt REST API.

```bash
./pipeline/05b_fetch_hit_structures.sh <blast_tsv> <output_dir> [options]
```

Example:

```bash
./pipeline/05b_fetch_hit_structures.sh \
    outputs/SH3/blast/blast_hit_results.tsv \
    outputs/SH3/blast
```

Example (AlphaFold only, skip experimental PDB lookup):

```bash
./pipeline/05b_fetch_hit_structures.sh \
    outputs/SH3/blast/blast_hit_results.tsv \
    outputs/SH3/blast --alphafold-only
```

Structures are saved as `{accession}.pdb` in `<output_dir>/reference_structures/`, which integrates directly with Step 6. A `structure_manifest.tsv` is written with source metadata (experimental vs. AlphaFold, PDB ID, resolution) for each accession.

Options: `--swissprot-dat <path>`, `--no-local-dat`, `--alphafold-only`, `--experimental-only`.

### Step 6: Structure Comparison (TMalign)

Compare predicted structures against BLAST reference structures:

```bash
./pipeline/06_compare_structures.sh <colabfold_csv> <blast_tsv> <structures_dir> <reference_dir> <output_dir>
```

Example:

```bash
./pipeline/06_compare_structures.sh \
    outputs/SH3/structures/colabfold_results.csv \
    outputs/SH3/blast/blast_hit_results.tsv \
    outputs/SH3/structures \
    outputs/SH3/blast/reference_structures \
    outputs/SH3/comparison
```

This produces `results.csv` with TM-score, RMSD, and sequence identity for each query-reference pair.

### Step 7: Plot Results

Generate plots from the comparison metrics:

```bash
./pipeline/07_plot_results.sh <results_csv> <output_dir> [--colabfold-csv <path>]
```

Example:

```bash
./pipeline/07_plot_results.sh \
    outputs/SH3/comparison/results.csv \
    outputs/SH3/images \
    --colabfold-csv outputs/SH3/structures/colabfold_results.csv
```

This produces strip plots for TM-score, RMSD, sequence identity, and (optionally) pLDDT.

### Step 8: Web App

Launch the BioM3 interactive web application for exploring pipeline outputs:

```bash
./pipeline/08_webapp.sh
```

This starts a Streamlit app at `http://localhost:8501` with six analysis pages:

| Page | Description |
| ---- | ----------- |
| View Structure | Load a PDB file and render it in 3D with configurable style and coloring |
| Align Structures | Superimpose two structures on C-alpha atoms, report RMSD |
| Highlight Residues | Color selected residue positions on a structure |
| Color by Values | Map per-residue float values (pLDDT, conservation) onto a structure with colormaps |
| Unmasking Order | Visualize the diffusion generation order from a `.pt` output |
| BLAST Search | Run a remote NCBI BLAST search from a protein sequence |

The app browses data directories configured in `configs/app_settings.json`. By default it exposes `outputs/`, `data/`, and `weights/`. Each page also supports direct file upload.

Options: `--port PORT` (default: 8501).

## Repository structure

```
BioM3-workflow-demo/
├── run_pipeline.py                             # Config-driven pipeline runner
├── configs/
│   ├── pipelines/                             # TOML pipeline configs
│   │   ├── SH3.toml                          # SH3 full pipeline (Steps 1-7)
│   │   ├── SH3_analysis.toml                # SH3 analysis only (Steps 4-7)
│   │   ├── SH3_mini.toml                    # SH3 mini subset (quick test)
│   │   └── CM.toml                           # CM full pipeline (Steps 1-7)
│   ├── inference/                             # Inference configs (Stages 1-3)
│   │   ├── stage1_PenCL.json
│   │   ├── stage2_Facilitator.json
│   │   ├── stage3_ProteoScribe_sample.json
│   │   └── models/                           # Base model configs (PenCL, Facilitator)
│   ├── stage3_training/                       # Training configs (Stage 3)
│   │   ├── finetune.json
│   │   └── models/                           # Base model config (ProteoScribe)
│   └── app_settings.json                    # Web app browsable directories
├── pipeline/                                   # Pipeline step scripts
│   ├── 01_embedding.sh                        # Step 1: CSV → HDF5
│   ├── 02_finetune.sh                         # Step 2: HDF5 → finetuned model
│   ├── 03_generate.sh                         # Step 3: prompts → sequences
│   ├── 04_colabfold.sh                        # Step 4: FASTA → predicted structures
│   ├── 05_blast_search.sh                     # Step 5: FASTA → BLAST hits
│   ├── 05b_fetch_hit_structures.sh            # Step 5b: fetch structures for non-PDB hits
│   ├── 06_compare_structures.sh               # Step 6: TMalign comparison
│   ├── 07_plot_results.sh                     # Step 7: metric plots
│   └── 08_webapp.sh                          # Step 8: interactive web app
├── scripts/                                    # Helpers and utilities
│   ├── samples_to_fasta.sh                    # Standalone utility: .pt → FASTA
│   ├── samples_to_fasta.py                    # Python helper for FASTA conversion
│   ├── fetch_hit_structures.py                # Python helper for Step 5b
│   ├── make_plots.py                          # Python helper for Step 8
│   ├── sync_weights.sh                        # Sync weights from shared directory
│   └── sync_databases.sh                      # Sync databases from shared directory
├── data/                                       # Input datasets (per family)
│   └── databases/                             # Reference databases (optional, for local BLAST)
├── outputs/                                    # Pipeline outputs (per family)
│   └── <family>/
│       ├── embeddings/                        # Step 1: embedding outputs
│       ├── finetuning/                        # Step 2: checkpoints and logs
│       ├── generation/                        # Step 3: generated sequences
│       ├── samples/                           # Step 3: FASTA output (--fasta)
│       ├── structures/                        # Step 4: ColabFold PDBs and results
│       ├── blast/                             # Step 5: BLAST hits and reference PDBs
│       ├── comparison/                        # Step 6: TMalign metrics
│       └── images/                            # Step 7: plots
└── weights/                                    # Pretrained model weights
```

## Configuration

### Inference configs (`configs/*.json`)

The JSON config files control model architecture and inference parameters. Most fields should not need modification unless you are using different backbone weights. The Stage 3 config includes sampling parameters you may want to adjust:

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| `unmasking_order` | `random` | Position reveal order: `random`, `confidence` (most-confident first), or `confidence_no_pad` (confidence, skipping PAD predictions) |
| `token_strategy` | `sample` | Token selection: `sample` (stochastic, Gumbel-max) or `argmax` (deterministic) |
| `num_replicas` | `5` | Number of sequences generated per prompt |
| `diffusion_steps` | `1024` | Number of diffusion steps |

These can also be overridden per-run via CLI flags (see Step 3).

### Finetuning config (`configs/stage3_training/finetune.json`)

Key parameters you may want to adjust:

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| `epochs` | 20 | Number of training epochs |
| `batch_size` | 32 | Training batch size |
| `lr` | 1e-4 | Learning rate |
| `valid_size` | 0.2 | Fraction of data used for validation |
| `finetune_last_n_blocks` | 1 | Number of transformer blocks to unfreeze |
| `finetune_last_n_layers` | 1 | Number of layers per block to unfreeze |
| `precision` | bf16 | Training precision |
| `wandb` | false | Enable Weights & Biases logging |

## References

[1] Natural Language Prompts Guide the Design of Novel Functional Protein Sequences. Nikša Praljak, Hugh Yeh, Miranda Moore, Michael Socolich, Rama Ranganathan, Andrew L. Ferguson. bioRxiv 2024.11.11.622734; doi: [10.1101/2024.11.11.622734](https://doi.org/10.1101/2024.11.11.622734)
