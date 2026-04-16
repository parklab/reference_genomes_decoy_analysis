#!/bin/bash
# 01_align_to_reference_genomes.sh — Align simulated decoy reads to all 7 references.
#
# For each decoy (hs37d5, hs38d1) this script:
#   - Creates a uBAM via FastqToSam if one does not already exist
#   - Submits one SLURM alignment job per reference (7 jobs per decoy, 14 total)
#   - If the uBAM was just created, alignment jobs are chained automatically
#     via SLURM dependency; if the uBAM already existed they start immediately
#
# Input:
#   data/simulated/<decoy>/simulated_<decoy>_reads1.fq
#   data/simulated/<decoy>/simulated_<decoy>_reads2.fq
#
# Output:
#   data/simulated/<decoy>/aligned/ubam/<decoy>.bam   (persisted uBAM)
#   data/simulated/<decoy>/aligned/<ref>/<decoy>.bam  (final BAMs)
#
# Logs: data/simulated/logs/
#
# Usage:
#   bash 03_alignment/01_simulated_decoy_reads/01_align_to_reference_genomes.sh
#   TEST=1 bash ...   # submit only hs37d5 → b37 to verify before full run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/../../config.sh"

SHARED="${SCRIPT_DIR}/../shared_scripts/align_sample.sh"
LOG_DIR="${DECOY_SIM_DIR}/logs"

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
log "Sim dir  : ${DECOY_SIM_DIR}"
log "GATK     : ${GATK}"
log "BWA      : ${BWA}"
[[ "${TEST}" == "1" ]] && log "TEST MODE: 1 job only (hs37d5 → b37)"
log "======================================================"

for decoy in hs37d5 hs38d1; do
    r1="${DECOY_SIM_DIR}/${decoy}/simulated_${decoy}_reads1.fq"
    r2="${DECOY_SIM_DIR}/${decoy}/simulated_${decoy}_reads2.fq"
    output_dir="${DECOY_SIM_DIR}/${decoy}/aligned"

    if [[ ! -f "${r1}" || ! -f "${r2}" ]]; then
        log "ERROR: FASTQ files not found for ${decoy}: ${r1}"
        exit 1
    fi

    log "Processing decoy: ${decoy}"
    bash "${SHARED}" "${decoy}" "${r1}" "${r2}" "${output_dir}" "${LOG_DIR}" \
        "0-11:59:59" "${OVERWRITE:-0}" "${TEST}"

    [[ "${TEST}" == "1" ]] && break
done

if [[ "${TEST}" == "1" ]]; then
    log "======================================================"
    log "TEST: jobs submitted for hs37d5 → b37 only."
    log "Check log before running full set."
    log "======================================================"
else
    log "======================================================"
    log "All jobs submitted for 2 decoys × 7 references."
    log "uBAMs : ${DECOY_SIM_DIR}/<decoy>/aligned/ubam/<decoy>.bam"
    log "BAMs  : ${DECOY_SIM_DIR}/<decoy>/aligned/<ref>/<decoy>.bam"
    log "Logs  : ${LOG_DIR}/map_<decoy>_<ref>.<JOBID>.out"
    log "======================================================"
fi
