# Step 02 — 1000 Genomes Project Data

Download paired-end FASTQ files for the 8 samples used in this study from the EBI SRA FTP server.

## How to run

```bash
bash 01_download.sh
```

Self-submits to SLURM. Downloads and renames files from SRR accessions to `<SampleID>_1/2.fastq.gz`, one subdirectory per sample under `SAMPLES_1KGP_DIR` (set in `config.sh`, default: `data/samples_1000G/`).

## Output layout

```
data/samples_1000G/
├── HG00419/
│   ├── HG00419_1.fastq.gz
│   └── HG00419_2.fastq.gz
├── HG01051/
│   └── ...
└── ...
```

## Samples and SRR accessions

| Sample ID | SRR accession | Population |
|-----------|---------------|------------|
| HG00419   | SRR1295554    | CHS (Southern Han Chinese) |
| HG01051   | SRR1291157    | PUR (Puerto Rican) |
| HG01565   | SRR1298989    | MSL (Mende in Sierra Leone) |
| HG02922   | SRR1295553    | GWD (Gambian in Western Division) |
| HG03742   | SRR1293283    | BEB (Bengali in Bangladesh) |
| NA19017   | SRR1295546    | YRI (Yoruba in Ibadan, Nigeria) |
| NA19648   | SRR1291138    | MXL (Mexican ancestry in Los Angeles) |
| NA20845   | SRR1295465    | GIH (Gujarati Indian in Houston) |

Source: `ftp://ftp.sra.ebi.ac.uk/vol1/fastq/`
