#!/bin/bash
# 01_compute_decoy_read_percentages.sh — Compute percent of reads mapping to decoy contigs
# for each 1KGP sample, in the decoy-containing references (grch37d5, grch38_no_alt_plus_decoy).
#
# For each sample and each decoy (hs37d5, hs38d1):
#   - total_mapped:      all mapped alignments in the decoy-containing BAM (idxstats col3 sum)
#   - decoy_mapq0:       alignments to decoy contigs (any MAPQ) via idxstats
#   - decoy_mapq20:      alignments to decoy contigs with MAPQ≥20 via samtools view -q 20 -c
#   - pct_mapq0/mapq20:  decoy / total_mapped × 100
#
# hs37d5 decoy contig: "hs37d5" (NC_007605/EBV excluded — present in 5/7 refs so not a true decoy)
# hs38d1 decoy contigs: all KN* and JTFH* contigs (2385 total)
#
# Output: results/intermediate/decoy_reads_samples/decoy_read_stats/percentage_decoy_reads/decoy_read_percentages.csv
#
# Usage:
#   bash 07_analysis_and_figures/02_samples_1000G/01_decoy_read_percentages/01_compute_decoy_read_percentages.sh
#   (submits itself to SLURM using partition/account from config.sh)
#
#SBATCH --job-name=decoy_pct
#SBATCH --mail-type=FAIL
#SBATCH --output=/dev/null
#SBATCH --time=0-02:00:00
#SBATCH --mem=4000
#SBATCH -c 1 -N 1

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../config.sh"

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }
trap 'log "ERROR at line ${LINENO}: ${BASH_COMMAND}"' ERR

OUT_DIR="${RESULTS_DIR}/intermediate/decoy_reads_samples/decoy_read_stats/percentage_decoy_reads"
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
        --output="${LOG_DIR}/decoy_read_percentages.%j.out" \
        "${BASH_SOURCE[0]}"
    exit 0
fi

log "Running as SLURM job ${SLURM_JOB_ID}"

CSV="${OUT_DIR}/decoy_read_percentages.csv"
CONTIGS="${RESULTS_DIR}/intermediate/decoy_reads_samples/hs38d1_decoy_contigs.txt"

# Build a BED file for hs38d1 contigs from the grch38_no_alt_plus_decoy BAM header.
# Used for samtools view -L (mapq20 count). Generated once and reused.
HS38D1_BED="${OUT_DIR}/hs38d1_decoy_contigs.bed"
if [[ ! -f "${HS38D1_BED}" ]]; then
    log "Generating hs38d1 BED from BAM header..."
    ref_bam="${SAMPLES_1KGP_DIR}/${SAMPLES[0]}/aligned/grch38_no_alt_plus_decoy/${SAMPLES[0]}.orig.bam"
    awk 'NR==FNR { c[$1]=1; next }
         /^@SQ/ {
             sn=""; ln=""
             for (i=1;i<=NF;i++) {
                 if ($i~/^SN:/) sn=substr($i,4)
                 if ($i~/^LN:/) ln=substr($i,4)
             }
             if (sn in c) print sn "\t0\t" ln
         }' \
        "${CONTIGS}" <(samtools view -H "${ref_bam}") > "${HS38D1_BED}"
    log "  ${HS38D1_BED}: $(wc -l < "${HS38D1_BED}") contigs"
fi

log "============================================================"
log "01_decoy_read_percentages.sh"
log "Samples : ${SAMPLES[*]}"
log "Output  : ${CSV}"
log "============================================================"

# Write CSV header
echo "sample,decoy,total_mapped,decoy_reads_mapq0,decoy_reads_mapq20,pct_mapq0,pct_mapq20" > "${CSV}"

for sample in "${SAMPLES[@]}"; do
    bam_v37="${SAMPLES_1KGP_DIR}/${sample}/aligned/grch37d5/${sample}.orig.bam"
    bam_v38="${SAMPLES_1KGP_DIR}/${sample}/aligned/grch38_no_alt_plus_decoy/${sample}.orig.bam"

    for decoy in hs37d5 hs38d1; do
        if [[ "${decoy}" == "hs37d5" ]]; then
            bam="${bam_v37}"
        else
            bam="${bam_v38}"
        fi

        if [[ ! -f "${bam}" ]]; then
            log "SKIP ${sample} × ${decoy}: BAM not found: ${bam}"
            continue
        fi

        log "${sample} × ${decoy}..."

        # Total mapped: sum of col3 across all idxstats rows
        # (* row has col3=0 so unmapped reads are excluded automatically)
        total_mapped=$(samtools idxstats "${bam}" | awk '{sum += $3} END {print sum}')

        if [[ "${decoy}" == "hs37d5" ]]; then
            # mapq0: reads mapped to hs37d5 contig (any MAPQ) from idxstats
            decoy_mapq0=$(samtools idxstats "${bam}" | awk '$1 == "hs37d5" {print $3}')
            # mapq20: reads mapped to hs37d5 with MAPQ≥20
            decoy_mapq20=$(samtools view -c -q 20 "${bam}" hs37d5)
        else
            # mapq0: sum reads mapped to KN* and JTFH* contigs from idxstats
            decoy_mapq0=$(samtools idxstats "${bam}" | \
                awk '{if ($1 ~ /^KN/ || $1 ~ /^JTFH/) sum += $3} END {print sum+0}')
            # mapq20: reads mapped to hs38d1 contigs with MAPQ≥20 via BED
            decoy_mapq20=$(samtools view -c -q 20 -L "${HS38D1_BED}" "${bam}")
        fi

        # Percentages (6 decimal places)
        pct_mapq0=$(awk  "BEGIN {printf \"%.6f\", ${decoy_mapq0}/${total_mapped}*100}")
        pct_mapq20=$(awk "BEGIN {printf \"%.6f\", ${decoy_mapq20}/${total_mapped}*100}")

        echo "${sample},${decoy},${total_mapped},${decoy_mapq0},${decoy_mapq20},${pct_mapq0},${pct_mapq20}" >> "${CSV}"
        log "  total=${total_mapped}  mapq0=${decoy_mapq0} (${pct_mapq0}%)  mapq20=${decoy_mapq20} (${pct_mapq20}%)"
    done
done

log "============================================================"
log "Done. Output: ${CSV}"
log "============================================================"
