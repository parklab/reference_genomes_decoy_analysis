#!/bin/bash
# extract_decoy_reads_sample.sh — Extract decoy-origin reads for one sample × decoy.
#
# Called by 01_extract_decoy_reads.sh via sbatch — not run directly.
#
# Step 1: Find reads that mapped to decoy contigs (mapped, optionally MAPQ-filtered)
#         in the decoy-containing reference BAM → write read names to a text file.
# Step 2: For each of the 7 reference BAMs, extract those reads by name
#         → write an indexed BAM per reference.
#         No MAPQ filter is applied in Step 2 so downstream analysis scripts
#         can impose their own thresholds.
#
# Arguments:
#   1: sample          — sample name (e.g. HG00419)
#   2: decoy           — "hs37d5" or "hs38d1"
#   3: src_bam         — BAM aligned to decoy-containing reference
#   4: decoy_out_dir   — output root: read_names/ and <ref>/ subdirs go here
#   5: kgsamples_dir   — aligned BAMs root: <dir>/<sample>/aligned/<ref>/<sample>.bam
#   6: hs38d1_contigs  — file listing hs38d1 contig names (one per line)
#   7: mapq            — minimum MAPQ for Step 1 (optional; empty = no filter)
#
# Outputs:
#   <decoy_out_dir>/read_names/<sample>.<decoy>.read_names.txt
#   <decoy_out_dir>/<ref>/<sample>.<decoy>_decoy_reads.<ref>.bam  (+ .bai)
#
#SBATCH --time=0-02:00:00
#SBATCH --mem=8000
#SBATCH -c 1
#SBATCH --mail-type=FAIL

set -euo pipefail

sample=$1
decoy=$2
src_bam=$3
decoy_out_dir=$4
kgsamples_dir=$5
hs38d1_contigs=$6
mapq=${7:-}          # optional; empty string = no MAPQ filter

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }
trap 'log "ERROR at line ${LINENO}: ${BASH_COMMAND}"' ERR

REFS=(b37 grch37 grch37d5 grch38_no_alt grch38_no_alt_plus_decoy hg38_gatk t2t)

read_names="${decoy_out_dir}/read_names/${sample}.${decoy}.read_names.txt"
mkdir -p "${decoy_out_dir}/read_names"

# Build samtools MAPQ flag: "-q <N>" if set, empty string otherwise
mapq_flag=""
[[ -n "${mapq}" ]] && mapq_flag="-q ${mapq}"

log "========================================================"
log "sample    : ${sample}"
log "decoy     : ${decoy}"
log "src_bam   : ${src_bam}"
log "MAPQ      : ${mapq:-none (mapped reads only)}"
log "output    : ${decoy_out_dir}"
log "========================================================"

tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT

# ---------------------------------------------------------------------------
# Step 1: Extract read names of reads mapping to decoy contigs
# ---------------------------------------------------------------------------
log "Step 1/2: extracting read names from ${decoy} contigs"

if [[ "${decoy}" == "hs37d5" ]]; then
    # Two named contigs in grch37d5: the hs37d5 sequence and EBV (NC_007605)
    # shellcheck disable=SC2086
    samtools view -F 4 ${mapq_flag} "${src_bam}" hs37d5 NC_007605 \
        | awk '{print $1}' \
        | sort -u \
        > "${read_names}"

else
    # hs38d1 decoy: 2385 contigs (JTFH*, KN*, etc.)
    # Build a BED from the BAM header filtered to contigs in the hs38d1 list,
    # then use samtools view -L to restrict to those regions.
    awk 'NR==FNR {
             contigs[$1] = 1; next
         }
         /^@SQ/ {
             sn = ""; ln = ""
             for (i = 1; i <= NF; i++) {
                 if ($i ~ /^SN:/) { sn = substr($i, 4) }
                 if ($i ~ /^LN:/) { ln = substr($i, 4) }
             }
             if (sn in contigs) print sn "\t0\t" ln
         }' \
        "${hs38d1_contigs}" \
        <(samtools view -H "${src_bam}") \
        > "${tmp_dir}/decoy_regions.bed"

    n_regions=$(wc -l < "${tmp_dir}/decoy_regions.bed")
    log "  ${n_regions} of $(wc -l < "${hs38d1_contigs}") hs38d1 contigs found in BAM header"

    if [[ "${n_regions}" -eq 0 ]]; then
        log "WARNING: no matching contigs found — check contig names match BAM header"
        touch "${read_names}"
    else
        # shellcheck disable=SC2086
        samtools view -F 4 ${mapq_flag} -L "${tmp_dir}/decoy_regions.bed" "${src_bam}" \
            | awk '{print $1}' \
            | sort -u \
            > "${read_names}"
    fi
fi

n_reads=$(wc -l < "${read_names}")
log "  ${n_reads} unique read names → ${read_names}"
[[ "${n_reads}" -eq 0 ]] && log "WARNING: 0 decoy read names found — downstream BAMs will be empty"

# ---------------------------------------------------------------------------
# Step 2: Extract those reads by name from each reference BAM (no MAPQ filter)
# ---------------------------------------------------------------------------
log "Step 2/2: finding decoy reads in ${#REFS[@]} reference BAMs"

for ref in "${REFS[@]}"; do
    in_bam="${kgsamples_dir}/${sample}/aligned/${ref}/${sample}.bam"
    out_dir="${decoy_out_dir}/${ref}"
    out_bam="${out_dir}/${sample}.${decoy}_decoy_reads.${ref}.bam"

    mkdir -p "${out_dir}"

    if [[ ! -f "${in_bam}" ]]; then
        log "  SKIP ${ref}: BAM not found"
        continue
    fi

    log "  ${ref}..."
    samtools view -b -h -N "${read_names}" "${in_bam}" > "${out_bam}"
    samtools index "${out_bam}"
    n_extracted=$(samtools view -c "${out_bam}")
    log "  ${ref}: ${n_extracted} reads → $(basename ${out_bam})"
done

log "========================================================"
log "Done: ${sample} × ${decoy}"
log "========================================================"
