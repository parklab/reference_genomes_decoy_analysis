#!/bin/bash
# align_sample.sh — Full pipeline for one sample: uBAM creation (if needed) + alignment to all refs.
#
# Consolidated replacement for the two-step 01_fastq_to_ubam + 02_align_to_refs_gatk pattern.
# Run interactively (not submitted to SLURM) by 01_align_to_reference_genomes.sh launchers.
#
# If the uBAM already exists it is reused directly and all 7 alignment jobs start
# immediately. If it does not exist, a uBAM job is submitted first and the 7
# alignment jobs are chained via --dependency=afterok so SLURM handles the wait
# automatically.
#
# uBAM location: <output_dir>/ubam/<sample>.bam  (persisted, shared across refs)
# BAM location : <output_dir>/<ref>/<sample>.bam
#
# Arguments:
#   1: sample      — sample name (e.g. HG00419, hs37d5)
#   2: r1          — R1 FASTQ path (gzipped or plain)
#   3: r2          — R2 FASTQ path (gzipped or plain)
#   4: output_dir  — root output dir; ubam/ and per-ref subdirs created here
#   5: log_dir     — directory for SLURM output logs
#   6: runtime     — SLURM runtime for alignment jobs (e.g. 0-11:59:59)
#   7: overwrite   — 1 to overwrite existing output; 0 to skip (default: 0)
#   8: test_mode   — 1 to submit only b37 alignment (for testing); 0 for all 7 refs (default: 0)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config.sh"

sample=$1
r1=$2
r2=$3
output_dir=$4
log_dir=$5
runtime=$6
overwrite=${7:-0}
test_mode=${8:-0}

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }
trap 'log "ERROR at line ${LINENO}: ${BASH_COMMAND}"' ERR

UBAM_WORKER="${SCRIPT_DIR}/fastq_to_ubam.sh"
ALIGN_WORKER="${SCRIPT_DIR}/align_and_recalibrate.sh"

ubam_dir="${output_dir}/ubam"
ubam="${ubam_dir}/${sample}.bam"
mkdir -p "${ubam_dir}" "${log_dir}"

# ---------------------------------------------------------------------------
# Step 1: uBAM — create if absent, reuse if present
# ---------------------------------------------------------------------------
ubam_dep=""   # empty = no dependency needed for alignment jobs

if [[ -f "${ubam}" && "${overwrite}" != "1" ]]; then
    log "[${sample}] uBAM already exists, reusing: ${ubam}"
else
    log "[${sample}] Submitting uBAM job..."
    ubam_job=$(sbatch --parsable \
        --job-name="ubam_${sample}" \
        --partition="${SLURM_PARTITION}" \
        --account="${SLURM_ACCOUNT}" \
        --mail-user="${SLURM_EMAIL}" \
        --output="${log_dir}/ubam_${sample}.%j.out" \
        "${UBAM_WORKER}" \
        "${sample}" "${r1}" "${r2}" "${ubam_dir}" "${log_dir}" "${GATK}" "${overwrite}")
    ubam_dep="--dependency=afterok:${ubam_job}"
    log "[${sample}] uBAM job submitted: ${ubam_job}"
fi

# ---------------------------------------------------------------------------
# Step 2: Submit alignment jobs (one per reference)
# ---------------------------------------------------------------------------
submit_one_ref() {
    local ref_name=$1
    local ref_fasta=$2
    local dbsnp=$3
    local mills=$4

    local ref_out="${output_dir}/${ref_name}"
    mkdir -p "${ref_out}"
    local slurm_log="${log_dir}/map_${sample}_${ref_name}.%j.out"

    # Skip if output already exists and overwrite is off
    if [[ -f "${ref_out}/${sample}.bam" && "${overwrite}" != "1" ]]; then
        log "[${sample}] ${ref_name}: BAM already exists, skipping"
        return
    fi

    log "[${sample}] Submitting alignment job → ${ref_name}"
    sbatch \
        ${ubam_dep} \
        --job-name="${sample}.${ref_name}" \
        --time="${runtime}" \
        --partition="${SLURM_PARTITION}" \
        --account="${SLURM_ACCOUNT}" \
        --mail-user="${SLURM_EMAIL}" \
        --output="${slurm_log}" \
        "${ALIGN_WORKER}" \
        "${sample}" "${ubam}" "${ref_fasta}" "${dbsnp}" "${mills}" \
        "${ref_out}" "${GATK}" "${BWA}" "${overwrite}"
}

if [[ "${test_mode}" == "1" ]]; then
    log "[${sample}] TEST MODE: submitting b37 only"
    submit_one_ref b37 "$REF_B37" "$V37_DBSNP" "$V37_MILLS"
    log "[${sample}] 1 test job submitted → log: ${log_dir}/map_${sample}_b37.<JOBID>.out"
else
    submit_one_ref b37                      "$REF_B37"                      "$V37_DBSNP" "$V37_MILLS"
    submit_one_ref grch37                   "$REF_GRCH37"                   "$V37_DBSNP" "$V37_MILLS"
    submit_one_ref grch37d5                 "$REF_GRCH37D5"                 "$V37_DBSNP" "$V37_MILLS"
    submit_one_ref grch38_no_alt            "$REF_GRCH38_NO_ALT"            "$V38_DBSNP" "$V38_MILLS"
    submit_one_ref grch38_no_alt_plus_decoy "$REF_GRCH38_NO_ALT_PLUS_DECOY" "$V38_DBSNP" "$V38_MILLS"
    submit_one_ref hg38_gatk                "$REF_HG38_GATK"                "$V38_DBSNP" "$V38_MILLS"
    submit_one_ref t2t                      "$REF_T2T"                      "$T2T_DBSNP" ""
    log "[${sample}] 7 alignment jobs submitted → logs: ${log_dir}/map_${sample}_<ref>.<JOBID>.out"
fi
