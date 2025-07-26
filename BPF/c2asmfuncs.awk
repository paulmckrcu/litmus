# c2asmfuncs.awk: Architecture-independent code for converting C-lanaguage
# LKMM litmus tests to assembly language.
#
# Usage: @include "c2asmfuncs.awk"

# Given a C-language .litmus file that is within this script's
# capabilities (e.g., no RCU), produces a assembly-language litmus file.
#
# If the litmus test is malformed, a message is printed on stderr and
# a non-zero exit code is returned as follows:
#
# 1:	Specified file does not exist or is not a C-language litmus
#	test.
# 2:	A global variable of form 'r[0-9][0-9]*' cannot be distinguished
#	from a register, which is something that this script will not put
#	up with.
# 3:	The specified initialized local variable declaration was
#	something that this script cannot deal with.
# 4:	The specified variable was not declared in the specified
#	process.
# 5:	The specified WRITE_ONCE() was something that this script
#	cannot deal with.
# 6:	There are not enough BPF machine registers to translate the
#	specified process.
# 7:	The specified smp_store_release() was something that this script
#	cannot deal with.
# 8:	The specified line is a C statement that is not (yet) supported
#	by the script, for example, a call to an RCU function.  That line
#	is placed into the output as a ocaml comment "(* ...  *)".

# Global array usage:
#
# allvars[p:v]: Map from process p global variable or register v to
#	the corresponding BPF register.  [NEEDED? @@@]
# allvarscaps[p:v]: Map from process p global variable or register v
#	to the corresponding BPF register, but with capital "R".  This is
#	used when translating "exists" clauses and the like.
# bpfcode[p:n]: Map from process p line n to the corresponding line of
#	BPF assembly code.
# gvars[p:v]: Map from process p global variable v to the corresponding
#	BPF register.  Local registers get an empty string.
# nlines[p]: Current assembly output line while processing process p,
#	and the total number of lines afterwards.
# lvars[p:r]: Map from process p local register r to the corresponding
#	BPF register.  Global variables get an empty string.  A special
#	per-process "-tmp-" register gets a temporary BPF register.
# stmts[p:n]: Map from process p BPF assembly line n to the line of
#	BPF assembly code.  A non-existing line of code gets "".
#
# Global variable usage:
#
# exists_str: String accumulating "exists" clauses.
# filter_str: String accumulating "filter" clauses.
# goterror: Flag indicating an error has been encountered an that the
#	END-clause output should therefore be suppressed.
# gotinit: Flag saying that initialization has been found.
#	@@@ Why is this not in pstate?  There was some reason...
# gvreg: While processing a give process, the number of the BPF register
#	to assign for the next global variable.  Counts down from r10.
# hdrcomment: Header comment from original litmus test onto which things
#	like register mappings are appended.  Contains newlines.
# hdrcommentpiece: Header ending comment line needing "*)" removed.
# if_nesting: Zero if not in a "if" statement.  Nested "if" statements
#	are currently not supported, so the values zero and one are
#	currently all that you get.
# if_stmtsleft: Number of statements remaining in a curly-brace-free
#	"then" or "else" clause.  Set to -1 when not in such a clause.
# inits: Newline-containing string accumulating generated initialization.
# locations_str: String accumulating "locations" clauses.
# lvreg: While processing a give process, the number of the BPF register
#	to assign for the next process-local register.  Counts up from r1.
# nifs: Number of the "if" statement currently being processed within
#	the current process, or later, the total number of "if"
#	statements.
# nprocs: Number of the process currently being processed, or later, the
#	total number of processes.
# pstate: State variable containing a string.  An empty string denotes
#	the initial state and the state before and after processes.
# srcinits: Newline-containing string with original initialization.
#	This must undergo register translation from source to BPF.

# Append "more" to "s", with a newline if "s" was non-empty, returning
# the result.
function append_string_nl(s, more) {
	if (s != "")
		s = s "\n";
	return s more;
}

