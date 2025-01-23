#/bin/sh
#
# Usage: sh c2bpf.sh file.litmus
#
# See c2asmfuncs.awk for diagnostics information.

litmusfile=${1}
if ! test -r "${litmusfile}"
then
	echo ${litmusfile} unreadable. 1>&2
	echo Usage: sh c2bpf.sh file.litmus 1>&2
	exit 1
fi

basename="`echo ${litmusfile} | sed -e 's/\.litmus$//'`"
sed < "${litmusfile}" -e 's, *//.*$,,' |
awk -v litmusfile="${basename}" -v bs="\\" -v dq='"' '

BEGIN {
	archname = "BPF";
}

@include "BPFlitmusout.awk"

########################################################################
#
# Functions to emit BPF code.

# Emit BPF code for regdst = READ_ONCE(regsrc).
function do_read_once_genasm(regdst, regsrc) {
	add_bpf_line(regdst " = *(u32 *)(" regsrc " + 0)");
}

# Emit BPF code for WRITE_ONCE(regdst, regsrc).
function do_write_once_genasm(regdst, regsrc) {
	add_bpf_line("*(u32 *)(" regdst " + 0) = " regsrc);
}

# Emit BPF code for smp_mb().  No need for _genasm because no registers
# to worry about at the litmus-test source-code level.
function do_smp_mb(  bpfregtmp, bpfregtmpv) {
	bpfregtmp = get_bpfreg("-tmp-");
	bpfregtmpv = allocate_greg("__temporary_" nprocs);
	add_bpf_line(bpfregtmp " = atomic_fetch_add((u64*)(" bpfregtmpv " + 0), " bpfregtmp ")");
}

# Emit BPF code for smp_load_acquire(regdst, regsrc).
function do_smp_load_acquire_genasm(regdst, regsrc) {
	add_bpf_line(regdst " = load_acquire((u32 *)(" regsrc " + 0))");
}

# Emit BPF code for regdst = smp_load_release(regsrc).
function do_smp_store_release_genasm(regdst, regsrc) {
	add_bpf_line("store_release((u32 *)(" regdst " + 0), " regsrc ")");
}

@include "c2asmfuncs.awk"
'
