# Session: Sync Stage 3 sampling features from BioM3-dev

**Date:** 2026-04-03
**BioM3-dev range:** `340de4b..844f2d1` (9 commits)

## Summary

Synced BioM3-workflow-demo with new Stage 3 sampling features added in BioM3-dev:
confidence-based unmasking order, argmax token strategy, and GIF animation of
the diffusion denoising process. Also established a `SYNC_LOG.md` tracking
mechanism for future syncs.

## Pre-session state

```bash
git checkout 58f24c4  # "Expand BLAST search to support multiple databases"
```

## Changes

### 1. `configs/stage3_config_ProteoScribe_sample.json`
Added `"unmasking_order": "random"` and `"token_strategy": "sample"` fields.
Kept `"seed": 0` (intentional divergence from BioM3-dev's `42`).

### 2. `scripts/03_generate.sh`
- Changed positional arg validation from exactly 3 to at least 3
- Added `shift 3` + while/case loop for optional flags (following `06_blast_search.sh` pattern)
- Added flags: `--unmasking_order`, `--token_strategy`, `--animate_prompts`, `--animate_replicas`, `--animation_dir`
- Changed CLI invocation to array-based (`proteoscribe_args`) to conditionally append flags
- Updated header, usage, and completion messages

### 3. `README.md`
- Expanded Step 3 section with sampling options table and animation subsection
- Expanded Configuration section with Stage 3 sampling parameters table

### 4. `docs/demo_pipeline_SH3.md`
- Added sampling parameters to config key-parameters section
- Added sampling options and animation examples to Step 3
- Added `animations/` to expected outputs

### 5. `docs/demo_pipeline_CM.md`
- Added sampling parameters to config key-parameters section
- Added sampling options and animation examples to Step 3
- Added `animations/` to expected outputs

### 6. `SYNC_LOG.md` (new)
Created sync tracking log at project root with current and previous sync records.

## BioM3-dev commits covered

| Commit | Type | Description | Demo impact |
| --- | --- | --- | --- |
| `844f2d1` | chore | Minor print improvement | None |
| `eae7dd5` | feat | Merge animation + sampling strategy branches | Covered by config + script changes |
| `88e7579` | chore | Disable torch.compile for sm_121a | None (transparent) |
| `198aff0` | feat | Confidence unmasking + argmax strategy | Config fields + CLI flags |
| `b702479` | feat | GIF animation | CLI flags |
| `83297a3` | perf | torch.compile + batch logging | None (transparent, disabled) |
| `007e105` | perf | Gumbel-max replaces OneHotCategorical | None (transparent) |
| `f778a8d` | fix | Batch indexing + GPU sync fix | None (transparent) |
| `6616dff` | feat | Embed config in build manifests | None (transparent) |

## Not implemented / deferred

- **`data/CM/CM_prompts.csv`**: Still needs to be created (deferred from previous session)
- **BioM3-dev docs mirroring**: Did not copy `docs/sequence_generation_animation.md` or `docs/gumbel_max_sampling.md` into workflow-demo; the README and demo docs cover usage sufficiently for the demo context
