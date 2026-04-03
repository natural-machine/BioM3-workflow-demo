# BioM3 Workflow Demo

A demonstration of the [BioM3 framework](https://openreview.net/forum?id=L1MyyRCAjX) (NeurIPS 2024) finetuning and sequence generation workflow. This repo shows how to take a pretrained ProteoScribe model and finetune it on a protein family dataset, generate novel protein sequences guided by natural language prompts, and evaluate the results with structure prediction and homology search.

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
        │
        ▼
04_samples_to_fasta.sh     → Convert .pt output to FASTA files
        │
        ├──────────────────────────────┐
        ▼                              ▼
05_colabfold.sh            06_blast_search.sh
  Structure prediction       BLAST homology search
  (ColabFold/AlphaFold2)     + download reference PDBs
        │                              │
        └──────────┬───────────────────┘
                   ▼
        07_compare_structures.sh  → TMalign structural comparison
                   │
                   ▼
        08_plot_results.sh        → Visualization (TM-score, RMSD, pLDDT)
```

Each step is a standalone script in `scripts/` that wraps BioM3 CLI entrypoints or external tools. Inputs and outputs are explicit — you control where data is read from and written to. Steps 5 and 6 can run in parallel.

## Prerequisites

**Required (Steps 1-4):**

- A working installation of the [BioM3-dev](https://github.com/addison-nm/BioM3-dev) package
- Pretrained model weights in the `weights/` directory
- An NVIDIA GPU (tested on DGX Spark)

**Optional (Steps 5-8):**

- [ColabFold](https://github.com/sokrypton/ColabFold) — for structure prediction (Step 5)
- [BLAST+](https://blast.ncbi.nlm.nih.gov/doc/blast-help/downloadblastdata.html) — for homology search (Step 6)
- [TMalign](https://zhanggroup.org/TM-align/) — for structural comparison (Step 7)
- matplotlib, seaborn, pandas — for plotting (Step 8)

## Installation and setup

### 1. Clone this repository

```bash
git clone <repo-url> && cd BioM3-workflow-demo
```

### 2. Create environment and install BioM3

Follow the setup instructions for your machine in the BioM3-dev repository. For the DGX Spark:

```bash
conda create -n biom3-env python=3.12
conda activate biom3-env
python -m pip install torch==2.8 torchvision --index-url https://download.pytorch.org/whl/cu129
python -m pip install -r requirements_spark.txt
python -m pip install git+https://github.com/addison-nm/BioM3-dev.git
```

### 3. Optional: ColabFold and BLAST environments

ColabFold and BLAST each require their own conda environment:

```bash
# ColabFold (Step 5)
conda create -n colabfold -c conda-forge -c bioconda python=3.13 kalign2=2.04 hhsuite=3.3.0 mmseqs2=18.8cc5c
conda activate colabfold
pip install "colabfold[alphafold,openmm]" "jax[cuda]==0.6.2" "openmm[cuda12]"

# BLAST (Step 6)
conda create -n blast-env
conda activate blast-env
conda install -c bioconda blast
```

TMalign (Step 7) must be compiled from source or downloaded as a binary from [https://zhanggroup.org/TM-align/](https://zhanggroup.org/TM-align/) and placed on your PATH.

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

This is only needed if you plan to run local BLAST searches (Step 6 with `--db <path>`).

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

Activate your BioM3 environment before running any scripts:

```bash
conda activate biom3-env
```

### Step 1: Embedding

Process a CSV through the BioM3 embedding pipeline (PenCL → Facilitator → HDF5 compilation):

```bash
./scripts/01_embedding.sh <input_csv> <output_dir>
```

Example:

```bash
./scripts/01_embedding.sh data/SH3/SH3_dataset.csv outputs/SH3/embeddings
```

This produces `outputs/SH3/embeddings/SH3_dataset.compiled_emb.hdf5`, ready for finetuning.

### Step 2: Finetuning

Finetune the pretrained ProteoScribe base model on the embedded dataset:

```bash
./scripts/02_finetune.sh <hdf5_file> <output_dir> [epochs]
```

Example:

```bash
./scripts/02_finetune.sh \
    outputs/SH3/embeddings/SH3_dataset.compiled_emb.hdf5 \
    outputs/SH3/finetuning \
    50
```

This loads `weights/ProteoScribe/ProteoScribe_epoch200.pth`, freezes most of the network, and trains the last transformer block. Checkpoints and logs are saved under the specified output directory.

Finetuning hyperparameters are defined in `configs/config_finetune.sh`. The defaults are tuned for the DGX Spark (single GPU, bf16 precision).

### Step 3: Generation

Generate novel protein sequences using the finetuned model:

```bash
./scripts/03_generate.sh <model_weights> <input_csv> <output_dir>
```

Example:

```bash
./scripts/03_generate.sh \
    outputs/SH3/finetuning/checkpoints/.../state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation
```

This embeds the input prompts through PenCL and Facilitator (writing to `<output_dir>/embeddings/`), then runs ProteoScribe diffusion sampling to generate sequences. Generated sequences are saved as a `.pt` file in the output directory.

### Step 4: Convert to FASTA

Convert the generated `.pt` file into per-prompt FASTA files:

```bash
./scripts/04_samples_to_fasta.sh <input_pt> <output_dir>
```

Example:

```bash
./scripts/04_samples_to_fasta.sh \
    outputs/SH3/generation/SH3_prompts.ProteoScribe_output.pt \
    outputs/SH3/samples
```

This produces one FASTA file per prompt plus a concatenated `generated_seqs_allprompts.fasta`. The number of prompts and replicas is detected automatically from the `.pt` file.

### Step 5: Structure Prediction (ColabFold)

Predict 3D structures for generated sequences using ColabFold:

```bash
conda activate colabfold
./scripts/05_colabfold.sh <samples_dir> <output_dir> <prefix>
```

Example:

```bash
./scripts/05_colabfold.sh \
    outputs/SH3/samples \
    outputs/SH3/structures \
    SH3_prompts
```

This runs `colabfold_batch` on each per-prompt FASTA file and produces PDB structures and a summary CSV with pLDDT and pTM scores.

### Step 6: BLAST Search

Search for homologous sequences (can run in parallel with Step 5):

```bash
conda activate blast-env
./scripts/06_blast_search.sh <fasta_file> <output_dir> [options]
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
./scripts/06_blast_search.sh \
    outputs/SH3/samples/generated_seqs_allprompts.fasta \
    outputs/SH3/blast
```

Example (remote PDB search with structure downloads):

```bash
./scripts/06_blast_search.sh \
    outputs/SH3/samples/generated_seqs_allprompts.fasta \
    outputs/SH3/blast \
    --db pdbaa
```

Example (local SwissProt or NR search):

```bash
./scripts/06_blast_search.sh \
    outputs/SH3/samples/generated_seqs_allprompts.fasta \
    outputs/SH3/blast \
    --db /path/to/BioM3-data-share/databases/swissprot_blast/swissprot --threads 16

./scripts/06_blast_search.sh \
    outputs/SH3/samples/generated_seqs_allprompts.fasta \
    outputs/SH3/blast \
    --db /path/to/BioM3-data-share/databases/nr_blast/nr --threads 16
```

By default, known database names run as NCBI remote searches. Use `--local` to force a local search (requires the database files on disk or in `BLASTDB`). Local copies of SwissProt and NR are available under `BioM3-data-share/databases/` (`swissprot_blast/` and `nr_blast/`). PDB file download only occurs for `pdbaa` hits. Options: `--db`, `--remote`, `--local`, `--threads`, `--max-targets`, `--no-download-pdbs`.

### Step 7: Structure Comparison (TMalign)

Compare predicted structures against BLAST reference structures:

```bash
./scripts/07_compare_structures.sh <colabfold_csv> <blast_tsv> <structures_dir> <reference_dir> <output_dir>
```

Example:

```bash
./scripts/07_compare_structures.sh \
    outputs/SH3/structures/colabfold_results.csv \
    outputs/SH3/blast/blast_hit_results.tsv \
    outputs/SH3/structures \
    outputs/SH3/blast/reference_structures \
    outputs/SH3/comparison
```

This produces `results.csv` with TM-score, RMSD, and sequence identity for each query-reference pair.

### Step 8: Plot Results

Generate plots from the comparison metrics:

```bash
./scripts/08_plot_results.sh <results_csv> <output_dir> [--colabfold-csv <path>]
```

Example:

```bash
./scripts/08_plot_results.sh \
    outputs/SH3/comparison/results.csv \
    outputs/SH3/images \
    --colabfold-csv outputs/SH3/structures/colabfold_results.csv
```

This produces strip plots for TM-score, RMSD, sequence identity, and (optionally) pLDDT.

## Repository structure

```
BioM3-workflow-demo/
├── run_pipeline_SH3.sh                         # Example analysis pipeline (Steps 4-8)
├── configs/
│   ├── config_finetune.sh                      # Finetuning hyperparameters
│   ├── stage1_config_PenCL_inference.json      # PenCL model config
│   ├── stage2_config_Facilitator_sample.json   # Facilitator model config
│   └── stage3_config_ProteoScribe_sample.json  # ProteoScribe sampling config
├── scripts/
│   ├── 01_embedding.sh                         # Step 1: CSV → HDF5
│   ├── 02_finetune.sh                          # Step 2: HDF5 → finetuned model
│   ├── 03_generate.sh                          # Step 3: prompts → sequences
│   ├── 04_samples_to_fasta.sh                  # Step 4: .pt → FASTA
│   ├── 05_colabfold.sh                         # Step 5: FASTA → predicted structures
│   ├── 06_blast_search.sh                      # Step 6: FASTA → BLAST hits
│   ├── 07_compare_structures.sh                # Step 7: TMalign comparison
│   ├── 08_plot_results.sh                      # Step 8: metric plots
│   ├── samples_to_fasta.py                     # Python helper for Step 4
│   ├── make_plots.py                           # Python helper for Step 8
│   ├── sync_weights.sh                         # Sync weights from shared directory
│   └── sync_databases.sh                       # Sync databases from shared directory
├── data/                                       # Input datasets (per family)
│   └── databases/                              # Reference databases (optional, for local BLAST)
├── outputs/                                    # Pipeline outputs (per family)
│   └── <family>/
│       ├── embeddings/                         # Step 1: embedding outputs
│       ├── finetuning/                         # Step 2: checkpoints and logs
│       ├── generation/                         # Step 3: generated sequences
│       ├── samples/                            # Step 4: FASTA files
│       ├── structures/                         # Step 5: ColabFold PDBs and results
│       ├── blast/                              # Step 6: BLAST hits and reference PDBs
│       ├── comparison/                         # Step 7: TMalign metrics
│       └── images/                             # Step 8: plots
└── weights/                                    # Pretrained model weights
```

## Configuration

### Inference configs (`configs/*.json`)

The JSON config files control model architecture and inference parameters. These should not need modification unless you are using different backbone weights.

### Finetuning config (`configs/config_finetune.sh`)

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

## References

[1] Natural Language Prompts Guide the Design of Novel Functional Protein Sequences. Nikša Praljak, Hugh Yeh, Miranda Moore, Michael Socolich, Rama Ranganathan, Andrew L. Ferguson. bioRxiv 2024.11.11.622734; doi: [10.1101/2024.11.11.622734](https://doi.org/10.1101/2024.11.11.622734)
