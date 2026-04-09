#!/bin/bash
# 00_install_ART.sh — Download and install ART MountRainier (v2.5.8) to tools/ART/.
#
# If ART_ILLUMINA in config.sh already points to an executable binary, this
# script exits immediately — nothing to do.
#
# Otherwise, two installation methods are tried in order:
#   1. Conda  — installs art_illumina into the active conda environment.
#   2. Direct download — fetches the Linux 64-bit binary tarball from NIEHS
#      and extracts it to ART_DIR (default: tools/ART/ inside the repo root).
#
# On success, ART_ILLUMINA in config.sh is updated automatically.
#
# Usage: bash 00_install_ART.sh
# Requires: conda (method 1) OR wget + tar (method 2)
#
# Reference: Huang W, Li L, Myers JR, Marth GT (2012). ART: a next-generation
# sequencing read simulator. Bioinformatics 28(4):593-594.
# https://doi.org/10.1093/bioinformatics/btr708

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
source "${SCRIPT_DIR}/../config.sh"

# ---------------------------------------------------------------------------
# Logging — stored with the tool; softlink from script directory for convenience
# ---------------------------------------------------------------------------
LOG_DIR="${ART_DIR}/logs"
mkdir -p "$LOG_DIR"
if [[ ! -L "${SCRIPT_DIR}/logs_ART_install" ]]; then
    ln -s "${LOG_DIR}" "${SCRIPT_DIR}/logs_ART_install"
fi
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.sh}_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*"; }
trap 'log "ERROR: command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

log "======================================================"
log "${SCRIPT_NAME} started"
log "Script   : ${SCRIPT_DIR}/${SCRIPT_NAME}"
log "Log file : $LOG_FILE"
log "Repo root: $REPO_ROOT"
log "ART_ILLUMINA (config): $ART_ILLUMINA"
log "ART_DIR  (config): $ART_DIR"
log "======================================================"

# ---------------------------------------------------------------------------
# Early exit if already installed
# ---------------------------------------------------------------------------
if [[ -x "$ART_ILLUMINA" ]]; then
    log "ART already installed and executable: $ART_ILLUMINA"
    log "Nothing to do. To reinstall, remove the binary or clear ART_ILLUMINA in config.sh."
    exit 0
fi

log "ART_ILLUMINA not found or not executable — proceeding with installation."
mkdir -p "$ART_DIR"

# ---------------------------------------------------------------------------
# Method 1: conda
# ---------------------------------------------------------------------------
ART_BIN=""
if command -v conda &>/dev/null || command -v mamba &>/dev/null; then
    CONDA_CMD="conda"
    command -v mamba &>/dev/null && CONDA_CMD="mamba"

    log "Conda found ($CONDA_CMD). Trying to install art from bioconda..."
    if ${CONDA_CMD} install -y bioconda::art; then
        ART_BIN="$(command -v art_illumina)"
        log "Conda installation complete: $ART_BIN"
    else
        log "Conda install failed (version unavailable or environment conflict). Falling back to direct download."
    fi
fi

# ---------------------------------------------------------------------------
# Method 2: direct download of the Linux 64-bit binary tarball from NIEHS
# ---------------------------------------------------------------------------
if [[ -z "$ART_BIN" ]]; then
    log "Conda not found. Attempting direct download from NIEHS..."

    # If NIEHS changes the URL, download the tarball manually, place it at
    # ${ART_DIR}/art_bin_MountRainier_Linux.tgz, and re-run — the download
    # will be skipped and extraction will proceed from the cached file.
    ART_TARBALL="${ART_DIR}/art_bin_MountRainier_Linux.tgz"
    ART_URL="https://www.niehs.nih.gov/research/resources/assets/docs/artbinmountrainierlinux64tgz.cfm"

    if [[ -f "$ART_TARBALL" ]]; then
        log "Tarball already present, skipping download: $ART_TARBALL"
    else
        log "Downloading: $ART_URL"
        wget -q --show-progress --content-disposition \
            -O "${ART_TARBALL}.tmp" "$ART_URL" 2>>"$LOG_FILE"
        echo "" >> "$LOG_FILE"
        mv "${ART_TARBALL}.tmp" "$ART_TARBALL"
        log "Saved: $ART_TARBALL"
    fi

    log "Extracting tarball to $ART_DIR ..."
    tar -xzf "$ART_TARBALL" -C "$ART_DIR" --strip-components=1
    chmod +x "${ART_DIR}/art_illumina"

    ART_BIN="${ART_DIR}/art_illumina"
    log "Direct download installation complete: $ART_BIN"
fi  # end direct download

if [[ -z "$ART_BIN" ]]; then
    log "ERROR: all installation methods failed."
    exit 1
fi

# ---------------------------------------------------------------------------
# Update config.sh
# ---------------------------------------------------------------------------
sed -i "s|^ART_ILLUMINA=.*|ART_ILLUMINA=\"${ART_BIN}\"|" "${SCRIPT_DIR}/../config.sh"
log "config.sh updated: ART_ILLUMINA=\"${ART_BIN}\""

log "======================================================"
log "${SCRIPT_NAME} completed successfully"
log "Log written to: $LOG_FILE"
log "======================================================"
