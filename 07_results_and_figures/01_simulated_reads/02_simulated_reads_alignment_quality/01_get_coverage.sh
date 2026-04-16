#!/bin/bash
# Computes coverage (number of bases with depth > 0) within primary-chromosome
# BED regions at eight MAPQ thresholds (0, 3, 10, 20, 30, 40, 50, 60) for each
# reference build.
#
# Reads BAMs from:
#   <DECOY_SIM_DIR>/<decoy>/aligned/<ref>/<decoy>.bam
# BED files from:
#   <BED_DIR>/<ref>.bed
# (both paths defined in config.sh)
#
# Output: one comma-separated file per reference per decoy panel, written to:
#   $INTERMEDIATE_DIR/simulated_reads_alignment_quality/
# Named <ref>.<decoy>.txt; each row: <MAPQ_threshold>,<covered_base_count>
#
# Usage: bash 01_get_coverage.sh
# Requires: samtools

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../config.sh"

OUTDIR="${INTERMEDIATE_DIR}/simulated_reads_alignment_quality"
mkdir -p "${OUTDIR}"

MAPQ_THRESHOLDS=(0 3 10 20 30 40 50 60)

for decoy in hs37d5 hs38d1; do
    aligned_dir="${DECOY_SIM_DIR}/${decoy}/aligned"
    if [[ ! -d "${aligned_dir}" ]]; then
        echo "WARNING: aligned directory not found: ${aligned_dir}" >&2
        continue
    fi
    for ref_dir in "${aligned_dir}"/*/; do
        ref=$(basename "${ref_dir}")
        [[ "${ref}" == "ubam" ]] && continue
        bam="${ref_dir}${decoy}.bam"
        if [[ ! -f "${bam}" ]]; then
            echo "WARNING: BAM not found: ${bam}" >&2
            continue
        fi
        bed="${BED_DIR}/${ref}.bed"
        if [[ ! -f "${bed}" ]]; then
            echo "WARNING: BED file not found for '${ref}', skipping: ${bed}" >&2
            continue
        fi
        outfile="${OUTDIR}/${ref}.${decoy}.txt"
        echo "Processing: ${bam} -> ${outfile}"
        > "${outfile}"
        for q in "${MAPQ_THRESHOLDS[@]}"; do
            samtools view -bh -q "${q}" "${bam}" \
                | samtools depth - -b "${bed}" \
                | awk -v q="${q}" 'BEGIN {count=0} $3 > 0 {count++} END {print q "," count}' \
                >> "${outfile}"
        done
    done
done

echo "Done. Output written to: ${OUTDIR}"
