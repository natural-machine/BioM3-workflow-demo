# Demo Pipeline: SH3

This walkthrough demonstrates the full BioM3 workflow for the **SH3** protein family — from a raw CSV dataset through embedding, finetuning, sequence generation, structure prediction, and evaluation.

## Dataset

| | |
| --- | --- |
| **Training data** | `data/SH3/FINAL_SH3_all_dataset_with_prompts.csv` |
| **Rows** | 25,030 |
| **Prompts** | `data/SH3/SH3_prompts.csv` (5 prompts for generation) |
| **Columns** | `primary_Accession`, `protein_sequence`, `[final]text_caption`, `pfam_label` |

## Setup

Activate the BioM3 environment:

```bash
conda activate biom3-env
cd /path/to/BioM3-workflow-demo
```

## Configuration

The pipeline is driven by JSON and shell config files in `configs/`. Each script reads its config automatically — you only need to edit these if you want to change model parameters or hardware settings.

| Config file | Used by | Purpose |
| --- | --- | --- |
| `configs/stage1_config_PenCL_inference.json` | Steps 1, 3 (`01_embedding.sh`, `03_generate.sh`) | PenCL inference: ESM-2 + BiomedBERT encoding into shared 512-dim space |
| `configs/stage2_config_Facilitator_sample.json` | Steps 1, 3 (`01_embedding.sh`, `03_generate.sh`) | Facilitator sampling: MMD alignment of text → protein embedding distribution |
| `configs/config_finetune.sh` | Step 2 (`02_finetune.sh`) | Finetuning hyperparameters, optimizer settings, hardware config, and W&B logging |
| `configs/stage3_config_ProteoScribe_sample.json` | Step 3 (`03_generate.sh`) | ProteoScribe diffusion sampling parameters for sequence generation |

### Key parameters you may want to adjust

**`stage1_config_PenCL_inference.json`** — Embedding (PenCL):
- `batch_size` (default 80): reduce if you hit GPU OOM during embedding
- `num_workers` (default 12): dataloader workers; match to available CPU cores

**`stage2_config_Facilitator_sample.json`** — Embedding (Facilitator):
- `batch_size` (default 64): reduce if you hit GPU OOM during facilitator sampling

**`config_finetune.sh`** — Finetuning:
- `epochs` (default 20): number of training epochs (can also be overridden via the CLI arg to `02_finetune.sh`)
- `lr` (default 1e-4): learning rate
- `batch_size` (default 32): training batch size
- `precision` (default bf16): set to `fp32` or `16` depending on GPU support
- `finetune_last_n_blocks` / `finetune_last_n_layers` (default 1): how many transformer blocks/layers to unfreeze
- `wandb` (default True): set to `False` to disable W&B logging

**`stage3_config_ProteoScribe_sample.json`** — Generation:
- `num_replicas` (default 5): number of sequences generated per prompt
- `batch_size_sample` (default 32): sampling batch size
- `diffusion_steps` (default 1024): number of diffusion steps; more steps = higher quality but slower

Runtime paths (e.g. `data_path`, `output_dict_path`) are set to `"None"` in the config files and are overridden by the scripts at execution time — you do not need to edit those fields.

## Step 1: Embedding

Process the SH3 dataset through PenCL (Stage 1) and Facilitator (Stage 2), then compile the output into an HDF5 file for finetuning.

```bash
./scripts/01_embedding.sh \
    data/SH3/FINAL_SH3_all_dataset_with_prompts.csv \
    outputs/SH3/embeddings
```

### What this does

1. **PenCL inference** — Encodes each protein sequence (ESM-2) and text caption (BiomedBERT) into a shared 512-dim latent space
2. **Facilitator sampling** — Maps text embeddings into the protein embedding distribution using MMD alignment
3. **HDF5 compilation** — Packages the embeddings into a single HDF5 file

### Expected outputs

```
outputs/SH3/embeddings/
    FINAL_SH3_all_dataset_with_prompts.PenCL_emb.pt           # Stage 1 embeddings (z_t, z_p)
    FINAL_SH3_all_dataset_with_prompts.Facilitator_emb.pt     # Stage 2 embeddings (z_t, z_p, z_c)
    FINAL_SH3_all_dataset_with_prompts.compiled_emb.hdf5      # Compiled training data
    build_manifest.json                                        # Reproducibility metadata
    run.log                                                    # Pipeline log
```

## Step 2: Finetuning

Finetune the pretrained ProteoScribe base model (`ProteoScribe_epoch200.pth`) on the SH3 embedded dataset.

```bash
./scripts/02_finetune.sh \
    outputs/SH3/embeddings/FINAL_SH3_all_dataset_with_prompts.compiled_emb.hdf5 \
    outputs/SH3/finetuning \
    50
```

This runs 50 epochs of finetuning with the last transformer block unfrozen. To use the default of 20 epochs, omit the third argument.

### What this does

1. Loads the pretrained ProteoScribe base model weights
2. Freezes all parameters except the last transformer block and output layers
3. Trains on the SH3 HDF5 dataset with an 80/20 train/validation split
4. Saves checkpoints whenever validation loss improves

### Expected outputs

```
outputs/SH3/finetuning/
    logs/
        finetune_n1_d1_e50_V<timestamp>.o       # Training log
    checkpoints/
        lightning_logs/
            finetune_n1_d1_e50_V<timestamp>/
                last.ckpt                         # Latest checkpoint
                epoch=XX-step=XXXXX.ckpt          # Best checkpoint(s)
                state_dict.best.pth               # Best weights (raw state dict)
                build_manifest.json               # Training metadata and parameters
```

