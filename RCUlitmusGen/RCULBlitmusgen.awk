# Generate a load-buffering LISA litmus test.
#
# Usage:
#	generate_lisa(desc);
#
# The "desc" argument is a string describing the litmus test.  This string
# is a space-separated (or "+"-separated) list consisting of one entry of
# global information followed by a list of per-rf descriptions.  The global
# information is a three-character string as follows:
#
#	[GL]: Global or local transitivity
#	[RW]: The first process reads or writes.
#	[RW]: The last process reads or writes.
#
#	For example, "GRW" would be a test for global transitivity
#	where the first process reads and the last process writes.
#
# The per-rf information describes a write-to-read operation of the form
# W-R as follows:
#
# W:	A: Use rcu_assign_pointer(), AKA w[assign].  Deprecated, use "R".
#	B: Use smp_mb(), AKA f[mb].
# 	O: Use WRITE_ONCE(), AKA w[once].
#	Q: C11 release seQuence:  Follow bogus ordered write with [once].
#	R: Use smp_write_release(), AKA w[release].
#
#	Only one of "A", "O", or "R" may be specified for a given rf link.
#	It is legal to add "B" and/or "Q" to any of them.
#
# R:	A: Use smp_read_acquire(), AKA r[acquire].
#	B: Use smp_assign_pointer, AKA f[mb].
#	c: Impose control dependency.
#	C: Impose control dependency with f[rmb].
#	d: Impose dependency (address dependency, historical!).
#	D: Use data dependency, AKA r[deref].
#	k: Use fake control dependency (write after "if").
#	L: Use non-RCU data dependency, AKA r[lderef].  Deprecated, use "D".
#	O: Use READ_ONCE(), AKA r[once].
#	v: Impose value dependency (data dependency, historical!)
#
#	Exactly one of "A", "D", "L", or "O" may be specified for a
#	given rf link, but any or all of "B", "c", and "d" may be added
#	in either case.
#
# A litmus test with N processes will have N-1 W-R per-rf descriptors.
#
#
# These tests map into the "periodic table" set of tests as follows
# (https://www.cl.cam.ac.uk/~pes20/ppc-supplemental/test6.pdf):
#
# GRR R-A: ISA2
# GRW R-A: 3.LB
# GWR R-A: W+WRC (allowed on Power)
# GWW R-A: ISA2
#
# LRR R-A: WRC
# LRW R-A R-A: 3.LB
# LWR R-A R-A: ISA2
# LWW R-A R-A: Z6.2
#
# I am currently assuming that adding release-acquire segments to a
# forbidden litmus test results in another forbidden litmus test.
#
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, you can access it online at
# http://www.gnu.org/licenses/gpl-2.0.html.
#
# Copyright (C) IBM Corporation, 2015
#
# Authors: Paul E. McKenney <paulmck@linux.vnet.ibm.com>

@include "RCUlitmusout.awk"
@include "RCUlitmusCout.awk"

########################################################################
#
# Global variables:
#
# comment: String containing the comment field, which may be multi-line.
# initializers: String containing initializers, which may be multi-line.
# exists: String containing the "exists" clause, which may be multi-line.
# i_dir[proc_num]: Incoming (read) directive
# i_op[proc_num]: Incoming operand ("r" or "w")
# i_mod[proc_num]: Incoming modifier ("once", "acquire", ...)
# i_operand1[proc_num]: Incoming first operand (register or variable)
# i_operand2[proc_num]: Incoming second operand (register or variable)
# i_val[proc_num]: Incoming variable expected value
# i_var[proc_num]: Incoming variable
# o_dir[proc_num]: Outgoing (write) directive
# o_op[proc_num]: Outgoing operand ("r" or "w")
# o_mod[proc_num]: Outgoing modifier ("once", "acquire", ...)
# o_operand1[proc_num]: Outgoing first operand (register or variable)
# o_operand2[proc_num]: Outgoing second operand (register or variable)
# o_var[proc_num]: Outgoing variable
# rf[rf_num]: Read-from directive
# stmts[proc_num ":" line_num]: Marshalled LISA statements
# vars[proc_num ":" name]: Global variables used by each process

