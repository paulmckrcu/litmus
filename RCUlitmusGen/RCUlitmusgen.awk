# Generate a LISA litmus test.
#
# Usage:
#	generate_lisa(desc);
#
# The "desc" argument is a string describing the litmus test.  This string
# is a space-separated (or "+"-separated) list of per-process descriptions,
# which are of the form X-Y-Z, where X, Y, and Z are as follows:
#
# X:	RR: A read of the incoming variable followed by a read of
#		the outgoing variable.
#	RW: A read of the incoming variable followed by a write of
#		the value one to the outgoing variable, AKA LB.
#	WR: A write of the value one to the incoming variable followed
#		by a read of the outgoing variable, AKA SB.
#	WW: A write of the value two to the incoming variable followed
#		by a write of the value one to the outgoing variable.
#
#	Note that if one process reads from the outgoing variable and
#	the next process reads from that same variable, there must be
#	a write to that variable in an auxiliary process.
#
#	Only one of the X values may be specified for a given process.
#
# Y:
#	a: Use an acquire load.  May be used only if the first accesses
#		is a load.
#	B: Separate the X accesses with a full memory barrier.
#	C: Maintain a control dependency betweeen the first access
#		(which must be a load) and the second access (which
#		must be a store).
#	D: Maintain an RCU data dependency betweeen the first access (which
#		must be a load) and the second access (which must be
#		a store).
#	G: Separate the X accesses with an RCU grace period.
#	I: Invert the order of the accesses so that the outgoing
#		variable is first and the incoming variable is second.
#	l: Maintain a lockless data dependency betweeen the first access
#		(which must be a load) and the second access (which must
#		be a store).
#	R: Enclose the X accesses in an RCU read-side critical section.
#	r: Use an release store.  May be used only if the second accesses
#		is a store.
#	s: Use an assign store, as in rcu_assign_poiner.  May be used
#		only if the second accesses is a store.
#
#	Any combination of these may be used, though quite a few do not
#	make sense.  It is OK to have Y empty, in which case the accesses
#	will be emitted without any sort of ordering control.
#
# Summary: X: RR, RW, WR, WW
#	   Y: a, B, C, D, G, I, R, r, s.
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
# exists: String containing the "exists" clause, which may be multi-line.
# f_op[proc_num]: First operand ("r" or "w")
# f_mod[proc_num]: First modifier ("once", "acquire", ...)
# f_operand1[proc_num]: First first operand (register or variable)
# f_operand2[proc_num]: First second operand (register or variable)
# i_op[proc_num]: Incoming operand ("r" or "w")
# i_mod[proc_num]: Incoming modifier ("once", "acquire", ...)
# i_operand1[proc_num]: Incoming first operand (register or variable)
# i_operand2[proc_num]: Incoming second operand (register or variable)
# i_t[proc_num]: Incoming operand timestamp.
# l_op[proc_num]: Last operand ("r" or "w")
# l_mod[proc_num]: Last modifier ("once", "acquire", ...)
# l_operand1[proc_num]: Last first operand (register or variable)
# l_operand2[proc_num]: Last second operand (register or variable)
# o_op[proc_num]: Outgoing operand ("r" or "w")
# o_mod[proc_num]: Outgoing modifier ("once", "acquire", ...)
# o_operand1[proc_num]: Outgoing first operand (register or variable)
# o_operand2[proc_num]: Outgoing second operand (register or variable)
# o_t[proc_num]: Outgoing operand timestamp.
# stmts[proc_num ":" line_num]: Marshalled LISA statements
#
# Incoming is first and outgoing is last, unless "I" is specified, in
# which case outgoing is first and incoming is last.

