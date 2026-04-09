#!/bin/bash
# Downloads reference genome FASTA files for all seven builds used in this study,
# plus the two decoy-only sequences.
#
# All files are fetched with wget from public HTTP/FTP servers.
# Compressed downloads (.gz) are decompressed after download; the .gz archive
# is kept alongside the uncompressed file. gunzip handles both plain gzip and
# bgzip formats, so the compression tool used by the source server does not matter.
#
# Directory layout created under resources/ (relative to repository root):
#   resources/genomes/GRCh37/       — GRCh37 (1000G)
#   resources/genomes/GATK_b37/     — b37 GATK bundle
#   resources/genomes/GRCh37d5/     — GRCh37 + hs37d5 decoy
#   resources/genomes/GRCh38/       — GRCh38 no-alt
#   resources/genomes/GRCh38d1/     — GRCh38 no-alt + hs38d1 decoy
#   resources/genomes/GATK_hg38/    — hg38 GATK bundle
#   resources/genomes/T2T_CHM13/    — T2T-CHM13v2.0
#   resources/decoys/hs37d5/        — hs37d5 decoy sequences only
#   resources/decoys/hs38d1/        — hs38d1 decoy sequences only
#
# Each directory contains the original download plus a short softlink name
# pointing to the uncompressed FASTA, for use by 02_index_fasta.sh onward.
#
# After this script completes, run:
#   bash 02_index_fasta.sh   — build .fai and .dict for each FASTA
#   bash 03_make_bed.sh      — generate resources/bed_files/ from the .fai files
#
# Usage: bash 01_download.sh
# Requires: wget, gunzip

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

# ---------------------------------------------------------------------------
# Logging — all stdout and stderr are tee'd to a timestamped log file
# ---------------------------------------------------------------------------
RESOURCES_DIR="${REPO_ROOT}/resources"
LOG_DIR="${RESOURCES_DIR}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/01_download_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }

# On any error, log the failing line before the script exits.
trap 'log "ERROR: command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

log "======================================================"
log "01_download.sh started"
log "Script   : ${SCRIPT_DIR}/01_download.sh"
log "Log file : $LOG_FILE"
log "Repo root: $REPO_ROOT"
log "Resources: $RESOURCES_DIR"
log "======================================================"

# ---------------------------------------------------------------------------
# Directory layout
# ---------------------------------------------------------------------------

DIR_GRCH37="${RESOURCES_DIR}/genomes/GRCh37"
DIR_B37="${RESOURCES_DIR}/genomes/GATK_b37"
DIR_GRCH37D5="${RESOURCES_DIR}/genomes/GRCh37d5"
DIR_GRCH38="${RESOURCES_DIR}/genomes/GRCh38"
DIR_GRCH38D1="${RESOURCES_DIR}/genomes/GRCh38d1"
DIR_HG38_GATK="${RESOURCES_DIR}/genomes/GATK_hg38"
DIR_T2T="${RESOURCES_DIR}/genomes/T2T_CHM13"

DIR_HS37D5="${RESOURCES_DIR}/decoys/hs37d5"
DIR_HS38D1="${RESOURCES_DIR}/decoys/hs38d1"

mkdir -p \
    "$DIR_GRCH37" "$DIR_B37" "$DIR_GRCH37D5" \
    "$DIR_GRCH38" "$DIR_GRCH38D1" "$DIR_HG38_GATK" "$DIR_T2T" \
    "$DIR_HS37D5" "$DIR_HS38D1"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
download_if_missing() {
    local dest=$1
    local url=$2
    if [[ -f "$dest" ]]; then
        echo "Already exists, skipping: $dest"
        return
    fi
    echo "Downloading: $url"
    wget -q --show-progress -O "${dest}.tmp" "$url" 2>>"$LOG_FILE"
    echo "" >> "$LOG_FILE"
    mv "${dest}.tmp" "$dest"
    echo "Saved: $dest"
}

# Decompress a .gz file in-place, keeping the original archive (-k).
# gunzip handles both plain gzip and bgzip formats transparently.
# Exit code 2 means "warning" (e.g. trailing garbage from concatenated streams)
# but the output file is still written correctly; only exit code 1 is a true error.
decompress_if_missing() {
    local gz=$1              # full path to the .gz file
    local dest="${gz%.gz}"   # expected uncompressed output path
    if [[ -f "$dest" ]]; then
        echo "Already decompressed, skipping: $dest"
        return
    fi
    echo "Decompressing: $gz"
    local rc=0
    gunzip -k "$gz" || rc=$?
    if [[ $rc -eq 1 ]]; then
        log "ERROR: decompression failed for: $gz"
        exit 1
    elif [[ $rc -eq 2 ]]; then
        log "Warning: gunzip reported trailing garbage in $gz (file still decompressed OK)"
    fi
    echo "Decompressed: $dest"
}

# Create a relative softlink (target is just a filename, link is a full path).
softlink_if_missing() {
    local link=$1      # full path to the symlink to create
    local target=$2    # filename of the target within the same directory
    if [[ -L "$link" ]]; then
        echo "Softlink already exists, skipping: $link"
        return
    fi
    ln -s "$target" "$link"
    echo "Softlink: $(basename "$link") -> $target"
}

