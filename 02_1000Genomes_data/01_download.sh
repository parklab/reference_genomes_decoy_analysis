#!/bin/bash
# 01_download.sh — Launcher: submits one SLURM download job per 1KGP sample.
#
# Usage:
#   bash 02_1000Genomes_data/01_download.sh
#   OVERWRITE=1 bash 02_1000Genomes_data/01_download.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/../config.sh"

LOG_DIR="${SAMPLES_1KGP_DIR}/logs"
mkdir -p "${LOG_DIR}"
if [[ ! -L "${SCRIPT_DIR}/logs" ]]; then
    ln -s "${LOG_DIR}" "${SCRIPT_DIR}/logs"
fi

LAUNCHER_LOG="${LOG_DIR}/${SCRIPT_NAME%.sh}_launcher_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LAUNCHER_LOG}") 2>&1

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }

log "======================================================"
log "${SCRIPT_NAME} launcher started"
log "Output    : ${SAMPLES_1KGP_DIR}"
log "Partition : ${SLURM_PARTITION}"
log "======================================================"

declare -a SAMPLES_MAP=(
    "HG00419  SRR1295554  SRR129/004"
    "HG01051  SRR1291157  SRR129/007"
    "HG01565  SRR1298989  SRR129/009"
    "HG02922  SRR1295553  SRR129/003"
    "HG03742  SRR1293283  SRR129/003"
    "NA19017  SRR1295546  SRR129/006"
    "NA19648  SRR1291138  SRR129/008"
    "NA20845  SRR1295465  SRR129/005"
)

# Check for existing files upfront
EXISTING=()
for entry in "${SAMPLES_MAP[@]}"; do
    sample=$(echo "$entry" | awk '{print $1}')
    for read in 1 2; do
        dest="${SAMPLES_1KGP_DIR}/${sample}/${sample}_${read}.fastq.gz"
        [[ -f "${dest}" ]] && EXISTING+=("${dest}")
    done
done

if [[ ${#EXISTING[@]} -gt 0 ]]; then
    log "WARNING: ${#EXISTING[@]} file(s) already exist:"
    for f in "${EXISTING[@]}"; do log "  $f"; done
    if [[ "${OVERWRITE:-0}" != "1" ]]; then
        log "Existing files will be skipped. Set OVERWRITE=1 to re-download."
    else
        log "OVERWRITE=1 — existing files will be re-downloaded."
    fi
fi

WORKER="${SCRIPT_DIR}/download_sample.sh"

for entry in "${SAMPLES_MAP[@]}"; do
    sample=$(echo "$entry" | awk '{print $1}')
    srr=$(echo "$entry"    | awk '{print $2}')
    subdir=$(echo "$entry" | awk '{print $3}')

    job_id=$(sbatch \
        --partition="${SLURM_PARTITION}" \
        --account="${SLURM_ACCOUNT}" \
        --mail-user="${SLURM_EMAIL}" \
        --job-name="download_${sample}" \
        "${WORKER}" \
            "${sample}" "${srr}" "${subdir}" \
            "${SAMPLES_1KGP_DIR}" "${LOG_DIR}" "${OVERWRITE:-0}" \
        | awk '{print $NF}')
    log "Submitted job ${job_id} for ${sample}"
done

log "======================================================"
log "All 8 download jobs submitted. Per-sample logs in: ${LOG_DIR}/"
log "======================================================"