########################################################################
#
# Initialize cycle-evaluation arrays and matrices.  Reads-from and
# in-process transitions are handled by cycle_rf and cycle_proc,
# respectively.  First-process in-process transitions are special:
# cycle_proc1.  Last-process in-process transitions depend on the type of
# the trailing access: cycle_procnR and cycl_procnW.  Each element
# is of the form "X:reason", where "X" is Sometimes, Maybe, or Never.
# The "reason" can be empty and normally will be for Never.
#
function initialize_cycle_evaluation() {
	# First-process transitions
	cycle_proc1["A"] = "Never:Deprecated, use \"R\" instead";
	cycle_proc1["B"] = "Never";
	cycle_proc1["O"] = "Sometimes:No ordering";
	cycle_proc1["R"] = "Never";

	# Last-process transitions for trailing read
	cycle_procnR["A"] = "Never";
	cycle_procnR["B"] = "Never";
	cycle_procnR["C"] = "Sometimes:Control dependencies do not order trailing reads";
	cycle_procnR["D"] = "Never";
	cycle_procnR["O"] = "Sometimes:No ordering";

	# Last-process transitions for trailing write
	cycle_procnW["A"] = "Never";
	cycle_procnW["B"] = "Never";
	cycle_procnW["C"] = "Maybe:Note lack of C11 guarantee, control dependency";
	cycle_procnW["D"] = "Never";
	cycle_procnW["O"] = "Sometimes:No ordering";

	# Read-from transitions
	cycle_rf["A:A"] = "Never";
	cycle_rf["A:B"] = "Never";
	cycle_rf["A:C"] = "Maybe:Note lack of C11 guarantee, control dependency";
	cycle_rf["A:D"] = "Never";
	cycle_rf["A:O"] = "Maybe:Note lack of C11 guarantee, no synchronizes-with";
	cycle_rf["B:A"] = "Never";
	cycle_rf["B:B"] = "Never";
	cycle_rf["B:C"] = "Maybe:Note lack of C11 guarantee, control dependency";
	cycle_rf["B:D"] = "Never";
	cycle_rf["B:O"] = "Maybe:Note lack of C11 guarantee, no synchronizes-with";
	cycle_rf["R:A"] = "Never";
	cycle_rf["R:B"] = "Never";
	cycle_rf["R:C"] = "Maybe:Note lack of C11 guarantee, control dependency";
	cycle_rf["R:D"] = "Never";
	cycle_rf["R:O"] = "Maybe:Note lack of C11 guarantee, no synchronizes-with";
	cycle_rf["O:A"] = "Maybe:Note lack of C11 guarantee, no synchronizes-with";
	cycle_rf["O:B"] = "Maybe:Note lack of C11 guarantee, no synchronizes-with";
	cycle_rf["O:C"] = "Maybe:Note lack of C11 guarantee, no synchronizes-with";
	cycle_rf["O:D"] = "Maybe:Note lack of C11 guarantee, no synchronizes-with";
	cycle_rf["O:O"] = "Maybe:Note lack of C11 guarantee, no synchronizes-with";

	# Process transitions
	cycle_proc["A:A"] = "Never:Deprecated, use \"R\" instead of Assign";
	cycle_proc["A:B"] = "Never";
	cycle_proc["A:O"] = "Never";
	cycle_proc["A:R"] = "Never";
	cycle_proc["B:A"] = "Never:Deprecated, use \"R\" instead of Assign";
	cycle_proc["B:B"] = "Never";
	cycle_proc["B:O"] = "Never";
	cycle_proc["B:R"] = "Never";
	cycle_proc["C:A"] = "Maybe:Note lack of C11 guarantee\n\tDeprecated, use \"R\" instead of Assign";
	cycle_proc["C:B"] = "Maybe:Note lack of C11 guarantee";
	cycle_proc["C:O"] = "Maybe:Note lack of C11 guarantee";
	cycle_proc["C:R"] = "Maybe:Note lack of C11 guarantee";
	cycle_proc["D:A"] = "Never:Deprecated, use \"R\" instead of Assign";
	cycle_proc["D:B"] = "Never";
	cycle_proc["D:O"] = "Never";
	cycle_proc["D:R"] = "Never";
	cycle_proc["O:A"] = "Maybe:Note lack of C11 guarantee\n\tDeprecated, use \"R\" instead of Assign";
	cycle_proc["O:B"] = "Never";
	cycle_proc["O:O"] = "Sometimes:No ordering";
	cycle_proc["O:R"] = "Maybe:Note lack of C11 guarantee";
}

