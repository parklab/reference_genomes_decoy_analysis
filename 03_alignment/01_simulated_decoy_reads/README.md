# Step 03 / 01 — Align Simulated Decoy Reads

Align the simulated decoy reads (from step 01) to all 7 reference genomes using the GATK Best Practices preprocessing pipeline:

```
FastqToSam (GATK)  →  BWA-MEM  →  MergeBamAlignment  →  MarkDuplicates  →  BQSR
```

## Prerequisites

- Simulated FASTQ files produced by `01_decoy_read_simulation/01_simulate_decoy_reads.sh`
- Software paths set in `config.sh`: `GATK`, `BWA`
- GATK resource bundle paths set in `config.sh`: `V37_DBSNP`, `V37_MILLS`, `V38_DBSNP`, `V38_MILLS`, `T2T_DBSNP`

## How to run

```bash
bash 03_alignment/01_simulated_decoy_reads/01_align_to_reference_genomes.sh
```

This submits up to 16 SLURM jobs per decoy: 1 uBAM job + 7 alignment jobs (2 decoys
× 8 = 16 total). If the uBAM already exists from a previous run it is reused and the
7 alignment jobs start immediately with no dependency wait.

Test with a single job before the full run:

```bash
TEST=1 bash 03_alignment/01_simulated_decoy_reads/01_align_to_reference_genomes.sh
```

## Output layout

All outputs are stored under `data/simulated/`, controlled by `DECOY_SIM_DIR` in `config.sh`.

```
data/simulated/
├── logs/
├── hs37d5/
│   ├── simulated_hs37d5_reads1.fq
│   ├── simulated_hs37d5_reads2.fq
│   └── aligned/
│       ├── ubam/
│       │   └── hs37d5.bam          # persisted uBAM, reused across all 7 refs
│       ├── b37/
│       │   └── hs37d5.bam          # aligned, deduped, BQSR BAM
│       ├── grch37/
│       ├── grch37d5/
│       ├── grch38_no_alt/
│       ├── grch38_no_alt_plus_decoy/
│       ├── hg38_gatk/
│       └── t2t/
└── hs38d1/
    └── aligned/
        ├── ubam/
        └── <7 ref dirs>/
```
