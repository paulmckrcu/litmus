#! /bin/sh
#
# Convert LISA litmus test to auxiliary-variable form.
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

# Uncomment the following to cause this script to detect RCU self-deadlock
# and force a LISA syntax error.
# rcu_deadlock="-v rcu_deadlock=1"

./stripocamlcomment |
gawk $rcu_deadlock '

########################################################################
#
# Data structures:
#
# @@@ preamble[proc][gp]: How many preambles emitted for process/gp combo.
# postamble[proc][gp]: How many postambles emitted for process/gp combo.
# aux[proc][line]: Litmus test with RCU statements translated.
# lisa[proc][line]: Input litmus-test statements.
# nproc: Number of processes.
# ngp: Number of grace periods across all processes.
# rcugp[gp]: Process containg RCU grace period gp.
# rcurl[proc]: Number of RCU read-side critical sections in process.


########################################################################
#
# Litmus-test variables and registers:
#
# gpstartGG: Has grace period GG started yet?  (GG count is one-based.)
# gpendGG: Has grace period GG ended yet?
#
# @@@ r1001:  Always 1 (to emulate unconditional branch).
# @@@ r1008:  Scratch register for conditionals.
# @@@ r1009:  Scratch register for conditionals.
# r1GG0:  Holds gpstartGG.
# r1GG1:  Holds gpendGG.


########################################################################
#
# Emit a preamble
#
function emit_one_preamble(proc_num, gp_num, line_out,  line) {
	line = line_out;
	aux[proc_num ":" line++] = "(* preamble " gp_num " *)";
	aux[proc_num ":" line++] = sprintf("r[once] r1%02d0 gpstart%02d", gp_num, gp_num);
	aux[proc_num ":" line++] = "(* end preamble " gp_num " *)";
	preamble[proc_num ":" gp_num]++;
	return line;
}

########################################################################
#
# Emit all preambles
#
function emit_preamble(proc_num, line_out,  gp_num, line) {
	line = line_out;
	for (gp_num = 1; gp_num <= ngp; gp_num++)
		line = emit_one_preamble(proc_num, gp_num, line);
	return line;
}

########################################################################
#
# Emit a postamble
#
function emit_one_postamble(proc_num, gp_num, line_out,  line, cpa) {
	line = line_out;
	cpa = postamble[proc_num ":" gp_num];
	aux[proc_num ":" line++] = "(* postamble " gp_num " *)";
	aux[proc_num ":" line++] = sprintf("r[once] r1%02d1 gpend%02d", gp_num, gp_num);
	aux[proc_num ":" line++] = "(* end postamble " gp_num " *)";
	postamble[proc_num ":" gp_num]++;
	return line;
}

########################################################################
#
# Emit a postamble
#
function emit_postamble(proc_num, line_out,  gp_num, line) {
	line = line_out;
	for (gp_num = 1; gp_num <= ngp; gp_num++)
		line = emit_one_postamble(proc_num, gp_num, line);
	return line;
}

########################################################################
#
# Emit an RCU grace period.
#
function emit_sync(gp_num, line_out, stmt,  line) {
	line = line_out;
	aux[proc_num ":" line++] = "(* GP " gp_num " *)";
	aux[proc_num ":" line++] = "f[mb]";
	aux[proc_num ":" line++] = sprintf("w[once] gpstart%02d 1", gp_num);
	aux[proc_num ":" line++] = stmt;
	aux[proc_num ":" line++] = sprintf("w[once] gpend%02d 1", gp_num);
	aux[proc_num ":" line++] = "f[mb]";
	aux[proc_num ":" line++] = "(* end GP " gp_num " *)";
	return line;
}

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
	print $1, $2 "-AuxCat";
	inpreamble = 1;
	next;
}

