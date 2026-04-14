#!/bin/bash
# Indexes all seven reference FASTA files.
#
# For each reference this script runs:
#   samtools faidx              — produces <fasta>.fai  (required by
#                                 samtools depth and other tools)
#   gatk CreateSequenceDictionary — produces <fasta>.dict (required by
#                                 GATK HaplotypeCaller and VQSR)
#   bwa index                  — produces <fasta>.sa/.amb/.bwt/.ann/.pac
#                                 (required by BWA-MEM alignment in step 03)
#
# FASTA paths are read from ../config.sh via the softlinks created by
# 01_download.sh. Run 01_download.sh first.
#
# All output and errors are tee'd to a timestamped log file under
# resources/logs/. Each step is skipped if its output already exists.
#
# Usage:
#   bash 02_index_fasta.sh            # sequential (default)
#   PARALLEL=1 bash 02_index_fasta.sh # one SLURM job per reference (~1.5 h)
#
# Requires: samtools, gatk, bwa

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

PARALLEL=${PARALLEL:-0}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
LOG_DIR="${REPO_ROOT}/resources/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/02_index_fasta_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }

trap 'log "ERROR: command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

log "======================================================"
log "02_index_fasta.sh started"
log "Script   : ${SCRIPT_DIR}/02_index_fasta.sh"
log "Log file : $LOG_FILE"
log "Repo root: $REPO_ROOT"
log "Mode     : $([ "${PARALLEL}" == "1" ] && echo "PARALLEL (one SLURM job per ref)" || echo "sequential")"
log "======================================================"

# ---------------------------------------------------------------------------
# index_fasta — run all three indexing steps for one reference
# Called directly in sequential mode; embedded in sbatch --wrap in parallel mode.
# ---------------------------------------------------------------------------
index_fasta() {
    local ref=$1
    local fasta=$2
    local gatk_path=$3
    local samtools_path=$4

    log "--- $ref: $fasta"

    if [[ ! -f "$fasta" ]]; then
        log "ERROR: FASTA not found for '$ref': $fasta"
        exit 1
    fi

    # samtools faidx → <fasta>.fai
    if [[ ! -f "${fasta}.fai" ]]; then
        log "  Running: samtools faidx"
        "${samtools_path}" faidx "$fasta"
        log "  Written: ${fasta}.fai"
    else
        log "  FAI already exists, skipping"
    fi

    # gatk CreateSequenceDictionary → <base>.dict
    local dict="${fasta%.*}.dict"
    if [[ ! -f "$dict" ]]; then
        log "  Running: gatk CreateSequenceDictionary"
        "${gatk_path}" CreateSequenceDictionary -R "$fasta"
        log "  Written: $dict"
    else
        log "  Dict already exists, skipping"
    fi

    # bwa index → <fasta>.bwt (plus .sa/.amb/.ann/.pac)
    if [[ ! -f "${fasta}.bwt" ]]; then
        log "  Running: bwa index (this takes ~1.5 h for a 3 GB genome)"
        bwa index "$fasta"
        log "  Written: ${fasta}.sa/.amb/.bwt/.ann/.pac"
    else
        log "  BWA index already exists, skipping"
    fi

    log "  Done: $ref"
}

# ---------------------------------------------------------------------------
# submit_index_job — sbatch wrapper used in PARALLEL mode
# All paths are substituted by the launcher so the job needs no config.sh.
# ---------------------------------------------------------------------------
submit_index_job() {
    local ref=$1
    local fasta=$2

    log "  Submitting job: $ref"
    sbatch \
        --job-name="index_${ref}" \
        --partition="${SLURM_PARTITION}" \
        --account="${SLURM_ACCOUNT}" \
        --time=0-03:00:00 \
        --mem=16G \
        --mail-type=FAIL \
        --mail-user="${SLURM_EMAIL}" \
        --output="${LOG_DIR}/index_${ref}.%j.out" \
        --wrap="
set -euo pipefail
log() { echo \"[\$(date +'%Y-%m-%d %H:%M:%S')] \$*\"; }
trap 'log \"ERROR at line \${LINENO}: \${BASH_COMMAND}\"' ERR
log '--- Indexing ${ref}: ${fasta}'
if [[ ! -f '${fasta}.fai' ]]; then
    log '  samtools faidx'
    ${SAMTOOLS} faidx '${fasta}'
fi
dict='${fasta%.*}.dict'
if [[ ! -f \"\$dict\" ]]; then
    log '  gatk CreateSequenceDictionary'
    ${GATK} CreateSequenceDictionary -R '${fasta}'
fi
if [[ ! -f '${fasta}.bwt' ]]; then
    log '  bwa index'
    bwa index '${fasta}'
fi
log 'Done: ${ref}'
"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
if [[ "${PARALLEL}" == "1" ]]; then
    log "Submitting 7 indexing jobs to SLURM..."
    submit_index_job grch37                   "$REF_GRCH37"
    submit_index_job b37                      "$REF_B37"
    submit_index_job grch37d5                 "$REF_GRCH37D5"
    submit_index_job grch38_no_alt            "$REF_GRCH38_NO_ALT"
    submit_index_job grch38_no_alt_plus_decoy "$REF_GRCH38_NO_ALT_PLUS_DECOY"
    submit_index_job hg38_gatk                "$REF_HG38_GATK"
    submit_index_job t2t                      "$REF_T2T"
    log "======================================================"
    log "7 jobs submitted. Logs: ${LOG_DIR}/index_<ref>.<JOBID>.out"
    log "======================================================"
else
    index_fasta grch37                   "$REF_GRCH37"           "$GATK" "$SAMTOOLS"
    index_fasta b37                      "$REF_B37"              "$GATK" "$SAMTOOLS"
    index_fasta grch37d5                 "$REF_GRCH37D5"         "$GATK" "$SAMTOOLS"
    index_fasta grch38_no_alt            "$REF_GRCH38_NO_ALT"    "$GATK" "$SAMTOOLS"
    index_fasta grch38_no_alt_plus_decoy "$REF_GRCH38_NO_ALT_PLUS_DECOY" "$GATK" "$SAMTOOLS"
    index_fasta hg38_gatk                "$REF_HG38_GATK"        "$GATK" "$SAMTOOLS"
    index_fasta t2t                      "$REF_T2T"              "$GATK" "$SAMTOOLS"
    log "======================================================"
    log "02_index_fasta.sh completed successfully"
    log "Log: $LOG_FILE"
    log "======================================================"
fi
