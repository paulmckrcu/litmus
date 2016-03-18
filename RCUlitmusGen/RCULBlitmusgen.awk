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
# W:	A: Use rcu_assign_pointer(), AKA w[assign].
# 	O: Use WRITE_ONCE(), AKA w[once].
#	R: Use smp_write_release(), AKA w[release].
#
#	Only one of "A", "O", or "R" may be specified for a given rf link.
#
# R:	A: Use smp_read_acquire(), AKA r[acquire].
#	C: Use control dependency.
#	D: Use data dependency.
#	l: Use lderef data dependency.
#	O: Use READ_ONCE(), AKA r[once].
#
#	Exactly one of "A", "l", or "O" may be specified for a given rf link,
#	but either or both of "C" and "D" may be added in either case.
#
# A litmus test with N processes will have N-1 W-R per-rf descriptors.
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

########################################################################
#
# Global variables:
#
# comment: String containing the comment field, which may be multi-line.
# initializers: String containing initializers, which may be multi-line.
# exists: String containing the "exists" clause, which may be multi-line.
# i_dir[proc_num]: Incoming (read) directive
# i_op[proc_num]: Incoming operand ("r" or "w") @@@ Always "r"
# i_mod[proc_num]: Incoming modifier ("once", "acquire", ...)
# i_operand1[proc_num]: Incoming first operand (register or variable) @@@ Always "r1"
# i_operand2[proc_num]: Incoming second operand (register or variable)
# o_dir[proc_num]: Outgoing (write) directive
# o_op[proc_num]: Outgoing operand ("r" or "w") @@@ Always "w".
# o_mod[proc_num]: Outgoing modifier ("once", "acquire", ...)
# o_operand1[proc_num]: Outgoing first operand (register or variable)
# o_operand2[proc_num]: Outgoing second operand (register or variable)
# stmts[proc_num ":" line_num]: Marshalled LISA statements

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
# Check the syntax of the specified reads-from (rf)  directive string.
# Complain and exit if there is a problem.
#
function gen_rf_syntax(rfn, x, y) {
	if (x != "A" && x != "O" && x != "R") {
		print "Reads-from edge " rfn " bad write-side specifier: " x > "/dev/stderr";
		exit 1;
	}
	if (y ~ /[^ACDlO]/) {
		print "Reads-from edge " rfn " bad read-side specifier: " y > "/dev/stderr";
		exit 1;
	}
	if ((y ~ /A/) + (y ~ /l/) + (y ~ /O/) != 1) {
		print "Reads-from edge " rfn " only one of "AlO" in read-side specifier: " x > "/dev/stderr";
		exit 1;
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
function gen_proc(p, n, g, x, y, xn,  i, line_num, tvar, v, vn, vnn) {
	if (g ~ /^L/)
		tvar = "u0";
	else
		tvar = "v0";
	v = p - 1;
	vn = (v + 1) % n;
	vnn = (vn + 1) % n;

	# Form incoming statement base.
	if (p == 1) {
		i_mod[p] = "once";
		if (g ~ /R[RW]$/) {
			i_op[p] = "r";
			i_operand1[p] = "r1";
			i_operand2[p] = "y0";
		} else {
			i_op[p] = "w";
			i_operand1[p] = "y0";
			i_operand2[p] = "1";
		}
	} else {
		if (x ~ /A/)
			i_mod[p] = "acquire";
		else if (x ~ /l/)
			i_mod[p] = "lderef";
		else
			i_mod[p] = "once";
		i_op[p] = "r";
		i_operand1[p] = "r1";
		i_operand2[p] = "x" v;
	}

	# Form outgoing statement base.
	if (p == n ) {
		o_mod[p] = "once";
		if (g ~ /R$/) {
			o_op[p] = "r";
			o_operand1[p] = "r2";
			o_operand2[p] = tvar;
		} else {
			o_op[p] = "w";
			o_operand1[p] = tvar;
			o_operand2[p] = "2";
		}
	} else {
		if (y == "A")
			o_mod[p] = "assign";
		else if (y == "R")
			o_mod[p] = "release";
		else
			o_mod[p] = "once";
		o_op[p] = "w";
		if (x ~ /[Dl]/) {
			o_operand1[p] = "r1";
		} else {
			o_operand1[p] = "x" vn;
		}
		if (xn ~ /[Dl]/) {
			o_operand2[p] = "r3";
			initializers = initializers " " p - 1 ":r3=x" vnn ";
			initializers = initializers x" vn "=y" vnn ";
			if (p == n - 1)
				initializers = initializers " vn ":r4=y" vnn;
			else
				initializers = initializers " vn ":r4=" tvar;
		} else {
			o_operand2[p] = "1";
		}
	}

	# Output statements
	line_num = 0;
	stmts[p ":" ++line_num] = i_op[p] "[" i_mod[p] "] " i_operand1[p] " " i_operand2[p];
	if (x ~ /C/) {
		stmts[p ":" ++line_num] = "mov r4 (eq r1 r4)";
		stmts[p ":" ++line_num] = "b[] r4 CTRL" p - 1;
	}
	stmts[p ":" ++line_num] = o_op[p] "[" o_mod[p] "] " o_operand1[p] " " o_operand2[p];
	if (x ~ /C/)
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
		stmts[n + 1 ":" ++line_num] = "w[once] z0 1"
		gen_add_exists(n - 1 ":r2=0");
	} else {
		stmts[n + 1 ":" ++line_num] = "r[once] r1 z0"
		gen_add_exists(n ":r1=2");
	}
	stmts[n + 1 ":" ++line_num] = "f[mb]"
	if (g ~ /^GR[RW]$/) {
		stmts[n + 1 ":" ++line_num] = "w[once] y0 1"
		gen_add_exists("0:r1=1");
	} else {
		stmts[n + 1 ":" ++line_num] = "r[once] r2 y0"
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
		stmts[n + 1 ":" ++line_num] = "w[once] y0 1"
		gen_add_exists("0:r1=1");
		gen_add_exists(n - 1 ":r2=0");
	} else if (g == "LRW") {
		gen_add_exists("0:r1=2");
	} else if (g == "LWR") {
		gen_add_exists(n - 1 ":r2=0");
	} else {
		gen_add_exists("y0=1");
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
		if (o_operand2[proc_num - 1] == "r3")
			wrcmp = "x" proc_num;
		else
			wrcmp = 1;
		gen_add_exists(proc_num - 1 ":" i_operand1[proc_num] "=" wrcmp);
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
# Given a timestamp, advance to the next slot.  This is appropriate
# when the process uses non-RCU ordering.
#
# The timestamp zero is special, and corresponds to the beginning of
# time.  This is useful when there is no ordering constraint, so that
# the outgoing variable might take on its value arbitrarily early.
#
function next_step(t) {
	return t + 1;
}

########################################################################
#
# Analyze timing.  @@@ Should not need timing...
#
# ptemp: Array of per-process directives.
# n: Number of processes.
#
function gen_timing(ptemp, n,  proc_num, t, t_min, y) {

	# Pick large number as starting point and propagate timestamps.
	t = 10000000;
	t_min = t;
	for (proc_num = 1; proc_num <= n; proc_num++) {
		i_t[proc_num] = t;
		y = extract_mod(ptemp[proc_num]);
		@@@ } else if ((y ~ /I/ && (y !~ /R/ || y ~ /[123]/)) || y == "") {
			# No ordering whatsoever, back to beginning of time.
			o_t[proc_num] = 0;
		} else {
			# Normal CPU-based ordering constrains.
			o_t[proc_num] = next_step(t);
		}

		# If already at the beginning of time, stay there.
		if (t == 0)
			o_t[proc_num] = 0;

		# Compute non-beginning-of-time minimum.
		if (o_t[proc_num] < t_min && o_t[proc_num] != 0)
			t_min = o_t[proc_num];

		# Advance one step for memory-reference propagation.
		# Yes, this is a gross approximation, but works for
		# current subset of operations.
		t = next_step(o_t[proc_num]);
	}

	# Normalize non-beginning-of-time values, but subtract an even
	# number of even grace periods, but stay out of the low-order
	# beginning-of-time area from 0 to 2000.
	t_min = t_min - 100000;
	for (proc_num = 1; proc_num <= n; proc_num++) {
		if (i_t[proc_num] != 0)
			i_t[proc_num] -= t_min;
		if (o_t[proc_num] != 0)
			o_t[proc_num] -= t_min;
		# print proc_num ": " ptemp[proc_num] " i: " i_t[proc_num] " o: " o_t[proc_num];
	}
}

########################################################################
#
# Convert timing into grace-period-relative string. @@@ should not need!
#
# t: Timestamp
#
function timing_to_gp_str(t,  gp_num) {
	return "(t=" t ")";
}

########################################################################
#
# Produce timing-related comment.  @@@ Should just use ordering and matching
#
# ptemp: Array of per-process directives.  @@@ Needed?
# n: Number of processes.
#
function gen_comment(ptemp, n,  proc_num, result, t, y) {

	# Generate SMP timing
	gen_timing(ptemp, n);

	# Generate the result-summary comment.
	result = i_t[1] >= o_t[n] ? "Sometimes" : "Never";
	comment = "Result: " result;
	print " result: " result;

	# Analyze timestamps and produce comments.
	gen_add_comment("\nProcess 0 starts " timing_to_gp_str(i_t[1]) ".");
	for (proc_num = 1; proc_num <= n; proc_num++) {
		y = extract_mod(ptemp[proc_num]);
		if (y !~ /I/ && y ~ /G/) {
			# RCU grace period constrains.
			gen_add_comment("\nP" proc_num - 1 " advances one grace period " timing_to_gp_str(o_t[proc_num]) ".");
		} else if ((y ~ /I/ && (y !~ /R/ || y ~ /[123]/)) || y == "") {
			# No ordering whatsoever, back to beginning of time.
			gen_add_comment("\nP" proc_num - 1 " is unordered, therefore cycle is allowed.");
			gen_add_comment("Skipping remainder of analysis.");
			break;
		} else if (y ~ /R/ && (y ~ /I/ || y ~ /^[R123]*$/)) {
			# RCU read-side critical section constrains.
			gen_add_comment("\nP" proc_num - 1 " goes back a bit less than one grace period " timing_to_gp_str(o_t[proc_num]) ".");
		} else {
			# Normal CPU-based ordering constrains.
			gen_add_comment("\nP" proc_num - 1 " advances slightly " timing_to_gp_str(o_t[proc_num]) ".");
		}

		# If already at the beginning of time, stay there.
		if (t == 0)
			o_t[proc_num] = 0;

		# Compute non-beginning-of-time minimum.
		if (o_t[proc_num] < t_min && o_t[proc_num] != 0)
			t_min = o_t[proc_num];

		# Advance one step for memory-reference propagation.
		# Yes, this is a gross approximation, but works for
		# current subset of operations.
		t = next_step(o_t[proc_num]);
	}

	# Summarize cycle status, if not already summarized.
	if (o_t[n] == 0)
		return;
	result = i_t[1] >= o_t[n] ? "allowed" : "forbidden";
	gen_add_comment("\nProcess 0 start at t=" i_t[1] ", process " n " end at t=" o_t[n] ": Cycle " result ".");
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
function gen_litmus(prefix, s,  gdir, i, line_num, n, name, ptemp) {

	# Delete arrays to avoid possible old cruft.
	delete i_op;
	delete i_mod;
	delete i_operand1;
	delete i_operand2;
	@@@ delete i_t;
	delete o_op;
	delete o_mod;
	delete o_operand1;
	delete o_operand2;
	@@@ delete o_t;
	delete stmts;
	exists = "";

	initializers = "";

	# Generate each process's code.
	if (s ~ /+/)
		n = split(s, ptemp, "+");
	else
		n = split(s, ptemp, " ");
	if (n < 3) {
		# Smaller configurations don't rely on transitivity
		print "Not enough directives: Need global and at least two rf!";
		exit 1;
	}
	gdir = ptemp[1];
	gen_global_syntax(gdir);
	i_dir[1] = "";
	o_dir[n] = "";
	i_dir[n + 1] = "";
	for (i = 2; i <= n; i++) {
		o_dir[i - 1] = ptemp[i];
		gsub(/-.*$/, "", o_dir[i - 1]);
		i_dir[i] = ptemp[i];
		gsub(/^.*-/, "", i_dir[i]);
		gen_rf_syntax(ptemp[i], o_dir[i - 1], i_dir[i]);
	}
	for (i = 1; i <= n; i++) {
		if (name == "")
			name = prefix ptemp[i];
		else
			name = name "+" ptemp[i];
		gen_proc(i, n, gdir, i_dir[i], o_dir[i], i_dir[i + 1]);
	}

	# Generate auxiliary process and exists clause, then dump it out.
	gen_aux_proc(gdir, n);
	gen_exists(n);
	printf "%s ", "name: " name ".litmus";
	gen_comment(ptemp, n);
	output_lisa(name, comment, initializers, stmts, exists);
}
