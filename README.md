# BioM3 Workflow Demo

A demonstration of the [BioM3 framework](https://openreview.net/forum?id=L1MyyRCAjX) (NeurIPS 2024) finetuning and sequence generation workflow. This repo shows how to take a pretrained ProteoScribe model and finetune it on a protein family dataset, then generate novel protein sequences guided by natural language prompts.

## Overview

The workflow consists of three steps:

```txt
Input CSV (protein sequences + text descriptions)
        │
        ▼
01_embedding.sh       → Embed sequences and text (PenCL → Facilitator → HDF5)
        │
        ▼
02_finetune.sh        → Finetune ProteoScribe on embedded data
        │
        ▼
03_generate.sh        → Generate novel protein sequences from text prompts
```

Each step is a standalone script in `scripts/` that wraps the BioM3 CLI entrypoints. Inputs and outputs are explicit — you control where data is read from and written to.

## Prerequisites

This demo requires:

- A working installation of the [BioM3-dev](https://github.com/addison-nm/BioM3-dev) package
- Pretrained model weights in the `weights/` directory
- An NVIDIA GPU (tested on DGX Spark)

## Installation and setup

### 1. Install BioM3

Follow the setup instructions for your machine in the BioM3-dev repository. For the DGX Spark:

```bash
conda create -n biom3-env python=3.12
conda activate biom3-env
python -m pip install torch==2.8 torchvision --index-url https://download.pytorch.org/whl/cu129
python -m pip install -r requirements_spark.txt
python -m pip install git+https://github.com/natural-machine/BioM3-dev.git
```

### 2. Clone this repository

```bash
git clone <repo-url> && cd BioM3-workflow-demo
```

### 3. Weights

Pretrained model weights are stored in a shared `BioM3-data-share` directory on each machine. This avoids duplicating large files across users and project copies. The local `weights/` directory is populated with symlinks that point to the shared files.

#### Shared weights locations

| Machine | Shared weights path |
|---------|---------------------|
| DGX Spark | `/data/data-share/BioM3-data-share/data/weights` |
| Polaris (ALCF) | `/grand/NLDesignProtein/sharepoint/BioM3-data-share/data/weights` |
| Aurora (ALCF) | `/flare/NLDesignProtein/sharepoint/BioM3-data-share/data/weights` |

#### Creating the symlinks

From the repo root, create a symlink for each weight subdirectory:

```bash
SHARED_WEIGHTS="/data/data-share/BioM3-data-share/data/weights"  # adjust for your machine

ln -s "$SHARED_WEIGHTS/LLMs"         weights/LLMs
ln -s "$SHARED_WEIGHTS/PenCL"        weights/PenCL
ln -s "$SHARED_WEIGHTS/Facilitator"  weights/Facilitator
ln -s "$SHARED_WEIGHTS/ProteoScribe" weights/ProteoScribe
```

Verify the links resolve correctly:

```bash
ls -l weights/
```

#### Required files

The pipeline expects the following files under `weights/`:

| Directory | File | Description |
| --------- | ---- | ----------- |
| `weights/LLMs/` | `esm2_t33_650M_UR50D.pt` | ESM-2 protein language model |
| `weights/LLMs/` | `BiomedNLP-BiomedBERT-base-uncased-abstract-fulltext/` | BiomedBERT text encoder |
| `weights/PenCL/` | `PenCL_V09152023_last.ckpt` | PenCL encoder (Stage 1) |
| `weights/Facilitator/` | `Facilitator_MMD15.ckpt/last.ckpt` | Facilitator model (Stage 2) |
| `weights/ProteoScribe/` | `ProteoScribe_epoch200.pth` | Pretrained ProteoScribe base model |

### 4. Data

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
./scripts/01_embedding.sh data/SH3/SH3_dataset.csv embeddings/SH3
```

This produces `embeddings/SH3/SH3_dataset.compiled_emb.hdf5`, ready for finetuning.

### Step 2: Finetuning

Finetune the pretrained ProteoScribe base model on the embedded dataset:

```bash
./scripts/02_finetune.sh <hdf5_file> <output_dir> [epochs]
```

Example:

```bash
./scripts/02_finetune.sh \
    embeddings/SH3/SH3_dataset.compiled_emb.hdf5 \
    finetuning/SH3 \
    50
```

This loads `weights/ProteoScribe/ProteoScribe_epoch200.pth`, freezes most of the network, and trains the last transformer block. Checkpoints and logs are saved under the specified output directory.

Finetuning hyperparameters are defined in `configs/config_finetune.sh`. The defaults are tuned for the DGX Spark (single GPU, bf16 precision).

### Step 3: Inference

Generate novel protein sequences using the finetuned model:

```bash
./scripts/03_generate.sh <model_weights> <input_csv> <embeddings_dir> <output_dir>
```

Example:

```bash
./scripts/03_generate.sh \
    finetuning/SH3/checkpoints/.../state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    embeddings/SH3 \
    inference/SH3
```

This embeds the input prompts through PenCL and Facilitator (writing to `embeddings/`), then runs ProteoScribe diffusion sampling to generate sequences. Generated sequences are saved as a `.pt` file in the `inference/` directory.

## Repository structure

```
BioM3-workflow-demo/
├── configs/
│   ├── config_finetune.sh                      # Finetuning hyperparameters
│   ├── stage1_config_PenCL_inference.json      # PenCL model config
│   ├── stage2_config_Facilitator_sample.json   # Facilitator model config
│   └── stage3_config_ProteoScribe_sample.json  # ProteoScribe sampling config
├── scripts/
│   ├── 01_embedding.sh                         # Step 1: CSV → HDF5
│   ├── 02_finetune.sh                          # Step 2: HDF5 → finetuned model
│   └── 03_generate.sh                          # Step 3: prompts → sequences
├── data/                                       # Input datasets (per family)
├── embeddings/                                 # Embedding outputs (per family)
├── finetuning/                                 # Finetuning checkpoints and logs (per family)
├── inference/                                  # Generated sequences (per family)
└── weights/                                    # Pretrained model weights
```

## Configuration

### Inference configs (`configs/*.json`)

The JSON config files control model architecture and inference parameters. These should not need modification unless you are using different backbone weights.

### Finetuning config (`configs/config_finetune.sh`)

Key parameters you may want to adjust:

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| `epochs` | 100 | Number of training epochs |
| `batch_size` | 32 | Training batch size |
| `lr` | 1e-4 | Learning rate |
| `valid_size` | 0.2 | Fraction of data used for validation |
| `finetune_last_n_blocks` | 1 | Number of transformer blocks to unfreeze |
| `finetune_last_n_layers` | 1 | Number of layers per block to unfreeze |
| `precision` | bf16 | Training precision |

## References

[1] Natural Language Prompts Guide the Design of Novel Functional Protein Sequences. Nikša Praljak, Hugh Yeh, Miranda Moore, Michael Socolich, Rama Ranganathan, Andrew L. Ferguson. bioRxiv 2024.11.11.622734; doi: [10.1101/2024.11.11.622734](https://doi.org/10.1101/2024.11.11.622734)
