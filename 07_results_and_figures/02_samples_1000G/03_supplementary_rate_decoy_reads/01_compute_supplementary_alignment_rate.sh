#!/bin/bash
# 01_compute_supplementary_alignment_rate.sh — Measure the supplementary alignment rate
# of MAPQ≥20 decoy reads across all samples, decoys, and reference genomes.
#
# For each sample × decoy (hs37d5, hs38d1) × reference (7 refs):
#   Uses the pre-extracted mapq20 orig BAMs from step 04.
#   Runs samtools flagstat to get mapped and supplementary alignment counts.
#
# Output:
#   results/intermediate/decoy_reads_samples/decoy_read_stats/supplementary_alignment_rate/
#     supplementary_alignment_rate.csv
#
# Usage:
#   bash 07_analysis_and_figures/02_samples_1000G/03_supplementary_rate_decoy_reads/01_compute_supplementary_alignment_rate.sh
#   (submits itself to SLURM using partition/account from config.sh)
#
#SBATCH --job-name=supp_rate
#SBATCH --mail-type=FAIL
#SBATCH --output=/dev/null
#SBATCH --time=0-01:00:00
#SBATCH --mem=4000
#SBATCH -c 1 -N 1

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../config.sh"

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }
trap 'log "ERROR at line ${LINENO}: ${BASH_COMMAND}"' ERR

OUT_DIR="${RESULTS_DIR}/intermediate/decoy_reads_samples/decoy_read_stats/supplementary_alignment_rate"
mkdir -p "${OUT_DIR}"

LOG_DIR="${OUT_DIR}/logs"
mkdir -p "${LOG_DIR}"

# Self-submit to SLURM when not already running as a job
if [[ -z "${SLURM_JOB_ID:-}" ]]; then
    log "Submitting to SLURM (partition=${SLURM_PARTITION}, account=${SLURM_ACCOUNT})..."
    sbatch \
        --partition="${SLURM_PARTITION}" \
        --account="${SLURM_ACCOUNT}" \
        --mail-user="${SLURM_EMAIL}" \
        --output="${LOG_DIR}/supplementary_alignment_rate.%j.out" \
        "${BASH_SOURCE[0]}"
    exit 0
fi

log "Running as SLURM job ${SLURM_JOB_ID}"

DECOY_DIR="${RESULTS_DIR}/intermediate/decoy_reads_samples"
REFS=(b37 grch37 grch37d5 grch38_no_alt grch38_no_alt_plus_decoy hg38_gatk t2t)
CSV="${OUT_DIR}/supplementary_alignment_rate.csv"

log "============================================================"
log "03_supplementary_rate_decoy_reads.sh"
log "Samples : ${SAMPLES[*]}"
log "Output  : ${CSV}"
log "============================================================"

echo "sample,decoy,ref,mapped,supplementary,pct_supplementary" > "${CSV}"

for sample in "${SAMPLES[@]}"; do
    for decoy in hs37d5 hs38d1; do
        for ref in "${REFS[@]}"; do
            bam="${DECOY_DIR}/${decoy}/${ref}/${sample}.${decoy}_decoy_reads.${ref}.mapq20.orig.bam"

            if [[ ! -f "${bam}" ]]; then
                log "SKIP ${sample} × ${decoy} × ${ref}: BAM not found"
                continue
            fi

            log "${sample} × ${decoy} × ${ref}..."

            flagstat=$(samtools flagstat "${bam}")
            mapped=$(echo "${flagstat}"       | awk '/^[0-9]+ \+ [0-9]+ mapped/       {print $1}')
            supplementary=$(echo "${flagstat}" | awk '/^[0-9]+ \+ [0-9]+ supplementary/ {print $1}')

            pct=$(awk "BEGIN {
                if (${mapped} > 0) printf \"%.6f\", ${supplementary}/${mapped}*100
                else print \"NA\"
            }")

            echo "${sample},${decoy},${ref},${mapped},${supplementary},${pct}" >> "${CSV}"
            log "  mapped=${mapped}  supplementary=${supplementary} (${pct}%)"
        done
    done
done

log "============================================================"
log "Done. Output: ${CSV}"
log "============================================================"
