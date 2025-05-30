#
#===============================
# WanT package
#===============================
#
include ../../make.sys


OBJS= \
allocate_nlpot.o \
atmproj_tools.o \
atom.o \
atomic.o \
atomic_wfc.o \
bachel.o \
becmod.o \
bshells_init.o \
ccalbec.o \
cleanup.o \
collect_wf.o \
compute_kham.o \
compute_kham_2D.o \
compute_rham.o \
control.o \
converters.o \
correlation.o \
cp2k_tools.o \
crystal_tools.o \
datafiles.o \
domega_aux.o \
domega.o \
dyson_solver.o \
etsf_io_data.o \
functionals.o \
get_monkpack.o \
get_points.o \
get_rgrid.o \
get_vectmap.o \
gglobal.o \
ggrids.o \
hamiltonian_calc.o \
hamiltonian.o \
init_at_1.o \
init_us_1.o \
init_us_2.o \
input.o \
input_base.o \
input_manager.o \
input_parameters.o \
internal_tools.o \
io_module.o \
io_tools.o \
ions.o \
kpoints.o \
lattice.o \
localization.o \
localization_init.o \
memusage.o \
monkpack.o \
omega.o \
omegai.o \
operator.o \
ordering.o \
overlap_augment.o \
overlap_bsymm.o \
overlap_extract.o \
overlap_calc.o \
overlap_module.o \
overlap_setmap.o \
overlap_update.o \
paratools.o \
polarization.o \
postproc_init.o \
projection_calc.o \
projection_frozen.o \
pseudo_types.o \
pwcom.o \
qvan2.o \
radial_grids.o \
random_orthovect.o \
read_fileqp.o \
read_ncpp.o \
read_pseudo.o \
read_upf_v1.o \
read_upf_v2.o \
read_uspp.o \
recips.o \
s_psi.o \
setqf.o \
shutdown.o \
smearing_base.o \
sort_gvec.o \
startup.o \
struct_fact_data.o \
struct_fact.o \
subspace.o \
subspace_init.o \
summary.o \
symmetrize_kgrid.o \
symmetry.o \
translations.o \
translations_calc.o \
translations_calc_atmproj.o \
trial_center_data.o \
trial_center.o \
unitary_update.o \
upf.o \
upf_to_internal.o \
uspp.o \
version.o \
wannier90_tools.o \
want_dftread.o \
want_init.o \
want_interfaces.o \
wf2_augment.o \
wfc_data.o \
wfc_info.o \
wfc_drv.o \
windows.o \
workspace_wan.o \
workspace_dis.o \
write_decay.o \
write_upf_v2.o \
xsf.o \
zmatrix.o

BIN= \
disentangle.x \
wannier.x \
blc2wan.x \
bands.x \
cmplx_bands.x \
dos.x \
plot.x \
unfold.x

LIBOBJS = ../baselib/libbase.a ../clib/libclib.a
BIN_DEPS=      $(OBJS) $(LIBOBJS)

#
# main targets
#
all : libwannier.a $(BIN)


libwannier.a : $(OBJS)
	$(AR) $(ARFLAGS) $@ $?
	$(RANLIB) $@

disentangle.x: disentangle.o $(BIN_DEPS)
	$(LD) $(LDFLAGS) -o $@ disentangle.o $(OBJS) $(LIBOBJS) $(LIBS)
	- ( cd ../../bin ; ln -sf ../src/wannier/$@ . )

wannier.x:     wannier.o $(BIN_DEPS)
	$(LD) $(LDFLAGS) -o $@ wannier.o $(OBJS) $(LIBOBJS) $(LIBS)
	- ( cd ../../bin ; ln -sf ../src/wannier/$@ . )

blc2wan.x:     blc2wan.o $(BIN_DEPS)
	$(LD) $(LDFLAGS) -o $@ blc2wan.o $(OBJS) $(LIBOBJS) $(LIBS)
	- ( cd ../../bin ; ln -sf ../src/wannier/$@ . )

bands.x:       bands.o $(BIN_DEPS)
	$(LD) $(LDFLAGS) -o $@ bands.o $(OBJS) $(LIBOBJS) $(LIBS)
	- ( cd ../../bin ; ln -sf ../src/wannier/$@ . )

cmplx_bands.x:       cmplx_bands.o $(BIN_DEPS)
	$(LD) $(LDFLAGS) -o $@ cmplx_bands.o $(OBJS) $(LIBOBJS) $(LIBS)
	- ( cd ../../bin ; ln -sf ../src/wannier/$@ . )

dos.x:         dos.o $(BIN_DEPS)
	$(LD) $(LDFLAGS) -o $@ dos.o $(OBJS) $(LIBOBJS) $(LIBS)
	- ( cd ../../bin ; ln -sf ../src/wannier/$@ . )

plot.x:        plot.o $(BIN_DEPS)
	$(LD) $(LDFLAGS) -o $@ plot.o $(OBJS) $(LIBOBJS) $(LIBS)
	- ( cd ../../bin ; ln -sf ../src/wannier/$@ . )

unfold.x:      unfold.o $(BIN_DEPS)
	$(LD) $(LDFLAGS) -o $@ unfold.o $(OBJS) $(LIBOBJS) $(LIBS)
	- ( cd ../../bin ; ln -sf ../src/wannier/$@ . )


#
# cleaning
#
clean:
	- /bin/rm -rf *.o *.a *core *.F90 work.pc work.pcl *.mod *.x

# dependencies
include make.depend

