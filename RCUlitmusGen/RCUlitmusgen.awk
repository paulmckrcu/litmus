# Generate a LISA litmus test.
#
# Usage:
#	generate_lisa(desc);
#
# The "desc" argument is a string describing the litmus test.  This
# string is a space-separated list of per-process descriptions, which
# are of the form X-Y-Z, where X, Y, and Z are as follows:
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
#	D: Maintain a data dependency betweeen the first access (which
#		must be a load) and the second access (which must be
#		a store).
#	G: Separate the X accesses with an RCU grace period.
#	I: Invert the order of the accesses so that the outgoing
#		variable is first and the incoming variable is second.
#	R: Enclose the X accesses in an RCU read-side critical section.
#	r: Use an release store.  May be used only if the second accesses
#		is a store.
#
#	Any combination of these may be used, though quite a few do not
#	make sense.  It is OK to have Y empty, in which case the accesses
#	will be emitted without any sort of ordering control.
#
# Summary: X: RR, RW, WR, WW
#	   Y: a, B, C, D, G, I, R, r.
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


########################################################################
#
# Data structures:
#
# @@@ preamble[proc][gp]: How many preambles emitted for process/gp combo.
# postamble[proc][gp]: How many postambles emitted for process/gp combo.
# stmts[proc][line]: Litmus test with RCU statements translated.
# stmts[proc][line]: Input litmus-test statements.
# nproc: Number of processes.

########################################################################
#
# Check the syntax of the specified process's directive string.
# Complain and exit if there is a problem.
#
function gen_proc_syntax(p, x, y,  i) {
	if (x !~ /[RW][RW]/) {
		print "Process " p - 1 " bad read-write specifier: " x > "/dev/stderr";
		exit;
	}
	if (y !~ /[aBCDGIRr]/) {
		print "Process " p - 1 " bad modifier: " y > "/dev/stderr";
		exit;
	}
	if (x ~ /^W/ && y ~ /aCD/ && y !~ /I/) {
		print "Process " p - 1 " no acquire/dependent store! " y > "/dev/stderr";
		exit;
	}
	if (x ~ /R$/ && y ~ /rCD/ && y !~ /I/) {
		print "Process " p - 1 " no release/dependent load! " y > "/dev/stderr";
		exit;
	}
	if (x ~ /W$/ && y ~ /aCD/ && y ~ /I/) {
		print "Process " p - 1 " no acquire/dependent store! " y > "/dev/stderr";
		exit;
	}
	if (x ~ /^R/ && y ~ /rCD/ && y ~ /I/) {
		print "Process " p - 1 " no release/dependent load! " y > "/dev/stderr";
		exit;
	}
	if (y ~ /R/ && y ~ /G/) {
		print "Process " p - 1 " RCU deadlock! " y > "/dev/stderr";
		exit;
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
		exit;
	}
}

########################################################################
#
# Parse the specified process's directive string.
#
function gen_proc(p, s,  i, line_num, x, y) {
	# Extract read-write (x) and modifier (y) portions of directive.
	x = s;
	gsub(/-.*$/, "", x);
	y = s;
	gsub(/^.*-/, "", y);
	if (s !~ /-/)
		y = "";
	print "x = " x, "y = " y;

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
		i_operand1[p] = "2";
		i_operand2[p] = "x" p - 1;
	}

	# Form outgoing statement base.
	o_mod[p] = "once";
	if (x ~ /R$/) {
		o_op[p] = "r";
		o_operand1[p] = "r2";
		o_operand2[p] = "x" p;
	} else {
		o_op[p] = "w";
		o_operand1[p] = "x" p;
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
		f_mod[p] = "acquire";
	if (y ~ /r/)
		l_mod[p] = "release";
	if (y ~ /D/)
		l_operand2[p] = "r1";

	# Output statements
	line_num = 0;
	if (y ~ /R/)
		stmts[p ":" ++line_num] = "r[lock]";
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
		stmts[p ":" ++line_num] = "r[unlock]";

	# Debug output
	for (i = 1; i <= line_num; i++)
		print i, stmts[p ":" i];
}
