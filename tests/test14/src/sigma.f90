
!============================
   PROGRAM sigma
!============================
   USE iotk_module
   IMPLICIT NONE

   INTEGER,      PARAMETER :: dbl=KIND(1.0d0)
   COMPLEX(dbl), PARAMETER :: CI=(0.0_dbl,1.0_dbl)
   !
   INTEGER  :: nbnd   = 120
   INTEGER  :: nkpts  = 16
   INTEGER  :: nspin  = 1
   INTEGER  :: nomega = 1
   LOGICAL  :: ldiag  = .TRUE.
   LOGICAL  :: ldynam = .FALSE.
   LOGICAL  :: binary = .FALSE.
   !
   INTEGER  :: ibnd_start = 1
   INTEGER  :: ibnd_end   
   !
   !
   CHARACTER(256)       :: fileout = "sigma.xml"
   CHARACTER(256)       :: filekpt = "kpt_441.dat"
   !
   !
   INTEGER  :: i, ik, ie, ierr
   REAL(dbl):: emin, emax
   !
   REAL(dbl),    ALLOCATABLE :: vkpt(:,:), grid(:)
   COMPLEX(dbl), ALLOCATABLE :: sgm_diag(:,:,:), sgm_full(:,:,:,:)
   CHARACTER(600)       :: attr
   !
   !--------------------------------------

   ibnd_end = ibnd_start + nbnd -1
   !
   emin     = -5.0
   emax     =  5.0

   IF ( ldynam .AND. nomega == 1 ) STOP "invalid nomega"

   IF ( ldiag ) THEN
      ALLOCATE( sgm_diag(nbnd, nkpts, nomega), STAT=ierr )
      IF ( ierr/=0 ) STOP "allocating sgm_diag"
   ELSE
      ALLOCATE( sgm_full(nbnd, nbnd, nkpts, nomega), STAT=ierr )
      IF ( ierr/=0 ) STOP "allocating sgm_full"
   ENDIF
 
   !
   ALLOCATE( vkpt(3, nkpts) )
   ALLOCATE( grid(nomega) )

   !
   ! read kpts
   !
   OPEN( 10, FILE=TRIM(filekpt) )
   READ(10, * )
   !
   DO ik = 1, nkpts
      !
      READ(10, *, IOSTAT=ierr ) vkpt(:,ik)
      IF ( ierr/=0 ) STOP "reading kpt"
      !
   ENDDO
   !
   CLOSE( 10 )


   !
   ! define grid
   !
   IF ( ldynam ) THEN
      !
      DO ie = 1, nomega 
         !
         grid( ie ) = emin + ( ie -1 ) * ( emax - emin ) / REAL( nomega -1 ) 
         !
      ENDDO
      !
   ELSE
      grid( : ) =  0.0
   ENDIF


   !
   ! define sgm
   !
   DO ie = 1, nomega
   DO ik = 1, nkpts
      !
      IF ( ldiag ) THEN
         !
         sgm_diag( 1:nbnd, ik, ie ) = -0.25 * CI
         !
      ELSE
         !
         sgm_full( :, :, ik, ie) = 0.0
         !
         DO i = 1, 24
            sgm_full( i, i, ik, ie ) = -0.25 * CI
         ENDDO
         !
      ENDIF
      !
   ENDDO
   ENDDO
   
   
   ! 
   ! write fo tile 
   ! 
   CALL iotk_open_write( 10, FILE=TRIM(fileout), BINARY=binary)
   !
   CALL iotk_write_attr( attr, "nbnd", nbnd, FIRST=.TRUE. )
   CALL iotk_write_attr( attr, "nkpts", nkpts )
   CALL iotk_write_attr( attr, "nspin", nspin )
   CALL iotk_write_attr( attr, "iband_start", ibnd_start )
   CALL iotk_write_attr( attr, "iband_end", ibnd_end )
   CALL iotk_write_attr( attr, "band_diagonal", ldiag )
   CALL iotk_write_attr( attr, "dynamical", ldynam )
   CALL iotk_write_attr( attr, "nomega", nomega )
   CALL iotk_write_attr( attr, "analyticity", "retarded" )
   !
   CALL iotk_write_empty( 10, "DATA", ATTR=attr)
   !
   !
   CALL iotk_write_attr( attr, "units", "crystal", FIRST=.TRUE. )
   CALL iotk_write_dat( 10, "VKPT", vkpt, COLUMNS=3, ATTR=attr )
   !
   IF ( ldynam ) THEN
      !
      CALL iotk_write_attr( attr, "units", "eV", FIRST=.TRUE. )
      CALL iotk_write_dat( 10, "GRID", grid, ATTR=attr )
      !
   ENDIF
   !
   DO ie = 1, nomega
      !
      IF ( ldynam ) THEN
         CALL iotk_write_begin( 10, "OPR"//TRIM(iotk_index(ie)) )
      ELSE
         CALL iotk_write_begin( 10, "OPR" )
         IF ( ie /= 1 ) STOP "invalid ie"
      ENDIF
      !
      DO ik = 1, nkpts
         !
         IF ( ldiag ) THEN
            CALL iotk_write_dat( 10, "KPT"//TRIM(iotk_index(ik)), sgm_diag(:,ik,ie) )  
         ELSE
            CALL iotk_write_dat( 10, "KPT"//TRIM(iotk_index(ik)), sgm_full(:,:,ik,ie) )  
         ENDIF
         !
      ENDDO
      !
      IF ( ldynam ) THEN
         CALL iotk_write_end( 10, "OPR"//TRIM(iotk_index(ie)) )
      ELSE
         CALL iotk_write_end( 10, "OPR" )
      ENDIF
      !
   ENDDO
   !
   !
   CALL iotk_close_write( 10 )
      

   !
   ! cleaning
   !
   IF ( ALLOCATED(sgm_diag) )DEALLOCATE( sgm_diag )
   IF ( ALLOCATED(sgm_full) )DEALLOCATE( sgm_full )
   DEALLOCATE( vkpt )

END PROGRAM sigma
