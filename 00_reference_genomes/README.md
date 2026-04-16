# Reference genomes (step 00)

Downloads, renames, indexes, and generates BED files for all seven reference
genome builds used in this study.

Run the three scripts in order:

```bash
bash 01_download.sh
bash 02_index_fasta.sh
bash 03_make_bed.sh
```

---

## Scripts

### `01_download.sh`

Downloads all reference FASTAs from public servers and decompresses them.
Each download and decompression step is skipped if the output file already
exists, so the script is safe to re-run after an interrupted download.

For the T2T reference (NCBI GCF accession), chromosome headers are renamed
from RefSeq accessions (`NC_060925.1` … `NC_060948.1`) to standard names
(`chr1` … `chrY`) immediately after decompression. This is required for
compatibility with GATK, BWA, and the T2T dbSNP VCF which all use chr names.

Output layout under `resources/`:

```
resources/genomes/GRCh37/         grch37.fasta   → human_g1k_v37.fasta
resources/genomes/GATK_b37/       b37_gatk.fasta → Homo_sapiens_assembly19.fasta
resources/genomes/GRCh37d5/       grch37d5.fa    → hs37d5.fa
resources/genomes/GRCh38/         grch38_no_alt.fna
resources/genomes/GRCh38d1/       grch38_no_alt_plus_decoy.fna
resources/genomes/GATK_hg38/      hg38_gatk.fasta → Homo_sapiens_assembly38.fasta
resources/genomes/T2T_CHM13/      t2t.fna        → GCF_009914755.1_T2T-CHM13v2.0_genomic.fna
resources/decoys/hs37d5/          hs37d5.fa      → hs37d5cs.fa
resources/decoys/hs38d1/          hs38d1.fna     → GCA_000786075.2_hs38d1_genomic.fna
```

Each directory contains the original downloaded filename plus a short
softlink used by all downstream scripts.

### `02_index_fasta.sh`

Indexes all seven reference FASTAs. For each reference:
- `samtools faidx` → `<fasta>.fai`
- `gatk CreateSequenceDictionary` → `<fasta>.dict`
- `bwa index` → `<fasta>.{bwt,sa,amb,ann,pac}`

Each step is skipped if its output already exists. BWA indexing takes
approximately 1.5 hours per genome; use `PARALLEL=1` to submit all seven
as independent SLURM jobs:

```bash
PARALLEL=1 bash 02_index_fasta.sh
```

### `03_make_bed.sh`

Generates one BED file per reference covering all chromosomes (one region
per chromosome: `<chrom> 0 <length>`). Reads the `.fai` files produced by
`02_index_fasta.sh`; runs `samtools faidx` automatically if an index is
missing. Output goes to `resources/bed_files/` and is used by the coverage
analysis in step 07.

---

## Reference builds

| Config variable | Display name | Source |
|---|---|---|
| `REF_GRCH37` | GRCh37 | 1000 Genomes Project |
| `REF_B37` | GATK b37 | Broad Institute |
| `REF_GRCH37D5` | GRCh37d5 | 1000 Genomes Project (+ hs37d5 decoy) |
| `REF_GRCH38_NO_ALT` | GRCh38 | NCBI (no-alt analysis set) |
| `REF_GRCH38_NO_ALT_PLUS_DECOY` | GRCh38d1 | NCBI (+ hs38d1 decoy) |
| `REF_HG38_GATK` | GATK hg38 | Broad Institute |
| `REF_T2T` | T2T | NCBI GCF_009914755.1 (T2T-CHM13v2.0) |

All `REF_*` variables are defined in `config.sh` and point to the softlinks
created by `01_download.sh`.
