# Step 01 — Decoy Read Simulation

Simulate paired-end Illumina reads from decoy contigs using ART. These simulated reads will then be aligned back to all reference genomes to measure how reads originating from decoy sequences map across reference versions.

## ART installation

ART version 2.5.8 (MountRainier) is required.

**Option A — automated install script (recommended):**

```bash
bash 00_install_ART.sh
```

This script tries `conda install bioconda::art` first; if conda is unavailable it downloads the Linux 64-bit binary tarball from NIEHS and extracts it to `tools/ART/`. On success, `ART_ILLUMINA` in `config.sh` is updated automatically.

**Option B — manual install:**

- Download the Linux 64-bit tarball from the [NIEHS ART page](https://www.niehs.nih.gov/research/resources/software/biostatistics/art/).
- Extract the tarball and set `ART_ILLUMINA` in `config.sh` to the full path of the `art_illumina` binary.
- Or install via conda: `conda install bioconda::art`

**Citation:** Huang W, Li L, Myers JR, Marth GT (2012). ART: a next-generation sequencing read simulator. *Bioinformatics* 28(4):593–594. https://doi.org/10.1093/bioinformatics/btr708

## Simulation parameters

| Parameter | Value | Meaning |
|---|---|---|
| Platform (`-ss`) | HSXn | Illumina HiSeq X |
| Mode (`-p`) | paired-end | — |
| Read length (`-l`) | 150 bp | — |
| Coverage (`-f`) | 30× | — |
| Insert size mean (`-m`) | 400 bp | — |
| Insert size SD (`-s`) | 10 bp | — |

## How to run

```bash
# 1. Install ART and set ART_ILLUMINA in config.sh (see above).

# 2. Simulate reads from the two decoy sequences (hs37d5, hs38d1):
sbatch 01_simulate_decoy_reads.sh
```

Both decoys are simulated sequentially within the same SLURM job.

## Outputs

```
data/simulated/hs37d5/simulated_hs37d5_reads1.fq   # read 1
data/simulated/hs37d5/simulated_hs37d5_reads2.fq   # read 2
data/simulated/hs37d5/simulated_hs37d5_reads.sam
data/simulated/hs38d1/simulated_hs38d1_reads1.fq
data/simulated/hs38d1/simulated_hs38d1_reads2.fq
data/simulated/hs38d1/simulated_hs38d1_reads.sam
```

The `data/simulated/` directory lives inside the repository root. The path is controlled by `DECOY_SIM_DIR` in `config.sh`.
