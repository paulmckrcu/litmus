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
	minreg = 1;
	maxreg = 14
}

@include "BPFlitmusout.awk"

########################################################################
#
# Functions to emit PPC code.

# Emit PPC code for loading a constant into a register.
function do_load_const_genasm(regdst, cv) {
	add_bpf_line("li " regdst "," cv);
}

# Emit PPC code for regdst = READ_ONCE(regsrc).
function do_read_once_genasm(regdst, regsrc) {
	add_bpf_line("lwz " regdst ",0(" regsrc ")");
}

# Emit PPC code for WRITE_ONCE(regdst, regsrc).
function do_write_once_genasm(regdst, regsrc) {
	if (regsrc ~ /^[0-9][0-9]*$/) {
		add_bpf_line("li r15," regsrc);
		add_bpf_line("stw r15,0(" regdst ")");
	} else {
		add_bpf_line("stw " regsrc ",0(" regdst ")");
	}
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

# Emit PPC code for regdst = smp_store_release(regsrc).
function do_smp_store_release_genasm(regdst, regsrc) {
	add_bpf_line("lwsync");
	do_write_once_genasm(regdst, regsrc);
}

@include "c2asmfuncs.awk"
'
