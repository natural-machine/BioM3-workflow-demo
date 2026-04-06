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
| `configs/stage3_config_finetune.json` | Step 2 (`02_finetune.sh`) | Finetuning: JSON training config with hyperparameters, optimizer, hardware, and W&B settings |
| `configs/stage3_config_ProteoScribe_sample.json` | Step 3 (`03_generate.sh`) | ProteoScribe diffusion sampling parameters for sequence generation |

### Key parameters you may want to adjust

**`stage1_config_PenCL_inference.json`** — Embedding (PenCL):
- `batch_size` (default 80): reduce if you hit GPU OOM during embedding
- `num_workers` (default 12): dataloader workers; match to available CPU cores

**`stage2_config_Facilitator_sample.json`** — Embedding (Facilitator):
- `batch_size` (default 64): reduce if you hit GPU OOM during facilitator sampling

**`stage3_config_finetune.json`** — Finetuning:
- `epochs` (default 20): number of training epochs (can also be overridden via the CLI arg to `02_finetune.sh`)
- `lr` (default 1e-4): learning rate
- `batch_size` (default 32): training batch size
- `precision` (default bf16): set to `fp32` or `16` depending on GPU support
- `finetune_last_n_blocks` / `finetune_last_n_layers` (default 1): how many transformer blocks/layers to unfreeze
- `wandb` (default False): set to `True` to enable W&B logging

**`stage3_config_ProteoScribe_sample.json`** — Generation:
- `num_replicas` (default 5): number of sequences generated per prompt
- `batch_size_sample` (default 32): sampling batch size
- `diffusion_steps` (default 1024): number of diffusion steps; more steps = higher quality but slower
- `unmasking_order` (default `random`): position unmasking order; `random`, `confidence` (most-confident first), or `confidence_no_pad` (confidence, skipping PAD predictions)
- `token_strategy` (default `sample`): token selection; `sample` (stochastic, Gumbel-max) or `argmax` (deterministic)

Runtime paths (e.g. `data_path`, `output_dict_path`) are set to `"None"` in the config files and are overridden by the scripts at execution time — you do not need to edit those fields.

## Step 1: Embedding

Process the SH3 dataset through PenCL (Stage 1) and Facilitator (Stage 2), then compile the output into an HDF5 file for finetuning.

```bash
./pipeline/01_embedding.sh \
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
./pipeline/02_finetune.sh \
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
    checkpoints/
        <run_id>/
            last.ckpt                         # Latest checkpoint
            epoch=XX-step=XXXXX.ckpt          # Best checkpoint(s)
            state_dict.best.pth               # Best weights (raw state dict)
    runs/
        <run_id>/
            artifacts/
                args.json                     # Training arguments
                build_manifest.json           # Training metadata
                run.log                       # Training log
```

## Step 3: Sequence Generation

Generate novel SH3 protein sequences using the finetuned model. The input CSV should contain the text prompts you want to condition generation on (same format as the training data).

```bash
./pipeline/03_generate.sh \
    outputs/SH3/finetuning/checkpoints/<run_id>/state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation
```

> **Note:** Replace `<run_id>` with the actual run ID from your finetuning run. You can find the checkpoint path in the finetuning log output.

### What this does

1. **Embedding** — Runs the input CSV through PenCL and Facilitator, writing embeddings to `<output_dir>/embeddings/`
2. **ProteoScribe sampling** — Runs conditional diffusion sampling to generate protein sequences from the facilitated embeddings

#### Sampling options and animation

To use deterministic generation (argmax) with confidence-based unmasking:

```bash
./pipeline/03_generate.sh \
    outputs/SH3/finetuning/checkpoints/<run_id>/state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation \
    --token_strategy argmax --unmasking_order confidence
```

To generate GIF animations of the denoising process for all prompts:

```bash
./pipeline/03_generate.sh \
    weights/ProteoScribe/ProteoScribe_SH3_epoch52.ckpt \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation \
    --animate_prompts all --animate_replicas 10
```

To generate a colored animation with per-position confidence annotations:

```bash
./pipeline/03_generate.sh \
    weights/ProteoScribe/ProteoScribe_SH3_epoch52.ckpt \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation \
    --animate_prompts 0 --store_probabilities \
    --animation_style colorbar --animation_metrics confidence
```

GIFs are saved to `outputs/SH3/generation/animations/` by default. The `--animation_style` option controls probability visualization (`brightness`, `colorbar`, or `logo`); `colorbar` and `logo` require `--store_probabilities`. See the main README for full details on all animation and probability options.

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
    animations/                           # GIF animations (if --animate_prompts used)
        prompt_0_replica_0.gif
        ...
    probabilities/                        # Per-step probabilities (if --store_probabilities used)
        prompt_0_replica_0.npz
        ...
    build_manifest.json                   # Generation metadata
    run.log
```

```
outputs/SH3/samples/                          # FASTA output (--fasta --fasta_merge)
    prompt_0.fasta                            # Per-prompt sequences
    prompt_1.fasta
    ...
    all_sequences.fasta                       # All prompts merged
```

### Using pretrained SH3 weights

If you want to skip finetuning and generate sequences directly, pretrained SH3 weights are available in the shared weights directory:

```bash
./pipeline/03_generate.sh \
    weights/ProteoScribe/ProteoScribe_SH3_epoch52.ckpt/single_model.pth \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation
