# constants.f90

## Overview
This module defines a comprehensive set of global physical and numerical constants used throughout the application. It ensures consistency and provides a central place for these fundamental values.

## Key Components
- **Numerical constants**: Basic mathematical values like `PI`, `TWO`, `SQRT2`, and various epsilon precision values (e.g., `EPS_m6`).
- **Physical constants**: Fundamental physical constants such as Boltzmann constant (`K_BOLTZMAN_SI`), Bohr radius (`BOHR_RADIUS_SI`), and electron mass (`ELECTRONMASS_SI`).
- **Units conversion factors**: Factors for converting between different unit systems, like ElectronVolts to SI (`ELECTRONVOLT_SI`), Angstroms to Atomic Units (`ANGSTROM_AU`), and Rydberg to eV (`RYD`).

## Important Variables/Constants
- `PI = 3.14159265358979323846_dbl`: The mathematical constant Pi.
- `BOHR_RADIUS_SI = 0.529177D-10`: Bohr radius in meters (m).
- `ELECTRONVOLT_SI = 1.6021892D-19`: Electronvolt in Joules (J).
- `RYD = 13.605826d0`: Rydberg energy unit in electronvolts (eV).
- `E2 = 2.d0`: The square of the electron charge in atomic units.
- `K_BOLTZMAN_AU = 3.1667D-6`: Boltzmann constant in Hartree K^-1.

## Usage Examples
The constants in this module are made available in other Fortran modules or programs by adding a `USE constants` statement.

```fortran
PROGRAM example_usage
  USE kinds
  USE constants
  IMPLICIT NONE

  REAL(dbl) :: radius_in_angstroms
  REAL(dbl) :: energy_in_ev

  radius_in_angstroms = BOHR_RADIUS_ANGS  ! Bohr radius directly in Angstroms
  energy_in_ev = 2.0_dbl * RYD            ! Energy of 2 Rydberg in eV

  PRINT *, "Bohr radius in Angstroms: ", radius_in_angstroms
  PRINT *, "2 Rydbergs in eV: ", energy_in_ev

END PROGRAM example_usage
```

## Dependencies and Interactions
This module uses the `kinds` module to define the precision of the constants (e.g., `dbl`). It is expected to be a foundational module, used by a vast majority of other modules in the quantum chemistry software that require physical or numerical constants.