# Complain if there are no more BPF registers.
function check_bpfreg() {
	if (lvreg > gvreg) {
		print "Ran out of BPF registers in process P" nprocs " line " NR > "/dev/stderr";
		goterror = 1;
		exit 6;
	}
}

# Allocate the specified global access for the current process.
function allocate_greg(var,  bpfreg) {
	check_bpfreg();
	bpfreg = "r" gvreg;
	gvars[nprocs ":" var] = bpfreg;
	allvars[nprocs ":" var] = bpfreg;
	allvarscaps[nprocs ":" var] = nprocs ":R" gvreg;
	inits = append_string_nl(inits, "\t" nprocs ":" bpfreg " = " var ";");
	gvreg--;
	# print "P" nprocs " global variable " i " is " curvar " assigned to " gvars[nprocs ":" curvar];
	return bpfreg;
}

# Allocate the specified register local to the current process.
function allocate_lreg(reg,  bpfreg) {
	check_bpfreg();
	bpfreg = "r" lvreg;
	lvars[nprocs ":" reg] = bpfreg;
	allvars[nprocs ":" reg] = bpfreg;
	allvarscaps[nprocs ":" reg] = nprocs ":R" lvreg;
	hdrcomment = append_string_nl(hdrcomment, " * " nprocs ":" reg " -> " nprocs ":" bpfreg);
	lvreg++;
	return bpfreg;
}

# Remove casts and the like from the specified variable/register.
function clean_srcreg(srcregvar,  clean)
{
	if (srcregvar ~ /^[a-z_A-Z][a-z_A-Z0-9]*$/)
		return srcregvar;
	clean = srcregvar;
	gsub(/^.*)/, "", clean);
	return clean;
}

# Get BPF register corresponding to specified source register.
function get_bpfreg(srcreg,  bpfreg, cleanreg) {
	cleanreg = clean_srcreg(srcreg);
	bpfreg = lvars[nprocs ":" cleanreg];
	if (bpfreg == "") {
		if (srcreg == "-tmp-" || srcreg ~ /^r[0-9][0-9]*$/) {
			bpfreg = allocate_lreg(cleanreg);
		} else {
			print "Undeclared local " cleanreg " in P" nprocs " line " NR > "/dev/stderr";
			goterror = 1;
			exit 4;
		}
	}
	return bpfreg;
}

# Get BPF register corresponding to specified source register or variable.
function get_bpfreg_regvar(srcregvar,  bpfreg, cleanreg) {
	cleanreg = clean_srcreg(srcregvar);
	if (cleanreg ~ /^r[0-9][0-9]*$/ || cleanreg == "-tmp-") {
		bpfreg = lvars[nprocs ":" cleanreg];
		if (bpfreg == "")
			bpfreg = allocate_lreg(cleanreg);
	} else {
		bpfreg = gvars[nprocs ":" cleanreg];
	}
	if (bpfreg == "") {
		print "Undeclared register/global " cleanreg " in P" nprocs " line " NR > "/dev/stderr";
		goterror = 1;
		print "Global variable dump:";
		for (i in gvars)
			print i, gvars[i];
		exit 4;
	}
	return bpfreg;
}

# Get BPF register corresponding to specified source variable.
function get_bpfreg_var(srcvar,  bpfreg) {
	bpfreg = gvars[nprocs ":" srcvar];
	if (bpfreg == "") {
		print "Undeclared global " srcvar " in P" nprocs " line " NR > "/dev/stderr";
		goterror = 1;
		exit 4;
	}
	return bpfreg;
}

# Add the specified BPF assembly line to the current process.
function add_bpf_line(bpfline) {
	bpfcode[nprocs + 1 ":" ++nlines[nprocs]] = bpfline;
}

