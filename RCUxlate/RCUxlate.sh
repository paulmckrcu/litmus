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

prophesy_check_lisa=
# prophesy_check_lisa="-v prophesy_check_lisa=1"

./stripocamlcomment |
gawk $prophesy_check_lisa '

########################################################################
#
# Data structures:
#
# preamble[proc][gp]: How many preambles emitted for process/gp combo.
# postamble[proc][gp]: How many postambles emitted for process/gp combo.
# aux[proc][line]: Litmus test with RCU statements translated.
# lisa[proc][line]: Input litmus-test statements.
# nproc: Number of processes, ignoring prophesy-variable process.
# ngp: Number of grace periods across all processes.
# rcugp[gp]: Process containg RCU grace period gp.
# rcurl[proc]: Number of RCU read-side critical sections in process.


########################################################################
#
# Litmus-test variables and registers:
#
# gpstartGG: Has grace period GG started yet?  (GG count is one-based.)
# gpendGG: Has grace period GG ended yet?
# prophGG: Prophesy variable for gpendGG.
#
# r1001:  Always 1 (to emulate unconditional branch).
# r1008:  Scratch register for conditionals.
# r1009:  Scratch register for conditionals.
# r1GG0:  Holds gpstartGG.
# r1GG1NN:  Holds gpendGG, NNth read by current process, zero-based.
# r1GG2NN:  Holds prophGG, NNth read by current process.


########################################################################
#
# Emit a preamble
#
function emit_preamble(proc_num, gp_num, line_out,  line) {
	line = line_out;
	aux[proc_num ":" line++] = "(* preamble " gp_num " *)";
	if (preamble[proc_num ":" gp_num] + 0 >= 1)
		aux[proc_num ":" line++] = sprintf("b[] r1%02d0 GPSS%02d%02d%d", gp_num, gp_num, proc_num, preamble[proc_num ":" gp_num]);
	aux[proc_num ":" line++] = sprintf("r[once] r1%02d0 gpstart%02d", gp_num, gp_num);
	aux[proc_num ":" line++] = sprintf("mov r1009 (eq r1%02d0 0)", gp_num);
	aux[proc_num ":" line++] = sprintf("b[] r1009 GPSS%02d%02d%d", gp_num, proc_num, preamble[proc_num ":" gp_num]);
	aux[proc_num ":" line++] = "f[mb]";
	aux[proc_num ":" line++] = sprintf("GPSS%02d%02d%d:", gp_num, proc_num, preamble[proc_num ":" gp_num]);
	aux[proc_num ":" line++] = "(* end preamble " gp_num " *)";
	preamble[proc_num ":" gp_num]++;
	return line;
}

########################################################################
#
# Emit a postamble prophesy check using LISA code.
#
function emit_postamble_prophesy_check_lisa(proc_num, gp_num, cpa, line_in,  line) {
	line = line_in;
	aux[proc_num ":" line++] = sprintf("mov r1008 (eq r1%02d1%02d r1%02d2%02d)", gp_num, cpa, gp_num, cpa);
	aux[proc_num ":" line++] = sprintf("b[] r1008 GPES%02d%02d%d", gp_num, proc_num, cpa);
	aux[proc_num ":" line++] = sprintf("b[] r1001 ERR%02d", proc_num);
	return line;
}

########################################################################
#
# Emit a postamble prophesy check using exists clause, that is, no check
# in the LISA code.
#
function emit_postamble_prophesy_check_exists(proc_num, gp_num, cpa, line_in) {
	return line_in;
}

########################################################################
#
# Emit a postamble
#
function emit_postamble(proc_num, gp_num, line_out,  line, cpa) {
	line = line_out;
	cpa = postamble[proc_num ":" gp_num];
	aux[proc_num ":" line++] = "(* postamble " gp_num " *)";
	if (cpa + 0 >= 1)
		aux[proc_num ":" line++] = sprintf("b[] r1%02d1%02d GPES%02d%02d%d", gp_num, cpa, gp_num, proc_num, cpa);
	aux[proc_num ":" line++] = sprintf("r[once] r1%02d2%02d proph%02d", gp_num, cpa, gp_num);
	aux[proc_num ":" line++] = sprintf("b[] r1%02d2%02d CKP%02d%02d%d", gp_num, cpa, gp_num, proc_num, cpa);
	aux[proc_num ":" line++] = "f[mb]";
	aux[proc_num ":" line++] = sprintf("CKP%02d%02d%d:", gp_num, proc_num, cpa);
	aux[proc_num ":" line++] = sprintf("r[once] r1%02d1%02d gpend%02d", gp_num, cpa, gp_num);
	if (prophesy_check_lisa)
		line = emit_postamble_prophesy_check_lisa(proc_num, gp_num, cpa, line);
	else
		line = emit_postamble_prophesy_check_exists(proc_num, gp_num, cpa, line);
	aux[proc_num ":" line++] = sprintf("GPES%02d%02d%d:", gp_num, proc_num, cpa);
	aux[proc_num ":" line++] = "(* end postamble " gp_num " *)";
	postamble[proc_num ":" gp_num]++;
	return line;
}

