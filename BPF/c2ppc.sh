#/bin/sh
#
# Usage: sh c2ppc.sh file.litmus
#
# See c2asmfuncs.awk for diagnostics information.

litmusfile=${1}
if ! test -r "${litmusfile}"
then
	echo ${litmusfile} unreadable. 1>&2
	echo Usage: sh c2ppc.sh file.litmus 1>&2
	exit 1
fi

basename="`echo ${litmusfile} | sed -e 's/\.litmus$//'`"
sed < "${litmusfile}" -e 's, *//.*$,,' |
awk -v litmusfile="${basename}" -v bs="\\" -v dq='"' '

BEGIN {
	archname = "PPC";
}

@include "BPFlitmusout.awk"

########################################################################
#
# Functions to emit PPC code.

# Emit PPC code for regdst = READ_ONCE(regsrc).
function do_read_once_genasm(regdst, regsrc) {
	add_bpf_line("lwz " regdst ",0(" regsrc ")");
}

# Emit PPC code for WRITE_ONCE(regdst, regsrc).
function do_write_once_genasm(regdst, regsrc) {
	add_bpf_line("stw " regsrc ",0(" regdst ")");
}

# Emit PPC code for smp_mb().  No need for _genasm because no registers
# to worry about at the litmus-test source-code level.
function do_smp_mb() {
	add_bpf_line("sync");
}

# Emit PPC code for smp_load_acquire(regdst, regsrc).
function do_smp_load_acquire_genasm(regdst, regsrc) {
	add_bpf_line("lwz " regdst ",0(" regsrc ")");
	add_bpf_line("lwsync");
}

# Emit PPC code for regdst = smp_load_release(regsrc).
function do_smp_store_release_genasm(regdst, regsrc) {
	add_bpf_line("lwsync");
	add_bpf_line("stw " regsrc ",0(" regdst ")");
}

@include "c2asmfuncs.awk"
'