########################################################################
#
# Check the syntax of the specified process's directive string.
# Complain and exit if there is a problem.
#
function gen_proc_syntax(p, x, y,  i) {
	if (x !~ /[RW][RW]/) {
		print "Process " p - 1 " bad read-write specifier: " x > "/dev/stderr";
		exit 1;
	}
	if (y ~ /[^aBCDGIlRrs]/) {
		print "Process " p - 1 " bad modifier: " y > "/dev/stderr";
		exit 1;
	}
	if (x ~ /^W/ && y ~ /alCD/ && y !~ /I/) {
		print "Process " p - 1 " no acquire/dependent store! " y > "/dev/stderr";
		exit 1;
	}
	if (x ~ /R$/ && y ~ /rsCD/ && y !~ /I/) {
		print "Process " p - 1 " no release/dependent load! " y > "/dev/stderr";
		exit 1;
	}
	if (x ~ /W$/ && y ~ /alCD/ && y ~ /I/) {
		print "Process " p - 1 " no acquire/dependent store! " y > "/dev/stderr";
		exit 1;
	}
	if (x ~ /^R/ && y ~ /rsCD/ && y ~ /I/) {
		print "Process " p - 1 " no release/dependent load! " y > "/dev/stderr";
		exit 1;
	}
	i = 0;
	if (y ~ /B/)
		i++;
	if (y ~ /C/)
		i++;
	if (y ~ /D/)
		i++;
	if (y ~ /G/)
		i++;
	if (i > 1) {
		print "Process " p - 1 " too many ordering directives! " y > "/dev/stderr";
		exit 1;
	}
}

########################################################################
#
# Extract the read-write portion of the specified directive string.
#
function extract_rw(s,  x) {
	# Extract read-write (x) and modifier (y) portions of directive.
	x = s;
	gsub(/-.*$/, "", x);
	return x;
}

########################################################################
#
# Extract the modifier portion of the specified directive string.
#
function extract_mod(s,  y) {
	# Extract read-write (x) and modifier (y) portions of directive.
	y = s;
	gsub(/^.*-/, "", y);
	if (s !~ /-/)
		y = "";
	return y;
}

########################################################################
#
# Parse the specified process's directive string and set up that
# process's LISA statements. Arguments are as follows:
#
# p: Number of current process, based from 1.
# n: Number of processes.
# s: Current process's directive.
#
# This function operates primarily by side effects on global variables.
#
function gen_proc(p, n, s,  i, line_num, x, y, vn) {
	# Extract read-write (x) and modifier (y) portions of directive.
	x = extract_rw(s);
	y = extract_mod(s);

	# Syntax check.
	gen_proc_syntax(p, x, y);

	# Form incoming statement base.
	i_mod[p] = "once";
	if (x ~ /^R/) {
		i_op[p] = "r";
		i_operand1[p] = "r1";
		i_operand2[p] = "x" p - 1;
	} else {
		i_op[p] = "w";
		i_operand1[p] = "x" p - 1;
		i_operand2[p] = "2";
	}

	# Form outgoing statement base.
	o_mod[p] = "once";
	vn = p == n ? 0 : p;
	if (x ~ /R$/) {
		o_op[p] = "r";
		o_operand1[p] = "r2";
		o_operand2[p] = "x" vn;
	} else {
		o_op[p] = "w";
		o_operand1[p] = "x" vn;
		o_operand2[p] = "1";
	}

	# Apply modifiers.
	if (y ~ /I/) {
		f_op[p] = o_op[p];
		f_mod[p] = o_mod[p];
		f_operand1[p] = o_operand1[p];
		f_operand2[p] = o_operand2[p];
		l_op[p] = i_op[p];
		l_mod[p] = i_mod[p];
		l_operand1[p] = i_operand1[p];
		l_operand2[p] = i_operand2[p];
	} else {
		f_op[p] = i_op[p];
		f_mod[p] = i_mod[p];
		f_operand1[p] = i_operand1[p];
		f_operand2[p] = i_operand2[p];
		l_op[p] = o_op[p];
		l_mod[p] = o_mod[p];
		l_operand1[p] = o_operand1[p];
		l_operand2[p] = o_operand2[p];
	}
	if (y ~ /a/)
		f_mod[p] = "acquire";	/* smp_load_acquire() */
	if (y ~ /D/) {
		f_mod[p] = "deref";	/* rcu_dereference() */
		l_operand2[p] = "r1";
	}
	if (y ~ /l/) {
		f_mod[p] = "lderef";	/* lockless_dereference() */
		l_operand2[p] = "r1";
	}
	if (y ~ /r/)
		l_mod[p] = "release";	/* smp_store_release() */
	if (y ~ /s/)
		l_mod[p] = "assign";	/* rcu_assign_pointer() */

	# Output statements
	line_num = 0;
	if (y ~ /R/)
		stmts[p ":" ++line_num] = "f[lock]";
	stmts[p ":" ++line_num] = f_op[p] "[" f_mod[p] "] " f_operand1[p] " " f_operand2[p];
	if (y ~ /B/)
		stmts[p ":" ++line_num] = "f[mb]";
	if (y ~ /C/) {
		stmts[p ":" ++line_num] = "b[] " f_operand1[p] " CTRL" p - 1;
		stmts[p ":" ++line_num] = "CTRL" p - 1 ":";
	}
	if (y ~ /G/)
		stmts[p ":" ++line_num] = "call[sync]";
	stmts[p ":" ++line_num] = l_op[p] "[" l_mod[p] "] " l_operand1[p] " " l_operand2[p];
	if (y ~ /R/)
		stmts[p ":" ++line_num] = "f[unlock]";

	# Update incoming and outgoing data for later reference.
	if (y ~ /I/) {
		o_op[p] = f_op[p];
		o_mod[p] = f_mod[p];
		o_operand1[p] = f_operand1[p];
		o_operand2[p] = f_operand2[p];
		i_op[p] = l_op[p];
		i_mod[p] = l_mod[p];
		i_operand1[p] = l_operand1[p];
		i_operand2[p] = l_operand2[p];
	} else {
		i_op[p] = f_op[p];
		i_mod[p] = f_mod[p];
		i_operand1[p] = f_operand1[p];
		i_operand2[p] = f_operand2[p];
		o_op[p] = l_op[p];
		o_mod[p] = l_mod[p];
		o_operand1[p] = l_operand1[p];
		o_operand2[p] = l_operand2[p];
	}
}