########################################################################
#
# Emit an RCU grace period.
#
function emit_sync(gp_num, line_out,  line) {
	line = line_out;
	aux[proc_num ":" line++] = "(* GP " gp_num " *)";
	aux[proc_num ":" line++] = "f[mb]";
	aux[proc_num ":" line++] = sprintf("w[once] gpstart%02d 1", gp_num);
	aux[proc_num ":" line++] = "f[mb]";
	aux[proc_num ":" line++] = sprintf("w[once] gpend%02d 1", gp_num);
	aux[proc_num ":" line++] = "f[mb]";
	aux[proc_num ":" line++] = "(* end GP " gp_num " *)";
	return line;
}

########################################################################
#
# Grace-period checks are only needed in processes containing RCU
# read-side critical sections, and even then only for grace periods
# in other processes.  This function checks to see if the specified
# process needs to check for the specified grace period.
#
function proc_needs_gp_check(proc_num, gp_num) {
	if (!rcurl[proc_num])
		return 0;
	return rcugp[gp_num] != proc_num;
}

########################################################################
#
# Does the specified statement of the specified process need check code
# against the specified grace period?
#
function stmt_needs_gp_check(stmt) {
	if (stmt == "f[lock]" || stmt == "f[unlock]")
		return 0;
	if (stmt ~ /^[frw]\[/)
		return 1;
	if (stmt == "-EOF-")
		return 1;
	if (stmt ~ /^P[0-9]/)
		return 0;
	return 0;
}

########################################################################
#
# Determine whether the specified line of the specified process needs
# against the specified grace period, and if so, cause the litmus-test
# code for the checks to be inserted into the aux[][] array.
#
function do_gp_checks(proc_num, line_out, rcurscs, rl, rul,  gp_num, line) {
	line = line_out;
	for (gp_num = 1; gp_num <= ngp; gp_num++) {
		if (proc_needs_gp_check(proc_num, gp_num)) {
			if (rcurscs > rl)
				line = emit_preamble(proc_num, gp_num, line);
			if (rul > 0)
				line = emit_postamble(proc_num, gp_num, line);
		}
	}
	return line;
}

########################################################################
#
# Determine whether the specified line of the specified process needs
# checks against any of the grace periods, and cause the litmus-test
# code for the checks to be inserted into the aux[][] array as needed.
#
function do_gp_checks_if_needed(proc_num, line_in, line_out, rcurscs, rl, rul,  line, stmt) {
	line = line_out;
	stmt = lisa[proc_num ":" line_in];
	if (!stmt_needs_gp_check(stmt))
		return line;  # Later check for empty RCU RS CS here
	line = do_gp_checks(proc_num, line, rcurscs, rl, rul);
	return line;
}

########################################################################
#
# Output the "exists" clause the old way, which uses LISA code to
# compute whether or not the prophesy was correct.
#
function output_exists_clause_lisa(proc_num, npa,  gp_num) {
	if (npa <= 0)
		return;
	printf(" /\\ %d:r1008=1", proc_num - 1);
	for (gp_num = 1; gp_num <= ngp; gp_num++)
		if (rcugp[gp_num] != proc_num)
			printf(" /\\ (%d:r1%02d0=1 \\/ %d:r1%02d100=0)", proc_num - 1, gp_num, proc_num - 1, gp_num);
}

########################################################################
#
# Output the "exists" clause the new way, which uses the exists clause
# to compute whether or not the prophesy was correct.
#
function output_exists_clause_exists(proc_num, npa,  i, gp_num) {
	for (i = 0; i < npa; i++) {
		for (gp_num = 1; gp_num <= ngp; gp_num++) {
			printf(" /\\ %d:r1%02d1%02d=%d:r1%02d2%02d", proc_num - 1, gp_num, i, proc_num - 1, gp_num, i);
			if (rcugp[gp_num] != proc_num)
				printf(" /\\ (%d:r1%02d0=1 \\/ %d:r1%02d1%02d=0)", proc_num - 1, gp_num, proc_num - 1, gp_num, i);
		}
	}
}

########################################################################
#
# Output the "exists" clause.
#
function output_exists_clause(  npa) {
	printf "%s", exists;
	for (proc_num = 1; proc_num <= nproc; proc_num++) {
		npa = 0;
		for (i = 1; i <= ngp; i++) {
			if (postamble[proc_num ":" i] > 0) {
				npa = postamble[proc_num ":" i];
				break;
			}
		}
		if (prophesy_check_lisa)
			output_exists_clause_lisa(proc_num, npa);
		else
			output_exists_clause_exists(proc_num, npa);
	}
	print ")";
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
	print $1, $2 "-Auxiliary";
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
	gsub(/exists */, "exists (", exists);
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
		if (cur_line[i] == "f[sync]") {
			if (rcunest[i] + 0 != 0) {
				# Force LISA syntax error
				cur_line[i] = "f[sync DEADLOCK]";
			} else {
				ngp++;
				rcugp[ngp] = i;
			}
		}
		if (cur_line[i] == "f[lock]") {
			if (rcunest[i] + 0 == 0)
				rcurl[i]++;
			else
				cur_line[i] = "(* nested " cur_line[i] " *)";
			rcunest[i]++;
		} else if (cur_line[i] == "f[unlock]") {
			if (rcunest[i] == 1)
				rcurul[i]++;
			else
				cur_line[i] = "(* nested " cur_line[i] " *)";
			rcunest[i]--;
		}
		if (cur_line[i] != "") {
			max_line[i]++;
			lisa[i ":" max_line[i]] = cur_line[i];
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
	# Output initialization for auxiliary litmus-test variables.
	for (i = 1; i <= ngp; i++)
		printf "proph%02d=0;\n", i;
	for (i = 1; i <= nproc; i++)
		printf " %d:r1001=1;", i - 1;
	print "\n}";

	# Do the translation from lisa[] to aux[].
	aux_max_line = 0;
	gp_num = 1;
	for (proc_num = 1; proc_num <= nproc; proc_num++) {
		line_in = 1;
		line_out = 1;
		drl = 0;
		rl = 0;
		rul = 0;
		for (line_in = 1; line_in <= max_line[proc_num]; line_in++) {
			line_out = do_gp_checks_if_needed(proc_num, line_in, line_out, rcurl[proc_num], rl, rul);
			stmt = lisa[proc_num ":" line_in];
			aux[proc_num ":" line_out] = stmt;
			if (line_out > aux_max_line)
				aux_max_line = line_out;
			if (stmt == "f[lock]") {
				drl++;
				aux[proc_num ":" line_out++] = "(* " stmt " *)";
			} else if (stmt == "f[unlock]") {
				rul += 1;
				rl += drl;
				drl = 0;
				aux[proc_num ":" line_out++] = "(* " stmt " *)";
			} else if (stmt == "f[sync]") {
				line_out = emit_sync(gp_num++, line_out);
			} else if (stmt ~ /^[frw]\[/) {
				rl += drl;
				drl = 0;
				aux[proc_num ":" line_out++] = stmt;
			} else {
				aux[proc_num ":" line_out++] = stmt;
			}
		}
		line_out = do_gp_checks(proc_num, line_out, rcurl[proc_num], rl, rul);
		if (prophesy_check_lisa) {
			sum = 0;
			for (i = 1; i <= ngp; i++)
				sum += postamble[proc_num ":" i];
			if (sum > 0)
				aux[proc_num ":" line_out++] = sprintf("ERR%02d:", proc_num);
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

	# Output the code and the stores to the prophesy variables.
	for (line_out = 1; line_out <= aux_max_line; line_out++) {
		for (proc_num = 1; proc_num <= nproc; proc_num++) {
			stmt = aux[proc_num ":" line_out];
			pad = max_length[proc_num] - length(stmt);
			printf " %s%*s |", stmt, pad, "";
		}
		if (line_out == 1) {
			printf " P%d", nproc;
		} else if (line_out <= ngp + 1) {
			printf " w[once] proph%02d 1", line_out - 1;
		}
		printf " ;\n";
	}

	# In case there are more prophesy variables than lines of code.
	for (; line_out <= ngp + 1; line_out++) {
		for (proc_num = 1; proc_num <= nproc; proc_num++)
			printf " %*s |", max_length[proc_num], "";
		printf " w[once] proph%2d 1 ;\n", line_out - 1, nproc;
	}

	# exists clause.
	output_exists_clause();
}
'
