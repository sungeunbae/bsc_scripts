#!/bin/bash
#SBATCH --exclusive
#SBATCH --account=cant1
#SBATCH --qos=gp_resa
#SBATCH --output=%x.%j.out
#SBATCH --error=%x.%j.err
# Note: Removed --constraint=high (invalid on MN5)

set -u
# --- 1. CRITICAL STABILITY FIXES ---
# Fix 1: Prevent segmentation faults during large file I/O (velocity model reading)
ulimit -s unlimited

# Fix 2: Prevent conflict between SLURM and OpenMPI binding
# Required on MN5 when using mpirun
export SLURM_CPU_BIND=none

echo "========================================================"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Running on nodes: $SLURM_JOB_NODELIST"
echo "Date: $(date)"
echo "========================================================"

SCRIPTS=/gpfs/projects/cant1/scripts/
BINDIR=/gpfs/projects/cant1/EMOD3D/tools

# --- 1. Load Modules (MN5 Specific) ---
# We source your custom script to ensure correct OpenMPI/GCC setup
if [[ -f "$SCRIPTS/mymodules.sh" ]]; then
    source "$SCRIPTS/mymodules.sh"
else
    echo "Warning: $SCRIPTS/mymodules.sh not found, loading defaults"
    exit -1
fi
module list

# --- 2. Set Working Directory ---
cd "$SLURM_SUBMIT_DIR" || exit 1

REL_DIR="$PWD"
mkdir -p "$REL_DIR/LF"

# --- 3. Setup Environment Variables ---
MAXMEM=${MAXMEM:-2500}
EMOD3D_BIN=${EMOD3D_BIN:-"$BINDIR/emod3d-mpi_v3.0.8"}
CREATE_E3D_SH=${CREATE_E3D_SH:-"$SCRIPTS/create_e3d.sh"}

# IMPORTANT: Get the total number of tasks derived from SLURM
# This ensures e3d.par matches the actual run size.
export N_PROC=$SLURM_NTASKS

# --- 4. E3D Generation ---
OUTPUT_PAR="$REL_DIR/LF/e3d.par"

if [[ ! -f "$OUTPUT_PAR" ]]; then
  echo "e3d.par not found, generating..."
  
  if [[ -z "${EMOD3D_DEFAULTS:-}" ]]; then
      echo "Error: EMOD3D_DEFAULTS env var not set (check submit script)"
      exit 1
  fi
 
  # Pass N_PROC implicitly via export
  "${CREATE_E3D_SH}" "$REL_DIR" "$OUTPUT_PAR" "$EMOD3D_DEFAULTS"
fi

# Update MAXMEM in par file
sed -i "s/^maxmem=.*/maxmem=$MAXMEM/" "$OUTPUT_PAR"

# --- 5. Restart Logic ---
ENABLE_RESTART=${ENABLE_RESTART:-"yes"}

if [[ "${ENABLE_RESTART,,}" == "no" ]]; then
    sed -i 's/^enable_restart=.*/enable_restart=0/' "$OUTPUT_PAR"
    sed -i 's/^read_restart=.*/read_restart=0/' "$OUTPUT_PAR"
else
    NT=$(awk -F= '/^nt=/ {print $2}' "$OUTPUT_PAR" || echo 0)
    if [[ -d "$REL_DIR/LF/Restart" ]] && [[ $(ls -1 "$REL_DIR/LF/Restart" | wc -l) -gt 0 ]]; then
      echo "Checkpoint found -> resuming"
      sed -i 's/read_restart=.*/read_restart="1"/' "$OUTPUT_PAR"
    else
      RESTART_ITINC=$(( (NT / 5 + 50) / 100 * 100 ))
      sed -i "s/restart_itinc=.*/restart_itinc=$RESTART_ITINC/" "$OUTPUT_PAR"
    fi
fi

# --- 6. Execution ---
start_time=$(date +%Y-%m-%d_%H:%M:%S)
start_epoch=$(date +%s)
echo "Starting simulation at $start_time with $N_PROC tasks"

# This forces OpenMPI to use TCP (slow but rock-stable) instead of Infiniband/UCX.
# Diagnostic Mode: Forces TCP (Ethernet) to bypass UCX/Infiniband issues
#mpirun --mca pml ob1 --mca btl self,vader,tcp -np $N_PROC "$EMOD3D_BIN" -args "par=$OUTPUT_PAR"
mpirun -np $N_PROC "$EMOD3D_BIN" -args "par=$OUTPUT_PAR"
#srun "$EMOD3D_BIN" -args "par=$OUTPUT_PAR"
EXIT_CODE=$?

end_time=$(date +%Y-%m-%d_%H:%M:%S)
end_epoch=$(date +%s)
runtime_seconds=$((end_epoch - start_epoch))

printf "Total runtime: %02d:%02d:%02d\n" $((runtime_seconds/3600)) $((runtime_seconds%3600/60)) $((runtime_seconds%60))

# Link output for verification
mkdir -p "$REL_DIR/LF/OutBin"
ln -sf "$OUTPUT_PAR" "$REL_DIR/LF/OutBin/e3d.par" || true

if [ $EXIT_CODE -eq 0 ]; then
    echo "EMOD3D finished successfully."
else
    echo "EMOD3D failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi
