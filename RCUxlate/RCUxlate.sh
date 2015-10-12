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

./stripocamlcomment |
gawk '

function proc_needs_gp_check(proc_num, gp_num) {
	if (!rcurl[proc_num])
		return 0;
	return rcugp[gp_num] != proc_num;
}

function stmt_needs_gp_check(proc_num, gp_num, stmt) {
	## printf "stmt_needs_gp_check(:%s:) ", stmt;
	if (!proc_needs_gp_check(proc_num, gp_num)) {
		## printf "\n";
		return 0;
	}
	## printf "proc_needs_gp_check() ";
	if (stmt == "f[lock]" || stmt == "f[unlock]") {
		## printf "\n";
		return 0;
	}
	## printf "f[lock]/f[unlock] ";
	if (stmt ~ /^[frw]\[/) {
		## printf "\n";
		return 1;
	}
	## printf "[frw][... ";
	if (stmt == "-EOF-") {
		## printf "\n";
		return 1;
	}
	## printf "-EOF-";
	if (stmt ~ /^P[0-9]/) {
		## printf "\n";
		return 0;
	}
	## printf "Other\n";
	return 0;
}

function do_one_gp_check(proc_num, stmt, line_out, rcurscs, rl, rul, gp_num,  line) {
	line = line_out;
	## print "do_one_gp_check(): proc_num = " proc_num " rcurscs = " rcurscs " rl = " rl " rul = " rul
	if (stmt_needs_gp_check(proc_num, i, stmt)) {
		## print "Need GP check, rcurscs = " rcurscs " rl = " rl " rul = " rul;
		if (rcurscs > rl) {
			## print "Adding preamble"
			aux[proc_num ":" line] = "(* preamble " gp_num " *)";
			line++;
		}
		if (rul > 0) {
			## print "Adding postamble"
			aux[proc_num ":" line] = "(* postamble " gp_num " *)";
			line++;
		}
	}
	return line;
}

function do_gp_checks(proc_num, line_in, line_out, rcurscs, rl, rul,  i, line, stmt) {
	line = line_out;
	## print "do_gp_checks(): proc_num = " proc_num " rcurscs = " rcurscs " rl = " rl " rul = " rul
	for (i = 1; i <= ngp; i++) {
		stmt = lisa[proc_num ":" line_in];
		line = do_one_gp_check(proc_num, stmt, line, rcurscs, rl, rul, i);
	}
	return line;
}

/^[ 	]*$/ {
	next;  /* Kill blank lines. */
}

NR == 1 {
	if ($1 != "LISA") {
		print "Need LISA file!";
		exit;
	}
	print $1, $2 "-Auxiliary";
	inpreamble = 1;
	next;
}

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

incode == 1 && $1 ~ /^exists/ {
	incode = 0;
	inexists = 1;
	exists = $0;
	gsub(/exists */, "exists (", exists);
	next;
}

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
			ngp++;
			rcugp[ngp] = i;
		}
		if (cur_line[i] == "f[lock]") {
			if (rcunest[i] + 0 == 0)
				rcurl[i]++;
			else
				cur_line[i] = "(* nested " cur_line[i] "*)";
			rcunest[i]++;
		} else if (cur_line[i] == "f[unlock]") {
			if (rcunest[i] == 1)
				rcurul[i]++;
			else
				cur_line[i] = "(* nested " cur_line[i] "*)";
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

inexists == 1 {
	exists = exists " " $0;
}

END {
	print nproc + 1 ":r001=1;";
	for (i = 1; i <= ngp; i++)
		print "proph" i "=1;";
	print "}";
	for (i = 1; i <= nproc; i++) {
		printf "Process %d: (%dR %dU) needs checks for grace periods:", i, rcurl[i], rcurul[i];
		for (j = 1; j <= ngp; j++) {
			if (proc_needs_gp_check(i, j))
				printf " %d", j;
		}
		printf "\n";
	}

	# Do the translation from lisa[] to aux[].
	aux_max_line = 0;
	for (proc_num = 1; proc_num <= nproc; proc_num++) {
		line_in = 1;
		line_out = 1;
		drl = 0;
		rl = 0;
		rul = 0;
		for (line_in = 1; line_in <= max_line[proc_num]; line_in++) {
			## print "line_out = " line_out;
			line_out = do_gp_checks(proc_num, line_in, line_out, rcurl[proc_num], rl, rul);
			stmt = lisa[proc_num ":" line_in];
			aux[proc_num ":" line_out] = stmt;
			if (line_out > aux_max_line)
				aux_max_line = line_out;
			## print "aux_max_line = " aux_max_line;
			if (stmt == "f[lock]") {
				drl++;
				aux[proc_num ":" line_out] = "(* " stmt " *)";
			} else if (stmt == "f[unlock]") {
				rul += 1;
				rl += drl;
				drl = 0;
				aux[proc_num ":" line_out] = "(* " stmt " *)";
			} else if (stmt ~ /^[frw]\[/) {
				rl += drl;
				drl = 0;
				aux[proc_num ":" line_out] = stmt;
			} else {
				aux[proc_num ":" line_out] = stmt;
			}
			line_out++;
		}
		for (cur_gp = 1; cur_gp <= ngp; cur_gp++) {
			## print "line_out = " line_out;
			line_out = do_one_gp_check(proc_num, "-EOF-", line_out, rcurl[proc_num], rl, rul);
			if (line_out - 1 > aux_max_line)
				aux_max_line = line_out - 1;
			## print "aux_max_line = " aux_max_line;
		}
	}
	## print "";
	## print "LISA:"
	## for (proc_num = 1; proc_num <= nproc; proc_num++) {
	## 	for (line_in = 1; line_in <= max_line[proc_num]; line_in++) {
	## 		if (lisa[proc_num ":" line_in] != "")
	## 			print ":" lisa[proc_num ":" line_in] ":";
	## 	}
	## }
	## print "";
	## print "AUX: aux_max_line = " aux_max_line;
	for (proc_num = 1; proc_num <= nproc; proc_num++) {
		max_length[proc_num] = 0;
		for (line_out = 1; line_out <= aux_max_line; line_out++) {
			stmt = aux[proc_num ":" line_out];
			if (length(stmt) > max_length[proc_num])
				max_length[proc_num] = length(stmt);
			## if (aux[proc_num ":" line_out] != "")
			## 	print ":" aux[proc_num ":" line_out] ":";
		}
	}
	for (line_out = 1; line_out <= aux_max_line; line_out++) {
		for (proc_num = 1; proc_num <= nproc; proc_num++) {
			stmt = aux[proc_num ":" line_out];
			pad = max_length[proc_num] - length(stmt);
			printf " %s%*s |", stmt, pad, "";
		}
		printf "\n";
	}
	print "exists "exists"@@@";
}
'
