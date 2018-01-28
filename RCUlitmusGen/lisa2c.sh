#! /bin/sh
#
# Convert LISA litmus test to C-language version
#
# Usage: sh lisa2c.sh < lisa.litmus > c.litmus
#
# Note that a C-language litmus test might not be semantically equivalent
# to its LISA-language counterpart.  For example, LISA and C have slightly
# different semantics for control dependencies.
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
# Copyright (C) IBM Corporation, 2018
#
# Authors: Paul E. McKenney <paulmck@linux.vnet.ibm.com>

gawk '

########################################################################
#
# Data structures:
#
# arglists[proc_num]: Argument list.
# stmts[proc][line]: Input litmus-test statements.
# max_line[nproc]: Number of input lines in lisa[].
# nproc: Number of processes, ignoring prophesy-variable process.

@include "RCUlitmusCout.awk"

########################################################################
#
# Start of patternist code.

# Kill blank lines
/^[ 	]*$/ {
	next;
}

# Header line
NR == 1 {
	if ($1 != "LISA") {
		print "Need LISA file!";
		exit;
	}
	print "C C-" $2
	inpreamble = 1;
	next;
}

# Copy out preamble verbatim.  End of preamble is P0 notation.
inpreamble == 1 {
	if ($1 == "P0" && ($2 == "|" || $2 == ";")) {
		inpreamble = 0;
		incode = 1;
		print "";
		next;
	}
	print $0;
	next;
}

# The "exists" statement at the end.  Handled first due to terminal laziness.
incode == 1 && $1 ~ /^exists/ {
	incode = 0;
	inexists = 1;
	exists = $0;
	next;
}

# The statements of the processes.
incode == 1 {
	gsub(/^[ 	]*/, "");
	gsub(/;[ 	]*$/, "");
	split($0, cur_line, "|");
	if (nproc == 0)
		nproc = length(cur_line);
	else if (nproc != length(cur_line)) {
		print "Line " NR ": Expected " nproc " processes!";
		exit;
	}
	for (i = 1; i <= nproc; i++) {
		gsub(/^[ 	]*/, "", cur_line[i]);
		gsub(/[ 	]*$/, "", cur_line[i]);
		if (cur_line[i] != "") {
			max_line[i]++;
			stmts[i ":" max_line[i]] = cur_line[i];
		}
		n = split(cur_line[i], splt, " ");
		curvar = "";
		if (n == 3 && splt[1] ~ /^r\[/)
			if (splt[3] !~ /^r[0-9]+$/ && splt[3] ~ /^[a-zA-z_][a-zA-z_0-9]*$/)
				curvar = splt[3];
			else {
				m = split(splt[3], spltexpr, "+");
				if (spltexpr[1] !~ /^r[0-9]+$/ && spltexpr[1] ~ /^[a-zA-z_][a-zA-z_0-9]*$/)
					curvar = spltexpr[1];
			}
		if (n == 3 && splt[1] ~ /^w\[/)
			if (splt[2] !~ /^r[0-9]+$/ && splt[2] ~ /^[a-zA-z_][a-zA-z_0-9]*$/)
				curvar = splt[2];
		if (n == 4 && splt[1] ~ /^rmw\[/)
			if (splt[4] !~ /^r[0-9]+$/ && splt[4] ~ /^[a-zA-z_][a-zA-z_0-9]*$/)
				curvar = splt[4];
		if (n == 5 && splt[1] == "mov")
			if (splt[4] !~ /^r[0-9]+$/ && splt[4] ~ /^[a-zA-z_][a-zA-z_0-9]*$/)
				curvar = splt[4];
		if (curvar != "")
			argsarray[i ":" curvar] = 1;
	}
	line++;
	next;
}

# In case we have a multi-line "exists" statement, pull it all together.
inexists == 1 {
	exists = exists "\n" $0;
}

# Translate and output!
END {
	# Find a scratch register for each process, just in case.
	find_scratch_regs(stmts);

	# Create argument lists
	for (i in argsarray) {
		j = split(i, arg_split, ":");
		proc_num = arg_split[1];
		curvar = arg_split[2];
		if (arglists[proc_num] != "")
			arglists[proc_num] = arglists[proc_num] ", ";
		arglists[proc_num] = arglists[proc_num] "int *" curvar;
	}

	# Eliminate branch-to-next statements and their labels.
	# These would translate to "if" statements with empty "then"
	# clauses, which herd7 objects strenuously to.
	for (proc_num = 1; proc_num <= nproc; proc_num++) {
		line_last = 1;
		for (line_in = 2; line_in <= max_line[proc_num]; line_in++) {
			if (stmts[proc_num ":" line_in] == "")
				continue;
			if (stmts[proc_num ":" line_in] ~ /^[a-zA-Z_][a-zA-Z0-9_]*:$/) {
				cur_label = stmts[proc_num ":" line_in];
				gsub(/:$/, "", cur_label);
				cur_label = "^b.*][ 	]*r[0-9]+[ 	]" cur_label "$";
				if (stmts[proc_num ":" line_last] ~ cur_label) {
					stmts[proc_num ":" line_last] = "";
					stmts[proc_num ":" line_in] = "";
				}
				while (stmts[proc_num ":" line_last] == "" && line_last > 1)
					line_last--;
			} else {
				line_last = line_in;
			}
		}
	}

	# Do the translation from stmts[] and output.
	for (proc_num = 1; proc_num <= nproc; proc_num++) {
		print "P" proc_num - 1 "(" arglists[proc_num] ")";
		print "{";
		tabs = "\t"
		for (line_in = 1; line_in <= max_line[proc_num]; line_in++) {
			stmt = stmts[proc_num ":" line_in];
			if (stmt == "")
				continue;
			stmt_list = translate_statement(proc_num, stmt);
			nstmts = split(stmt_list, stmt_splt, "\n");
			for (i = 1; i <= nstmts; i++) {
				if (stmt_splt[i] == "")
					continue;
				if (stmt_splt[i] == "}")
					tabs = substr(tabs, 2);
				print tabs stmt_splt[i];
				if (stmt_splt[i] ~ /^if /)
					tabs = tabs "\t";
			}
		}
		print "}\n";
	}

	# exists clause.
	print exists;
}
'