# Handle a regout = READ_ONCE(*rv).  An empty register name says to use
# the tmp register.  The "ro" argument is the full READ_ONCE(*rv).
function do_read_once(regout, ro,  bpfreg, bpfregvar, src) {
	src = ro;
	if (regout != "")
		bpfreg = get_bpfreg(regout);
	else
		bpfreg = get_bpfreg("-tmp-");
	gsub(/^READ_ONCE\(\*/, "", src);
	gsub(/\);$/, "", src);
	bpfregvar = get_bpfreg_regvar(src);
	do_read_once_genasm(bpfreg, bpfregvar);
}

# Handle a WRITE_ONCE(*rv, v).  The "wo" argument is the full
# WRITE_ONCE(*rv, v).  The "v" might be a constant, register,
# or global variable.
function do_write_once(wo,  bpfregdst, bpfregsrc, i, n_args, src, wo_args) {
	src = wo;
	gsub(/^	*WRITE_ONCE\(\*/, "", src);
	gsub(/\);$/, "", src);
	gsub(/ /, "", src);
	n_args = split(src, wo_args, ",");
	if (n_args != 2) {
		print "Malformed WRITE_ONCE() in P" nprocs " line " NR > "/dev/stderr";
		goterror = 1;
		exit 5;
	}
	bpfregdst = get_bpfreg_regvar(wo_args[1]);
	if (wo_args[2] ~ /^[0-9][0-9]*$/)
		bpfregsrc = wo_args[2];
	else
		bpfregsrc = get_bpfreg_regvar(wo_args[2]);
	do_write_once_genasm(bpfregdst, bpfregsrc);
}

# Handle a regout = smp_load_acquire(rv).  An empty register name
# says to use the tmp register.  The "sla" argument is the full
# smp_load_acquire(*rv).
function do_smp_load_acquire(regout, sla,  bpfreg, bpfregvar, src) {
	src = sla;
	if (regout != "")
		bpfreg = get_bpfreg(regout);
	else
		bpfreg = get_bpfreg("-tmp-");
	gsub(/^smp_load_acquire\(/, "", src);
	gsub(/\);$/, "", src);
	bpfregvar = get_bpfreg_regvar(src);
	do_smp_load_acquire_genasm(bpfreg, bpfregvar);
}

# Handle an smp_store_release(rv, v).  The "ssr" argument is the full
# smp_store_release(*rv, v).  The "v" might be a constant, register,
# or global variable.
function do_smp_store_release(ssr,  bpfregdst, bpfregsrc, cv, i, n_args, src, ssr_args) {
	src = ssr;
	gsub(/^	*smp_store_release\(/, "", src);
	gsub(/\);$/, "", src);
	gsub(/ /, "", src);
	n_args = split(src, ssr_args, ",");
	if (n_args != 2) {
		print "Malformed smp_store_release() in P" nprocs " line " NR > "/dev/stderr";
		goterror = 1;
		exit 7;
	}
	bpfregdst = get_bpfreg_regvar(ssr_args[1]);
	if (ssr_args[2] ~ /^[0-9][0-9]*$/) {
		cv = ssr_args[2];
		bpfregsrc = get_bpfreg("-tmp-");
		do_load_const_genasm(bpfregsrc, cv);
	} else {
		bpfregsrc = get_bpfreg_regvar(ssr_args[2]);
	}
	do_smp_store_release_genasm(bpfregdst, bpfregsrc);
}

# Create the tail of the "if" labels for the current "if" statement.
# This is prefixed with "ELSE" and "ENDIF" for the two labels.  Note that
# labels must be globally unique, as in herd7 has been happy to have on
# process branch to another process's label.
function make_if_label_tail() {
	return "_" nprocs "_" nifs;
}

# Map the specified string from source registers to BPF registers,
# returning the mapped string.
function map_to_bpf_regs(s,  i, mapcap) {
	mapcap = s;
	for (i in allvarscaps)
		gsub(i, allvarscaps[i], mapcap);
	gsub(/R/, "r", mapcap);
	return mapcap;
}

