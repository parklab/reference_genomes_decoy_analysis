#!/bin/bash
#SBATCH -c 1
#SBATCH -N 1
#SBATCH -t 0-04:00:00
#SBATCH --mem=12000
#SBATCH --mail-type=FAIL

# 01_fastq_to_ubam.sh — Convert simulated decoy FASTQ pairs to unmapped BAMs.
#
# Runs Picard FastqToSam for hs37d5 and hs38d1 decoy reads sequentially within
# one SLURM job.  The resulting uBAMs are the input to 02_align_to_refs.sh.
#
# Input (from DECOY_SIM_DIR in config.sh):
#   data/simulated/hs37d5/simulated_hs37d5_reads1.fq
#   data/simulated/hs37d5/simulated_hs37d5_reads2.fq
#   data/simulated/hs38d1/simulated_hs38d1_reads1.fq
#   data/simulated/hs38d1/simulated_hs38d1_reads2.fq
#
# Output:
#   data/simulated/hs37d5/aligned/ubam/hs37d5.bam
#   data/simulated/hs38d1/aligned/ubam/hs38d1.bam
#
# Usage: bash 03_alignment/01_simulated_decoy_reads/01_fastq_to_ubam.sh
#   OVERWRITE=1 bash ... to overwrite existing uBAMs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
source "${SCRIPT_DIR}/../../config.sh"

# ---------------------------------------------------------------------------
# Self-submission
# ---------------------------------------------------------------------------
if [[ -z "${SLURM_JOB_ID:-}" ]]; then
    echo "Submitting ${SCRIPT_NAME} to SLURM (partition: ${SLURM_PARTITION}, account: ${SLURM_ACCOUNT})..."
    sbatch \
        --partition="${SLURM_PARTITION}" \
        --account="${SLURM_ACCOUNT}" \
        --mail-user="${SLURM_EMAIL}" \
        "$0"
    exit 0
fi

# ---------------------------------------------------------------------------
# Logging — shared with simulation logs
# ---------------------------------------------------------------------------
LOG_DIR="${DECOY_SIM_DIR}/logs"
mkdir -p "$LOG_DIR"
if [[ ! -L "${SCRIPT_DIR}/logs" ]]; then
    ln -s "${LOG_DIR}" "${SCRIPT_DIR}/logs"
fi
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.sh}_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }
trap 'log "ERROR: command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

log "======================================================"
log "${SCRIPT_NAME} started"
log "Script    : ${SCRIPT_DIR}/${SCRIPT_NAME}"
log "Log file  : $LOG_FILE"
log "Repo root : $REPO_ROOT"
log "Sim dir   : $DECOY_SIM_DIR"
log "GATK      : $GATK"
log "======================================================"

TMP_DIR="${DECOY_SIM_DIR}/.tmp"
mkdir -p "${TMP_DIR}"

# ---------------------------------------------------------------------------
# Check for existing uBAMs
# ---------------------------------------------------------------------------
EXISTING=()
for sample in hs37d5 hs38d1; do
    [[ -f "${DECOY_SIM_DIR}/${sample}/aligned/ubam/${sample}.bam" ]] && \
        EXISTING+=("${DECOY_SIM_DIR}/${sample}/aligned/ubam/${sample}.bam")
done

if [[ ${#EXISTING[@]} -gt 0 ]]; then
    if [[ "${OVERWRITE:-0}" != "1" ]]; then
        log "WARNING: existing uBAMs found:"
        for f in "${EXISTING[@]}"; do log "  $f"; done
        log "Remove or rename them and re-run, or set OVERWRITE=1 to overwrite."
        exit 1
    else
        log "OVERWRITE=1 — existing uBAMs will be overwritten."
    fi
fi

# ---------------------------------------------------------------------------
# Picard FastqToSam — one call per decoy
# ---------------------------------------------------------------------------
for sample in hs37d5 hs38d1; do
    ubam_dir="${DECOY_SIM_DIR}/${sample}/aligned/ubam"
    mkdir -p "${ubam_dir}"

    log "Running FastqToSam for ${sample}..."
    "${GATK}" FastqToSam \
        --FASTQ "${DECOY_SIM_DIR}/${sample}/simulated_${sample}_reads1.fq" \
        --FASTQ2 "${DECOY_SIM_DIR}/${sample}/simulated_${sample}_reads2.fq" \
        --OUTPUT "${ubam_dir}/${sample}.bam" \
        --READ_GROUP_NAME "${sample}_RG" \
        --SAMPLE_NAME "${sample}" \
        --LIBRARY_NAME "lib_name" \
        --PLATFORM illumina \
        --TMP_DIR "${TMP_DIR}"
    log "...${sample} uBAM done: ${ubam_dir}/${sample}.bam"
done

log "======================================================"
log "${SCRIPT_NAME} completed successfully"
log "Next step: bash 02_align_to_refs.sh"
log "Log written to: $LOG_FILE"
log "======================================================"
