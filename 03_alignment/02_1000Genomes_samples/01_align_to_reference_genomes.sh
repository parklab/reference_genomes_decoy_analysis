#!/bin/bash
# 01_align_to_reference_genomes.sh — Align 1KGP samples to all 7 references.
#
# For each of the 8 samples this script:
#   - Creates a uBAM via FastqToSam if one does not already exist
#   - Submits one SLURM alignment job per reference (7 jobs per sample, 56 total)
#   - If the uBAM was just created, alignment jobs are chained automatically
#     via SLURM dependency; if the uBAM already existed they start immediately
#
# Input:
#   data/samples_1000G/<sample>/<sample>_1.fastq.gz
#   data/samples_1000G/<sample>/<sample>_2.fastq.gz
#
# Output:
#   data/samples_1000G/<sample>/aligned/ubam/<sample>.bam   (persisted uBAM)
#   data/samples_1000G/<sample>/aligned/<ref>/<sample>.bam  (final BAMs)
#
# Logs: data/samples_1000G/logs/
#
# Usage:
#   bash 03_alignment/02_1000Genomes_samples/01_align_to_reference_genomes.sh
#   TEST=1 bash ...   # submit only HG00419 → b37 to verify before full run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/../../config.sh"

SHARED="${SCRIPT_DIR}/../shared_scripts/align_sample.sh"
LOG_DIR="${SAMPLES_1KGP_DIR}/logs"

mkdir -p "${LOG_DIR}"
if [[ ! -L "${SCRIPT_DIR}/logs" ]]; then
    ln -s "${LOG_DIR}" "${SCRIPT_DIR}/logs"
fi

LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.sh}_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }
trap 'log "ERROR: command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

TEST=${TEST:-0}

log "======================================================"
log "${SCRIPT_NAME} started"
log "Script   : ${SCRIPT_DIR}/${SCRIPT_NAME}"
log "Log file : ${LOG_FILE}"
log "Samples  : ${SAMPLES_1KGP_DIR}"
log "GATK     : ${GATK}"
log "BWA      : ${BWA}"
[[ "${TEST}" == "1" ]] && log "TEST MODE: 1 job only (${SAMPLES[0]} → b37)"
log "======================================================"

for sample in "${SAMPLES[@]}"; do
    r1="${SAMPLES_1KGP_DIR}/${sample}/${sample}_1.fastq.gz"
    r2="${SAMPLES_1KGP_DIR}/${sample}/${sample}_2.fastq.gz"
    output_dir="${SAMPLES_1KGP_DIR}/${sample}/aligned"

    if [[ ! -f "${r1}" || ! -f "${r2}" ]]; then
        log "ERROR: FASTQ files not found for ${sample}: ${r1}"
        exit 1
    fi

    log "Processing sample: ${sample}"
    bash "${SHARED}" "${sample}" "${r1}" "${r2}" "${output_dir}" "${LOG_DIR}" \
        "0-11:59:59" "${OVERWRITE:-0}" "${TEST}"

    [[ "${TEST}" == "1" ]] && break
done

if [[ "${TEST}" == "1" ]]; then
    log "======================================================"
    log "TEST: jobs submitted for ${SAMPLES[0]} → b37 only."
    log "Check log before running full set."
    log "======================================================"
else
    log "======================================================"
    log "All jobs submitted for ${#SAMPLES[@]} samples × 7 references."
    log "uBAMs : ${SAMPLES_1KGP_DIR}/<sample>/aligned/ubam/<sample>.bam"
    log "BAMs  : ${SAMPLES_1KGP_DIR}/<sample>/aligned/<ref>/<sample>.bam"
    log "Logs  : ${LOG_DIR}/map_<sample>_<ref>.<JOBID>.out"
    log "======================================================"
fi