########################################################################
#
# Check the syntax of the specified process's initial directive string.
# Complain and exit if there is a problem.
#
function gen_global_syntax(x) {
	if (x !~ /^[LG][RW][RW]$/) {
		print "Global information bad format: " x > "/dev/stderr";
		exit 1;
	}
}

########################################################################
#
# Check the syntax of the specified reads-from (rf) directive string.
# Complain and exit if there is a problem.
#
function gen_rf_syntax(rfn, x, y, xn, yn) {
	if ((x ~ /A/) + (x ~ /O/) + (x ~ /R/) != 1) {
		print "Reads-from edge " rfn " only one of \"AOR\" allowed in write-side specifier: \"" x "\"" > "/dev/stderr";
	}
	if (x !~ /^[ABOQR]*$/) {
		print "Reads-from edge " rfn " bad write-side specifier: \"" x "\"" > "/dev/stderr";
		exit 1;
	}
	if (y ~ /v/ && xn ~ /Q/) {
		print "Reads-from edge " rfn " Cannot mix Q with next v: \"" y "\", \"" xn "\"" > "/dev/stderr";
		exit 1;
	}
	if (x ~ /Q/ && y ~ /d/) {
		print "Reads-from edge " rfn " Cannot mix Q with d: \"" x "\", \"" y "\"" > "/dev/stderr";
		exit 1;
	}
	if (y ~ /v/ && yn ~ /d/) {
		print "Reads-from edge " rfn " Cannot mix v with next d: \"" y "\", \"" yn "\"" > "/dev/stderr";
		exit 1;
	}
	if (y ~ /[^ABcCdDkLOv]/) {
		print "Reads-from edge " rfn " bad read-side specifier: \"" y "\"" > "/dev/stderr";
		exit 1;
	}
	if ((y ~ /A/) + (y ~ /D/) + (y ~ /L/) + (y ~ /O/) != 1) {
		print "Reads-from edge " rfn " only one of \"ADLO\" in read-side specifier: \"" y "\"" > "/dev/stderr";
		exit 1;
	}
	if ((y ~ /d/) + (y ~ /v/) > 1) {
		print "Reads-from edge " rfn " only one of \"dv\" in read-side specifier: \"" y "\"" > "/dev/stderr";
		exit 1;
	}
	if ((y ~ /c/) + (y ~ /C/) + (y ~ /k/) > 1) {
		print "Reads-from edge " rfn " only one of \"cCk\" in read-side specifier: \"" y "\"" > "/dev/stderr";
		exit 1;
	}
}

########################################################################
#
# Generate the incoming and outgoing variable names for each process and
# place them into the i_dir[] and o_dir[] arrays.
#
function gen_vars(g, n,  p, tvar, v, vn) {
	# Form the name of the last process's test variable
	if (g ~ /^L/)
		tvar = "u0";
	else
		tvar = "v0";

	for (p = 1; p <= n; p++) {
		v = p - 1;
		vn = v + 1;

		# Incoming variable
		if (p == 1)
			i_var[p] = "u0";
		else
			i_var[p] = "x" v;

		# Outgoing variable
		if (p == n)
			o_var[p] = tvar;
		else
			o_var[p] = "x" vn;
	}
}

