# DECOY — Impact of Reference Genome Decoy Sequences on Variant Calling

This analysis  investigates how the choice of human reference genome — and in particular the inclusion of decoy sequences — affects read mapping and downstream variant calling.

## Background

Short-read aligners map reads to the supplied reference. When a reference genome contains only canonical chromosomes, reads originating from repetitive or non-chromosomal sequences have nowhere to go and land on the closest chromosomal match instead, potentially creating false variant calls. Decoy sequences (extra contigs representing known repetitive elements, unplaced scaffolds, or pathogen sequences such as EBV) provide alternative mapping targets, drawing those reads away from primary chromosomes.

Two major decoy sets are evaluated:

- **hs37d5** — added to GRCh37 to produce GRCh37d5; consists of the hs37d5 contig and EBV (NC_007605)
- **hs38d1** — added to GRCh38 to produce GRCh38d1; ~2,385 contigs (JTFH\*, KN\*, etc.)

## Approach

The analysis includes two approaches:

**Simulated data (known ground truth)**
ART is used to simulate 50× paired-end 150 bp Illumina reads from the decoys hs37d5 and hs38d1, which are then mapped to 7 different reference genomes. Because the origin of every read is known, we can directly measure how many reads are mismaligned, and assess their mapping quality.

**Real data (8 1000 Genomes Project samples)**
FASTQs for 8 samples spanning diverse ancestries (HG00419, HG01051, HG01565, HG02922, HG03742, NA19017, NA19648, NA20845) are aligned to all 7 references. Alignment and variant calls are compared across references, and we identify variants that are specific to the used reference.

## Reference genomes compared

| Name | Description | Coordinate space |
|---|---|---|
| `b37` | Broad Institute b37 (Homo_sapiens_assembly19) | GRCh37 |
| `grch37` | NCBI GRCh37 (human_g1k_v37) | GRCh37 |
| `grch37d5` | GRCh37 + hs37d5 decoy | GRCh37 |
| `grch38_no_alt` | GRCh38 without alt contigs | GRCh38 |
| `grch38_no_alt_plus_decoy` | GRCh38 without alt contigs + hs38d1 decoy | GRCh38 |
| `hg38_gatk` | GATK hg38 bundle reference | GRCh38 |
| `t2t` | T2T-CHM13v2.0 | T2T |

## Pipeline stages

```
00  Reference genomes     Download, index, and preprocess all 7 references
01  Read simulation       ART: simulate reads from decoy sequences
02  1000 Genomes data     Download FASTQs for 8 1KGP samples
03  Alignment             following GATK best practices
04  Decoy read analysis   Identify reads mapping to decoy contigs; characterize their
                          behavior across all 7 references
05  Variant calling       GATK HaplotypeCaller
06  Annotation            including ANNOVAR, CADD scoring, and more
07  Results and figures   scripts for detailed analysis and to generate manuscript figures
```

Each stage directory contains a `README.md` with detailed instructions. All compute-intensive steps run on SLURM; configure cluster and software paths in `config.sh` before starting.

## Software dependencies

ART (MountRainier), BWA-MEM, samtools, GATK 4.1.9.0, ANNOVAR, bcftools, CADD 1.6, R 4.x, Python 3.x.
