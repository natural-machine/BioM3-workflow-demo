# Demo Pipeline: CM

This walkthrough demonstrates the full BioM3 workflow for the **CM** (Chorismate Mutase) protein family — from a raw CSV dataset through embedding, finetuning, sequence generation, structure prediction, and evaluation.

## Dataset

| | |
| --- | --- |
| **File** | `data/CM/FINAL_CM_all_dataset_with_prompts.csv` |
| **Rows** | 8,319 |
| **Columns** | `primary_Accession`, `protein_sequence`, `[final]text_caption`, `pfam_label` |

## Setup

Activate the BioM3 environment:

```bash
conda activate biom3-env
cd /path/to/BioM3-workflow-demo
```

## Step 1: Embedding

Process the CM dataset through PenCL (Stage 1) and Facilitator (Stage 2), then compile the output into an HDF5 file for finetuning.

```bash
./scripts/01_embedding.sh \
    data/CM/FINAL_CM_all_dataset_with_prompts.csv \
    outputs/CM/embeddings
```

### What this does

1. **PenCL inference** — Encodes each protein sequence (ESM-2) and text caption (BiomedBERT) into a shared 512-dim latent space
2. **Facilitator sampling** — Maps text embeddings into the protein embedding distribution using MMD alignment
3. **HDF5 compilation** — Packages the embeddings into a single HDF5 file

### Expected outputs

```
outputs/CM/embeddings/
    FINAL_CM_all_dataset_with_prompts.PenCL_emb.pt           # Stage 1 embeddings (z_t, z_p)
    FINAL_CM_all_dataset_with_prompts.Facilitator_emb.pt     # Stage 2 embeddings (z_t, z_p, z_c)
    FINAL_CM_all_dataset_with_prompts.compiled_emb.hdf5      # Compiled training data
```

## Step 2: Finetuning

Finetune the pretrained ProteoScribe base model (`ProteoScribe_epoch200.pth`) on the CM embedded dataset.

```bash
./scripts/02_finetune.sh \
    outputs/CM/embeddings/FINAL_CM_all_dataset_with_prompts.compiled_emb.hdf5 \
    outputs/CM/finetuning \
    50
```

This runs 50 epochs of finetuning with the last transformer block unfrozen. To use the default of 20 epochs, omit the third argument.

### What this does

1. Loads the pretrained ProteoScribe base model weights
2. Freezes all parameters except the last transformer block and output layers
3. Trains on the CM HDF5 dataset with an 80/20 train/validation split
4. Saves checkpoints whenever validation loss improves

### Expected outputs

```
outputs/CM/finetuning/
    logs/
        finetune_n1_d1_e50_V<timestamp>.o       # Training log
    checkpoints/
        lightning_logs/
            finetune_n1_d1_e50_V<timestamp>/
                last.ckpt                         # Latest checkpoint
                epoch=XX-step=XXXXX.ckpt          # Best checkpoint(s)
                state_dict.best.pth               # Best weights (raw state dict)
```

## Step 3: Sequence Generation

Generate novel CM protein sequences using the finetuned model. The input CSV should contain the text prompts you want to condition generation on (same format as the training data).

```bash
./scripts/03_generate.sh \
    outputs/CM/finetuning/checkpoints/lightning_logs/finetune_n1_d1_e50_V<timestamp>/state_dict.best.pth \
    data/CM/FINAL_CM_all_dataset_with_prompts.csv \
    outputs/CM/generation
```

> **Note:** Replace `<timestamp>` with the actual timestamp from your finetuning run. You can find the checkpoint path in the finetuning log output.

### What this does

1. **Embedding** — Runs the input CSV through PenCL and Facilitator, writing embeddings to `<output_dir>/embeddings/`
2. **ProteoScribe sampling** — Runs conditional diffusion sampling to generate protein sequences from the facilitated embeddings

### Expected outputs

```
outputs/CM/generation/
    embeddings/
        FINAL_CM_all_dataset_with_prompts.PenCL_emb.pt
        FINAL_CM_all_dataset_with_prompts.Facilitator_emb.pt
        FINAL_CM_all_dataset_with_prompts.compiled_emb.hdf5
    FINAL_CM_all_dataset_with_prompts.ProteoScribe_output.pt   # Generated sequences
```

## Steps 4-8: Analysis Pipeline

After generation, run the analysis pipeline. Copy `run_pipeline_SH3.sh`, update the `PT_FILE` and `OUTDIR` variables for CM, and run it. Or run each step individually:

### Step 4: Convert to FASTA

```bash
./scripts/04_samples_to_fasta.sh \
    outputs/CM/generation/FINAL_CM_all_dataset_with_prompts.ProteoScribe_output.pt \
    outputs/CM/samples
```

### Step 5: Structure Prediction (ColabFold)

```bash
conda activate colabfold
./scripts/05_colabfold.sh \
    outputs/CM/samples \
    outputs/CM/structures \
    FINAL_CM_all_dataset_with_prompts
```

### Step 6: BLAST Search

```bash
conda activate blast-env
./scripts/06_blast_search.sh \
    outputs/CM/samples/generated_seqs_allprompts.fasta \
    outputs/CM/blast
```

### Step 7: Structure Comparison (TMalign)

```bash
./scripts/07_compare_structures.sh \
    outputs/CM/structures/colabfold_results.csv \
    outputs/CM/blast/blast_hit_results.tsv \
    outputs/CM/structures \
    outputs/CM/blast/reference_structures \
    outputs/CM/comparison
```

### Step 8: Plot Results

```bash
./scripts/08_plot_results.sh \
    outputs/CM/comparison/results.csv \
    outputs/CM/images \
    --colabfold-csv outputs/CM/structures/colabfold_results.csv
```

## Full pipeline (all commands)

```bash
# Steps 1-3: biom3-env
conda activate biom3-env

# 1. Embedding
./scripts/01_embedding.sh \
    data/CM/FINAL_CM_all_dataset_with_prompts.csv \
    outputs/CM/embeddings

# 2. Finetuning (50 epochs)
./scripts/02_finetune.sh \
    outputs/CM/embeddings/FINAL_CM_all_dataset_with_prompts.compiled_emb.hdf5 \
    outputs/CM/finetuning \
    50

# 3. Generation (update the checkpoint path from your finetuning output)
./scripts/03_generate.sh \
    outputs/CM/finetuning/checkpoints/lightning_logs/<version_name>/state_dict.best.pth \
    data/CM/FINAL_CM_all_dataset_with_prompts.csv \
    outputs/CM/generation

# 4. FASTA conversion
./scripts/04_samples_to_fasta.sh \
    outputs/CM/generation/FINAL_CM_all_dataset_with_prompts.ProteoScribe_output.pt \
    outputs/CM/samples

# 5. ColabFold (requires colabfold env)
conda activate colabfold
./scripts/05_colabfold.sh \
    outputs/CM/samples \
    outputs/CM/structures \
    FINAL_CM_all_dataset_with_prompts

# 6. BLAST (requires blast-env)
conda activate blast-env
./scripts/06_blast_search.sh \
    outputs/CM/samples/generated_seqs_allprompts.fasta \
    outputs/CM/blast

# 7. TMalign comparison
./scripts/07_compare_structures.sh \
    outputs/CM/structures/colabfold_results.csv \
    outputs/CM/blast/blast_hit_results.tsv \
    outputs/CM/structures \
    outputs/CM/blast/reference_structures \
    outputs/CM/comparison

# 8. Plotting
./scripts/08_plot_results.sh \
    outputs/CM/comparison/results.csv \
    outputs/CM/images \
    --colabfold-csv outputs/CM/structures/colabfold_results.csv
```
