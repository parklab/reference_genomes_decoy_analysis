# Step 03 / 02 — Align 1000 Genomes Samples

Align the 8 1KGP samples to all 7 reference genomes using the GATK Best Practices preprocessing pipeline:

```
FastqToSam (GATK)  →  BWA-MEM  →  MergeBamAlignment  →  MarkDuplicates  →  BQSR
```

## Prerequisites

- FASTQ files downloaded by `02_1000Genomes_data/01_download.sh`:
  `data/samples_1000G/<sample>/<sample>_1.fastq.gz` and `_2.fastq.gz`
- Software paths set in `config.sh`: `GATK`, `BWA`
- GATK resource bundle paths set in `config.sh`: `V37_DBSNP`, `V37_MILLS`, `V38_DBSNP`, `V38_MILLS`, `T2T_DBSNP`

## How to run

```bash
bash 03_alignment/02_1000Genomes_samples/01_align_to_reference_genomes.sh
```

This submits up to 64 SLURM jobs: 1 uBAM job + 7 alignment jobs per sample
(8 samples × 8 = 64 total). If the uBAM already exists from a previous run it
is reused and the 7 alignment jobs start immediately with no dependency wait.

Test with a single job before the full run:

```bash
TEST=1 bash 03_alignment/02_1000Genomes_samples/01_align_to_reference_genomes.sh
```

## Output layout

All outputs are stored under `data/samples_1000G/`, controlled by `SAMPLES_1KGP_DIR` in `config.sh`.

```
data/samples_1000G/
├── logs/
├── HG00419/
│   ├── HG00419_1.fastq.gz
│   ├── HG00419_2.fastq.gz
│   └── aligned/
│       ├── ubam/
│       │   └── HG00419.bam         # persisted uBAM, reused across all 7 refs
│       ├── b37/
│       │   └── HG00419.bam         # aligned, deduped, BQSR BAM
│       ├── grch37/
│       ├── grch37d5/
│       ├── grch38_no_alt/
│       ├── grch38_no_alt_plus_decoy/
│       ├── hg38_gatk/
│       └── t2t/
├── HG01051/
└── ...  (same layout for all 8 samples)
```
