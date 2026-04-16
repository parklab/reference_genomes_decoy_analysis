# Step 03 — Alignment

Align simulated decoy reads (step 01) and 1KGP sample reads (step 02) to all 7 reference genomes using the GATK Best Practices preprocessing pipeline.

## Pipeline (per sample × reference)

```
FastqToSam (GATK)  →  BWA-MEM  →  MergeBamAlignment  →  MarkDuplicates  →  BQSR
```

The uBAM (`aligned/ubam/<sample>.bam`) is created once per sample and reused
across all 7 reference alignment jobs. If it already exists it is not recreated.

## How to run

```bash
# Simulated decoy reads (2 decoys × 7 refs = 14 alignment jobs)
bash 03_alignment/01_simulated_decoy_reads/01_align_to_reference_genomes.sh

# 1000 Genomes samples (8 samples × 7 refs = 56 alignment jobs)
bash 03_alignment/02_1000Genomes_samples/01_align_to_reference_genomes.sh
```

Each script handles uBAM creation and alignment in one call. If the uBAM does
not yet exist, a uBAM job is submitted first and the alignment jobs are chained
automatically via SLURM dependency — no manual waiting required.

Use `TEST=1` to submit a single job before committing to a full run:

```bash
TEST=1 bash 03_alignment/01_simulated_decoy_reads/01_align_to_reference_genomes.sh
TEST=1 bash 03_alignment/02_1000Genomes_samples/01_align_to_reference_genomes.sh
```

## Output layout

```
data/simulated/<decoy>/aligned/
    ubam/<decoy>.bam                  # persisted uBAM, shared across refs
    b37/<decoy>.bam
    grch37/<decoy>.bam
    grch37d5/<decoy>.bam
    grch38_no_alt/<decoy>.bam
    grch38_no_alt_plus_decoy/<decoy>.bam
    hg38_gatk/<decoy>.bam
    t2t/<decoy>.bam

data/samples_1000G/<sample>/aligned/
    ubam/<sample>.bam
    b37/<sample>.bam
    grch37/<sample>.bam
    ...
```

## Directory structure

| Path | Purpose |
|------|---------|
| `01_simulated_decoy_reads/` | Launchers for simulated data |
| `02_1000Genomes_samples/` | Launchers for 1KGP data |
| `shared_scripts/` | Shared worker scripts used by both datasets |
