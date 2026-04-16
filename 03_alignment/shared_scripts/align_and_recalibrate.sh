#!/bin/bash
# align_and_recalibrate.sh — Align one sample to one reference and apply BQSR.
#
# Runs: BWA-MEM → MergeBamAlignment → MarkDuplicates → SortSam →
#       SetNmMdAndUqTags → BaseRecalibrator → ApplyBQSR
# Submitted via sbatch by align_sample.sh — not run directly.
# Does NOT source config.sh; all paths are passed as arguments.
#
# Pipeline steps (GATK Best Practices):
#   SamToFastq → BWA-MEM → MergeBamAlignment → MarkDuplicates →
#   SortSam → SetNmMdAndUqTags → BaseRecalibrator → ApplyBQSR → BuildBamIndex
#
# Arguments:
#   1: sample      — sample name (e.g. HG00419, hs37d5)
#   2: ubam        — path to input uBAM
#   3: ref_fasta   — reference FASTA (must be indexed: .fai, .dict, .bwt, ...)
#   4: dbsnp       — dbSNP VCF (must have .idx)
#   5: mills       — Mills indels VCF (must have .idx); pass "" to skip (e.g. T2T has no native Mills)
#   6: output_dir  — directory for final BAM; created if absent
#   7: gatk        — path to GATK executable
#   8: bwa         — path to BWA executable
#   9: overwrite   — 1 to overwrite existing output; 0 to skip (default: 0)
#
# Log: SLURM captures stdout/stderr via --output set by the launcher.
# Disk: ~3× the uBAM size is needed in output_dir/.tmp_<sample>/ for intermediate files.
#
#SBATCH -c 16
#SBATCH -t 0-11:59:59
#SBATCH --mem=32000
#SBATCH --mail-type=FAIL

set -euo pipefail

sample=$1
ubam=$2
ref_fasta=$3
dbsnp=$4
mills=$5
output_dir=$6
gatk=$7
bwa=$8
overwrite=${9:-0}

mkdir -p "${output_dir}"

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }
trap 'log "ERROR at line ${LINENO}: ${BASH_COMMAND}"' ERR

final_bam="${output_dir}/${sample}.bam"

if [[ -f "${final_bam}" && "${overwrite}" != "1" ]]; then
    log "Output already exists, skipping: ${final_bam}"
    exit 0
fi

tmp_dir="${output_dir}/.tmp_${sample}"
mkdir -p "${tmp_dir}"
# Remove tmp dir on exit (success or failure) so disk is not left cluttered
trap 'log "Cleaning up: ${tmp_dir}"; rm -rf "${tmp_dir}"' EXIT

log "======================================================"
log "preprocess_sample.sh: ${sample}"
log "  uBAM     : ${ubam}"
log "  Reference: ${ref_fasta}"
log "  dbSNP    : ${dbsnp}"
log "  Mills    : ${mills}"
log "  Output   : ${final_bam}"
log "======================================================"

# ---------------------------------------------------------------------------
# Step 1: uBAM → interleaved FASTQ
# ---------------------------------------------------------------------------
log "Step 1/7: SamToFastq"
"${gatk}" SamToFastq \
    --java-options "-Xms3g -Xmx10g" \
    --INPUT        "${ubam}" \
    --FASTQ        "${tmp_dir}/interleaved.fastq.gz" \
    --INTERLEAVE   true \
    --NON_PF       true \
    --TMP_DIR      "${tmp_dir}"

# ---------------------------------------------------------------------------
# Step 2: BWA-MEM alignment  (-p = interleaved paired-end; -Y = soft-clip supplementary)
# ---------------------------------------------------------------------------
log "Step 2/7: BWA-MEM"
"${bwa}" mem \
    -K 100000000 -p -t 16 -Y \
    "${ref_fasta}" \
    "${tmp_dir}/interleaved.fastq.gz" | \
samtools view -bh -o "${tmp_dir}/aligned.bam"
rm -f "${tmp_dir}/interleaved.fastq.gz"

