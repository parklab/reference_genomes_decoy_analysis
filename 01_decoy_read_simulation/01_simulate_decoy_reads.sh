#!/bin/bash
#SBATCH -c 1
#SBATCH -N 1
#SBATCH -t 0-01:00:00
#SBATCH --mem=2000
#SBATCH --mail-type=FAIL

# 01_simulate_decoy_reads.sh — Simulate 150 bp paired-end reads from hs37d5 and/or hs38d1 decoy sequences.
#
# Runs ART on the selected decoy FASTAs sequentially within one SLURM job.
# FASTA paths and SLURM settings are taken from config.sh automatically.
#
# Output layout (relative to repository root):
#   data/simulated/hs37d5/simulated_hs37d5_reads1.fq, simulated_hs37d5_reads2.fq, simulated_hs37d5_reads.sam
#   data/simulated/hs38d1/simulated_hs38d1_reads1.fq, simulated_hs38d1_reads2.fq, simulated_hs38d1_reads.sam
#
# Usage:
#   bash 01_simulate_decoy_reads.sh [hs37d5|hs38d1]   # one decoy only
#   bash 01_simulate_decoy_reads.sh                    # both (default)
#   OVERWRITE=1 bash 01_simulate_decoy_reads.sh        # overwrite existing outputs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
source "${SCRIPT_DIR}/../config.sh"

# ---------------------------------------------------------------------------
# Determine targets from optional argument (default: both)
# ---------------------------------------------------------------------------
TARGET="${1:-both}"
case "$TARGET" in
    hs37d5)  TARGETS=(hs37d5) ;;
    hs38d1)  TARGETS=(hs38d1) ;;
    both)    TARGETS=(hs37d5 hs38d1) ;;
    *)
        echo "ERROR: unknown target '${TARGET}'. Valid options: hs37d5, hs38d1, or omit for both."
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Self-submission: if not already running inside SLURM, re-submit via sbatch
# using settings from config.sh, then exit.
# OVERWRITE and the target argument are forwarded automatically.
# ---------------------------------------------------------------------------
if [[ -z "${SLURM_JOB_ID:-}" ]]; then
    echo "Submitting ${SCRIPT_NAME} to SLURM (partition: ${SLURM_PARTITION}, account: ${SLURM_ACCOUNT})..."
    echo "  Target(s): ${TARGETS[*]}"
    sbatch \
        --partition="${SLURM_PARTITION}" \
        --account="${SLURM_ACCOUNT}" \
        --mail-user="${SLURM_EMAIL}" \
        "$0" "$@"
    exit 0
fi

# ---------------------------------------------------------------------------
# Logging — stored with the results; softlink from script directory for convenience
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
log "Output dir: $DECOY_SIM_DIR"
log "ART binary: $ART_ILLUMINA"
log "Target(s) : ${TARGETS[*]}"
log "Overwrite : ${OVERWRITE:-0}"
log "======================================================"

# ---------------------------------------------------------------------------
# Check for existing outputs
# ---------------------------------------------------------------------------
EXISTING=()
for target in "${TARGETS[@]}"; do
    [[ -f "${DECOY_SIM_DIR}/${target}/simulated_${target}_reads1.fq" ]] && \
        EXISTING+=("${DECOY_SIM_DIR}/${target}/simulated_${target}_reads1.fq")
done

if [[ ${#EXISTING[@]} -gt 0 ]]; then
    if [[ "${OVERWRITE:-0}" != "1" ]]; then
        log "WARNING: existing simulated reads found:"
        for f in "${EXISTING[@]}"; do log "  $f"; done
        log "Remove or rename the existing files and re-run, or set OVERWRITE=1 to overwrite them."
        exit 1
    else
        log "OVERWRITE=1 — existing files will be overwritten."
    fi
fi

# ---------------------------------------------------------------------------
# Declare FASTA paths per target
# ---------------------------------------------------------------------------
declare -A DECOY_FASTA=(
    [hs37d5]="${REF_HS37D5_DECOY}"
    [hs38d1]="${REF_HS38D1_DECOY}"
)

# ---------------------------------------------------------------------------
# Run ART
# ---------------------------------------------------------------------------
for target in "${TARGETS[@]}"; do
    mkdir -p "${DECOY_SIM_DIR}/${target}"
    log "Running ART for ${target}..."
    "${ART_ILLUMINA}" \
        -ss HSXn \
        -sam \
        -i "${DECOY_FASTA[$target]}" \
        -p \
        -l 150 \
        -f 50 \
        -m 400 \
        -s 10 \
        -o "${DECOY_SIM_DIR}/${target}/simulated_${target}_reads"
    log "...read simulation from ${target} done."
done

log "======================================================"
log "${SCRIPT_NAME} completed successfully"
log "Log written to: $LOG_FILE"
log "======================================================"
