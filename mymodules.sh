module purge

module load bsc/1.0
# --- 1. Low-Level Transport (Fixes Remote Op Errors) ---
# Use the GCC version to avoid Intel conflicts.
# 1.16.0 is newer, so we try that first.
module load ucx/1.16.0-gcc

# --- 2. The Foundation ---
module load openmpi/4.1.5-gcc

# --- 3. I/O Dependencies ---
module load hdf5/1.14.1-2-gcc-openmpi
module load pnetcdf/1.12.3-gcc-openmpi

# --- 4. The Big Bundle ---
module load netcdf/c-4.9.2_fortran-4.6.1_cxx4-4.3.1_hdf5-1.14.1-2_pnetcdf-1.12.3-gcc-openmpi

# --- 5. Math Libraries ---
module load fftw/3.3.10-gcc-ompi
module load mkl

# --- 6. Utilities ---
module load python/3.12.1-gcc
module load cmake


# Python virtual environment
source /gpfs/projects/cant1/venv/py312gcc/bin/activate