########################################################################
#
# Parse the specified process's directive string and set up that
# process's LISA statements. Arguments are as follows:
#
# p: Number of current process, based from 1.
# n: Number of processes.
# g: Global directive.
# x: Current process's read directive.
# y: Current process's write directive.
# xn: Next process's read directive, used to set up for data dependency.
#
# This function operates primarily by side effects on global variables.
#
function gen_proc(p, n, g, x, y, xn,  i, line_num, tvar, vi, vo, vno) {
	vi = i_var[p]; /* Input variable. */
	vo = o_var[p]; /* Output variable. */
	vno = o_var[p == n ? 1 : p + 1]; /* Next process's output variable. */

	# Form incoming statement base.
	if (p == 1) {
		i_mod[p] = "once";
		if (g ~ /R[RW]$/) {
			i_op[p] = "r";
			i_operand1[p] = "r1";
			i_operand2[p] = i_var[p];
			vars[p ":" i_var[p]] = 1;
		} else {
			i_op[p] = "w";
			i_operand1[p] = i_var[p];
			vars[p ":" i_var[p]] = 1;
			i_operand2[p] = "3";
		}
	} else {
		if (x ~ /A/)
			i_mod[p] = "acquire";
		else if (x ~ /D/)
			i_mod[p] = "deref";
		else if (x ~ /L/)
			i_mod[p] = "lderef";
		else
			i_mod[p] = "once";
		i_op[p] = "r";
		i_operand1[p] = "r1";
		i_operand2[p] = i_var[p];
		vars[p ":" i_var[p]] = 1;
		if (x ~ /[cCk]/ && x !~ /d/)
			initializers = initializers " " p - 1 ":r4=1;";
		else if (x ~ /[cCk]/)
			initializers = initializers " " p - 1 ":r4=" o_var[p] ";";
	}

	# Form outgoing statement base.
	if (p == n ) {
		o_mod[p] = "once";
		if (g ~ /R$/) {
			o_op[p] = "r";
			if (x ~ /v/) {
				print "Last reads-from edge: Cannot do value/data dependency (\"v\") to trailing read" > "/dev/stderr";
				exit 1;
			}
			o_operand1[p] = "r2";
			if (x ~ /d/) {
				o_operand2[p] = "r1";
			} else {
				o_operand2[p] = o_var[p];
				vars[p ":" o_var[p]] = 1;
			}
		} else {
			o_op[p] = "w";
			if (x ~ /d/) {
				o_operand1[p] = "r1";
			} else {
				o_operand1[p] = o_var[p];
				vars[p ":" o_var[p]] = 1;
			}
			if (x ~ /v/) {
				o_operand2[p] = "r1";
				i_val[1] = i_val[p];
			} else {
				o_operand2[p] = "1";
				i_val[1] = "1";
			}
		}
	} else {
		if (y ~ /A/)
			o_mod[p] = "assign";
		else if (y ~ /R/)
			o_mod[p] = "release";
		else
			o_mod[p] = "once";
		o_op[p] = "w";
		if (x ~ /d/) {
			o_operand1[p] = "r1";
		} else {
			o_operand1[p] = o_var[p];
			vars[p ":" o_var[p]] = 1;
		}
		if (xn ~ /d/) {
			o_operand2[p] = "r3";
			initializers = initializers " " p - 1 ":r3=" o_var[p + 1] ";";
			initializers = initializers " " o_var[p] "=y" p ";";
			i_val[p + 1] = o_var[p + 1];
		} else if (x ~ /v/) {
			o_operand2[p] = "r1";
			i_val[p + 1] = i_val[p];
		} else {
			o_operand2[p] = "1";
			if (y ~ /Q/)
				o_operand3[p] = 2;
			i_val[p + 1] = "1";
		}
	}

	# Output statements
	line_num = 0;
	stmts[p ":" ++line_num] = i_op[p] "[" i_mod[p] "] " i_operand1[p] " " i_operand2[p];
	if (x ~ /[cCk]/) {
		stmts[p ":" ++line_num] = "mov r4 (neq r1 r4)";
		stmts[p ":" ++line_num] = "b[] r4 CTRL" p - 1;
	}
	if (x ~ /[C]/)
		stmts[p ":" ++line_num] = "f[rmb]";
	if (x ~ /B/ || y ~ /B/)
		stmts[p ":" ++line_num] = "f[mb]";
	if (x ~ /k/) {
		stmts[p ":" ++line_num] = "r[once] r4 z" p - 1;
		vars[p ":" "z" p - 1] = 1;
		stmts[p ":" ++line_num] = "CTRL" p - 1 ":";
	}
	if (y ~ /Q/) {
		stmts[p ":" ++line_num] = o_op[p] "[" o_mod[p] "] " o_operand1[p] " " o_operand3[p];
		stmts[p ":" ++line_num] = o_op[p] "[once] " o_operand1[p] " " o_operand2[p];
	} else {
		stmts[p ":" ++line_num] = o_op[p] "[" o_mod[p] "] " o_operand1[p] " " o_operand2[p];
	}
	if (x ~ /[cC]/)
		stmts[p ":" ++line_num] = "CTRL" p - 1 ":";
}