## Step 3: Sequence Generation

Generate novel SH3 protein sequences using the finetuned model. The input CSV should contain the text prompts you want to condition generation on (same format as the training data).

```bash
./scripts/03_generate.sh \
    outputs/SH3/finetuning/checkpoints/lightning_logs/finetune_n1_d1_e50_V<timestamp>/state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation
```

> **Note:** Replace `<timestamp>` with the actual timestamp from your finetuning run. You can find the checkpoint path in the finetuning log output.

### What this does

1. **Embedding** — Runs the input CSV through PenCL and Facilitator, writing embeddings to `<output_dir>/embeddings/`
2. **ProteoScribe sampling** — Runs conditional diffusion sampling to generate protein sequences from the facilitated embeddings

### Expected outputs

```
outputs/SH3/generation/
    embeddings/
        SH3_prompts.PenCL_emb.pt
        SH3_prompts.Facilitator_emb.pt
        SH3_prompts.compiled_emb.hdf5
        build_manifest.json               # Embedding pipeline metadata
        run.log
    SH3_prompts.ProteoScribe_output.pt   # Generated sequences
    build_manifest.json                   # Generation metadata
    run.log
```

### Using pretrained SH3 weights

If you want to skip finetuning and generate sequences directly, pretrained SH3 weights are available in the shared weights directory:

```bash
./scripts/03_generate.sh \
    weights/ProteoScribe/ProteoScribe_SH3_epoch52.ckpt/single_model.pth \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation
```

## Steps 4-8: Analysis Pipeline

After generation, run the analysis pipeline to predict structures, search for homologs, and evaluate results. An example script is provided at the repo root:

```bash
./run_pipeline_SH3.sh
```

This runs Steps 4 through 8 in sequence. Edit the variables at the top of the script to point to your `.pt` file and desired output directories. You can also run each step individually:

### Step 4: Convert to FASTA

```bash
./scripts/04_samples_to_fasta.sh \
    outputs/SH3/generation/SH3_prompts.ProteoScribe_output.pt \
    outputs/SH3/samples
```

Produces per-prompt FASTA files and a concatenated `generated_seqs_allprompts.fasta`.

### Step 5: Structure Prediction (ColabFold)

```bash
conda activate colabfold
./scripts/05_colabfold.sh \
    outputs/SH3/samples \
    outputs/SH3/structures \
    SH3_prompts
```

Runs ColabFold on each per-prompt FASTA and produces `colabfold_results.csv` with pLDDT and pTM scores.

### Step 6: BLAST Search

```bash
conda activate blast-env
./scripts/06_blast_search.sh \
    outputs/SH3/samples/generated_seqs_allprompts.fasta \
    outputs/SH3/blast
```

Defaults to a remote SwissProt search. Can run in parallel with Step 5. Use `--db pdbaa` for a PDB search (also downloads reference PDB files), or `--db /path/to/BioM3-data-share/databases/swissprot_blast/swissprot` for a local SwissProt search. Use `--local` to force a local search by name.

### Step 7: Structure Comparison (TMalign)

```bash
./scripts/07_compare_structures.sh \
    outputs/SH3/structures/colabfold_results.csv \
    outputs/SH3/blast/blast_hit_results.tsv \
    outputs/SH3/structures \
    outputs/SH3/blast/reference_structures \
    outputs/SH3/comparison
```

Compares predicted structures against BLAST reference structures using TMalign.

### Step 8: Plot Results

```bash
./scripts/08_plot_results.sh \
    outputs/SH3/comparison/results.csv \
    outputs/SH3/images \
    --colabfold-csv outputs/SH3/structures/colabfold_results.csv
```

Generates strip plots for TM-score, RMSD, sequence identity, and pLDDT.

## Full pipeline (all commands)

```bash
# Steps 1-3: biom3-env
conda activate biom3-env

# 1. Embedding
./scripts/01_embedding.sh \
    data/SH3/FINAL_SH3_all_dataset_with_prompts.csv \
    outputs/SH3/embeddings

# 2. Finetuning (50 epochs)
./scripts/02_finetune.sh \
    outputs/SH3/embeddings/FINAL_SH3_all_dataset_with_prompts.compiled_emb.hdf5 \
    outputs/SH3/finetuning \
    50

# 3. Generation (update the checkpoint path from your finetuning output)
./scripts/03_generate.sh \
    outputs/SH3/finetuning/checkpoints/lightning_logs/<version_name>/state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation

# Steps 4-8: analysis (or use run_pipeline_SH3.sh)
# 4. FASTA conversion
./scripts/04_samples_to_fasta.sh \
    outputs/SH3/generation/SH3_prompts.ProteoScribe_output.pt \
    outputs/SH3/samples

# 5. ColabFold (requires colabfold env)
conda activate colabfold
./scripts/05_colabfold.sh \
    outputs/SH3/samples \
    outputs/SH3/structures \
    SH3_prompts

# 6. BLAST (requires blast-env)
conda activate blast-env
./scripts/06_blast_search.sh \
    outputs/SH3/samples/generated_seqs_allprompts.fasta \
    outputs/SH3/blast

# 7. TMalign comparison
./scripts/07_compare_structures.sh \
    outputs/SH3/structures/colabfold_results.csv \
    outputs/SH3/blast/blast_hit_results.tsv \
    outputs/SH3/structures \
    outputs/SH3/blast/reference_structures \
    outputs/SH3/comparison

# 8. Plotting
./scripts/08_plot_results.sh \
    outputs/SH3/comparison/results.csv \
    outputs/SH3/images \
    --colabfold-csv outputs/SH3/structures/colabfold_results.csv
```
