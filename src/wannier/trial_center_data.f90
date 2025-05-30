!
! Copyright (C) 2005 WanT Group
!
! This file is distributed under the terms of the
! GNU General Public License. See the file `License\'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!

!*********************************************
   MODULE trial_center_data_module
!*********************************************
   !
   USE kinds,                  ONLY : dbl
   USE constants,              ONLY : ZERO
   USE log_module,             ONLY : log_push, log_pop
   USE subspace_module,        ONLY : dimwann
   USE trial_center_module
   IMPLICIT NONE
   PRIVATE
   SAVE

! This module contains data related to the trial orbitals
! for WF localization.
! Basic definitions are in trial_center_module
!
! routines in this module:
! SUBROUTINE trial_center_data_allocate()
! SUBROUTINE trial_center_data_deallocate()
!

!
   TYPE(trial_center), ALLOCATABLE  :: trial(:)
   LOGICAL                          :: alloc = .FALSE.

!
! end of declarations
!

   PUBLIC :: dimwann
   PUBLIC :: trial
   PUBLIC :: trial_center_data_allocate
   PUBLIC :: trial_center_data_deallocate
   PUBLIC :: trial_center_data_memusage
   PUBLIC :: alloc

CONTAINS

!
! subroutines
!

!**********************************************************
   SUBROUTINE trial_center_data_allocate()
   !**********************************************************
   IMPLICIT NONE
      CHARACTER(26)  :: subname='trial_center_data_allocate'
      INTEGER        :: ierr

      CALL log_push( subname )
      !
      IF ( alloc ) CALL errore(subname,'trial_centers already allocated',1)
      IF ( dimwann <= 0 ) CALL errore(subname,'invalid dimwann',-dimwann+1)
      ALLOCATE( trial(dimwann), STAT=ierr )
         IF (ierr/=0)  CALL errore(subname,'allocating trial_centers',ABS(ierr))
      alloc = .TRUE.
      !
      CALL log_pop( subname )
      !
   END SUBROUTINE trial_center_data_allocate


!**********************************************************
   SUBROUTINE trial_center_data_deallocate()
   !**********************************************************
   IMPLICIT NONE
      CHARACTER(28)  :: subname='trial_center_data_deallocate'
      INTEGER        :: ierr

      CALL log_push( subname )
      !
      IF ( .NOT. alloc ) CALL errore(subname,'trial_centers not yet allocated',1)
      DEALLOCATE( trial, STAT=ierr )
         IF (ierr/=0)  CALL errore(subname,'deallocating trial_centers',ABS(ierr))
      
      CALL log_pop( subname )
      !
   END SUBROUTINE trial_center_data_deallocate


!**********************************************************
   REAL(dbl) FUNCTION trial_center_data_memusage()
   !**********************************************************
   IMPLICIT NONE
       !
       REAL(dbl) :: cost
       !
       cost = ZERO
       IF ( ALLOCATED(trial) )    cost = cost + REAL(SIZE(trial))  * 34 * 4.0_dbl
       !
       trial_center_data_memusage = cost / 1000000.0_dbl
       !
   END FUNCTION trial_center_data_memusage 

END MODULE trial_center_data_module

