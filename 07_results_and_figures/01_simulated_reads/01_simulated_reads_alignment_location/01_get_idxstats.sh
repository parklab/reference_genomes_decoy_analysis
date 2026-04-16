#!/bin/bash
# Runs samtools idxstats on aligned BAMs of simulated decoy reads across all reference builds.
# Outputs one <reference>.<decoy>.idxstats.txt file per reference per decoy panel.
#
# Usage: bash 01_get_idxstats.sh
# Outputs are written to:
#   $INTERMEDIATE_DIR/simulated_reads_alignment_location/
# (paths defined in config.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../config.sh"

OUTDIR="${INTERMEDIATE_DIR}/simulated_reads_alignment_location"
mkdir -p "${OUTDIR}"

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
        outfile="${OUTDIR}/${ref}.${decoy}.idxstats.txt"
        echo "Running idxstats: ${bam} -> ${outfile}"
        samtools idxstats "${bam}" > "${outfile}"
    done
done

echo "Done. Output written to: ${OUTDIR}"
