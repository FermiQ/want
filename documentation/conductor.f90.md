# conductor.f90

## Overview
This program, `conductor`, calculates the quantum transmittance and conductance across a nanoelectronic junction. It likely employs Green's function-based methods (e.g., Non-Equilibrium Green's Functions - NEGF) to determine transport properties as a function of energy and k-points. The calculation involves setting up the Hamiltonian for the system, computing self-energies for the leads, and then calculating the Green's function for the central conductor region to derive transport characteristics.

## Key Components
- **PROGRAM `conductor`**: The main executable. It orchestrates the entire calculation by:
    - Initializing modules for versioning, I/O, timing, logging.
    - Calling `input_manager()` (from `T_input_module`) to read user-defined parameters.
    - Initializing various components: data files (`datafiles_init`), smearing parameters (`smearing_init`), k-points grid (`kpoints_init`), Hamiltonian (`hamiltonian_init`), correlation effects (`correlation_init` if `lhave_corr` is true), and the energy grid (`egrid_init`).
    - Printing a summary of input parameters.
    - Calling the core computational subroutine `do_conductor()`.
    - Cleaning up allocated resources and finalizing the execution.

- **SUBROUTINE `do_conductor()`**: This is the heart of the transport calculation. Its primary responsibilities include:
    - Allocating workspace arrays for matrices and results.
    - Looping over a defined energy grid (`energy_loop`).
        - Optionally reading pre-computed correlation self-energies.
        - Looping over a set of k-points for Brillouin zone integration (`kpt_loop`).
            - Setting up the Hamiltonian components for the current energy and k-point (`hamiltonian_setup`).
            - Calculating lead self-energies (`sgm_L`, `sgm_R`) using routines like `transfer_mtrx` and `green`.
            - Constructing the retarded Green's function (`gC`) for the conductor region, incorporating the lead self-energies.
            - Calculating the Density of States (DOS) for the conductor.
            - Computing the coupling matrices (`gamma_L`, `gamma_R`).
            - Calculating the transmittance using the `transmittance` subroutine/module, potentially resolving eigenchannels.
            - Accumulating results for DOS and conductance.
    - Summing results across MPI processes if run in parallel.
    - Writing out final and k-point resolved data (conductance, DOS) using `T_write_data_module` and custom file operations.

- **Key Modules Used**:
    - `T_input_module`: Manages reading and processing of input parameters.
    - `T_control_module`: Provides run-time control flags and parameters (e.g., `conduct_formula`, `nprint`, `write_kdata`, `do_eigenchannels`).
    - `T_hamiltonian_module`: Defines, stores, and sets up the Hamiltonian matrices for the leads and the central conductor region (e.g., `blc_00L`, `blc_01R`, `blc_LC`).
    - `T_egrid_module`: Defines and manages the energy grid over which calculations are performed.
    - `T_kpoints_module`: Defines and manages the k-point grid used for Brillouin zone integration.
    - `T_correlation_module`: Handles the inclusion of correlation effects (self-energies) if specified.
    - `T_write_data_module`: Provides routines for writing formatted output data (e.g., `wd_write_data`).
    - `transmittance` (subroutine/module): Contains the core logic to calculate transmittance, likely using the Fisher-Lee formula or a generalized version, from the Green's functions and coupling matrices.
    - `T_workspace_module`: Manages allocation and deallocation of large work arrays.
    - `T_smearing_module`: Initializes parameters for energy smearing.
    - `files_module`, `io_module`: Handle file operations and I/O management.
    - `timing_module`, `log_module`: Provide utilities for performance timing and logging.
    - `mp_global`, `mp`: Support for MPI-based parallel execution.
    - `operator_module`, `T_operator_blc_module`: Likely used for handling matrix operations related to physical operators and their block structures.

## Important Variables/Constants
- Control parameters (typically from `T_control_module`):
    - `conduct_formula`: String specifying the formula/method for conductance calculation (e.g., Fisher-Lee).
    - `nprint`: Integer controlling the frequency of printing progress information to standard output.
    - `write_kdata`: Logical flag; if true, k-point resolved conductance and DOS data are written to separate files.
    - `write_lead_sgm`: Logical flag; if true, lead self-energies are written out.
    - `write_gf`: Logical flag; if true, the conductor's Green's function is written out.
    - `do_eigenchannels`: Logical flag to enable eigenchannel analysis.
    - `neigchn`, `neigchnx`: Integers controlling the number of eigenchannels to calculate/store.
- Key arrays computed in `do_conductor()`:
    - `conduct(1+neigchn, ne)`: Stores the total conductance and eigenchannel contributions at each energy point.
    - `dos(ne)`: Stores the Density of States at each energy point.
    - `conduct_k(1+neigchn, nkpts_par, ne)`: Stores k-point resolved conductance.
    - `dos_k(ne, nkpts_par)`: Stores k-point resolved DOS.
- Hamiltonian and system dimensions (typically from `T_hamiltonian_module`):
    - `dimL`, `dimR`, `dimC`: Dimensions of the left lead, right lead, and conductor part of the basis.
    - `blc_00L`, `blc_01L`, `blc_00R`, `blc_01R`, `blc_00C`, `blc_LC`, `blc_CR`: Arrays/structures holding blocks of the Hamiltonian matrix.

## Usage Examples
The `conductor` program is a command-line executable. It requires a primary input file (often named with a `.in` extension or similar) that defines the physical system, calculation parameters, and paths to other necessary data files (like those defining the Hamiltonian).

```bash
# Example of how conductor might be run from the shell:
# (The exact command can vary based on the specific build and environment)
./conductor < conductor_input.in > conductor_output.log
```
The input parameters specified in `conductor_input.in` are parsed by routines within `T_input_module`. The program then typically generates various output files, including a main log file (redirected above), and data files containing conductance, DOS, and potentially k-resolved data or eigenchannel information as specified by the input.

## Dependencies and Interactions
- **Core Algorithmic Dependencies**: The program relies on modules providing Hamiltonian construction (`T_hamiltonian_module`), energy grid setup (`T_egrid_module`), k-point integration (`T_kpoints_module`), and routines to perform matrix operations, Green's function calculations (`gzero_maker`, `mat_inv`), self-energy calculations (`transfer_mtrx`, `green`), and transmittance evaluation (`transmittance`).
- **Workflow**:
    1.  The `conductor` program initializes the environment, reads inputs via `T_input_module`, and sets up various data structures.
    2.  It calls `do_conductor()`, which is the main computational engine.
    3.  `do_conductor()` iterates over energies and k-points. In each iteration:
        a.  It sets up the Hamiltonian for the specific (E, k) point using `T_hamiltonian_module`.
        b.  It computes the self-energies for the left and right leads.
        c.  It constructs the Green's function for the central conductor region, embedding the lead self-energies.
        d.  It calculates the DOS and then the transmittance using the Green's function and coupling matrices (Gamma_L, Gamma_R), derived from the self-energies. Eigenchannel analysis may also be performed.
    4.  Results are accumulated and, if running in parallel, aggregated using MPI routines (`mp_sum`).
    5.  Finally, `T_write_data_module` and other I/O routines are used to write the calculated conductance, DOS, and other requested data to output files.
- **Parallelism**: The code uses MPI (`mp` module) for parallelism, primarily by distributing the energy loop (`divide_et_impera`) across different processes.
- **File I/O**: Extensive use of `io_module` and `files_module` for reading input files (Hamiltonian, parameters) and writing output data (conductance, DOS, logs, optional detailed outputs like self-energies or Green's functions). Files are often named using a `prefix` and `postfix` defined in the input.
