! 
! Copyright (C) 2004 WanT Group
! 
! This file is distributed under the terms of the 
! GNU General Public License. See the file `License' 
! in the root directory of the present distribution, 
! or http://www.gnu.org/copyleft/gpl.txt . 
! 
!*********************************************************
SUBROUTINE overlap_setmap( npwk, npwx_g, ngx, ngy, ngz, &
                           igsort, nncell, isign, map)
   !*********************************************************
   !
   ! This subroutine set the map between the G coefficients of the
   ! calculated wfc and the vectors entering the overlap scalar
   ! product eventually accounting for the e^{iGr} phase
   ! (giving an overall permutation of the G indexes)
   !
   ! returns -1 in the map when the point is not find in the
   ! final fft2gv transform. This should be checked outside
   !
   ! The routine may be optimized eliminating some IF in the
   ! loops whether necessary
   !
   USE kinds
   USE ggrids_module, ONLY : igv, ggrids_gk_indexes, ggrids_gv_indexes
   USE timing_module, ONLY : timing
   USE log_module,    ONLY : log_push, log_pop
   !   
   IMPLICIT NONE
   
   !
   ! input variables
   !
   INTEGER,  INTENT(in)      :: npwk                ! max pw number for wfc among kpts
   INTEGER,  INTENT(in)      :: npwx_g              ! total number of G for wfcs
   INTEGER,  INTENT(in)      :: ngx,ngy,ngz         ! FFT dimensions
   INTEGER,  INTENT(in)      :: igsort(npwk)        ! indexes of the G coeff for wfcs
   INTEGER,  INTENT(in)      :: nncell(3)           ! BZ of the required neighbour
   INTEGER,  INTENT(in)      :: isign               ! used to revert the sign of G in the 
                                                    ! gamma_only case
   INTEGER,  INTENT(out)     :: map(npwk)           ! map between the actual G ordering for 
                                                    ! wfcs and the one required for overlaps 
                                                    ! eventually including the permutation
                                                    ! due to the inclusion of the e^iGr phase
   !
   ! local variables
   !
   CHARACTER(14)    :: subname="overlap_setmap"
   INTEGER          :: ix,  iy,  iz
   INTEGER          :: ix2, iy2, iz2
   INTEGER          :: nnrx
   INTEGER          :: itmp, ipoint, ipoint_new
   INTEGER          :: ig, ierr
   INTEGER, ALLOCATABLE :: fft2gv(:), gk2fft(:)
   !
   ! end of declarations
   !

!
!-----------------------------
! main body
!-----------------------------
!
   CALL timing('overlap_setmap',OPR='start')
   CALL log_push('overlap_setmap')


   ALLOCATE( gk2fft(npwk), STAT=ierr )
   IF (ierr/=0) CALL errore(subname,'allocating gk2fft', ABS(ierr) )
   !
   ALLOCATE( fft2gv(0:ngx*ngy*ngz), STAT=ierr )
   IF (ierr/=0) CALL errore(subname,'allocating fft2gv', ABS(ierr) )

   CALL ggrids_gk_indexes(igv, igsort, npwk, ngx, ngy, ngz, GK2FFT=gk2fft )
   CALL ggrids_gv_indexes(igv, SIZE(igv,2), ngx, ngy, ngz, FFT2GV=fft2gv )
   !
   nnrx = ngx*ngy*ngz+1
   !
!$omp parallel do private(ipoint,ix,ix2,iy,iy2,iz,iz2,ipoint_new,itmp)
   !
   DO ig=1, npwk
      
      ipoint = gk2fft(ig)
      !
      ! ipoint index in the FFT grid is built as
      ! ipoint = ix + (iy-1)*ngx + (iz-1)*ngx*ngy
      !
      ix = MOD( ipoint, ngx )
      IF( ix < 1   ) ix = ix + ngx
      IF( ix > ngx ) ix = ix - ngx
      !
      ix2 = isign*( ix -1 -nncell( 1 ) ) +1
      IF( ix2 < 1   ) ix2 = ix2 + ngx
      IF( ix2 > ngx ) ix2 = ix2 - ngx

      iy = ( MOD( ipoint, ngx*ngy) - ix ) / ngx +1 
      IF ( MOD( MOD( ipoint, ngx*ngy) - ix, ngx ) /= 0 )  &
           CALL errore(subname,'invalid FFT grid',1)
      IF( iy < 1   ) iy = iy + ngy
      IF( iy > ngy ) iy = iy - ngy
      !
      iy2 = isign*( iy -1 -nncell( 2 ) ) +1
      IF( iy2 < 1   ) iy2 = iy2 + ngy
      IF( iy2 > ngy ) iy2 = iy2 - ngy

      iz = ( ipoint - ix -(iy-1)*ngx ) / (ngx*ngy) +1
      IF ( MOD(ipoint - ix -(iy-1)*ngx, ngx*ngy) /= 0 )  &
           CALL errore(subname,'invalid FFT grid',2)
      IF( iz < 1   ) iz = iz + ngz
      IF( iz > ngz ) iz = iz - ngz
      !
      iz2 = isign*( iz -1 -nncell( 3 ) ) +1
      IF( iz2 < 1   ) iz2 = iz2 + ngz
      IF( iz2 > ngz ) iz2 = iz2 - ngz

      ipoint_new = ix2 + (iy2-1)*ngx + (iz2-1)*ngx*ngy
      !
      IF ( ipoint_new > nnrx .OR. ipoint_new < 1 ) &
           CALL errore(subname,'invalid indexes', ABS(ipoint_new)+1)
      !
      ! go to the density grid
      !
      itmp = fft2gv(ipoint_new)
      !
      ! this used to give an error. Now we just set the index to -1
      ! and this has to be checked in the parent calling routine.
      IF ( itmp <= 0 ) itmp = -1
          !CALL errore(subname,'unexpected index',-itmp+1)

      !
      ! if the translation of the G goes over a point out of the 
      ! initial G group, we set the related inxed to a dummy position
      !
      map(ig) = MIN( itmp, npwx_g)
      !
   ENDDO
!$omp end parallel do

   DEALLOCATE( gk2fft, STAT=ierr )
   IF (ierr/=0) CALL errore(subname,'deallocating gk2fft', ABS(ierr) )
   DEALLOCATE( fft2gv, STAT=ierr )
   IF (ierr/=0) CALL errore(subname,'deallocating fft2gv', ABS(ierr) )

   CALL timing('overlap_setmap',OPR='stop')
   CALL log_pop('overlap_setmap')
   !
END SUBROUTINE overlap_setmap