# Handle the specified declaration, which might include initialization.
# Initialization might be static or dynamic.
function do_decl(newdecl,  bpfreg, bpfregsrc, initstr, localname) {
	localname = newdecl;
	gsub(/;$/, "", localname);
	if (newdecl ~ /=/) {
		initstr = localname;
		gsub(/ *= *.*$/, "", localname);
		gsub(/^.*= */, "", initstr);
	}
	gsub(/.*[^r0-9]/, "", localname);
	bpfreg = allocate_lreg(localname);
	if (initstr != "") {
		if (initstr ~ /^[0-9][0-9]*$/) {
			inits = append_string_nl(inits, "\t" nprocs ":" bpfreg " = " initstr ":");
		} else if (initstr ~ /^[a-z_A-Z][a-z_A-Z0-9]*$/) {
			if (initstr ~ /^r[0-9][0-9]*$/) {
				bpfregsrc = get_bpfreg(initstr);
				add_bpf_line(bpfreg " = " bpfregsrc);
			} else {
				inits = append_string_nl(inits, "\t" nprocs ":" bpfreg " = " initstr ":");
			}
		} else if (initstr ~ /READ_ONCE\(/) {
			do_read_once(localname, initstr ";");
		} else if (initstr ~ /smp_load_acquire\(/) {
			do_smp_load_acquire(localname, initstr ";");
		} else {
			print "Troublesome initialization in P" nprocs " line " NR ": " initstr > "/dev/stderr";
			goterror = 1;
			exit 3;
		}
	}
}

# Output code for source code that this script cannot handle.
function do_bad_input_line(badline, msg,  errline, spc) {
	errline = badline;
	gsub(/^[ 	]*/, "", errline);
	gsub(/[ 	]*$/, "", errline);
	spc = ""
	if (msg != "")
		spc = " ";
	add_bpf_line("(* Line " NR ": " errline " ??? " msg spc "*)");
	# @@@ Uncomment the following line to get nice summary of unhandled statements.
	# print "(* Line " NR ": " errline " ??? " pstate " *)" >> "/tmp/badlines.txt";
	gotbadline++;
}

BEGIN {
	if_nesting = 0;
	if_stmtsleft = -1;
	nifs = -1;
	nprocs = 0;
	goterror = 0;
	gotbadline = 0;
}

# Process the file header line, which must begin with "C " for C-style
# LKMM litmus test.
NR == 1 {
	if ($0 !~ /^C /) {
		print "Malformed first line, expected " dq "C" dq > "/dev/stderr";
		goterror = 1;
		exit 1;
	}
	litmusname = substr($0, 3);
	pstate = "gotlitname";
	next;
}

# Ignore blank lines.
/^[ 	]*$/ {
	next;
}

# Ignore various types of automatically generated commentary.
/^"[a-zA-Z ]*"$/ {
	next;
}

/^Cycle=[a-zA-Z ]*$/ {
	next;
}

/^Relax=[a-zA-Z ]*$/ {
	next;
}

/^Safe=[a-zA-Z ]*$/ {
	next;
}

/^Prefetch=[a-zA-Z0-9:=, ]*$/ {
	next;
}

/^Com=[a-zA-Z ]*$/ {
	next;
}

/^Orig=[a-zA-Z ]*$/ {
	next;
}

# Various forms of header comments.  These are preserved for the
# benefit of scripts that process the "Result:" tag.  This script also
# adds variable-to-register mappings.
pstate ~ /^gotlitname$/ && /[ 	]*\(\*$/ {
	pstate = "incomment";
	next;
}

pstate ~ /^gotlitname$/ && /[ 	]*\(\*.*\*\)/ {
	hdrcomment = $0;
	sub(/\(\*/, "  ", hdrcomment);
	sub(/\*\)/, "", hdrcomment);
	pstate = "";
	next;
}

pstate ~ /^gotlitname$/ && /[ 	]*\(\*/ {
	hdrcomment = $0;
	sub(/\(/, " ", hdrcomment);
	pstate = "incomment";
	next;
}

pstate ~ /^incomment$/ && $0 !~ /\*\)$/ {
	hdrcomment = append_string_nl(hdrcomment, $0);
	next;
}

pstate ~ /^incomment$/ && /^ \*\)$/ {
	pstate = "";
	hdrcomment = append_string_nl(hdrcomment, " *");
	next;
}

pstate ~ /^incomment$/ && /\*\)$/ {
	pstate = "";
	hdrcommentpiece = $0;
	sub(/\*\)$/, "", hdrcommentpiece);
	hdrcomment = append_string_nl(hdrcomment, hdrcommentpiece);
	next;
}

# Various formats of initializers
!gotinit && /^{}$/ {
	gotinit = 1;
	next;
}

!gotinit && /^{$/ {
	gotinit = 1;
	pstate = "ininit";
	next;
}

pstate ~ /^ininit$/ && $0 !~ /^}$/ {
	srcinits = append_string_nl(srcinits, $0);
	next;
}

pstate ~ /^ininit$/ && $0 ~ /^}$/ {
	pstate = "";
	next;
}

