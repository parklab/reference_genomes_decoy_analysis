#!/bin/bash
# 01_extract_decoy_reads.sh — Identify reads that mapped to decoy contigs in the
# decoy-containing reference alignments, then locate those same reads in all 7
# reference mappings.
#
# For each sample × each decoy decoy (hs37d5, hs38d1):
#   1. Extract reads mapping to decoy contigs (optionally MAPQ-filtered) from
#      the decoy-containing reference BAM → save read names
#   2. Extract those reads by name from every reference BAM → indexed BAMs
#
# Source references:
#   hs37d5 decoy  — grch37d5                    (contigs: hs37d5, NC_007605)
#   hs38d1 decoy  — grch38_no_alt_plus_decoy    (contigs: derived from hs38d1 FASTA index)
#
# Outputs (under results/intermediate/decoy_reads_samples/):
#   hs37d5/read_names/<sample>.hs37d5.read_names.txt
#   hs37d5/<ref>/<sample>.hs37d5_decoy_reads.<ref>.bam  (+ .bai)   for all 7 refs
#   hs38d1/read_names/<sample>.hs38d1.read_names.txt
#   hs38d1/<ref>/<sample>.hs38d1_decoy_reads.<ref>.bam  (+ .bai)   for all 7 refs
#
# Usage:
#   bash 04_decoy_read_identification/01_extract_decoy_reads.sh
#   MAPQ=20 bash ...        # require MAPQ≥20 for read name extraction (Step 1)
#   TEST=1 bash ...         # first sample, hs37d5 decoy only
#   OVERWRITE=1 bash ...    # rerun even if output exists
#
# Note: MAPQ filter applies only to Step 1 (identifying decoy reads). Step 2
# (finding those reads in other references) always extracts all alignments of
# those reads regardless of MAPQ, so downstream scripts can apply their own
# thresholds.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

WORKER="${SCRIPT_DIR}/extract_decoy_reads_sample.sh"
OUT_DIR="${INTERMEDIATE_DIR}/decoy_reads_samples"
LOG_DIR="${OUT_DIR}/logs"
mkdir -p "${LOG_DIR}"
if [[ ! -L "${SCRIPT_DIR}/logs" ]]; then
    ln -s "${LOG_DIR}" "${SCRIPT_DIR}/logs"
fi

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }
trap 'log "ERROR at line ${LINENO}: ${BASH_COMMAND}"' ERR

TEST=${TEST:-0}
OVERWRITE=${OVERWRITE:-0}
MAPQ=${MAPQ:-}       # optional minimum MAPQ for Step 1; empty = mapped reads only

# ---------------------------------------------------------------------------
# hs38d1 contig list — derived from the decoy FASTA index on first run.
# The hs38d1 FASTA contains only the decoy contigs (JTFH*, KN*, etc.) so
# every entry in the index is a decoy contig.
# ---------------------------------------------------------------------------
HS38D1_CONTIGS="${OUT_DIR}/hs38d1_decoy_contigs.txt"
if [[ ! -f "${HS38D1_CONTIGS}" ]]; then
    mkdir -p "${OUT_DIR}"
    log "Generating hs38d1 contig list from FASTA index..."
    if [[ ! -f "${REF_HS38D1_DECOY}.fai" ]]; then
        samtools faidx "${REF_HS38D1_DECOY}"
    fi
    cut -f1 "${REF_HS38D1_DECOY}.fai" > "${HS38D1_CONTIGS}"
    log "  Written: ${HS38D1_CONTIGS} ($(wc -l < "${HS38D1_CONTIGS}") contigs)"
fi

# Source BAM reference for each decoy
declare -A DECOY_SOURCE_REF=(
    [hs37d5]="grch37d5"
    [hs38d1]="grch38_no_alt_plus_decoy"
)

# ---------------------------------------------------------------------------
# Submit one SLURM job per sample × decoy
# ---------------------------------------------------------------------------
log "======================================================"
log "01_extract_decoy_reads.sh"
log "Samples : ${SAMPLES[*]}"
log "Panels  : hs37d5 hs38d1"
log "MAPQ    : ${MAPQ:-none (mapped reads only)}"
log "Output  : ${OUT_DIR}"
[[ "${TEST}" == "1" ]] && log "TEST MODE: first sample × hs37d5 only"
log "======================================================"

submitted=0
skipped=0

for sample in "${SAMPLES[@]}"; do
    for decoy in hs37d5 hs38d1; do
        src_ref="${DECOY_SOURCE_REF[${decoy}]}"
        src_bam="${SAMPLES_1KGP_DIR}/${sample}/aligned/${src_ref}/${sample}.bam"
        done_marker="${OUT_DIR}/${decoy}/read_names/${sample}.${decoy}.read_names.txt"

        if [[ ! -f "${src_bam}" ]]; then
            log "SKIP (BAM missing): ${sample} × ${decoy} — ${src_bam}"
            ((skipped++)); continue
        fi

        if [[ -f "${done_marker}" && "${OVERWRITE}" != "1" ]]; then
            log "SKIP (already done): ${sample} × ${decoy}"
            ((skipped++)); continue
        fi

        mkdir -p "${OUT_DIR}/${decoy}/read_names"

        log "Submit: ${sample} × ${decoy}"
        sbatch \
            --job-name="decoy_${sample}_${decoy}" \
            --partition="${SLURM_PARTITION}" \
            --account="${SLURM_ACCOUNT}" \
            --mail-type=FAIL \
            --mail-user="${SLURM_EMAIL}" \
            --output="${LOG_DIR}/extract_${sample}_${decoy}.%j.out" \
            --time="0-02:00:00" \
            --mem=8000 \
            -c 1 -N 1 \
            "${WORKER}" \
            "${sample}" \
            "${decoy}" \
            "${src_bam}" \
            "${OUT_DIR}/${decoy}" \
            "${SAMPLES_1KGP_DIR}" \
            "${HS38D1_CONTIGS}" \
            "${MAPQ}"

        ((submitted++))
        [[ "${TEST}" == "1" ]] && break 2
    done
done

log "======================================================"
log "Submitted : ${submitted} jobs"
log "Skipped   : ${skipped}"
log "Logs      : ${LOG_DIR}/extract_<sample>_<decoy>.<jobid>.out"
log "======================================================"
