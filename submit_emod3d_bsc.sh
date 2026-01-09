#!/bin/bash
# SLURM Wrapper for EMOD3D on BSC (MareNostrum 4)
# Usage:
#   ./submit_emod3d_bsc.sh <job_dir> <nodes> <ntasks> <mem> <time> <defaults_yaml>

set -euo pipefail

# --- Configuration ---
# Point this to where you save the Runner script below
SLURM_TEMPLATE="/gpfs/projects/cant1/scripts/run_emod3d.slurm"
SAFETY_FACTOR=0.85
DEFAULT_ACCOUNT="cant1"

# --- Functions ---
mem_to_mb() {
    local mem_str=$1
    mem_str=${mem_str%[bB]} 
    case ${mem_str: -1} in
        G|g) echo $((${mem_str%?} * 1024)) ;;
        M|m) echo ${mem_str%?} ;;
        T|t) echo $((${mem_str%?} * 1024 * 1024)) ;;
        *)   echo "Error: Invalid memory format '$mem_str'" >&2; exit 1 ;;
    esac
}

calculate_maxmem() {
    awk "BEGIN {printf \"%.0f\", ($1 / $2) * $3}"
}

# --- Main Script ---

if [ "$#" -lt 6 ] || [ "$#" -gt 7 ]; then
  echo "Usage: $0 <job_dir> <nodes> <ntasks> <mem> <time> <defaults_yaml> [enable_restart]"
  echo "Example: ./submit_emod3d_bsc.sh . 2 48 90G 02:00:00 ./emod3d_defaults.yaml"
  exit 1
fi

JOB_DIR=$1
NODES=$2
NTASKS_PER_NODE=$3
MEM_PER_NODE=$4      
WALLTIME=$5
DEFAULTS_ARG=$6
ENABLE_RESTART=${7:-"no"}

# Validate inputs
if [[ ! -f "$DEFAULTS_ARG" ]]; then
    echo "Error: Defaults file '$DEFAULTS_ARG' not found."
    exit 1
fi
export EMOD3D_DEFAULTS=$(realpath "$DEFAULTS_ARG")

echo "→ Changing directory to: $JOB_DIR"
cd "$JOB_DIR" || { echo "Failed to change directory to $JOB_DIR"; exit 1; }

# --- Calculations ---
MEM_MB=$(mem_to_mb "$MEM_PER_NODE")
MAXMEM_MB=$(calculate_maxmem "$MEM_MB" "$NTASKS_PER_NODE" "$SAFETY_FACTOR")

# --- BSC Environment Paths ---
export JOBNAME=$(basename "$PWD")
export MAXMEM="$MAXMEM_MB"
export ENABLE_RESTART="$ENABLE_RESTART"

# Specific paths for account cant1
export EMOD3D_BIN="/gpfs/projects/cant1/EMOD3D/tools/emod3d-mpi_v3.0.8"
export CREATE_E3D_SH="/gpfs/projects/cant1/scripts/create_e3d.sh"

# --- Reporting ---
echo "===================================================================="
echo "Job Configuration (BSC MN5 - cant1):"
echo "  Job Name:        lf.$JOBNAME"
echo "  Nodes:           $NODES"
echo "  Tasks per Node:  $NTASKS_PER_NODE"
echo "  Account:         $DEFAULT_ACCOUNT"
echo "  QOS:             gp_resa"
echo "  MAXMEM:          $MAXMEM_MB MB/core"
echo "  Defaults File:   $EMOD3D_DEFAULTS"
echo "===================================================================="
# --- Submit ---
# Note: --account and --qos are hardcoded here based on your request
sbatch \
  --account="$DEFAULT_ACCOUNT" \
  --qos="gp_resa" \
  --job-name="lf.${JOBNAME}" \
  --nodes="$NODES" \
  --ntasks-per-node="$NTASKS_PER_NODE" \
  --time="$WALLTIME" \
  --output="lf.${JOBNAME}.%j.out" \
  --error="lf.${JOBNAME}.%j.err" \
  --export=ALL,MAXMEM="$MAXMEM",JOBNAME="$JOBNAME",EMOD3D_BIN="$EMOD3D_BIN",CREATE_E3D_SH="$CREATE_E3D_SH",EMOD3D_DEFAULTS="$EMOD3D_DEFAULTS",ENABLE_RESTART="$ENABLE_RESTART" \
  "$SLURM_TEMPLATE"