# Process declaration on one line, including parameters.  Sorry, but
# the open curly brace must currently be on the next line.
pstate ~ /^$/ && $0 ~ /^P[0-9]*\(/ {
	gvreg = maxreg;
	lvreg = minreg;
	nlines[nprocs] = 0;
	phdr = $0;
	gsub(/P[0-9]*\(/, "", pdhr);
	gsub(/)/, "", pdhr);
	nargs = split(phdr, pargs, ",");
	for (i = 1; i <= nargs; i++) {
		# print "P" nprocs " global variable declaration " i " is " pargs[i];
		npieces = patsplit(pargs[i], psargs, /[a-z_A-Z0-9]*/);
		curvar = psargs[npieces];
		if (curvar == "")
			curvar = psargs[npieces - 1];
		if (curvar ~ /^r[0-9][0-9]*$/) {
			print "Variable " curvar " of form rN cannot be global in P" nprocs " line " NR > "/dev/stderr";
			goterror = 1;
			exit 2;
		}
		allocate_greg(curvar);
	}
	pstate = "inproc";
	next;
}

# A line containing a single open curly brace can start a process.
pstate ~ /^inproc$/ && $0 ~ /^{$/ {
	next;
}

# Handle "if" statements lacking curly braces, which we do by counting
# lines.  This means that a given braceless "if" statement's then-clause
# and else-clause must fit on a single line.
pstate ~ /^inproc$/ && if_stmtsleft >= 0 && !if_stmtsleft-- {
	labeltail = make_if_label_tail();
	add_bpf_line("ELSE" labeltail ":");
	add_bpf_line("ENDIF" labeltail ":");
	if_nesting = 0;
}

# Local variable declaration without initializer.
pstate ~ /^inproc$/ && $0 ~ /^	[a-zA-Z_][a-zA-Z_0-9]*[^=]*\<r[0-9][0-9]*;$/ {
	do_decl($0);
	next;
}

# Local variable declaration with initializer, which can include
# READ_ONCE() or smp_load_acquire().
pstate ~ /^inproc$/ && $0 ~ /^	[a-zA-Z_][a-zA-Z_0-9]*.*\<r[0-9][0-9]* *=.*;$/ {
	do_decl($0);
	next;
}

# READ_ONCE(), WRITE_ONCE(), and WRITE_ONCE(..., READ_ONCE()).
pstate ~ /^inproc$/ && $0 ~ /^		*r[0-9][0-9]* *= *READ_ONCE\(\*.*\);$/ {
	ro = $0;
	gsub(/^.*=[ 	]*/, "", ro);
	do_read_once($1, ro);
	next;
}

pstate ~ /^inproc$/ && $0 ~ /^		*WRITE_ONCE\(\*.*, *[a-z_A-Z0-9]*\);$/ {
	wo = $0;
	gsub(/^.*=[ 	]*/, "", wo);
	do_write_once(wo);
	next;
}

pstate ~ /^inproc$/ && $0 ~ /^		*WRITE_ONCE\(\*.*, *READ_ONCE\(\*.*\)\);$/ {
	ro = $0;
	gsub(/^.*, *READ_ONCE/, "READ_ONCE", ro);
	gsub(/));/, ");", ro);
	do_read_once("-tmp-", ro);
	wo = $0;
	gsub(/READ_ONCE\(\*.*\)\);$/, "-tmp-);", wo);
	do_write_once(wo);
	next;
}

