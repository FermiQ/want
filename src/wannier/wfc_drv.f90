! 
! Copyright (C) 2004 WanT Group
! 
! This file is distributed under the terms of the 
! GNU General Public License. See the file `License' 
! in the root directory of the present distribution, 
! or http://www.gnu.org/copyleft/gpl.txt . 
! 
!*********************************************************
   SUBROUTINE wfc_drv_x( do_proj, do_ovp, do_transl, read_proj, read_ovp )
   !*********************************************************
   !
   ! This subroutine permforms all the
   ! operations needed to obtain the internal data from DFT wfcs
   ! (OVERLAP, PROJECTIONS, or TRANSLATIONS matrix elements).
   !
   ! Tasks performed:
   ! * read and init G grids
   ! * compute overlaps (reading the needed wfcs)
   ! * compute projections (reading the needed wfcs)
   ! * compute translations (reading the needed wfcs)
   ! * write data to file
   ! * clear ggrids and wfcs data
   !
   USE kinds
   USE parameters,                 ONLY : nstrx
   USE constants,                  ONLY : CZERO, ZERO
   USE io_module,                  ONLY : stdout, ionode, dft_unit, ovp_unit
   USE io_module,                  ONLY : io_name, dftdata_fmt, wantdata_form
   USE io_module,                  ONLY : io_open_dftdata, io_close_dftdata
   USE log_module,                 ONLY : log_push, log_pop
   USE timing_module,              ONLY : timing, timing_upto_now
   USE files_module,               ONLY : file_open, file_close
   
   USE control_module,             ONLY : use_atomwfc, use_pseudo, use_uspp, use_blimit, &
                                          nwfc_buffer, nkb_buffer
   USE lattice_module,             ONLY : tpiba
   USE subspace_module,            ONLY : dimwann
   USE trial_center_data_module,   ONLY : trial
   USE windows_module,             ONLY : windows_alloc => alloc, dimwin, dimwinx, imin
   USE kpoints_module,             ONLY : kpoints_alloc, bshells_alloc, nkpts, nkpts_g, iks, vkpt_g, &
                                          nb, nnlist, nncell, nnpos
   USE overlap_module,             ONLY : Mkb, proj, overlap_alloc => alloc, overlap_write, overlap_read
   USE translations_module,        ONLY : nvect, rvect, ndim, ndimx, transl, transl_alloc => alloc   
   USE ggrids_module,              ONLY : ggrids_summary, ggrids_read_ext, ggrids_deallocate
   USE wfc_data_module,            ONLY : npwkx, npwk, igsort, evc, evc_info, &
                                          wfc_data_grids_read, wfc_data_grids_summary, &
                                          wfc_data_kread, wfc_data_deallocate 
   USE wfc_info_module
   USE struct_fact_data_module,    ONLY : struct_fact_data_init
   USE uspp,                       ONLY : nkb, vkb
   USE becmod,                     ONLY : becp
   USE mp,                         ONLY : mp_barrier
   !
   IMPLICIT NONE
      !
      ! input vars
      !
      LOGICAL, OPTIONAL, INTENT(IN)   :: do_proj
      LOGICAL, OPTIONAL, INTENT(IN)   :: do_ovp
      LOGICAL, OPTIONAL, INTENT(IN)   :: do_transl
      LOGICAL, OPTIONAL, INTENT(IN)   :: read_proj
      LOGICAL, OPTIONAL, INTENT(IN)   :: read_ovp
      !
      ! local variables
      !
      LOGICAL                   :: do_proj_, do_ovp_, do_transl_
      LOGICAL                   :: read_proj_, read_ovp_
      !
      CHARACTER(7)              :: subname="wfc_drv"
      CHARACTER(nstrx)          :: filename
      REAL(dbl)                 :: xk(3)
      INTEGER                   :: nstepx, nstep_kb, nwfcx, nkbx
      INTEGER,      ALLOCATABLE :: nstep(:), ibnds(:,:), ibnde(:,:)
      INTEGER,      ALLOCATABLE :: ibetas(:), ibetae(:)
      COMPLEX(dbl), ALLOCATABLE :: aux(:,:), aux1(:,:), aux2(:,:), aux_transl(:,:,:)
      LOGICAL                   :: lfound
      INTEGER                   :: ib, ikb_g, ik, ik_g, inn
      INTEGER                   :: is, js, ks, ibs, ibe, jbs, jbe, kbs, kbe
      INTEGER                   :: indin, indout, index
      INTEGER                   :: ierr
      !
      ! End of declaration
      !

!
!------------------------------
! main body
!------------------------------
!
      CALL timing(subname,OPR='start')
      CALL log_push(subname)

      do_proj_    = .FALSE.
      do_ovp_     = .FALSE.
      do_transl_  = .FALSE.
      IF ( PRESENT( do_proj ) )    do_proj_   = do_proj
      IF ( PRESENT( do_ovp ) )     do_ovp_    = do_ovp
      IF ( PRESENT( do_transl ) )  do_transl_ = do_transl
      !
      read_proj_  = .FALSE.
      read_ovp_   = .FALSE.
      IF ( PRESENT( read_proj ) )    read_proj_   = read_proj
      IF ( PRESENT( read_ovp ) )     read_ovp_    = read_ovp

!
! Some checks
!

      IF ( .NOT. kpoints_alloc) CALL errore(subname,'kpoints NOT alloc',2) 
      IF ( .NOT. windows_alloc) CALL errore(subname,'windows NOT alloc',4) 
      !
      IF ( do_ovp_ .AND. .NOT. bshells_alloc) &
           CALL errore(subname,'bshells NOT alloc',3) 
      IF ( do_ovp_ .AND. .NOT. overlap_alloc) &
           CALL errore(subname,'overlap_mod NOT alloc',5) 
      IF ( do_transl_ .AND. .NOT. transl_alloc) &
           CALL errore(subname,'transl_mod NOT alloc',5) 

!
! Here compute the needed quantites 
! (overlaps, projections, and/or trans)
!
      IF ( do_ovp_ .OR. do_proj_ .OR. do_transl_ ) THEN


          !
          ! ... opening the file containing the PW-DFT data
          !
          CALL io_open_dftdata( LSERIAL=.FALSE. ) 
          CALL io_name('dft_data',filename,LPATH=.FALSE.)

          !
          ! ... Read grids
          IF (ionode) WRITE( stdout,"( 2x,'Reading density G-grid from file: ',a)") TRIM(filename)
          CALL ggrids_read_ext( dftdata_fmt )

          !
          ! ... Read wfcs
          IF (ionode) WRITE( stdout,"( 2x,'Reading Wfc grids from file: ',a)") TRIM(filename)
          CALL wfc_data_grids_read( dftdata_fmt )

          !
          ! ... closing the main data file
          !
          CALL io_close_dftdata( LSERIAL=.FALSE. )



          !
          ! ... stdout summary about grids
          !
          CALL ggrids_summary( stdout )
          CALL wfc_data_grids_summary( stdout )


          !
          ! ... if pseudo are used do the required allocations
          !
          IF ( use_pseudo ) THEN
              IF (ionode) WRITE( stdout,"(/,2x,'Initializing global dft data')")
              !
              ! ... data required by USPP and atomic WFC
              CALL allocate_nlpot()
              !
              ! ... structure factors 
              CALL struct_fact_data_init()
          ENDIF


          !
          ! ... Wfc & Vkb buffering
          !     define the maximum number of wfcs to be read and managed at
          !     the same time (reduce non-scalable memory)
          !
          IF ( nwfc_buffer ==  0 .OR. nwfc_buffer < -1 ) &
               CALL errore(subname,'invalid nwfc_buffer',ABS(nwfc_buffer)+1)
          IF ( nwfc_buffer == -1 .OR. nwfc_buffer > dimwinx ) nwfc_buffer = dimwinx
          !
          IF ( nkb_buffer ==  0 .OR. nkb_buffer < -1 ) &
               CALL errore(subname,'invalid nkb_buffer',ABS(nkb_buffer)+1)
          IF ( nkb_buffer == -1 .OR. nkb_buffer > nkb ) nkb_buffer = nkb
          !
          ! Wfcs
          !
          nstepx = INT( dimwinx/ nwfc_buffer )
          IF ( MOD( dimwinx, nwfc_buffer) /= 0 ) nstepx = nstepx+1
          !
          ALLOCATE( ibnds(nstepx, nkpts_g), ibnde(nstepx, nkpts_g), STAT=ierr )
          IF ( ierr/=0 ) CALL errore(subname,'allocating ibnds, ibnde', ABS(ierr))
          ALLOCATE( nstep(nkpts_g), STAT=ierr )
          IF ( ierr/=0 ) CALL errore(subname,'allocating nstep', ABS(ierr))
          !
          !
          DO ik_g = 1, nkpts_g
              !
              nstep( ik_g ) = INT( dimwin(ik_g) / nwfc_buffer )
              IF ( MOD( dimwin(ik_g), nwfc_buffer) /= 0 ) nstep(ik_g) = nstep(ik_g)+1
              !
              DO is = 1, nstep( ik_g )
                  CALL divide_et_impera( 1, dimwin(ik_g), &
                                         ibnds(is, ik_g), ibnde(is, ik_g), is-1, nstep(ik_g) )
              ENDDO
              !
          ENDDO
          !
          nwfcx = MAXVAL( ibnde(:,:) -ibnds(:,:) +1 )
          IF ( nwfcx > nwfc_buffer) CALL errore(subname,'nwfcx too large', 10)
          !
          !
          ! Beta projectors
          !
          IF ( nkb == 0 ) THEN
              nstep_kb = 1
              ALLOCATE( ibetas( nstep_kb), ibetae(nstep_kb), STAT=ierr)
              IF ( ierr/=0 ) CALL errore(subname,'allocating ibetas, ibetae', ABS(ierr))
              !
              ibetas   = 1
              ibetae   = 1
          ELSE
              nstep_kb = INT( nkb/ nkb_buffer )
              IF ( MOD( nkb, nkb_buffer) /= 0 ) nstep_kb = nstep_kb+1
              !
              ALLOCATE( ibetas(nstep_kb), ibetae(nstep_kb), STAT=ierr )
              IF ( ierr/=0 ) CALL errore(subname,'allocating ibetas, ibetae', ABS(ierr))
              !
              DO is = 1, nstep_kb
                  CALL divide_et_impera( 1, nkb, ibetas(is), ibetae(is), is-1, nstep_kb )
              ENDDO
              !
          ENDIF
          !
          nkbx = MAXVAL( ibetae(:) -ibetas(:) +1 )
          IF ( nkbx > nkb_buffer .AND. nkb_buffer /= 0 ) &
              CALL errore(subname,'nkbx too large', 10)
          !
          !
          !IF (ionode .AND. ( nwfc_buffer /= dimwinx .OR. nkb_buffer /= nkb ) ) THEN
          IF ( ionode ) THEN
              !
              WRITE( stdout, "(/, 1x, '<WFC_BUFFERING>',/ )")
              WRITE( stdout, "(   2x, '     dimwinx = ', i6)") dimwinx
              WRITE( stdout, "(   2x, ' nwfc_buffer = ', i6)") nwfc_buffer
              WRITE( stdout, "(   2x, '  nkb_buffer = ', i6)") nkb_buffer
              WRITE( stdout, "(   2x, '       nwfcx = ', i6)") nwfcx
              WRITE( stdout, "(   2x, '        nkbx = ', i6, /)") nkbx
              !
              DO ik_g = 1, nkpts_g
                  WRITE( stdout, "(4x, 'ik(',i4,' )  -->',i6,'  step(s)')") &
                         ik_g, nstep(ik_g) 
              ENDDO
              !
              WRITE( stdout, "(/, 4x,  'beta kb    -->',i6,'  step(s)')") nstep_kb
              !
              WRITE( stdout, "(/, 1x, '</WFC_BUFFERING>',/ )")
              !
          ENDIF


          !
          ! ... if USPP are used, initialize the related quantities
          !
          IF ( use_uspp ) THEN
              !
              IF ( .NOT. use_pseudo ) CALL errore(subname,'pseudo should be used',4)
              IF (ionode) WRITE( stdout,"(2x,'Initializing US pseudopot. data')")
              !
              IF ( nkb <= 0 ) CALL errore(subname,'no beta functions with USPP',-nkb+1)
              
              !
              ! ... first initialization
              !     here we compute (among other quantities) \int dr Q_ij(r)
              !                                              \int dr e^ibr Q_ij(r)
              CALL init_us_1()
              !
              IF ( use_blimit ) &
                 CALL warning( subname, "setting b = 0 in qb (overlap augment.)" )
                 !
              IF (ionode) &
                 WRITE( stdout, '(2x, "Total number Nkb of beta functions: ",i5 ) ') nkb

              !
              !
              ALLOCATE (vkb( npwkx, nkbx), STAT=ierr)    
              IF (ierr/=0) CALL errore(subname,'allocating vkb',ABS(ierr))
              !
              ALLOCATE( becp(nkb, nwfcx, 2), STAT=ierr )
              IF (ierr/=0) CALL errore(subname,'allocating becp',ABS(ierr))
              !
          ENDIF

          !
          ! ... if ATOMWFC are used
          !
          IF ( use_atomwfc ) THEN
              !
              IF ( .NOT. use_pseudo ) CALL errore(subname,'pseudo should be used',5)
              IF (ionode) WRITE( stdout,"(/,2x,'Initializing atomic wfc')")
              !
              ! ... atomic init
              CALL init_at_1()
              !
          ENDIF
          !
          IF ( ionode ) WRITE( stdout, "()" )
          CALL flush_unit( stdout )



          !
          ! we need anyway to have becp allocated even if it is not used
          ! becp(i,j,ik) = <beta_i |psi_j_ik >
          !
          IF ( .NOT. ALLOCATED(becp) ) THEN
              ALLOCATE( becp(1, 1, 2), STAT=ierr )
              IF (ierr/=0) CALL errore(subname,'allocating becp',ABS(ierr))
          ENDIF


          !
          ! Local workspace
          ALLOCATE( aux(nwfcx, nwfcx), STAT=ierr )
          IF (ierr/=0) CALL errore(subname,'allocating aux',ABS(ierr))
          ALLOCATE( aux1(nwfcx, dimwann), STAT=ierr )
          IF (ierr/=0) CALL errore(subname,'allocating aux1',ABS(ierr))
          ALLOCATE( aux2(nkbx, nwfcx), STAT=ierr )
          IF (ierr/=0) CALL errore(subname,'allocating aux2',ABS(ierr))

          !
          ! Allocating wfcs
          CALL wfc_info_allocate(npwkx, dimwinx, nkpts, 2*nwfcx, evc_info)
          !
          ALLOCATE( evc(npwkx, 2*nwfcx ), STAT=ierr )
          IF (ierr/=0) CALL errore(subname,'allocating EVC',ABS(ierr))

          !
          ! Re-open the main data file
          CALL io_name('dft_data',filename)
          CALL io_open_dftdata( LSERIAL=.FALSE. )


          !
          ! memory report
          CALL memusage( stdout )
          IF (ionode) WRITE( stdout, "()")

          !
          ! initializing Ca and Mkb
          IF ( do_proj_ )     proj(:,:,:)   = CZERO
          IF ( do_ovp_ )      Mkb(:,:,:,:)  = CZERO
          IF ( do_transl_ )   transl(:,:,:) = CZERO
      

          !
          ! main loop on kpts
          !
          kpoints_loop : &
          DO ik= 1, nkpts
             !
             ik_g = ik + iks-1
             !
             IF ( ionode ) THEN
                 WRITE(stdout,"( 4x,'Matrix elements calculation for k-point: ',i4)") ik_g
                 WRITE(stdout,"( 4x,'npw = ',i6,',', 4x,'dimwin = ',i4)") npwk(ik_g), dimwin(ik_g)
             ENDIF
             !
             CALL flush_unit( stdout )

             !
             ! loop over buffering steps
             !
             buffering_ik_loop : &
             DO is = 1, nstep( ik_g )
                 !
                 ibs = ibnds(is,ik_g)
                 ibe = ibnde(is,ik_g)
                 !
                 !
                 CALL wfc_data_kread( dftdata_fmt, ik_g, "IK", evc, evc_info, &
                                      imin(ik_g)+ibs-1, imin(ik_g)+ibe-1 )

                 IF ( use_uspp ) THEN
                     !
                     ! determine the index related to the first wfc of the current ik
                     ! to be used in evc to get the right starting point
                     !
                     index = wfc_info_getindex(imin(ik_g)+ibs-1, ik_g, "IK", evc_info )
                     !
                     xk(:) = vkpt_g(:,ik_g) / tpiba
                     !
                     DO ks = 1, nstep_kb
                         !
                         kbs = ibetas( ks ) 
                         kbe = ibetae( ks ) 
                         !
                         CALL init_us_2( npwk(ik_g), igsort(1,ik_g), xk, kbs, kbe, vkb )
                         !
                         CALL ccalbec( nkbx, kbe-kbs+1, npwkx, npwk(ik_g), ibe-ibs+1, &
                                       aux2, vkb, evc(1,index) )
                         !
                         becp( kbs:kbe, 1:ibe-ibs+1, 1) = aux2( 1:kbe-kbs+1, 1:ibe-ibs+1)
                         !
                     ENDDO
                     !
                 ENDIF


                 IF ( do_ovp_ ) THEN
                     !
                     ! overlap
                     !
                     neighbors_loop : &
                     DO inn=1,nb/2
                         !
                         ! here impose the symmetrization on Mkb: i.e.
                         ! M_ij(k,b) = CONJG( M_ji (k+b, -b) )
                         !
                         ! In order to do that we compute the Mkb integrals only 
                         ! for half of the defined b vectors and then impose the
                         ! other values by symmetry (at end of the driver)
                         !
                         ib    = nnpos(inn)
                         ikb_g = nnlist( ib , ik_g)
                         !
                         buffering_ikb_loop: &
                         DO js = 1, nstep( ikb_g )
                             !
                             jbs = ibnds(js,ikb_g)
                             jbe = ibnde(js,ikb_g)
                             ! 
                             ! 
                             CALL wfc_data_kread( dftdata_fmt, ikb_g, "IKB", evc, evc_info, &
                                                  imin(ikb_g)+jbs-1, imin(ikb_g)+jbe-1 )
                             !
                             IF( use_uspp ) THEN
                                 !
                                 index = wfc_info_getindex(imin(ikb_g)+jbs-1, ikb_g, "IKB", evc_info)
                                 !
                                 xk(:) = vkpt_g(:,ikb_g) / tpiba
                                 !
                                 DO ks = 1, nstep_kb
                                     !
                                     kbs = ibetas( ks ) 
                                     kbe = ibetae( ks ) 
                                     !
                                     CALL init_us_2( npwk(ikb_g), igsort(1,ikb_g), xk, kbs, kbe, vkb )
                                     !
                                     CALL ccalbec( nkbx, kbe-kbs+1, npwkx, npwk(ikb_g), &
                                                   jbe-jbs+1, aux2, vkb, evc(1,index))
                                     !
                                     becp( kbs:kbe, 1:jbe-jbs+1, 2) = aux2( 1:kbe-kbs+1, 1:jbe-jbs+1)
                                     !
                                 ENDDO
                                 !
                             ENDIF


                             !
                             !
                             CALL overlap_calc( ik_g, ikb_g, ibe-ibs+1, jbe-jbs+1, &
                                                imin(ik_g)+ibs-1, imin(ikb_g)+jbs-1, &
                                                nwfcx, evc, evc_info,  &
                                                igsort, nncell(1,ib,ik_g), aux )
                                                !
                             Mkb(ibs:ibe,jbs:jbe,inn,ik) = aux( 1:ibe-ibs+1, 1:jbe-jbs+1)

                             !
                             ! ... add the augmentation term fo USPP
                             !
                             IF ( use_uspp ) THEN
                                 !
                                 CALL overlap_augment( nwfcx, ibe-ibs+1, jbe-jbs+1, &
                                                       ib, aux )
                             
                                 Mkb( ibs:ibe, jbs:jbe, inn, ik ) = &
                                        Mkb( ibs:ibe, jbs:jbe, inn, ik ) + &
                                        aux(1:ibe-ibs+1, 1:jbe-jbs+1)
                                 !
                             ENDIF
              
                             !
                             ! clean nn wfc data (but not free memory!)
                             !
                             CALL wfc_info_delete(evc_info, LABEL="IKB" )

                         ENDDO buffering_ikb_loop
                         !
                     ENDDO neighbors_loop
                     !
                 ENDIF


                 IF ( do_proj_ ) THEN
                     !
                     ! projections
                     !
                     ! construct S \psi and use them instead of the base \psi 
                     ! (they are equal if NCPP case)
                     ! after the call to s_psi evc will contain the S \psi wfc
                     ! with the label SPSI_IK
                     ! 
                     indin = wfc_info_getindex( imin(ik_g)+ibs-1, ik_g, "IK", evc_info)
                     !
                     DO ib = imin(ik_g)+ibs-1, imin(ik_g)+ibe-1
                          CALL wfc_info_add(npwk(ik_g), ib, ik_g, 'SPSI_IK', evc_info)
                     ENDDO
                     !
                     indout = wfc_info_getindex(imin(ik_g)+ibs-1, ik_g, "SPSI_IK", evc_info)
 
                     !
                     ! buffering of vkb is dealt with inside the routine
                     !
                     CALL s_psi(npwkx, npwk(ik_g), ibe-ibs+1, ik_g, evc(:,indin:), evc(:,indout:), &
                                MAX(nkb,1), becp(:,:,1), nstep_kb, ibetas, ibetae)
                     !
                     CALL projection_calc( ik_g, ibe-ibs+1, imin(ik_g)+ibs-1, nwfcx, evc, evc_info, &
                                           dimwann, trial, aux1 )
                     !
                     proj(ibs:ibe, :, ik ) = aux1( 1:ibe-ibs+1, 1: dimwann )
                     !
                     ! clean the ik wfc data
                     CALL wfc_info_delete(evc_info, LABEL="SPSI_IK")
                     !
                 ENDIF
                 !
                 !
                 IF ( do_transl_ ) THEN
                     !
                     ! translations
                     !
                     ! compute the translation operator matrix elements on the
                     ! basis of the WFs
                     !
                     ! TR_ij = < i | S TR | j >
                     ! TR = e^{ip.R}
                     !
                     ! < G | TR | i >  =  c_G * e^-iGR  where
                     ! < G | i >  = c_G
                     !
                     ALLOCATE( aux_transl(nwfcx, nwfcx, nvect), STAT=ierr )
                     IF ( ierr/=0 ) CALL errore(subname,"allocating aux_transl",ABS(ierr))
                     ! 
                     ! 
                     indin = wfc_info_getindex( imin(ik_g)+ibs-1, ik_g, "IK", evc_info)
                     !
                     DO ib = imin(ik_g)+ibs-1, imin(ik_g)+ibe-1
                          CALL wfc_info_add(npwk(ik_g), ib, ik_g, 'SPSI_IK', evc_info)
                     ENDDO
                     !
                     indout = wfc_info_getindex(imin(ik_g)+ibs-1, ik_g, "SPSI_IK", evc_info)
 
                     !
                     ! buffering of vkb is dealt with inside the routine
                     !
                     CALL s_psi(npwkx, npwk(ik_g), ibe-ibs+1, ik_g, evc(:,indin:), evc(:,indout:), &
                                MAX(nkb,1), becp(:,:,1), nstep_kb, ibetas, ibetae)
                     !
                     ! clear the memory at IK
                     !
                     CALL wfc_info_delete(evc_info, LABEL="IK")
                     !
                     !
                     buffering_ik2_loop: &
                     DO js = 1, nstep( ik_g )
                         !
                         jbs = ibnds(js,ik_g)
                         jbe = ibnde(js,ik_g)
                         ! 
                         ! 
                         CALL wfc_data_kread( dftdata_fmt, ik_g, "IK_RIGHT", evc, evc_info, &
                                              imin(ik_g)+jbs-1, imin(ik_g)+jbe-1 )
  
                         !
                         ! compute translations
                         ! ibs, ibe:   S | psi >
                         ! jbs, jbe:     | psi >
                         !
                         CALL translations_calc( ik_g, ibe-ibs+1, jbe-jbs+1,         &
                                                 imin(ik_g)+ibs-1, imin(ik_g)+jbs-1, &
                                                 nwfcx, evc, evc_info, igsort(:,ik_g),&
                                                 nvect, rvect, aux_transl ) 
                                                 !
                         transl(ibs:ibe,jbs:jbe,1:nvect) = aux_transl( 1:ibe-ibs+1, 1:jbe-jbs+1, 1:nvect)
  
                         !
                         ! clean wfc data (but not free memory!)
                         !
                         CALL wfc_info_delete(evc_info, LABEL="IK_RIGHT" )
  
                     ENDDO buffering_ik2_loop
                     
                     !
                     ! clean the ik wfc data
                     !
                     CALL wfc_info_delete(evc_info, LABEL="SPSI_IK")
                     !
                     DEALLOCATE( aux_transl, STAT=ierr )
                     IF ( ierr/=0 ) CALL errore(subname,"deallocating aux_transl",ABS(ierr))
                     !
                 ENDIF
                 !
                 !
                 CALL wfc_info_delete(evc_info, LABEL="IK")
                 CALL timing_upto_now(stdout)
                 ! 
             ENDDO buffering_ik_loop
             !
          ENDDO kpoints_loop


          !
          ! re-closing the main data file
          CALL io_close_dftdata( LSERIAL=.FALSE. )


          !
          ! ... local cleaning
          DEALLOCATE( becp, STAT=ierr )
          IF (ierr/=0) CALL errore(subname,'deallocating becp',ABS(ierr))
          !
          IF ( use_uspp ) THEN
             DEALLOCATE( vkb, STAT=ierr )
             IF (ierr/=0) CALL errore(subname,'deallocating vkb',ABS(ierr))
          ENDIF
          !
          DEALLOCATE( aux, aux1, aux2, STAT=ierr )
          IF (ierr/=0) CALL errore(subname,'deallocating aux, aux1, aux2',ABS(ierr))
          !
          DEALLOCATE( ibnds, ibnde, nstep, ibetas, ibetae, STAT=ierr )
          IF (ierr/=0) CALL errore(subname,'deallocating ibnds -- ibetae',ABS(ierr))


          !
          ! ... clean the large amount of memory used by the wfcs and grids
          !
          CALL wfc_data_deallocate()
          CALL ggrids_deallocate()

          !
          ! end of the newly computed quantities
          !
      ENDIF


!
! ... Here read overlap or projections (or both) if needed
!     Note that only half of the overlaps are read, and then symmetrized
!     according to the +/- b symm
!
      IF ( read_ovp_ .OR. read_proj_ ) THEN
          !
          CALL io_name('overlap_projection',filename)
          CALL file_open(ovp_unit,TRIM(filename),PATH="/",ACTION="read", IERR=ierr)
          IF ( ierr/=0 ) CALL errore(subname, 'opening '//TRIM(filename), ABS(ierr)) 
          !
          CALL overlap_read(ovp_unit,"OVERLAP_PROJECTION", lfound, &  
               LOVERLAP=read_ovp_, LPROJECTION=read_proj_ )
               !
          IF ( .NOT. lfound ) CALL errore(subname,'reading ovp and proj',1)
          !
          CALL file_close(ovp_unit,PATH="/",ACTION="read", IERR=ierr)
          IF ( ierr/=0 ) CALL errore(subname, 'closing '//TRIM(filename), ABS(ierr)) 

          CALL io_name('overlap_projection',filename,LPATH=.FALSE., LPROC=.FALSE.)
          IF (ionode) WRITE(stdout, "(/)")
          !
          IF ( read_ovp_ .AND. ionode ) &
               WRITE( stdout,"(2x,'Overlaps read from file: ',a)") TRIM(filename)
          !
          IF ( read_proj_ .AND. ionode ) &
               WRITE( stdout,"(2x,'Projections read from file: ',a)") TRIM(filename)
          !
          IF (ionode) WRITE(stdout,"()")
          !
      ENDIF

      !
      ! to avoid any interference between read and write
      !
      CALL mp_barrier()

      !
      ! write projections and overlaps on file (if the case)
      !
      IF ( do_ovp .OR. do_proj_ .AND. .NOT. (read_ovp_ .AND. read_proj_ )  ) THEN

          IF ( ionode ) THEN
              !
              CALL io_name('overlap_projection',filename)
              CALL file_open(ovp_unit,TRIM(filename),PATH="/",ACTION="write", &
                                      FORM=TRIM(wantdata_form), IERR=ierr)
              IF ( ierr/=0 ) CALL errore(subname, 'opening '//TRIM(filename), ABS(ierr)) 
              !
          ENDIF
          !
          CALL overlap_write(ovp_unit,"OVERLAP_PROJECTION")
          !
          IF ( ionode ) THEN
              CALL file_close(ovp_unit,PATH="/",ACTION="write", IERR=ierr)
              IF ( ierr/=0 ) CALL errore(subname, 'closing '//TRIM(filename), ABS(ierr)) 
              !
              CALL io_name('overlap_projection',filename,LPATH=.FALSE., LPROC=.FALSE.)
              WRITE( stdout,"(/,'  Overlaps and projections written on file: ',a)") TRIM(filename)
          ENDIF
          !
      ENDIF

 
      !
      ! Finally, symmetrize to have both +b and -b
      ! In principle this is not needed, but it is useful in terms of 
      ! parallelization
      !
      IF ( do_ovp_ .OR. read_ovp_ ) THEN
          !
          CALL overlap_bsymm( dimwinx, nkpts, Mkb )
          !
      ENDIF


      CALL timing_upto_now( stdout )
      CALL flush_unit( stdout )
      !
      CALL timing(subname,OPR='stop')
      !
      CALL log_pop (subname)

   END SUBROUTINE wfc_drv_x