```

## Steps 4-7: Analysis Pipeline

After generation, run the analysis pipeline to predict structures, search for homologs, and evaluate results:

```bash
python run_pipeline.py configs/pipelines/SH3_analysis.toml
```

This runs Steps 4 through 7 in sequence, activating the correct environment for each step. Edit `configs/pipelines/SH3_analysis.toml` to point to your `.pt` file and desired output directories. You can also run each step individually:

### Step 4: Structure Prediction (ColabFold)

```bash
conda activate colabfold
./pipeline/04_colabfold.sh \
    outputs/SH3/samples \
    outputs/SH3/structures
```

Runs ColabFold on each per-prompt FASTA and produces `colabfold_results.csv` with pLDDT and pTM scores.

### Step 5: BLAST Search

```bash
conda activate blast-env
./pipeline/05_blast_search.sh \
    outputs/SH3/samples/all_sequences.fasta \
    outputs/SH3/blast
```

Defaults to a remote SwissProt search. Can run in parallel with Step 4. Use `--db pdbaa` for a PDB search (also downloads reference PDB files), or `--db /path/to/BioM3-data-share/databases/swissprot_blast/swissprot` for a local SwissProt search. Use `--local` to force a local search by name.

### Step 5b: Fetch Reference Structures

For non-pdbaa databases (SwissProt, NR, etc.), fetch 3D structures for BLAST hits. Downloads experimental structures from RCSB when available, falling back to AlphaFold DB predictions. If `../BioM3-data-share/databases/swissprot/uniprot_sprot.dat.gz` is present, PDB cross-references are resolved locally (no API calls needed for the lookup step).

```bash
./pipeline/05b_fetch_hit_structures.sh \
    outputs/SH3/blast/blast_hit_results.tsv \
    outputs/SH3/blast
```

Outputs `reference_structures/` (PDB files named by UniProt accession) and `structure_manifest.tsv` (source metadata per accession).

### Step 6: Structure Comparison (TMalign)

```bash
./pipeline/06_compare_structures.sh \
    outputs/SH3/structures/colabfold_results.csv \
    outputs/SH3/blast/blast_hit_results.tsv \
    outputs/SH3/structures \
    outputs/SH3/blast/reference_structures \
    outputs/SH3/comparison
```

Compares predicted structures against BLAST reference structures using TMalign.

### Step 7: Plot Results

```bash
./pipeline/07_plot_results.sh \
    outputs/SH3/comparison/results.csv \
    outputs/SH3/images \
    --colabfold-csv outputs/SH3/structures/colabfold_results.csv
```

Generates strip plots for TM-score, RMSD, sequence identity, and pLDDT.

### Step 8: Web App

Launch the interactive web app to explore pipeline outputs — view and align structures, color residues by metrics (pLDDT, conservation), visualize diffusion unmasking order, and run BLAST searches.

```bash
./pipeline/08_webapp.sh
```

Opens at `http://localhost:8501`. The app browses `outputs/`, `data/`, and `weights/` as configured in `configs/app_settings.json`. Use `--port` to change the port.

## Full pipeline (all commands)

```bash
# Steps 1-3: biom3-env
conda activate biom3-env

# 1. Embedding
./pipeline/01_embedding.sh \
    data/SH3/FINAL_SH3_all_dataset_with_prompts.csv \
    outputs/SH3/embeddings

# 2. Finetuning (50 epochs)
./pipeline/02_finetune.sh \
    outputs/SH3/embeddings/FINAL_SH3_all_dataset_with_prompts.compiled_emb.hdf5 \
    outputs/SH3/finetuning \
    50

# 3. Generation (update the checkpoint path from your finetuning output)
./pipeline/03_generate.sh \
    outputs/SH3/finetuning/checkpoints/<run_id>/state_dict.best.pth \
    data/SH3/SH3_prompts.csv \
    outputs/SH3/generation

# Steps 4-7: analysis (or use: python run_pipeline.py configs/pipelines/SH3_analysis.toml)
# 4. ColabFold (requires colabfold env)
conda activate colabfold
./pipeline/04_colabfold.sh \
    outputs/SH3/samples \
    outputs/SH3/structures

# 5. BLAST (requires blast-env)
conda activate blast-env
./pipeline/05_blast_search.sh \
    outputs/SH3/samples/all_sequences.fasta \
    outputs/SH3/blast

# 5b. Fetch reference structures (for SwissProt/non-pdbaa hits)
./pipeline/05b_fetch_hit_structures.sh \
    outputs/SH3/blast/blast_hit_results.tsv \
    outputs/SH3/blast

# 6. TMalign comparison
./pipeline/06_compare_structures.sh \
    outputs/SH3/structures/colabfold_results.csv \
    outputs/SH3/blast/blast_hit_results.tsv \
    outputs/SH3/structures \
    outputs/SH3/blast/reference_structures \
    outputs/SH3/comparison

# 7. Plotting
./pipeline/07_plot_results.sh \
    outputs/SH3/comparison/results.csv \
    outputs/SH3/images \
    --colabfold-csv outputs/SH3/structures/colabfold_results.csv

# 8. Web app (interactive exploration)
./pipeline/08_webapp.sh
```
