# Output a LISA litmus test.
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
# lisa[proc][line]: Input litmus-test statements.
# nproc: Number of processes.
# ngp: Number of grace periods across all processes.
# rcugp[gp]: Process containg RCU grace period gp.
# rcurl[proc]: Number of RCU read-side critical sections in process.

########################################################################
#
# Output comments if non-empty string supplied.  Varies format based
# on number of lines in the comments parameter.
#
function output_comments(comments, fn,  comment, i, n) {
	# Extract comment lines.
	n = split(comments, comment, "\n");

	# If no comment, don't bother.
	if (n == 0)
		return;

	# If single line of comments, use single-line format.
	if (n == 1) {
		print "(* " comment[1] " *)" > fn;
		return;
	}

	print "(*" > fn;
	for (i = 1; i <= n; i++)
		print " * " comment[i] > fn;
	print " *)" > fn;
}

########################################################################
#
# Output a full LISA litmus test.  The arguments are as follows:
#
# litname: Name of the litmus test.  A ".litmus" is appended for filename.
# comments: String containing comments, optionally with embedded "\n".
#	Can be empty string for no comment.
# varinit: String containing initializers, optionally with embedded "\n".
#	Can be empty string for no initializers.
# stmts[proc_num ":" line_out]: Array of LISA statements.
# exists: String containing exists clause, optionally with embedded "\n".
#	The outermost set of parentheses are supplied by output_lisa.
#
function output_lisa(litname, comments, varinit, stmts, exists,  aux_max_line, comment, fn, i, line_out, max_length, max_stmts, nproc, pad, proc_num, stmt) {
	fn = litname ".litmus";
	# Output file header.
	print "LISA " litname > fn;

	# Process and output comments
	output_comments(comments, fn);

	# Output initialization.
	print "{" > fn;
	if (varinit != "")
		print varinit > fn;
	print "}" > fn;

	# Find maximum number of statements and maximum statement length
	# for each process.
	for (i in stmts) {
		proc_num = i;
		gsub(/:.*$/, "", proc_num);
		line_out = i;
		gsub(/^.*:/, "", line_out);
		if (proc_num > nproc)
			nproc = proc_num;
		if (line_out > max_stmts[proc_num])
			max_stmts[proc_num] = line_out;
		if (line_out > aux_max_line)
			aux_max_line = line_out;
		stmt = stmts[proc_num ":" line_out];
		if (length(stmt) > max_length[proc_num])
			max_length[proc_num] = length(stmt);
	}

	# Create the process headers as line zero.
	for (proc_num = 1; proc_num <= nproc; proc_num++)
		stmts[proc_num ":0"] = "P" proc_num - 1;

	# Output the code.
	for (line_out = 0; line_out <= aux_max_line; line_out++) {
		for (proc_num = 1; proc_num <= nproc; proc_num++) {
			stmt = stmts[proc_num ":" line_out];
			pad = max_length[proc_num] - length(stmt);
			printf " %s%*s %s", stmt, pad, "", proc_num < nproc ? "|" : ";" > fn;
		}
		printf "\n" > fn;
	}

	# exists clause.
	printf "exists\n(%s)\n", exists > fn;
	close(fn);
}
