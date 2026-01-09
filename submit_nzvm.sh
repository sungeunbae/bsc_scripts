#!/bin/bash

# ==============================================================================
# NZVM Job Submitter for BSC MN5 (GPP)
# Usage: ./submit_nzvm.sh path/to/nzvm.cfg [walltime]
# Example: ./submit_nzvm.sh ./nzvm.cfg 00:30:00
# ==============================================================================

CONFIG_FILE="$1"
WALLTIME="${2:-00:30:00}"  # Default to 30 mins if not provided
ACCOUNT="cant1"

# --- 1. Validation ---
if [[ -z "$CONFIG_FILE" ]]; then
    echo "Usage: $0 <config_file> [walltime]"
    echo "Example: $0 nzvm.cfg 01:00:00"
    exit 1
fi

# Get absolute path of config to be safe
if [[ -f "$CONFIG_FILE" ]]; then
    CONFIG_PATH=$(readlink -f "$CONFIG_FILE")
    CONFIG_DIR=$(dirname "$CONFIG_PATH")
    CONFIG_NAME=$(basename "$CONFIG_PATH")
else
    echo "Error: Configuration file '$CONFIG_FILE' not found."
    exit 1
fi

# --- 2. Resources ---
# MN5 GPP Standard Node: 112 Cores.
# We use 56 cores (1 socket) for OpenMP efficiency.
PARTITION="gpp"
QOS="gp_debug"  # Change to gp_normal for longer runs
CPUS=56

# --- 3. Submit to Slurm ---
# We use a Here-Doc to pass the script directly to sbatch
JOB_ID=$(sbatch --parsable \
    --account="$ACCOUNT" \
    --job-name="nzvm_${CONFIG_NAME}" \
    --partition="$PARTITION" \
    --qos="$QOS" \
    --nodes=1 \
    --ntasks=1 \
    --cpus-per-task="$CPUS" \
    --time="$WALLTIME" \
    --output="${CONFIG_DIR}/nzvm_%j.out" \
    --error="${CONFIG_DIR}/nzvm_%j.err" \
    <<EOF
#!/bin/bash
set -e

# --- A. Setup Environment ---
if [[ -f "\$PROJECT/scripts/mymodules.sh" ]]; then
    source "\$PROJECT/scripts/mymodules.sh"
else
    echo "Error: mymodules.sh not found!"
    exit 1
fi

# --- B. Critical Fixes ---
ulimit -s unlimited

# --- C. OpenMP Settings ---
export OMP_NUM_THREADS=$CPUS
export OMP_PROC_BIND=true
export OMP_PLACES=cores

# --- D. Execution ---
cd "$CONFIG_DIR"
echo "Starting NZVM generation for $CONFIG_NAME"
echo "Running on node: \$(hostname)"
echo "Threads: \$OMP_NUM_THREADS"

cd "$PROJECT/Velocity-Model"
"./NZVM" "$CONFIG_PATH"

cd -

echo "------------------------------------------------"
echo "Finished. Checking generated files..."
ls -lh *.p *.s *.d *.b 2>/dev/null || echo "Warning: Output files missing."
EOF
)

# --- 4. User Feedback ---
if [[ -n "$JOB_ID" ]]; then
    echo "Submitted NZVM job: $JOB_ID"
    echo "   Config: $CONFIG_PATH"
    echo "   Output: ${CONFIG_DIR}/nzvm_${JOB_ID}.out"
else
    echo "Submission failed."
fi
