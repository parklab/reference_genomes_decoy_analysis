#!/usr/bin/env python3
"""
Parse samtools idxstats output files and compute per-category alignment percentages.

Processes both hs37d5 and hs38d1 decoy panels in a single run, outputting
one CSV per panel ready for plotting (no post-processing needed).

Categories assigned to match the final figure:
  - chr1–22, X, Y, M (exact names only)  ->  "Main chromosomes"
  - hs37d5, JTFH/KN/.*decoy contigs, EBV ->  "Decoy sequence"
  - chrUn_*, GL*, *_random, *_alt, HLA   ->  "Unplaced sequence"
  - unmapped column + * sentinel row     ->  "Unmapped"

  re.fullmatch is used throughout so that contig names like
  "chr1_KI270706v1_random" are NOT matched by the "chr1" pattern and
  are correctly classified as Unplaced sequence (not Main chromosomes).
  Decoy patterns are tested before Unplaced patterns, so any
  chrUn_*_decoy contig is caught by Decoy first.

Usage:
    python3 02_parse_idxstats.py [idxstats_dir [output_dir]]

    idxstats_dir: directory containing *.idxstats.txt files
                  (default: results/intermediate/simulated_reads_alignment_location)
    output_dir:   directory where CSVs are written (default: same as idxstats_dir)

Output:
    panel_hs37d5.csv  -- percentages for reads mapped against hs37d5 decoy reference
    panel_hs38d1.csv  -- percentages for reads mapped against hs38d1 decoy reference

CSV columns: sample, category, percent
"""

import re
import csv
import glob
import os
import sys

# Default paths derived from this script's location (3 levels up = repo root).
_REPO_ROOT    = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../.."))
_DEFAULT_DATA = os.path.join(_REPO_ROOT, "results", "intermediate", "simulated_reads_alignment_location")


# Internal classification of contigs.
# re.fullmatch is used, so "chr1" only matches the contig named exactly "chr1",
# not "chr1_KI270706v1_random" etc.
# Dict order matters: Decoy is checked before Unplaced, so any chrUn_*_decoy
# contig is caught by the ".*decoy" Decoy pattern first.
_CONTIG_CATEGORIES = {
    "Main chromosomes":  (["chr{}".format(i) for i in range(1, 23)]
                        + ["{}".format(i) for i in range(1, 23)]
                        + ["chrX", "chrY", "X", "Y", "chrM", "chrMT", "M", "MT"]),
    "Decoy sequence":    ["hs37d5", "JTFH.*", "KN.*", ".*decoy",
                          "chrEBV", "chrNC_007605", "NC_007605"],
    "Unplaced sequence": ["chrUn_.*", "GL.*", ".*random", ".*alt", "HLA.*"],
    "Unmapped":          [],   # populated from the unmapped column
}

# Categories written to the output CSV, in plot order.
OUTPUT_CATEGORIES = ["Main chromosomes", "Unplaced sequence", "Decoy sequence", "Unmapped"]

# Maps the filename prefix (reference directory name) to its display label.
# grch37d5 must precede grch37, and grch38_no_alt_plus_decoy must precede
# grch38_no_alt, to avoid prefix collisions during lookup.
NAME_MAP = {
    "grch37":                   "GRCh37",
    "b37":                      "GATK b37",
    "grch37d5":                 "GRCh37d5",
    "grch38_no_alt":            "GRCh38",
    "hg38_gatk":                "GATK hg38",
    "grch38_no_alt_plus_decoy": "GRCh38d1",
    "t2t":                      "T2T",
}

# Sample processing order (also the plot order enforced by the R factor levels).
SAMPLE_ORDER = ["grch37", "b37", "grch37d5", "grch38_no_alt", "hg38_gatk", "grch38_no_alt_plus_decoy", "t2t"]


def classify_contig(contig):
    if contig == "*":
        return "Unmapped"   # samtools idxstats last-line sentinel for unplaced unmapped reads
    for category, patterns in _CONTIG_CATEGORIES.items():
        if category == "Unmapped":
            continue
        for pattern in patterns:
            if re.fullmatch(pattern, contig):
                return category
    return None


def parse_idxstats(filepath):
    counts = {cat: 0 for cat in _CONTIG_CATEGORIES}
    with open(filepath) as fh:
        for line in fh:
            fields = line.strip().split('\t')
            if len(fields) != 4:
                continue
            contig = fields[0].strip()
            mapped = int(fields[2])
            unmapped = int(fields[3])
            category = classify_contig(contig)
            if category is None:
                print(f"WARNING: unclassified contig '{contig}' in {filepath}", file=sys.stderr)
            else:
                counts[category] += mapped
            counts["Unmapped"] += unmapped
    return counts


def counts_to_output_percents(counts):
    total = sum(counts.values())
    if total == 0:
        return {cat: 0.0 for cat in OUTPUT_CATEGORIES}
    return {cat: counts[cat] / total * 100 for cat in OUTPUT_CATEGORIES}


def get_sample_name(filepath):
    prefix = os.path.basename(filepath).split(".")[0]
    if prefix not in NAME_MAP:
        raise ValueError(f"Unrecognized reference prefix '{prefix}' in filename: {filepath}")
    return NAME_MAP[prefix]


def process_panel(filepaths, output_csv):
    if not filepaths:
        print(f"WARNING: no files found for {output_csv}", file=sys.stderr)
        return

    with open(output_csv, 'w', newline='') as f:
        writer = csv.writer(f)
        for filepath in filepaths:
            sample = get_sample_name(filepath)
            counts = parse_idxstats(filepath)
            percents = counts_to_output_percents(counts)
            for category, pct in percents.items():
                writer.writerow([sample, category, f"{pct:.6f}"])

    print(f"Written: {output_csv}")


if __name__ == "__main__":
    data_dir   = sys.argv[1] if len(sys.argv) > 1 else _DEFAULT_DATA
    output_dir = sys.argv[2] if len(sys.argv) > 2 else data_dir
    os.makedirs(output_dir, exist_ok=True)

    for suffix, csv_name in [("hs37d5", "panel_hs37d5.csv"), ("hs38d1", "panel_hs38d1.csv")]:
        pattern = os.path.join(data_dir, f"*.{suffix}.idxstats.txt")
        found = {os.path.basename(f).split(".")[0]: f for f in glob.glob(pattern)}
        ordered = [found[s] for s in SAMPLE_ORDER if s in found]
        missing = [s for s in SAMPLE_ORDER if s not in found]
        if missing:
            print(f"WARNING: missing idxstats files for: {missing}", file=sys.stderr)
        process_panel(ordered, os.path.join(output_dir, csv_name))