########################################################################
#
# Generate the auxiliary process for the current litmus test, if one
# is required.  One is required if both the outgoing and the incoming
# operations for a given variable are reads, in which case an auxiliary
# write is required to determine ordering.  This function also adds the
# corresponding "exists" clauses.  Arguments:
#
# n: Number of processes (not counting possible auxiliary process).
#
function gen_aux_proc(n,  line_num, old_proc_num, proc_num) {
	old_proc_num = n;
	line_num = 0;
	for (proc_num = 1; proc_num <= n; proc_num++) {
		if (o_op[old_proc_num] == "r" && i_op[proc_num] == "r") {
			stmts[n + 1 ":" ++line_num] = "w[once] " i_operand2[proc_num] " 1"
		}
		old_proc_num = proc_num;
	}
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
# Generate the exists clause.
#
# n: Number of processes.
#
function gen_exists(n,  old_op, op, old_proc_num, proc_num) {
	exists = "";
	old_proc_num = n;
	line_num = 0;
	for (proc_num = 1; proc_num <= n; proc_num++) {
		old_op = o_op[old_proc_num];
		op = i_op[proc_num];
		if (old_op == "r" && op == "r") {
			gen_add_exists(old_proc_num - 1 ":" o_operand1[old_proc_num] "=0 /\\ " proc_num - 1 ":" i_operand1[proc_num] "=1");
		} else if (old_op == "r" && op == "w") {
			gen_add_exists(old_proc_num - 1 ":" o_operand1[old_proc_num] "=0");
		} else if (old_op == "w" && op == "r") {
			gen_add_exists(proc_num - 1 ":" i_operand1[proc_num] "=1");
		} else if (old_op == "w" && op == "w") {
			gen_add_exists(i_operand1[proc_num] "=2");
		}
		old_proc_num = proc_num;
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
# If the litmus test is subject to RCU self-deadlock, make a comment
# that says so.
#
# ptemp: Array of per-process directives.
# n: Number of processes.
#
function gen_comment_deadlock(ptemp, n, proc_num, deadlock, plural) {
	comment = "";

	# Check for RCU self-deadlock.
	deadlock = "";
	for (proc_num = 1; proc_num <= n; proc_num++) {
		if (ptemp[proc_num] ~ /-.*G/ && ptemp[proc_num] ~ /-.*R/) {
			if (deadlock == "")
				deadlock = proc_num - 1 "";
			else
				deadlock = deadlock ", " proc_num - 1;
		}
	}
	if (deadlock != "") {
		if (deadlock ~ / [0-9][0-9]*, /) {
			deadlock = gensub(/, ([0-9][0-9]*)$/, ", and \\1", 1, deadlock);
			plural = "es";
		} else {
			deadlock = gensub(/,/, " and", 1, deadlock);
			plural = "";
		}
		gen_add_comment("Result: DEADLOCK");
		gen_add_comment("\nRCU self-deadlock on process" plural " " deadlock ".");
		print " result: DEADLOCK";
		return 1;
	}
	return 0;
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
# Given a timestamp, go forward to the end of the next grace period.
#
# We cheat horribly here.  Because an RCU read-side critical section
# cannot span an RCU grace period, we define an RCU grace period to be
# slightly longer than an RCU read-side critical section.  This will result
# in errors if there are too many processes, like more than about 100 or so.
# This can be fixed by increasing the constants used to define grace-period
# and critical-section duration.
#
function next_gp(t) {
	return t + 100000;
}

########################################################################
#
# Given a timestamp, go back to the beginning of the previous grace
# period.
#
function prev_gp(t) {
	return t - 99000;
}

########################################################################
#
# Analyze timing.
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
		if (y !~ /I/ && y ~ /G/) {
			# RCU grace period constrains.
			o_t[proc_num] = next_gp(t);
		} else if ((y ~ /I/ && y !~ /R/) || y == "") {
			# No ordering whatsoever, back to beginning of time.
			o_t[proc_num] = 0;
		} else if ((y ~ /I/ && y ~ /R/) || y == "R") {
			# RCU read-side critical section constrains.
			o_t[proc_num] = prev_gp(t);
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
# Convert timing into grace-period-relative string.
#
# t: Timestamp
#
function timing_to_gp_str(t,  gp_num) {
	return "(t=" t ")";
}

########################################################################
#
# Produce timing-related comment.
#
# ptemp: Array of per-process directives.
# n: Number of processes.
#
function gen_comment_timing(ptemp, n,  proc_num, result, t, y) {
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
		} else if ((y ~ /I/ && y !~ /R/) || y == "") {
			# No ordering whatsoever, back to beginning of time.
			gen_add_comment("\nP" proc_num - 1 " is unordered, therefore cycle is allowed.");
			gen_add_comment("Skipping remainder of analysis.");
			break;
		} else if ((y ~ /I/ && y ~ /R/) || y == "R") {
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
# Generate the comment, which predicts the test result with a rationale
# for that prediction.
#
# ptemp: Array of per-process directives.
# n: Number of processes.
#
function gen_comment(ptemp, n,  proc_num, deadlock, plural) {
	if (gen_comment_deadlock(ptemp, n))
		return;
	gen_comment_timing(ptemp, n);
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
function gen_litmus(prefix, s,  i, line_num, n, name, ptemp) {

	# Delete arrays to avoid possible old cruft.
	delete f_op;
	delete f_mod;
	delete f_operand1;
	delete f_operand2;
	delete i_op;
	delete i_mod;
	delete i_operand1;
	delete i_operand2;
	delete i_t;
	delete l_op;
	delete l_mod;
	delete l_operand1;
	delete l_operand2;
	delete o_op;
	delete o_mod;
	delete o_operand1;
	delete o_operand2;
	delete o_t;
	delete stmts;

	# Generate each process's code.
	if (s ~ /+/)
		n = split(s, ptemp, "+");
	else
		n = split(s, ptemp, " ");
	if (n < 1) {
		print "Error: No directives!";
		exit 1;
	}
	for (i = 1; i <= n; i++) {
		if (name == "")
			name = prefix ptemp[i];
		else
			name = name "+" ptemp[i];
		gen_proc(i, n, ptemp[i]);
	}

	# Generate auxiliary process and exists clause, then dump it out.
	gen_aux_proc(n);
	gen_exists(n);
	printf "%s ", "name: " name ".litmus";
	gen_comment(ptemp, n);
	output_lisa(name, comment, "", stmts, exists);
}
