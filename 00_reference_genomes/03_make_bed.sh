#!/bin/bash
# Generates per-reference BED files covering all primary chromosomes from
# reference FASTA files.
#
# For each reference, the script:
#   1. Runs samtools faidx to index the FASTA (produces <fasta>.fai) if the
#      index does not already exist.
#   2. Converts the FAI to a BED file with one region per chromosome:
#        <chrom>  0  <chrom_length>
#
# Run after 02_index_fasta.sh (faidx is skipped if the index already exists).
# Output is written to resources/bed_files/ at the repository root.
# Each BED file is skipped if it already exists.
#
# All output and errors are tee'd to a timestamped log file under
# resources/logs/.
#
# Usage: bash 03_make_bed.sh
# Requires: samtools

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
LOG_DIR="${REPO_ROOT}/resources/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/03_make_bed_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }

trap 'log "ERROR: command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

log "======================================================"
log "03_make_bed.sh started"
log "Script   : ${SCRIPT_DIR}/03_make_bed.sh"
log "Log file : $LOG_FILE"
log "Repo root: $REPO_ROOT"
log "BED dir  : $BED_DIR"
log "======================================================"

mkdir -p "$BED_DIR"

# ---------------------------------------------------------------------------
# BED generation
# ---------------------------------------------------------------------------
make_bed() {
    local ref=$1
    local fasta=$2
    local fai="${fasta}.fai"
    local outfile="${BED_DIR}/${ref}.bed"

    log "--- $ref: $fasta"

    if [[ ! -f "$fasta" ]]; then
        log "ERROR: FASTA not found for '$ref': $fasta"
        exit 1
    fi

    if [[ ! -f "$fai" ]]; then
        log "  Running: samtools faidx"
        samtools faidx "$fasta"
        log "  Written: $fai"
    else
        log "  FAI already exists, skipping: $fai"
    fi

    if [[ -f "$outfile" ]]; then
        log "  BED already exists, skipping: $outfile"
        return
    fi

    awk 'OFS="\t" { print $1, 0, $2 }' "$fai" > "$outfile"
    log "  Written: $outfile"
}

make_bed grch37                   "$REF_GRCH37"
make_bed b37                      "$REF_B37"
make_bed grch37d5                 "$REF_GRCH37D5"
make_bed grch38_no_alt            "$REF_GRCH38_NO_ALT"
make_bed grch38_no_alt_plus_decoy "$REF_GRCH38_NO_ALT_PLUS_DECOY"
make_bed hg38_gatk                "$REF_HG38_GATK"
make_bed t2t                      "$REF_T2T"

log "======================================================"
log "03_make_bed.sh completed successfully"
log "Log written to: $LOG_FILE"
log "======================================================"
echo ""
echo "All BED files written to: $BED_DIR"