########################################################################
#
# Add a term to the exists clause.  Terms are separated by AND.
#
# e: Exists clause to add.
#
function gen_add_exists(e) {
	if (exists == "")
		exists = e;
	else
		exists = exists " /\\ " e;
}

########################################################################
#
# Generate the auxiliary process given a global-transitivity litmus test.
# This function also adds the corresponding "exists" clauses.
#
# Arguments:
#
# g: Global information descriptor
# n: Number of processes (not counting possible auxiliary process).
#
function gen_aux_proc_global(g, n,  line_num) {
	line_num = 0;
	if (g ~ /^G[RW]R$/) {
		stmts[n + 1 ":" ++line_num] = "w[once] v0 1"
		vars[n + 1 ":" "v0"] = 1;
		gen_add_exists(n - 1 ":r2=0");
	} else {
		stmts[n + 1 ":" ++line_num] = "r[once] r1 v0"
		vars[n + 1 ":" "v0"] = 1;
		gen_add_exists(n ":r1=1");
	}
	stmts[n + 1 ":" ++line_num] = "f[mb]"
	if (g ~ /^GR[RW]$/) {
		stmts[n + 1 ":" ++line_num] = "w[once] u0 1"
		vars[n + 1 ":" "u0"] = 1;
		i_val[1] = "1";
		gen_add_exists("0:r1=1");
	} else {
		stmts[n + 1 ":" ++line_num] = "r[once] r2 u0"
		vars[n + 1 ":" "u0"] = 1;
		gen_add_exists(n ":r2=0");
	}
}

########################################################################
#
# Generate the auxiliary process given a local-transitivity litmus test.
# This function also adds the corresponding "exists" clauses.
#
# Arguments:
#
# g: Global information descriptor
# n: Number of processes (not counting possible auxiliary process).
#
function gen_aux_proc_local(g, n,  line_num) {
	line_num = 0;
	if (g == "LRR") {
		stmts[n + 1 ":" ++line_num] = "w[once] u0 1"
		i_val[1] = "1";
		gen_add_exists("0:r1=1");
		gen_add_exists(n - 1 ":r2=0");
	} else if (g == "LRW") {
		gen_add_exists("0:r1=" i_val[1]);
	} else if (g == "LWR") {
		gen_add_exists(n - 1 ":r2=0");
	} else {
		gen_add_exists("u0=3");
	}
}

########################################################################
#
# Generate the auxiliary process for the current litmus test, if one is
# required.  One is required for tests of global transitivity (which is the
# gen_aux_proc_global() function's job) and for tests of local transitivity
# where both operations are reads (which is the gen_aux_proc_local()
# function's job).  These functions also add the corresponding "exists"
# clauses.
#
# Arguments:
#
# g: Global information descriptor
# n: Number of processes (not counting possible auxiliary process).
#
function gen_aux_proc(g, n) {
	if (g ~ /^G/)
		gen_aux_proc_global(g, n);
	else
		gen_aux_proc_local(g, n);
}