# smp_mb().
pstate ~ /^inproc$/ && $0 ~ /^		*smp_mb\(\);$/ {
	do_smp_mb();
	next;
}

# smp_load_acquire().
pstate ~ /^inproc$/ && $0 ~ /^		*r[0-9][0-9]* *= *smp_load_acquire\(.*\);$/ {
	sla = $0;
	gsub(/^.*=[ 	]*/, "", sla);
	do_smp_load_acquire($1, sla);
	next;
}

# smp_store_release().
pstate ~ /^inproc$/ && $0 ~ /^		*smp_store_release\(.*, *[a-z_A-Z0-9]*\);$/ {
	ssr = $0;
	gsub(/^.*=[ 	]*/, "", ssr);
	do_smp_store_release(ssr);
	next;
}

pstate ~ /^inproc$/ && $0 ~ /^		*if *\(r[0-9][0-9]*)$/ {
	if (if_nesting) {
		do_bad_input_line($0, "nested " dq "if" dq " unsupported");
		next
	}
	if_nesting++;
	nifs++;
	ifcond = $0;
	sub(/^[	 ]*if \(/, "", ifcond);
	sub(/\)$/, "", ifcond);
	bpfreg = get_bpfreg(ifcond);
	labeltail = make_if_label_tail();
	do_if_cond_genasm(bpfreg, "ELSE" labeltail, "ENDIF" labeltail);
	if_stmtsleft = 1;
	next;
}

# A line consisting of a single unindented close curly brace marks the
# end of the current process.
pstate ~ /^inproc$/ && $0 ~ /^}$/ {
	if (if_nesting)
		do_bad_input_line($0, "unterminated " dq "if" dq);
	nprocs++;
	pstate = "";
	next;
}

# The locations, filter, and exists clauses after all processes.
/^locations\>/ {
	clause = $0;
	gsub(/locations */, "", clause);
	locations_str = append_string_nl(locations_str, clause);
	pstate = "locations";
	next;
}

/^filter\>/ {
	clause = $0;
	gsub(/filter */, "", clause);
	filter_str = append_string_nl(filter_str, clause);
	pstate = "filter";
	next;
}

/^exists\>/ {
	clause = $0;
	gsub(/exists */, "", clause);
	exists_str = append_string_nl(exists_str, clause);
	pstate = "exists";
	next;
}

{
	if (pstate == "locations")
		locations_str = append_string_nl(locations_str, $0);
	else if (pstate == "filter")
		filter_str = append_string_nl(filter_str, $0);
	else if (pstate == "exists")
		exists_str = append_string_nl(exists_str, $0);
	else
		do_bad_input_line($0, "");
}

END {
	if (!goterror) {
		# print "All-caps map:"
		# for (i in allvarscaps)
		# 	print i " -> " allvarscaps[i];
		# print "Mapped exists clause: " map_to_bpf_regs(exists_str);
		locations_str = map_to_bpf_regs(locations_str);
		filter_str = map_to_bpf_regs(filter_str);
		exists_str = map_to_bpf_regs(exists_str);
		output_litmus(litmusfile, litmusname, hdrcomment, inits, bpfcode, locations_str, filter_str, exists_str);
		if (gotbadline) {
			print "Unable to translate " gotbadline " line(s), see " dq "???" dq " in BPF output file" > "/dev/stderr";
			exit 8;
		}
	}
}