# ---------------------------------------------------------------------------
# Step 3: MergeBamAlignment — restore read-group metadata from the uBAM
# ---------------------------------------------------------------------------
log "Step 3/7: MergeBamAlignment"
# bwa with no args exits 1; || true prevents set -e from aborting
bwa_version=$({ "${bwa}" 2>&1 || true; } | grep -m1 "^Version:" | awk '{print $2}')
"${gatk}" MergeBamAlignment \
    --java-options "-Xms3g -Xmx10g" \
    --UNMAPPED_BAM                   "${ubam}" \
    --ALIGNED_BAM                    "${tmp_dir}/aligned.bam" \
    --OUTPUT                         "${tmp_dir}/merged.bam" \
    --REFERENCE_SEQUENCE             "${ref_fasta}" \
    --SORT_ORDER                     unsorted \
    --IS_BISULFITE_SEQUENCE          false \
    --ALIGNED_READS_ONLY             false \
    --CLIP_ADAPTERS                  false \
    --ADD_MATE_CIGAR                 true \
    --MAX_INSERTIONS_OR_DELETIONS    -1 \
    --PRIMARY_ALIGNMENT_STRATEGY     MostDistant \
    --ATTRIBUTES_TO_RETAIN           X0 \
    --PROGRAM_RECORD_ID              bwamem \
    --PROGRAM_GROUP_VERSION          "${bwa_version}" \
    --PROGRAM_GROUP_COMMAND_LINE     "bwa mem -K 100000000 -p -t 16 -Y ${ref_fasta}" \
    --PROGRAM_GROUP_NAME             bwamem \
    --TMP_DIR                        "${tmp_dir}"
rm -f "${tmp_dir}/aligned.bam"

# ---------------------------------------------------------------------------
# Step 4: MarkDuplicates
# ---------------------------------------------------------------------------
log "Step 4/7: MarkDuplicates"
"${gatk}" MarkDuplicates \
    --java-options "-Xms4g -Xmx7g" \
    --INPUT                          "${tmp_dir}/merged.bam" \
    --OUTPUT                         "${tmp_dir}/markdup.bam" \
    --METRICS_FILE                   "${output_dir}/${sample}.duplicate_metrics" \
    --VALIDATION_STRINGENCY          SILENT \
    --OPTICAL_DUPLICATE_PIXEL_DISTANCE 2500 \
    --ASSUME_SORT_ORDER              queryname \
    --TMP_DIR                        "${tmp_dir}"
rm -f "${tmp_dir}/merged.bam"

# ---------------------------------------------------------------------------
# Step 5: SortSam (coordinate sort)
# ---------------------------------------------------------------------------
log "Step 5/7: SortSam"
"${gatk}" SortSam \
    --java-options "-Xms8g -Xmx16g" \
    --INPUT       "${tmp_dir}/markdup.bam" \
    --OUTPUT      "${tmp_dir}/sorted.bam" \
    --SORT_ORDER  coordinate \
    --TMP_DIR     "${tmp_dir}"
rm -f "${tmp_dir}/markdup.bam"

# ---------------------------------------------------------------------------
# Step 6: SetNmMdAndUqTags — fix NM / MD / UQ tags after coordinate sort
# ---------------------------------------------------------------------------
log "Step 6/7: SetNmMdAndUqTags"
"${gatk}" SetNmMdAndUqTags \
    --java-options "-Xms2g -Xmx4g" \
    --INPUT               "${tmp_dir}/sorted.bam" \
    --OUTPUT              "${tmp_dir}/sorted_fixed.bam" \
    --REFERENCE_SEQUENCE  "${ref_fasta}" \
    --CREATE_INDEX        true \
    --TMP_DIR             "${tmp_dir}"
rm -f "${tmp_dir}/sorted.bam"

# ---------------------------------------------------------------------------
# Step 7a: BaseRecalibrator
# ---------------------------------------------------------------------------
log "Step 7/7: BaseRecalibrator + ApplyBQSR"
mills_arg=""
[[ -n "${mills}" ]] && mills_arg="--known-sites ${mills}"

"${gatk}" BaseRecalibrator \
    --java-options "-Xms4g -Xmx5g" \
    --input        "${tmp_dir}/sorted_fixed.bam" \
    --reference    "${ref_fasta}" \
    --known-sites  "${dbsnp}" \
    ${mills_arg} \
    --output       "${tmp_dir}/recal.table"

# ---------------------------------------------------------------------------
# Step 7b: ApplyBQSR — write final BAM to tmp then rename atomically
# ---------------------------------------------------------------------------
"${gatk}" ApplyBQSR \
    --java-options "-Xms3g -Xmx4g" \
    --input            "${tmp_dir}/sorted_fixed.bam" \
    --reference        "${ref_fasta}" \
    --bqsr-recal-file  "${tmp_dir}/recal.table" \
    --output           "${tmp_dir}/${sample}.bam"

mv "${tmp_dir}/${sample}.bam"     "${final_bam}"
mv "${tmp_dir}/${sample}.bai"     "${final_bam%.bam}.bai" 2>/dev/null || \
mv "${tmp_dir}/${sample}.bam.bai" "${final_bam%.bam}.bai" 2>/dev/null || \
"${gatk}" BuildBamIndex --INPUT "${final_bam}"

log "======================================================"
log "Done: ${final_bam}"
log "======================================================"
