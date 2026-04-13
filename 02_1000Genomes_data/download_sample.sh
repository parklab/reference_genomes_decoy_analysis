#!/bin/bash
#SBATCH -c 2
#SBATCH -N 1
#SBATCH -t 0-06:00:00
#SBATCH --mem=2000
#SBATCH --mail-type=FAIL

# 01_download_worker.sh — Download both FASTQs for one 1KGP sample.
# Called by 01_download.sh with all paths passed as arguments — no config.sh needed.
#
# Arguments: <sample> <srr> <ebi_subdir> <output_dir> <log_dir> <overwrite>
# Example:   HG00419 SRR1295554 SRR129/004 /path/to/samples_1000G /path/to/logs 0

set -euo pipefail

sample=$1
srr=$2
subdir=$3
output_dir=$4
log_dir=$5
overwrite=$6

FTP_BASE="ftp://ftp.sra.ebi.ac.uk/vol1/fastq"

mkdir -p "${log_dir}"
LOG_FILE="${log_dir}/01_download_${sample}_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }
trap 'log "ERROR: command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

log "======================================================"
log "download_worker started — sample: ${sample}"
log "Log file  : ${LOG_FILE}"
log "Output    : ${output_dir}/${sample}/"
log "======================================================"

sample_dir="${output_dir}/${sample}"
mkdir -p "${sample_dir}"

# Clean up any stale .tmp files from interrupted previous runs
for tmp in "${sample_dir}"/*.tmp; do
    [[ -f "${tmp}" ]] || continue
    log "WARNING: removing stale tmp file: $(basename "${tmp}")"
    rm -f "${tmp}"
done

for read in 1 2; do
    src="${FTP_BASE}/${subdir}/${srr}/${srr}_${read}.fastq.gz"
    dest="${sample_dir}/${sample}_${read}.fastq.gz"

    if [[ -f "${dest}" && "${overwrite}" != "1" ]]; then
        log "Skipping (already exists): ${sample}_${read}.fastq.gz"
        continue
    fi

    log "Downloading: ${sample}_${read}.fastq.gz"
    log "  Source: ${src}"
    t0=$(date +%s)
    wget -nv -O "${dest}.tmp" "${src}" 2>&1
    mv "${dest}.tmp" "${dest}"
    t1=$(date +%s)
    elapsed=$(( t1 - t0 ))
    log "  Done: $(du -m "${dest}" | cut -f1) MB in $(( elapsed / 60 ))m$(( elapsed % 60 ))s"
done

log "======================================================"
log "${sample} download complete"
log "======================================================"
