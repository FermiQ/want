!
! Copyright (C) 2005 WanT Group
!
! This file is distributed under the terms of the
! GNU General Public License. See the file `License\'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!

!**********************************************************
   SUBROUTINE summary(iunit)
   !**********************************************************
   ! 
   ! Print out all the informnatins obtained from the 
   ! input and initialization routines.
   !
   USE kinds,                ONLY : dbl
   USE constants,            ONLY : ZERO
   USE parser_module,        ONLY : log2char
   USE mp_global,            ONLY : nproc
   USE E_hamiltonian_module, ONLY : dimT, dimE, dimB, shift_T
   USE E_correlation_module, ONLY : lhave_corr
   USE E_control_module,     ONLY : datafile_tot, datafile_emb, &
                                    datafile_sgm, datafile_sgm_emb, &
                                    transport_dir, nprint, write_embed_sgm
   USE T_egrid_module,       ONLY : ne, emin, emax, de, ne_buffer
   USE T_smearing_module,    ONLY : delta, smearing_type, nx_smear => nx, xmax
   USE T_kpoints_module,     ONLY : nkpts_par, nk_par, s_par, vkpt_par3D, wk_par, use_symm, &
                                    kpoints_alloc => alloc
   USE T_kpoints_module,     ONLY : nrtot_par, nr_par, ivr_par3D, wr_par
   USE T_kpoints_module,     ONLY : kpoints_imask
   USE io_module,            ONLY : work_dir, prefix, postfix
   !
   IMPLICIT NONE

   !
   ! input variables
   !
   INTEGER,   INTENT(in)  :: iunit

   !
   ! local variables
   !
   INTEGER      :: ik, ir
   INTEGER      :: nk_par3D(3)       ! 3D kpt mesh generator
   INTEGER      :: s_par3D(3)        ! 3D shifts
   INTEGER      :: nr_par3D(3)       ! 3D R-vect mesh generator

!--------------------------------------------------------

   CALL write_header( iunit, "INPUT Summary" )

   !
   ! <INPUT> section
   !
   WRITE(iunit,"( 2x,'<INPUT>')" )
   WRITE(iunit,"(   7x,'           prefix :',5x,   a)") TRIM(prefix)
   WRITE(iunit,"(   7x,'          postfix :',5x,   a)") TRIM(postfix)
   IF ( LEN_TRIM(work_dir) <= 65 ) THEN
      WRITE(iunit,"(7x,'            work_dir :',5x,   a)") TRIM(work_dir)
   ELSE
      WRITE(iunit,"(7x,'            work_dir :',5x,/,10x,a)") TRIM(work_dir)
   ENDIF
   WRITE(iunit,"( 7x,'         total dim. :',5x,i5)") dimT
   WRITE(iunit,"( 7x,'         embed dim. :',5x,i5)") dimE
   WRITE(iunit,"( 7x,'          bath dim. :',5x,i5)") dimB
   WRITE(iunit,"( 7x,'Transport Direction :',8x,i2)") transport_dir
   WRITE(iunit,"( 7x,'   Have Correlation :',5x,a)") log2char(lhave_corr)
   WRITE(iunit,"( )")
   WRITE(iunit,"( 7x,'             nprint :',5x,i5)") nprint
   WRITE(iunit,"( 7x,'          Shift_tot :',5x,f10.5)") shift_T
   WRITE(iunit,"( )")
   WRITE(iunit,"( 7x,'    global datafile :',5x,a)") TRIM(datafile_tot)
   WRITE(iunit,"( 7x,'     embed datafile :',5x,a)") TRIM(datafile_emb)
   WRITE(iunit,"( 7x,' sgm embed datafile :',5x,a)") TRIM(datafile_sgm_emb)
   WRITE(iunit,"( 7x,'    write sgm embed :',5x,a)") log2char(write_embed_sgm)
   !
   IF (lhave_corr) THEN
       WRITE(iunit,"( 7x,'  sgm corr datafile :',5x,a)") TRIM(datafile_sgm)
   ENDIF
   WRITE( iunit,"( 2x,'</INPUT>',2/)" )

   WRITE(iunit,"( 2x,'<ENERGY_GRID>')" )
   WRITE(iunit,"( 7x,'          Dimension :',5x,i6)")    ne
   WRITE(iunit,"( 7x,'          Buffering :',5x,i6)")    ne_buffer
   WRITE(iunit,"( 7x,'         Min energy :',5x,f10.5)") emin
   WRITE(iunit,"( 7x,'         Max energy :',5x,f10.5)") emax
   WRITE(iunit,"( 7x,'        Energy step :',5x,f10.5)") de
   WRITE(iunit,"( 7x,'              Delta :',5x,f10.5)") delta
   WRITE(iunit,"( 7x,'      Smearing type :',5x,a)")     TRIM(smearing_type)
   WRITE(iunit,"( 7x,'      Smearing grid :',5x,i6)")    nx_smear
   WRITE(iunit,"( 7x,'      Smearing gmax :',5x,f10.5)") xmax
   WRITE(iunit,"( 2x,'</ENERGY_GRID>',/)" )

   IF ( kpoints_alloc ) THEN
       !
       WRITE(iunit, "( /,2x,'<K-POINTS>')" )
       WRITE(iunit, "( 7x, 'nkpts_par = ',i4 ) " ) nkpts_par
       WRITE(iunit, "( 7x, 'nrtot_par = ',i4 ) " ) nrtot_par
       WRITE(iunit, "( 7x, ' use_symm = ',a  ) " ) TRIM(log2char(use_symm))
       !
       !
       nk_par3D(:) = kpoints_imask( nk_par, 1, transport_dir )
       s_par3D(:)  = kpoints_imask(  s_par, 0, transport_dir )
       !
       WRITE( iunit, "(/,7x, 'Parallel kpoints grid:',8x, &
                           &'nk = (',3i3,' )',3x,'s = (',3i3,' )') " ) nk_par3D(:), s_par3D(:) 
       !
       DO ik=1,nkpts_par
           !
           WRITE( iunit, "(7x, 'k (', i4, ') =    ( ',3f9.5,' ),   weight = ', f8.4 )") &
                 ik, vkpt_par3D(:,ik), wk_par(ik)
           !
       ENDDO
       !
       nr_par3D(:) = kpoints_imask( nr_par, 1, transport_dir )
       !
       WRITE( iunit, "(/,7x, 'Parallel R vector grid:      nr = (',3i3,' )') " ) nr_par3D(:) 
       !
       DO ir=1,nrtot_par
           !
           WRITE( iunit, "(7x, 'R (', i4, ') =    ( ',3f9.5,' ),   weight = ', f8.4 )") &
                  ir, REAL(ivr_par3D(:,ir),dbl), wr_par(ir)
           !
       ENDDO
       !    
       WRITE( iunit, " ( 2x,'</K-POINTS>',/)" )
       !
   ENDIF
   !
   !
   WRITE( iunit, "( /,2x,'<PARALLELISM>')" )
   WRITE( iunit, "(   7x, 'Paralellization over frequencies' ) " )
   WRITE( iunit, "(   7x, '# of processes: ', i5 ) " ) nproc
   WRITE( iunit, "(   2x,'</PARALLELISM>',/)" )
   !
   CALL flush_unit( iunit )
   !
   RETURN
   !
END SUBROUTINE summary