# String and comments.
inpreamble == 1 {
	if ($1 ~ /"/)
		print;
	if ($0 ~ /{/) {
		print;
		if ($0 != "{") {
			print "Line " NR ": Single { to begin initialization!";
			exit;
		}
		inpreamble = 0;
		ininit = 1;
	}
	next;
}

# Initialization statements.
ininit == 1 {
	if ($0 ~ /}/) {
		if ($0 != "}") {
			print "Line " NR ": Single } to end initialization!";
			exit;
		}
		print "}"
		ininit = 0;
		incode = 1;
		line = 1;
		nproc = 0;
		ngp = 0;
	} else {
		print;
	}
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
	## print $0 # @@@
	gsub(/^[ 	]*/, "");
	gsub(/;[ 	]*$/, "");
	split($0, cur_line, "|");
	if (nproc == 0)
		nproc = length(cur_line);
	else if (nproc != length(cur_line)) {
		print "Line " NR ": Expected " nproc " processes!";
		exit;
	}
	for (proc_num = 1; proc_num <= nproc; proc_num++) {
		gsub(/^[ 	]*/, "", cur_line[proc_num]);
		gsub(/[ 	]*$/, "", cur_line[proc_num]);
		## print "P" proc_num - 1 ": " cur_line[proc_num] # @@@
		if (cur_line[proc_num] == "f[sync]" || cur_line[proc_num] == "call[sync]") {
			if (rcunest[proc_num] + 0 != 0 && rcu_deadlock + 0) {
				# Force LISA syntax error
				cur_line[proc_num] = "call[sync DEADLOCK]";
			} else {
				ngp++;
				rcugp[ngp] = proc_num;
			}
		}
		if (cur_line[proc_num] == "f[lock]") {
			if (rcunest[proc_num] + 0 == 0)
				rcurl[proc_num]++;
			else
				cur_line[proc_num] = "(* nested " cur_line[proc_num] " *)";
			rcunest[proc_num]++;
		} else if (cur_line[proc_num] == "f[unlock]") {
			if (rcunest[proc_num] == 1)
				rcurul[proc_num]++;
			else
				cur_line[proc_num] = "(* nested " cur_line[proc_num] " *)";
			rcunest[proc_num]--;
		}
		if (cur_line[proc_num] != "") {
			max_line[proc_num]++;
			lisa[proc_num ":" max_line[proc_num]] = cur_line[proc_num];
			## print "P" proc_num - 1 " line " max_line[proc_num] ": " cur_line[proc_num] # @@@
		}
	}
	line++;
	next;
}

# In case we have a multi-line "exists" statement, pull it all together.
inexists == 1 {
	exists = exists " " $0;
}

# Translate and output!
END {
	# Do the translation from lisa[] to aux[].
	aux_max_line = 0;
	gp_num = 1;
	for (proc_num = 1; proc_num <= nproc; proc_num++) {
		## print "max_line[" proc_num "] = " max_line[proc_num]; # @@@
		line_in = 1;
		line_out = 1;
		for (line_in = 1; line_in <= max_line[proc_num]; line_in++) {
			stmt = lisa[proc_num ":" line_in];
			if (line_in == 1) {
				aux[proc_num ":" line_out++] = stmt;
			} else if (stmt == "f[lock]") {
				aux[proc_num ":" line_out++] = stmt;

				line_out = emit_preamble(proc_num, line_out);
				aux[proc_num ":" line_out++] = "(* end " stmt " *)";
			} else if (stmt == "f[unlock]") {
				aux[proc_num ":" line_out++] = "(* start " stmt " *)";
				line_out = emit_postamble(proc_num, line_out);
				aux[proc_num ":" line_out++] = stmt;
			} else if (stmt == "f[sync]" || stmt = "call[sync]") {
				line_out = emit_sync(gp_num++, line_out, stmt);
			} else {
				aux[proc_num ":" line_out++] = stmt;
			}
		}
		if (line_out - 1 > aux_max_line)
			aux_max_line = line_out - 1;
	}

	# Find maximum statement length for each process.
	for (proc_num = 1; proc_num <= nproc; proc_num++) {
		max_length[proc_num] = 0;
		for (line_out = 1; line_out <= aux_max_line; line_out++) {
			stmt = aux[proc_num ":" line_out];
			if (length(stmt) > max_length[proc_num])
				max_length[proc_num] = length(stmt);
		}
	}

	# Output the code.
	for (line_out = 1; line_out <= aux_max_line; line_out++) {
		for (proc_num = 1; proc_num <= nproc; proc_num++) {
			stmt = aux[proc_num ":" line_out];
			pad = max_length[proc_num] - length(stmt);
			printf " %s%*s %s", stmt, pad, "", proc_num < nproc ? "|" : ";";
		}
		printf "\n";
	}

	# exists clause.
	printf "%s\n", exists;
}
'