########################################################################
#
# Generate the exists clause.
#
# n: Number of processes.
#
function gen_exists(n,  proc_num, wrcmp) {
	for (proc_num = 2; proc_num <= n; proc_num++) {
		gen_add_exists(proc_num - 1 ":" i_operand1[proc_num] "=" i_val[proc_num]);
	}
}

########################################################################
#
# Add a line to the comment.
#
# s: String to add, may contain newline character.
#
function gen_add_comment(s) {
	if (comment == "")
		comment = s;
	else
		comment = comment "\n" s;
}

########################################################################
#
# Update the running result based on the current transition
#
# oldresult: Prior running result
# desc: Description of current transition
# reasres: Reason-result combination from appropriate array
#
function result_update(oldresult, desc, reasres,  reason, result) {
	result = reasres;
	gsub(/:.*$/, "", result);
	reason = reasres;
	if (reason ~ /:/)
		gsub(/^.*:/, "", reason);
	else
		reason = "";

	# "Things can only get worse!"  ;-)
	if (result != "Never" && result != "Maybe" && result != "Sometimes") {
		print "Internal error: Bad result \"" result "\" in initialize_cycle_evaluation() table: \"" reasres "\"" > "/dev/stderr";
		exit 1;
	}
	if (oldresult == "Sometimes" ||
	    (oldresult == "Maybe" && result == "Never"))
		result = oldresult;

	if (reason != "" && result != oldresult)
		gen_add_comment(desc ": " oldresult "->" result ": " reason);
	else if (reason != "" && result == oldresult)
		gen_add_comment(desc ": " reason);
	else if (reason == "" && result != oldresult)
		gen_add_comment(desc ": " oldresult "->" result);

	return result;
}

########################################################################
#
# Find the strongest in-bound ordering constraint.  Note that DEC Alpha
# must have a full memory barrier for read-read data dependencies.
# Therefore, without one of "L", "C", or "D", a "d" is only as good as is
# a "c".
#
# cur_rf: String containing constraints
#
function best_rfin(cur_rf,  rfin) {
	if (cur_rf ~ /B/)
		rfin = "B";
	else if (cur_rf ~ /A/)
		rfin = "A";
	else if ((cur_rf ~ /L/ || cur_rf ~ /D/) && cur_rf ~ /[dv]/)
		rfin = "D";
	else if (cur_rf ~ /C/)
		rfin = "D";
	else if (cur_rf ~ /[cdv]/)
		rfin = "C";
	else
		rfin = "O";
	return rfin;
}

########################################################################
#
# Find the strongest out-bound ordering constraint.
#
# cur_rf: String containing constraints
#
function best_rfout(cur_rf,  rfout) {
	if (cur_rf ~ /B/)
		rfout = "B";
	else if (cur_rf ~ /R/)
		rfout = "R";
	else if (cur_rf ~ /A/)
		rfout = "A";
	else
		rfout = "O";
	return rfout;
}

