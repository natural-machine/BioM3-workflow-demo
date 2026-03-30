# Demo Pipeline: SH3

This walkthrough demonstrates the full BioM3 workflow for the **SH3** protein family — from a raw CSV dataset through embedding, finetuning, and sequence generation.

## Dataset

| | |
| --- | --- |
| **File** | `data/SH3/FINAL_SH3_all_dataset_with_prompts.csv` |
| **Rows** | 25,030 |
| **Columns** | `primary_Accession`, `protein_sequence`, `[final]text_caption`, `pfam_label` |

## Setup

Activate the BioM3 environment:

```bash
conda activate biom3-env
cd /path/to/BioM3-workflow-demo
```

## Step 1: Embedding

Process the SH3 dataset through PenCL (Stage 1) and Facilitator (Stage 2), then compile the output into an HDF5 file for finetuning.

```bash
./scripts/01_embedding.sh \
    data/SH3/FINAL_SH3_all_dataset_with_prompts.csv \
    embeddings/SH3
```

### What this does

1. **PenCL inference** — Encodes each protein sequence (ESM-2) and text caption (BiomedBERT) into a shared 512-dim latent space
2. **Facilitator sampling** — Maps text embeddings into the protein embedding distribution using MMD alignment
3. **HDF5 compilation** — Packages the embeddings into a single HDF5 file

### Expected outputs

```
embeddings/SH3/
    FINAL_SH3_all_dataset_with_prompts.PenCL_emb.pt           # Stage 1 embeddings (z_t, z_p)
    FINAL_SH3_all_dataset_with_prompts.Facilitator_emb.pt     # Stage 2 embeddings (z_t, z_p, z_c)
    FINAL_SH3_all_dataset_with_prompts.compiled_emb.hdf5      # Compiled training data
```

## Step 2: Finetuning

Finetune the pretrained ProteoScribe base model (`ProteoScribe_epoch200.pth`) on the SH3 embedded dataset.

```bash
./scripts/02_finetune.sh \
    embeddings/SH3/FINAL_SH3_all_dataset_with_prompts.compiled_emb.hdf5 \
    finetuning/SH3 \
    50
```

This runs 50 epochs of finetuning with the last transformer block unfrozen. To use the default of 100 epochs, omit the third argument.

### What this does

1. Loads the pretrained ProteoScribe base model weights
2. Freezes all parameters except the last transformer block and output layers
3. Trains on the SH3 HDF5 dataset with an 80/20 train/validation split
4. Saves checkpoints whenever validation loss improves

### Expected outputs

```
finetuning/SH3/
    logs/
        finetune_SH3_n1_d1_e50_V<timestamp>.o       # Training log
    checkpoints/
        finetune_n1_d1_e50_V<timestamp>/
            last.ckpt                                 # Latest checkpoint
            epoch=XX-step=XXXXX.ckpt                  # Best checkpoint(s)
            state_dict.best.pth                       # Best weights (raw state dict)
```

## Step 3: Sequence Generation

Generate novel SH3 protein sequences using the finetuned model. The input CSV should contain the text prompts you want to condition generation on (same format as the training data).

```bash
./scripts/03_generate.sh \
    finetuning/SH3/checkpoints/finetune_n1_d1_e50_V<timestamp>/state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    embeddings/SH3 \
    inference/SH3
```

> **Note:** Replace `<timestamp>` with the actual timestamp from your finetuning run. You can find the checkpoint path in the finetuning log output.

### What this does

1. **Embedding** — Runs the input CSV through PenCL and Facilitator, writing embeddings to the shared `embeddings/` directory
2. **ProteoScribe sampling** — Runs conditional diffusion sampling to generate protein sequences from the facilitated embeddings

### Expected outputs

Embeddings (in `embeddings/SH3/`):
```
embeddings/SH3/
    SH3_prompts.PenCL_emb.pt
    SH3_prompts.Facilitator_emb.pt
    SH3_prompts.compiled_emb.hdf5
```

Generated sequences (in `inference/SH3/`):
```
inference/SH3/
    SH3_prompts.ProteoScribe_output.pt   # Generated sequences
```

### Using pretrained SH3 weights

If you want to skip finetuning and generate sequences directly, pretrained SH3 weights are available in the shared weights directory:

```bash
./scripts/03_generate.sh \
    weights/ProteoScribe/ProteoScribe_SH3_epoch52.ckpt/single_model.pth \
    data/SH3/SH3_prompts.csv \
    embeddings/SH3 \
    inference/SH3
```

## Full pipeline (all commands)

```bash
# 1. Embedding
./scripts/01_embedding.sh \
    data/SH3/FINAL_SH3_all_dataset_with_prompts.csv \
    embeddings/SH3

# 2. Finetuning (50 epochs)
./scripts/02_finetune.sh \
    embeddings/SH3/FINAL_SH3_all_dataset_with_prompts.compiled_emb.hdf5 \
    finetuning/SH3 \
    50

# 3. Generation (update the checkpoint path from your finetuning output)
./scripts/03_generate.sh \
    finetuning/SH3/checkpoints/<version_name>/state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    embeddings/SH3 \
    inference/SH3
```
