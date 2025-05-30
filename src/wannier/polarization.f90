! 
! Copyright (C) 2005 WanT Group
!
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!*****************************************************
   SUBROUTINE polarization( dimwann, rave )
   !*****************************************************
   !    
   ! Evaluates the spontanueus polarization according to
   ! the computed WFs.
   ! The implemented formulas are:
   !
   ! P_el (:) = 2e/Omega * \sum_{m} <r>_m(:)
   ! P_ion(:) =  e/Omega * \sum_{I} Z_I * tau_I(:) 
   !
   ! P_tot(:) = P_ion - P_el
   !
   ! Constants are set for the case nspin ==1, otherwise a 1/nspin
   ! factor should appear
   ! 
   ! 
   USE kinds
   USE constants,           ONLY : ZERO, ONE, TWO, EPS_m6, &
                                   ELECTRONVOLT_SI, BOHR_RADIUS_SI
   USE io_module,           ONLY : stdout, ionode
   USE timing_module,       ONLY : timing
   USE log_module,          ONLY : log_push, log_pop
   USE windows_module,      ONLY : nspin, nkpts_g, windows_alloc => alloc
   USE ions_module,         ONLY : ityp, zv, nat, tau, ion_charge, ions_alloc => alloc
   USE lattice_module,      ONLY : alat, omega, avec, lattice_alloc => alloc
   USE converters_module,   ONLY : cry2cart, cart2cry

   IMPLICIT NONE 
   !
   ! input variables
   ! 
   INTEGER,      INTENT(in) :: dimwann                  ! the # of WFs
   REAL(dbl),    INTENT(in) :: rave(3,dimwann)          ! <r> for each WF
   
   !
   ! local variables
   !
   INTEGER       :: i, m, ierr
   LOGICAL       :: lsupercell
   REAL(dbl)     :: P_ion(3), P_el(3), delta_P(3), const_SI
   REAL(dbl), ALLOCATABLE :: tau_cry(:,:), rave_cry(:,:)
 
   !
   ! end of declariations
   !

!
!------------------------------
! main body
!------------------------------
!
      CALL timing('polarization',OPR='start')
      CALL log_push('polarization')

      !
      ! checks
      !
      IF ( .NOT. windows_alloc ) CALL errore('polarization', 'windows not alloc', 1)
      IF ( .NOT. lattice_alloc ) CALL errore('polarization', 'lattice not alloc', 1)
      IF ( .NOT. ions_alloc )    CALL errore('polarization', 'ions not alloc', 1)

      IF (dimwann == 0 ) CALL errore('polarization', 'dimwann == 0 ', 1)
      IF (nat == 0 )     CALL errore('polarization', 'nat == 0 ', 1)

      IF ( ABS(ion_charge - REAL(2*dimwann, dbl) ) > EPS_m6 ) &
           CALL errore('polarization', 'illegal computation of polarization', 1)


      !
      ! convert tau and rave to crystal units
      !
      ALLOCATE( tau_cry(3, nat), rave_cry(3, dimwann), STAT=ierr)
      IF (ierr/=0) CALL errore('polarization', 'allocating tau_cry, rave_cry', ABS(ierr))

      tau_cry = tau * alat
      CALL cart2cry( tau_cry, avec)
      !
      rave_cry = rave 
      CALL cart2cry( rave_cry, avec)
     
!
! ionic polarization
!
      P_ion(:) = ZERO 
      !
      DO i = 1, nat
           P_ion(:) = P_ion(:) + zv( ityp(i) ) * tau_cry(:,i)
      ENDDO

      !
      ! clean the ionic contribution respect to spurious contributions
      !
      P_ion(:) = P_ion(:) - REAL( NINT( P_ion(:) ), dbl )

!
! electronic polarization
!
      P_el(:) = ZERO 
      !
      DO m = 1, dimwann
           P_el(:) = P_el(:) + rave_cry(:,m)
      ENDDO

      !
      ! clean the electronic contribution respect to spurious contributions
      !
      P_el(:) = P_el(:) - REAL( NINT( P_el(:) ), dbl )

      !
      ! ionic + electronic polarization. the TWO factor appear considering
      ! that each band, i.e. each WF carries two electrons. In spin polarized
      ! cases, only the final result must be divided by two (i.e. by nspin)
      !
      delta_P(:) = P_ion(:) - TWO * P_el(:)
      delta_P(:) = delta_P(:) - REAL( NINT( delta_P(:) ), dbl )
      !
      ! note that the line before makes unnecessary all the previous
      ! REAL ( NINT (xxx) ). They are left there as a trace, 
      ! to be removed sooner or later.
      !

      !
      ! stdout writing
      !
      IF ( ionode ) THEN
          !
          WRITE(stdout, "(/,2x, 'Charge centers: (crystal coord.)')")
          WRITE(stdout, "(4x,'Ionic charge  =     ( ',3f12.6, ' )' )") &
                         P_ion(:) / ion_charge
          WRITE(stdout, "(4x,' Elec charge  =     ( ',3f12.6, ' )' )") &
                         P_el(:)  / ion_charge
          !
      ENDIF

      CALL cry2cart( P_ion, avec) 
      CALL cry2cart( P_el,  avec) 
      CALL cry2cart( delta_P,  avec) 

      const_SI = ELECTRONVOLT_SI / BOHR_RADIUS_SI**2

      lsupercell = .FALSE.
      IF ( nkpts_g == 1 ) lsupercell = .TRUE.
      
      IF ( ionode ) THEN
          !
          IF ( lsupercell ) THEN
              WRITE(stdout, "(/,2x, 'Dipole contributions: &
                                    &(cart. coord. in e*Bohr = 2.541766 Debye)')")
              !
              WRITE(stdout, "(4x,'Ionic dipole  =     ( ',3f12.6, ' )')") &
                              P_ion(:) / REAL(nspin, dbl) 
              WRITE(stdout, "(4x,'Elec  dipole  =     ( ',3f12.6, ' )')") &
                              -P_el(:) * TWO / REAL(nspin, dbl)
              WRITE(stdout, "(/,4x,'Total dipole  =     ( ',3f12.6, ' )')") &
                              delta_P(:) / REAL(nspin, dbl)
              WRITE(stdout, "(  4x,'              =     | ',f12.6, ' |')") &
                              SQRT (DOT_PRODUCT( delta_P(:), delta_P(:))) / REAL(nspin, dbl)
          ELSE
              WRITE(stdout, "(/,2x, 'Polarization contributions: (cart. coord. in C/m^2)')")
              !
              WRITE(stdout, "(4x,'Ionic pol.    =     ( ',3f12.6, ' )')") &
                              P_ion(:) / ( REAL(nspin, dbl) * omega ) * const_SI
              WRITE(stdout, "(4x,'Elec  pol.    =     ( ',3f12.6, ' )')") &
                              -P_el(:) * TWO / ( REAL(nspin, dbl) * omega ) * const_SI
              WRITE(stdout, "(4x,'Total pol.    =     ( ',3f12.6, ' )')") &
                              delta_P(:) / ( REAL(nspin, dbl) * omega ) * const_SI
          ENDIF
          WRITE(stdout, "()")     
          !
      ENDIF

      ! 
      ! cleaning 
      ! 
      DEALLOCATE( tau_cry, rave_cry, STAT=ierr)
      IF (ierr/=0) CALL errore('polarization', 'deallocating tau_cry, rave_cry', ABS(ierr))

      CALL timing('polarization',OPR='stop')
      CALL log_pop('polarization')
      !
END SUBROUTINE polarization