########################################################################
#
# Produce ordering-prediction comment.
#
# gdir: Global directive
# n: Number of processes.
#
function gen_comment(gdir, n,  desc, result, rfin, rfn, rfout) {

	# Handle global directive ordering constraints, one full barrier
	# is all it takes to promote local to global transitivity.
	result = "";
	for (rfn = 1; rfn < n; rfn++) {
		if (i_dir[rfn] ~ /B/ || o_dir[rfn] ~ /B/)
			result = "Never";
	}
	if (result == "" && gdir == "GWR") {
		result = "Never";
		result = result_update(result, "P0 GWR", "Sometimes:Power rel-acq does not provide write-to-read global transitivity");
	}
	if (result == "" && gdir == "GRW") {
		result = "Never";
		result = result_update(result, "P0 GRW", "Never:B-cumulativity provides guarantee");
	}
	if (result == "" && gdir ~ /^G/) {
		result = "Never";
		result = result_update(result, "P0 " gdir, "Maybe:Should rel-acq provide any global transitivity?");
	}
	if (result == "")
		result = "Never";

	# Handle first-process ordering constraints
	rfout = best_rfout(o_dir[1]);
	result = result_update(result, "P0 " gdir "," o_dir[1], cycle_proc1[rfout]);

	# Handle rf and in-process constraints
	for (rfn = 1; rfn < n; rfn++) {
		rfin = best_rfin(i_dir[rfn + 1]);
		rfout = best_rfout(o_dir[rfn]);
		desc = "P" rfn - 1 "-P" rfn " rf " rf[rfn];
		result = result_update(result, desc, cycle_rf[rfout ":" rfin]);
		if (rfn == n - 1)
			break;
		rfout = best_rfout(o_dir[rfn]);
		desc = "P" rfn " " i_dir[rfn + 1] "," o_dir[rfn + 1];
		result = result_update(result, desc, cycle_proc[rfin ":" rfout]);
	}

	# Handle last-process ordering constraints
	rfin = best_rfin(i_dir[n]);
	desc = "P" n - 1 " " i_dir[n] "," gdir;
	if (gdir ~ /R$/)
		result = result_update(result, desc, cycle_procnR[rfin]);
	else
		result = result_update(result, desc, cycle_procnW[rfin]);

	# Print the result and stick it on the front of the comment.
	comment = "Result: " result "\n" comment;
	print " result: " result;
}

########################################################################
#
# Parse the specified process's directive string and set up that
# process's LISA statements.  The directive string is the single
# argument, and the litmus test is output to the file whose name
# is formed by separating the directives with "+".  Arguments:
#
# prefix: Filename prefix for litmus-file output.
# s: Directive string.
#
function gen_lb_litmus(prefix, s,  gdir, i, line_num, n, name, ptemp) {

	# Delete arrays to avoid possible old cruft.
	delete i_op;
	delete i_mod;
	delete i_operand1;
	delete i_operand2;
	delete o_op;
	delete o_mod;
	delete o_operand1;
	delete o_operand2;
	delete stmts;
	delete vars;

	comment = "";
	exists = "";
	initializers = "";

	initialize_cycle_evaluation();

	# Crack the directive strings and do error checking
	if (s ~ /+/)
		n = split(s, ptemp, "+");
	else
		n = split(s, ptemp, " ");
	gdir = ptemp[1];
	# Smaller configurations don't rely on transitivity
	if ((gdir ~ /^L/) && n < 3) {
		print "Locally transitive tests need at least two rf!";
		exit 1;
	} else if ((gdir ~ /^G/) && n < 2) {
		print "Globally transitive tests need at least one rf!";
		exit 1;
	}
	gen_global_syntax(gdir);
	i_dir[1] = "";
	o_dir[n] = "";
	i_dir[n + 1] = "";
	for (i = 2; i <= n; i++) {
		rf[i - 1] = ptemp[i];
		o_dir[i - 1] = ptemp[i];
		gsub(/-.*$/, "", o_dir[i - 1]);
		i_dir[i] = ptemp[i];
		gsub(/^.*-/, "", i_dir[i]);
		if (o_dir[i - 1] ~ /B/ && i_dir[i - 1] !~ /B/)
			i_dir[i - 1] = i_dir[i - 1] "B";
	}
	for (i = 2; i <= n; i++)
		gen_rf_syntax(ptemp[i], o_dir[i - 1], i_dir[i], o_dir[i], i_dir[i + 1]);

	# Generate each process's code.
	gen_vars(gdir, n);
	for (i = 1; i <= n; i++) {
		if (name == "")
			name = prefix "LB-" ptemp[i];
		else
			name = name "+" ptemp[i];
		gen_proc(i, n, gdir, i_dir[i], o_dir[i], i_dir[i + 1]);
	}

	# Generate auxiliary process and exists clause, then dump it out.
	gen_aux_proc(gdir, n);
	gen_exists(n);
	printf "%s ", "name: " name ".litmus";
	gen_comment(gdir, n);
	output_litmus(name, comment, initializers, vars, stmts, exists);
	output_C_litmus(name, comment, initializers, vars, stmts, exists);
}
