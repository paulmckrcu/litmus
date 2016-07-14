# Output a C-language litmus test.
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
# Copyright (C) IBM Corporation, 2016
#
# Authors: Paul E. McKenney <paulmck@linux.vnet.ibm.com>


########################################################################
#
# Translate from LISA to C.
#
function translate_statement(stmt,  n, rel, splt) {
	if (stmt ~ /^P[0-9]*/)
		return ""
	if (stmt ~ /^[A-Za-z][A-Za-z0-9]*:/)
		return "}"
	if (stmt ~ /^b\[] /)
		return ""; # Generate "if" from preceding "mov".
	if (stmt == "f[lock]")
		return "rcu_read_lock();"
	if (stmt == "f[mb]")
		return "smp_mb();"
	if (stmt == "f[rbdep]")
		return "smp_read_memory_depends();"
	if (stmt == "f[rmb]")
		return "smp_rmb();"
	if (stmt == "f[sync]")
		return "synchronize_rcu();"
	if (stmt == "f[unlock]")
		return "rcu_read_unlock();"
	if (stmt == "f[wmb]")
		return "smp_wmb();"
	if (stmt ~ /^mov /) {
		n = split(stmt, splt, " ");
		if (n != 5 || (splt[3] != "(eq" && splt[3] != "(neq"))
			return "???" stmt;
		gsub(")", "", splt[5]);
		if (splt[3] == "(eq")
			rel = " != ";
		else if (splt[3] == "(neq")
			rel = " == ";
		return "if (" splt[4] rel splt[5] ") {";
	}
	if (stmt ~ /^r\[acquire] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return splt[2] " = smp_load_acquire(" splt[3] ");"
	}
	if (stmt ~ /^r\[deref] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return splt[2] " = rcu_dereference(*" splt[3] ");"
	}
	if (stmt ~ /^r\[lderef] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return splt[2] " = lockless_dereference(*" splt[3] ");"
	}
	if (stmt ~ /^r\[once] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return splt[2] " = READ_ONCE(*" splt[3] ");"
	}
	if (stmt ~ /^w\[assign] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return "rcu_assign_pointer(*" splt[2] ", "splt[3] ");"
	}
	if (stmt ~ /^w\[once] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return "WRITE_ONCE(*" splt[2] ", "splt[3] ");"
	}
	if (stmt ~ /^w\[release] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return "smp_store_release(" splt[2] ", "splt[3] ");"
	}
	return "???" stmt;
}

########################################################################
#
# Output a full C-language litmus test.  The arguments are as follows:
#
# litname: Name of the litmus test.  A ".litmus" is appended for filename.
# comments: String containing comments, optionally with embedded "\n".
#	Can be empty string for no comment.
# varinit: String containing initializers, optionally with embedded "\n".
#	Can be empty string for no initializers.
# stmts[proc_num ":" line_out]: Array of LISA statements.
# exists: String containing exists clause, optionally with embedded "\n".
#	The outermost set of parentheses are supplied by output_litmus.
#
function output_C_litmus(litname, comments, varinit, gvars, stmts, exists,  arglists, aux_max_line, comment, curvar, fn, i, line_out, max_length, max_stmts, nproc, pad, proc_num, stmt, tabs) {
	fn = litname;
	gsub("[^/]*$", "", fn);
	pad = litname;
	gsub("^.*/", "", pad);
	fn = fn "C-" pad ".litmus";
	# Output file header.
	print "C " litname > fn;

	# Process and output comments
	output_comments(comments, fn);

	# Output initialization.
	print "{" > fn;
	if (varinit != "")
		print varinit > fn;
	print "}" > fn;

	# Find the number of processes and maximum number of lines
	for (i in stmts) {
		proc_num = i;
		gsub(/:.*$/, "", proc_num);
		proc_num = proc_num + 0;
		line_out = i;
		gsub(/^.*:/, "", line_out);
		line_out = line_out + 0;
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

	# Form each process's parameter list
	for (i in gvars) {
		proc_num = i;
		gsub(/:.*$/, "", proc_num);
		curvar = i;
		gsub(/^.*:/, "", curvar);
		if (arglists[proc_num] != "")
			arglists[proc_num] = arglists[proc_num] ", ";
		arglists[proc_num] = arglists[proc_num] "int *" curvar;
	}

	# Output each process
	for (proc_num = 1; proc_num <= nproc; proc_num++) {
		print "" > fn;
		print "P" proc_num - 1 "(" arglists[proc_num] ")" > fn;
		print "{" > fn;
		tabs = "\t"
		for (line_out = 0; line_out <= aux_max_line; line_out++) {
			stmt = stmts[proc_num ":" line_out];
			if (stmt == "")
				continue;
			stmt = translate_statement(stmt);
			if (stmt == "")
				continue;
			if (stmt == "}")
				tabs = substr(tabs, 2);
			print tabs stmt > fn;
			if (stmt ~ /^if /)
				tabs = tabs "\t";
		}
		print "}\n" > fn;
	}

	# exists clause.
	printf "exists\n(%s)\n", exists > fn;
	close(fn);
}
