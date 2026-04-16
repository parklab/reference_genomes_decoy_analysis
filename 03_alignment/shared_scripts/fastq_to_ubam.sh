#!/bin/bash
#SBATCH -c 1
#SBATCH -N 1
#SBATCH -t 0-04:00:00
#SBATCH --mem=12000
#SBATCH --mail-type=FAIL

# fastq_to_ubam_sample.sh — Convert one paired FASTQ sample to an unmapped BAM.
#
# Shared by 01_simulated_decoy_reads and 02_1000Genomes_samples pipelines.
# Submitted via sbatch by 01_fastq_to_ubam.sh with all paths passed as
# arguments — no config.sh dependency, safe to run from SLURM spool.
#
# Arguments:
#   1: sample      — sample name (e.g. HG00419, hs37d5)
#   2: r1          — absolute path to read 1 FASTQ (.fq or .fastq.gz)
#   3: r2          — absolute path to read 2 FASTQ
#   4: output_dir  — directory to write <sample>.bam into
#   5: log_dir     — directory to write log file into
#   6: gatk_path   — path to GATK executable
#   7: overwrite   — 0 or 1 (default 0)

set -euo pipefail

sample=$1
r1=$2
r2=$3
output_dir=$4
log_dir=$5
gatk_path=$6
overwrite=${7:-0}

mkdir -p "${log_dir}"
LOG_FILE="${log_dir}/fastq_to_ubam_${sample}_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }
trap 'log "ERROR: command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

log "======================================================"
log "fastq_to_ubam_sample.sh started — sample: ${sample}"
log "R1        : ${r1}"
log "R2        : ${r2}"
log "Output    : ${output_dir}/${sample}.bam"
log "Log file  : ${LOG_FILE}"
log "GATK      : ${gatk_path}"
log "======================================================"

ubam="${output_dir}/${sample}.bam"
tmp_dir="${output_dir}/.tmp"
mkdir -p "${output_dir}" "${tmp_dir}"

if [[ -f "${ubam}" && "${overwrite}" != "1" ]]; then
    log "uBAM already exists, skipping: ${ubam}"
    log "Set OVERWRITE=1 to overwrite."
    exit 0
fi

log "Running FastqToSam..."
"${gatk_path}" FastqToSam \
    --FASTQ "${r1}" \
    --FASTQ2 "${r2}" \
    --OUTPUT "${ubam}" \
    --READ_GROUP_NAME "${sample}_RG" \
    --SAMPLE_NAME "${sample}" \
    --LIBRARY_NAME "lib_name" \
    --PLATFORM illumina \
    --TMP_DIR "${tmp_dir}"

log "======================================================"
log "Done: ${output_dir}/${sample}.bam"
log "======================================================"
