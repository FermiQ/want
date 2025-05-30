!
! Copyright (C) 2009 WanT Group
!
! This file is distributed under the terms of the
! GNU General Public License. See the file `License\'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!*********************************************
   MODULE E_correlation_module
!*********************************************
   !
   USE kinds,                   ONLY : dbl
   USE constants,               ONLY : EPS_m6
   USE parameters,              ONLY : nstrx
   USE io_module,               ONLY : sgm_unit, ionode, ionode_id, stdout, io_set_nd_nmbr
   USE mp,                      ONLY : mp_bcast
   USE mp_global,               ONLY : mpime, nproc
   USE parser_module,           ONLY : change_case
   USE operator_module,         ONLY : operator_read_aux, operator_read_data
   USE timing_module,           ONLY : timing
   USE log_module,              ONLY : log_push, log_pop
   USE files_module,            ONLY : file_open, file_close, file_exist
   !
   USE E_hamiltonian_module,    ONLY : dimT, dimE, dimB, blc_T, blc_E, blc_B, blc_EB, blc_BE
   USE E_control_module,        ONLY : transport_dir, datafile_sgm
   !
   USE T_egrid_module,          ONLY : de, ne, egrid, emin, emax, &
                                       ne_buffer, egrid_alloc => alloc
   USE T_kpoints_module,        ONLY : nkpts_par, nrtot_par, ivr_par
   USE T_operator_blc_module
   !
   IMPLICIT NONE
   PRIVATE 
   SAVE

!
! Contains correlation self-energy data
! 
    INTEGER     :: dimT_corr
    INTEGER     :: nrtot_corr
    !
    LOGICAL     :: lhave_corr   = .FALSE.
    LOGICAL     :: ldynam_corr  = .FALSE.
    !
    LOGICAL     :: init = .FALSE.


!
! end delcarations
!

   PUBLIC :: dimT
   PUBLIC :: nkpts_par
   !
   PUBLIC :: dimT_corr
   PUBLIC :: nrtot_corr
   PUBLIC :: lhave_corr, ldynam_corr
   !
   PUBLIC :: init
   !
   PUBLIC :: correlation_init
   PUBLIC :: correlation_sgmread
   PUBLIC :: correlation_read


CONTAINS

!
! subroutines
!
!**********************************************************
   SUBROUTINE correlation_init(iunit)
   !**********************************************************
   !
   ! open the sigma file and allocate the main workspace
   ! energy grid is read from file
   !
   IMPLICIT NONE
      !
      ! I/O vars
      !
      INTEGER, INTENT(in)   :: iunit
      !
      ! local vars
      !
      CHARACTER(16)         :: subname="correlation_init"
      CHARACTER(nstrx)      :: analyticity
      CHARACTER(6)          :: str
      INTEGER,  ALLOCATABLE :: ivr_corr(:,:)
      INTEGER               :: ne_corr, ierr

      CALL log_push( 'correlation_init' )
      IF ( egrid_alloc )   CALL errore(subname,'egrid already allocated', 1 )


      !
      ! check the existence of datafile
      !
      IF ( .NOT. file_exist(TRIM(datafile_sgm)) ) THEN
          !
          CALL io_set_nd_nmbr( str, mpime, nproc )
          str="."//TRIM(str)
          !
          IF ( file_exist( TRIM(datafile_sgm)//TRIM(str) ) ) THEN
              !
              datafile_sgm=TRIM(datafile_sgm)//TRIM(str)
              !
          ELSE
              CALL errore(subname,"datafile sgm not found",10)
          ENDIF
          !
      ENDIF


      !
      ! This file must be opened by all the processors
      !
      CALL file_open( sgm_unit, TRIM(datafile_sgm), PATH="/", ACTION="read", IERR=ierr )
      IF ( ierr/=0 ) CALL errore(subname,'opening '//TRIM(datafile_sgm), ABS(ierr) )

      !
      ! get main data and check them
      !
      IF ( ionode ) THEN
          !
          CALL operator_read_aux( iunit, DIMWANN=dimT_corr, NR=nrtot_corr, &
                                  DYNAMICAL=ldynam_corr, &
                                  NOMEGA=ne_corr, ANALYTICITY=analyticity, IERR=ierr )
          !
          IF ( ierr/=0 ) CALL errore(subname,'reading DIMWANN--ANALYTICITY', ABS(ierr))
          !
      ENDIF
      !
      CALL mp_bcast( dimT_corr,    ionode_id )
      CALL mp_bcast( nrtot_corr,   ionode_id )
      CALL mp_bcast( ldynam_corr,  ionode_id )
      CALL mp_bcast( ne_corr,      ionode_id )
      CALL mp_bcast( analyticity,  ionode_id )
      !
      !
      ! this is a workaround, 
      ! when the sgm files a re too big, iotk seems to have problems
      ! to go back and forth
      !
      CALL file_close( sgm_unit, PATH="/", ACTION="read", IERR=ierr )
      IF ( ierr/=0 ) CALL errore(subname,'closing '//TRIM(datafile_sgm), ABS(ierr) )
      
      !
      ! checks
      !
      IF ( dimT_corr > dimT)               CALL errore(subname,'invalid dicT_corr',3)
      IF ( nrtot_corr <= 0 )               CALL errore(subname,'invalid nrtot_corr',3)
      IF ( ne_corr <= 0 .AND. ldynam_corr) CALL errore(subname,'invalid ne_corr',3)

      !
      ! reset buffering
      !
      IF ( .NOT. ldynam_corr ) THEN
          !
          ne_buffer = 1
          CALL warning( subname, 'buffering reset to 1')
          !
      ELSE
          !
          ne_buffer = MIN( ne_buffer, INT(  ne_corr / nproc ) + 1 )
          CALL warning( subname, 'buffering reset')
          !
      ENDIF

      !
      CALL change_case( analyticity, 'lower' )
      IF ( TRIM(analyticity) /= 'retarded' .AND. ldynam_corr) &
                CALL errore(subname,'invalid analyticity = '//TRIM(analyticity),1)
      !
      !
      ! re-open the file
      !
      CALL file_open( sgm_unit, TRIM(datafile_sgm), PATH="/", ACTION="read", IERR=ierr )
      IF ( ierr/=0 ) CALL errore(subname,'opening '//TRIM(datafile_sgm), ABS(ierr) )
      !
      ALLOCATE ( ivr_corr(3,nrtot_corr), STAT=ierr )
      IF( ierr /=0 ) CALL errore(subname, 'allocating ivr_corr', ABS(ierr) )
      !
      IF ( ldynam_corr ) THEN
          !
          ne = ne_corr
          !
          ALLOCATE( egrid(ne), STAT=ierr )
          IF (ierr/=0) CALL errore(subname,'allocating egrid',ABS(ierr))
          !
      ENDIF
      !
      !
      IF ( ionode ) THEN
          !
          IF ( ldynam_corr ) THEN
              !
              CALL operator_read_aux( iunit, GRID=egrid, IVR=ivr_corr, IERR=ierr )
              IF (ierr/=0) CALL errore(subname,'reading GRID, IVR',ABS(ierr))
              !
          ELSE
              !
              CALL operator_read_aux( iunit, IVR=ivr_corr, IERR=ierr )
              IF (ierr/=0) CALL errore(subname,'reading IVR',ABS(ierr))
              !
          ENDIF
          !
      ENDIF
      !
      IF ( ldynam_corr ) CALL mp_bcast( egrid, ionode_id )
      CALL mp_bcast( ivr_corr, ionode_id )

      !
      ! store data
      !
      CALL operator_blc_allocate( dimT, dimT, nkpts_par, NRTOT_SGM=nrtot_corr, &
                                  NE_SGM=ne_buffer, LHAVE_CORR=.TRUE., OBJ=blc_T)
      CALL operator_blc_allocate( dimE, dimE, nkpts_par, NRTOT_SGM=nrtot_corr, &
                                  NE_SGM=ne_buffer, LHAVE_CORR=.TRUE., OBJ=blc_E)
      CALL operator_blc_allocate( dimB, dimB, nkpts_par, NRTOT_SGM=nrtot_corr, &
                                  NE_SGM=ne_buffer, LHAVE_CORR=.TRUE., OBJ=blc_B)
      CALL operator_blc_allocate( dimE, dimB, nkpts_par, NRTOT_SGM=nrtot_corr, &
                                  NE_SGM=ne_buffer, LHAVE_CORR=.TRUE., OBJ=blc_EB)
      CALL operator_blc_allocate( dimB, dimE, nkpts_par, NRTOT_SGM=nrtot_corr, &
                                  NE_SGM=ne_buffer, LHAVE_CORR=.TRUE., OBJ=blc_BE)
      !
      blc_T%ivr_sgm = ivr_corr
      blc_E%ivr_sgm = ivr_corr
      blc_B%ivr_sgm = ivr_corr
      blc_EB%ivr_sgm = ivr_corr
      blc_BE%ivr_sgm = ivr_corr
      !
      DEALLOCATE ( ivr_corr, STAT=ierr )
      IF( ierr /=0 ) CALL errore(subname, 'allocating ivr_corr', ABS(ierr) )

      ! 
      !
      ! set further data about the energy grid
      !
      IF ( ldynam_corr ) THEN
          !
          CALL warning( subname, "energy egrid is forced from SGM datafile" )
          WRITE( stdout, "()")
          !
          emin = egrid(1)
          emax = egrid(ne)
          de   = ( emax - emin ) / REAL( ne -1, dbl )  
          egrid_alloc = .TRUE.
          !
      ENDIF
      !
      init = .TRUE.
      !
      CALL log_pop( 'correlation_init' )
      ! 
   END SUBROUTINE correlation_init


!**********************************************************
   SUBROUTINE correlation_sgmread( iun, opr, ie, ie_buff )
   !**********************************************************
   !
   IMPLICIT NONE
      INTEGER,            INTENT(IN)    :: iun
      TYPE(operator_blc), INTENT(INOUT) :: opr
      INTEGER, OPTIONAL,  INTENT(IN)    :: ie, ie_buff
      !
      CHARACTER(19)              :: subname="correlation_sgmread"
      COMPLEX(dbl), ALLOCATABLE  :: caux(:,:,:), caux_small(:,:,:)
      LOGICAL                    :: lfound
      INTEGER                    :: ind, ivr_aux(3)
      INTEGER                    :: i, j, ir, ir_par, ierr
      INTEGER                    :: ie_bl


      CALL timing( subname, OPR='start' )
      CALL log_push( subname )

      IF ( .NOT. init ) CALL errore(subname,'correlation not init',71)
      !
      IF ( PRESENT(ie) .AND. .NOT. PRESENT(ie_buff) ) &
           CALL errore(subname,'ie and ie_buff should be present together',3)
 
      IF ( .NOT. opr%alloc )        CALL errore(subname,'opr not alloc',71)
      IF ( opr%dim1 >  dimT_corr )  CALL errore(subname,'invalid dim1',1)
      IF ( opr%dim2 >  dimT_corr )  CALL errore(subname,'invalid dim2',2)
      IF ( opr%nkpts /= nkpts_par ) CALL errore(subname,'invalid nkpts',3)
      !
      IF ( ANY( opr%irows_sgm(:) > dimT_corr ) ) &
                                    CALL errore(subname,'invalid irows_sgm',3)
      IF ( ANY( opr%icols_sgm(:) > dimT_corr ) ) &
                                    CALL errore(subname,'invalid icols_sgm',3)

      !
      ! setting index for buffering
      !
      ie_bl = 1
      IF ( PRESENT(ie_buff) ) ie_bl = ie_buff

      !
      ! allocate auxiliary quantities
      !
      ALLOCATE( caux(dimT_corr, dimT_corr, nrtot_corr), STAT=ierr )
      IF ( ierr/=0 ) CALL errore(subname, 'allocating caux', ABS(ierr))
      !
      ALLOCATE( caux_small(opr%dim1, opr%dim2, nrtot_par), STAT=ierr )
      IF ( ierr/=0 ) CALL errore(subname, 'allocating caux_small', ABS(ierr))

      !
      ! get the required data
      !
      IF ( PRESENT( ie ) ) THEN
          !
          opr%ie = ie
          CALL operator_read_data( iun, ie, R_OPR=caux, IERR=ierr )
          !
      ELSE
          !
          CALL operator_read_data( iun, R_OPR=caux, IERR=ierr )
          !
      ENDIF
      !
      IF ( ierr/=0 ) CALL errore(subname, 'reading data from file', ABS(ierr))


      !
      ! get the required matrix elements
      !
      R_loop: &
      DO ir_par = 1, nrtot_par

          !
          ! set the indexes
          !
          j = 0
          DO i=1,3
              !
              IF ( i == transport_dir ) THEN
                  !
                  ! set ivr_aux(i) = 0 , 1 depending on the
                  ! required matrix (detected from opr%blc_name)
                  !
                  SELECT CASE( TRIM(opr%blc_name) )
                  !
                  CASE( "block_00C", "block_00R", "block_00L", &
                        "block_T",   "block_E",   "block_B",   "block_EB",  "block_BE" )
                      ivr_aux(i) = 0
                  CASE( "block_01R", "block_01L", "block_LC", "block_CR" )
                      ivr_aux(i) = 1
                  CASE DEFAULT
                      CALL errore(subname, 'invalid label = '//TRIM(opr%blc_name), 1009 )
                  END SELECT
                  !
              ELSE
                  !
                  ! set the 2D parallel indexes
                  !
                  j = j + 1
                  ivr_aux(i) = ivr_par( j, ir_par)
                  !
              ENDIF
              !
          ENDDO
      
          !
          ! search the 3D index corresponding to ivr_aux
          !
          lfound = .FALSE.
          !
          DO ir = 1, opr%nrtot_sgm
              !
              IF ( ALL( opr%ivr_sgm(:,ir) == ivr_aux(:) ) )  THEN
                  !
                  lfound = .TRUE.
                  ind    = ir
                  EXIT
                  !
              ENDIF
              !
          ENDDO
          !
          IF ( .NOT. lfound ) CALL errore(subname, '3D R-vector not found', ir_par )


          !
          ! cut the operator (caux) 
          ! according to the required rows and cols
          !
          DO j=1,opr%dim2
          DO i=1,opr%dim1
              !
              caux_small(i, j, ir_par) = caux( opr%irows_sgm(i), opr%icols_sgm(j), ind )
              !
          ENDDO
          ENDDO
          !
          !
      ENDDO R_loop

      !
      ! Compute the 2D fourier transform
      !
      CALL fourier_par (opr%sgm(:,:,:,ie_bl), opr%dim1, opr%dim2, caux_small, opr%dim1, opr%dim2)

      !
      ! local cleaning
      !
      DEALLOCATE( caux, caux_small, STAT=ierr )
      IF ( ierr/=0 ) CALL errore(subname, 'deallocating caux, caux_small', ABS(ierr))

      CALL timing( subname, OPR='stop' )
      CALL log_pop( subname )
      !
   END SUBROUTINE correlation_sgmread
    

!*******************************************************************
   SUBROUTINE correlation_read( ie_s, ie_e )
   !*******************************************************************
   !
   ! Read correlation data
   ! If IE_S, IE_E are present, it means that we are reading
   ! dynamic self-energies
   !
   IMPLICIT NONE

   !
   ! Input variabls
   !
   INTEGER, OPTIONAL, INTENT(IN) :: ie_s, ie_e

   !
   ! local variables
   !
   CHARACTER(16) :: subname="correlation_read"
   LOGICAL       :: lopen
   INTEGER       :: ie, ie_buff

   !
   ! end of declarations
   !

!
!----------------------------------------
! main Body
!----------------------------------------
!

   CALL timing( subname, OPR='start')
   CALL log_push( subname )

   !
   ! few checks
   !
   IF ( .NOT. init )       CALL errore(subname,'correlation not init',10)
   IF ( .NOT. lhave_corr ) CALL errore(subname,'correlation not required',10)
   !
   IF ( .NOT. ( PRESENT( ie_s ) .EQV.  PRESENT( ie_e ) )  ) &
       CALL errore(subname,' ie_s and ie_e should be given together or not given at all',10)
   !
   IF ( ( PRESENT( ie_s ) .OR. PRESENT( ie_e ) ) .AND. .NOT. ldynam_corr ) &
       CALL errore(subname,'correlation is not dynamic',10)

   IF ( ldynam_corr .AND. .NOT. PRESENT( ie_s ) ) &
       CALL errore(subname,'ie_s should be present',10)

   INQUIRE( sgm_unit, OPENED=lopen)
   IF ( .NOT. lopen ) CALL errore(subname,'sgm datafile not connected',10)

   !
   ! read data
   !
   IF ( ldynam_corr ) THEN
       !
       ie_buff = 0
       !
       DO ie = ie_s, ie_e
           !
           ie_buff = ie_buff + 1
           ! 
           CALL correlation_sgmread( sgm_unit, blc_T,  IE=ie, IE_BUFF=ie_buff )
           CALL correlation_sgmread( sgm_unit, blc_E,  IE=ie, IE_BUFF=ie_buff )
           CALL correlation_sgmread( sgm_unit, blc_B,  IE=ie, IE_BUFF=ie_buff )
           CALL correlation_sgmread( sgm_unit, blc_EB, IE=ie, IE_BUFF=ie_buff )
           CALL correlation_sgmread( sgm_unit, blc_BE, IE=ie, IE_BUFF=ie_buff )
           !
       ENDDO
       !
   ELSE
       !
       CALL correlation_sgmread( sgm_unit, blc_T )
       CALL correlation_sgmread( sgm_unit, blc_E )
       CALL correlation_sgmread( sgm_unit, blc_B )
       CALL correlation_sgmread( sgm_unit, blc_EB )
       CALL correlation_sgmread( sgm_unit, blc_BE )
       !
   ENDIF

   CALL timing( subname, OPR='STOP' )
   CALL log_pop( subname )
   !
   RETURN
   !
END SUBROUTINE correlation_read

END MODULE E_correlation_module