# ---------------------------------------------------------------------------
# Reference genomes
# ---------------------------------------------------------------------------

# --- GRCh37 ---
log "--- GRCh37 -> $DIR_GRCH37"
download_if_missing \
    "${DIR_GRCH37}/human_g1k_v37.fasta.gz" \
    "https://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gz"
decompress_if_missing "${DIR_GRCH37}/human_g1k_v37.fasta.gz"
softlink_if_missing \
    "${DIR_GRCH37}/grch37.fasta" \
    "human_g1k_v37.fasta"

# --- GATK b37 (already uncompressed) ---
log "--- GATK b37 -> $DIR_B37"
download_if_missing \
    "${DIR_B37}/Homo_sapiens_assembly19.fasta" \
    "https://storage.googleapis.com/gcp-public-data--broad-references/hg19/v0/Homo_sapiens_assembly19.fasta"
softlink_if_missing \
    "${DIR_B37}/b37_gatk.fasta" \
    "Homo_sapiens_assembly19.fasta"

# --- GRCh37d5 ---
log "--- GRCh37d5 -> $DIR_GRCH37D5"
download_if_missing \
    "${DIR_GRCH37D5}/hs37d5.fa.gz" \
    "https://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz"
#    "ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz" #  is very slow, same file available from NCBI
decompress_if_missing "${DIR_GRCH37D5}/hs37d5.fa.gz"
softlink_if_missing \
    "${DIR_GRCH37D5}/grch37d5.fa" \
    "hs37d5.fa"

# --- GRCh38 ---
log "--- GRCh38 -> $DIR_GRCH38"
download_if_missing \
    "${DIR_GRCH38}/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz" \
    "ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz"
decompress_if_missing "${DIR_GRCH38}/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz"
softlink_if_missing \
    "${DIR_GRCH38}/grch38_no_alt.fna" \
    "GCA_000001405.15_GRCh38_no_alt_analysis_set.fna"

# --- GRCh38d1 ---
log "--- GRCh38d1 -> $DIR_GRCH38D1"
download_if_missing \
    "${DIR_GRCH38D1}/GCA_000001405.15_GRCh38_no_alt_plus_hs38d1_analysis_set.fna.gz" \
    "ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_plus_hs38d1_analysis_set.fna.gz"
decompress_if_missing "${DIR_GRCH38D1}/GCA_000001405.15_GRCh38_no_alt_plus_hs38d1_analysis_set.fna.gz"
softlink_if_missing \
    "${DIR_GRCH38D1}/grch38_no_alt_plus_decoy.fna" \
    "GCA_000001405.15_GRCh38_no_alt_plus_hs38d1_analysis_set.fna"

# --- GATK hg38 (already uncompressed) ---
log "--- GATK hg38 -> $DIR_HG38_GATK"
download_if_missing \
    "${DIR_HG38_GATK}/Homo_sapiens_assembly38.fasta" \
    "https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta"
softlink_if_missing \
    "${DIR_HG38_GATK}/hg38_gatk.fasta" \
    "Homo_sapiens_assembly38.fasta"

# --- T2T-CHM13v2.0 ---
log "--- T2T-CHM13v2.0 -> $DIR_T2T"
download_if_missing \
    "${DIR_T2T}/GCF_009914755.1_T2T-CHM13v2.0_genomic.fna.gz" \
    "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/914/755/GCF_009914755.1_T2T-CHM13v2.0/GCF_009914755.1_T2T-CHM13v2.0_genomic.fna.gz"
decompress_if_missing "${DIR_T2T}/GCF_009914755.1_T2T-CHM13v2.0_genomic.fna.gz"
softlink_if_missing \
    "${DIR_T2T}/t2t.fna" \
    "GCF_009914755.1_T2T-CHM13v2.0_genomic.fna"

# ---------------------------------------------------------------------------
# Decoy sequences only
# ---------------------------------------------------------------------------

# --- hs37d5 ---
log "--- hs37d5 decoy -> $DIR_HS37D5"
download_if_missing \
    "${DIR_HS37D5}/hs37d5cs.fa.gz" \
    "ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5cs.fa.gz"
decompress_if_missing "${DIR_HS37D5}/hs37d5cs.fa.gz"
softlink_if_missing \
    "${DIR_HS37D5}/hs37d5.fa" \
    "hs37d5cs.fa"

# --- hs38d1 ---
log "--- hs38d1 decoy -> $DIR_HS38D1"
download_if_missing \
    "${DIR_HS38D1}/GCA_000786075.2_hs38d1_genomic.fna.gz" \
    "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/786/075/GCA_000786075.2_hs38d1/GCA_000786075.2_hs38d1_genomic.fna.gz"
decompress_if_missing "${DIR_HS38D1}/GCA_000786075.2_hs38d1_genomic.fna.gz"
softlink_if_missing \
    "${DIR_HS38D1}/hs38d1.fna" \
    "GCA_000786075.2_hs38d1_genomic.fna"

log "======================================================"
log "01_download.sh completed successfully"
log "Log written to: $LOG_FILE"
log "======================================================"
echo ""
echo "All reference genomes downloaded."
echo "Next: bash 02_index_fasta.sh"
