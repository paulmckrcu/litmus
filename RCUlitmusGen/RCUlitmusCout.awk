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
# Global variables:
#
# gvars_init[proc_name ":" var]: Variables needed for register initialization.
# reg_init[proc_num]: Per-process register-initialization table.
# reg_table[proc_num ":" reg]: Per-process register table.
# scratch_regs[proc_num]: Per-process scratch register.


########################################################################
#
# Parse out register initialization from LISA initialization statements,
# placing C-language equivalents in reg_init[].  Also flag global variables
# that must be present in function argument lists due to those global
# variables being used in register initialization.  These global variables
# are tracked in gvars_init[].
#
# Returns the remaining list of global-variable initializations, if any.
#
function filter_varinit(varinit,  i, proc_num, ri, rn, vi, vi_out) {
	split(varinit, vi, ";");
	for (i = 1; i <= length(vi); i++) {
		gsub(/[[:space:]]*/, "", vi[i]);  # Strip whitespace.
		if (vi[i] == "")
			continue;
		if (vi[i] !~ /:/) { # Global-variable initialization
			vi_out = vi_out "\t" vi[i] ";\n";
			continue;
		}
		split(vi[i], ri, ":"); # Process number and initializer.
		proc_num = ri[1] + 1;
		reg_init[proc_num] = reg_init[proc_num] "\n\tintptr_t " ri[2] ";";
		split(ri[2], rn, "="); # Isolate register name.
		reg_table[proc_num ":" rn[1]] = 2; # Already declared.
		if (rn[2] !~ /^r?[0-9]+$/)
			gvars_init[proc_num ":" rn[2]] = 1;
	}
	return vi_out;
}

########################################################################
#
# Find a scratch register for every process.
#
function find_scratch_regs(stmts,  i, idx, j, proc_max, stmt_regs, trash) {
	proc_max = 0;
	for (i in stmts) {
		split(i, idx, ":");
		if (idx[1] > proc_max)
			proc_max = idx[1];
		patsplit(stmts[i], trash, /[ \[\]()]/, stmt_regs);
		for (j in stmt_regs) {
			if (stmt_regs[j] ~ /^r[0-9]+$/ &&
			    reg_table[idx[1] ":" stmt_regs[j]] != 2)
				reg_table[idx[1] ":" stmt_regs[j]] = 1;
		}
	}
	for (i = 1; i <= proc_max; i++) {
		j = 1000;
		while (reg_table[i ":r" j] != "")
			j++;
		scratch_regs[i] = "r"j;
	}
}

########################################################################
#
# If this is the first use of the specified register by the specified
# process, prefix it with a declaration.
#
function reg_first_use(proc_num, r) {
	if (r !~ /^r[0-9]+$/)
		return r;
	if (reg_table[proc_num ":" r] != 2) {
		reg_table[proc_num ":" r] = 2;
		r = "intptr_t " r;
	}
	return r;
}

########################################################################
#
# Return the specified process's scratch register, prefixing with
# a declaration on first use.
#
function get_scratch_reg(proc_num,  r) {
	r = scratch_regs[proc_num];
	return reg_first_use(proc_num, r);
}

########################################################################
#
# Output the specified read, using a scratch register if needed.
#
function output_read(proc_num, rtype, splt, casts,  c, c2, reg, reg1, stmt_end) {
	split(casts, c, ",");
	if (splt[3] ~ /^r[0-9]+/)
		c2 = c[2];
	else
		c2 = c[3];
	if (rtype == "*")
		stmt_end = ";";
	else
		stmt_end = ");";
	if (splt[3] ~ /^[a-zA-Z0-9_]+$/) {
		reg = reg_first_use(proc_num, splt[2]);
		return reg " = " c[1] rtype c2 splt[3] stmt_end;
	}
	reg = get_scratch_reg(proc_num);
	reg1 = reg;
	if (reg1 ~ / /)
		gsub("^[^ ]+ +", "", reg1);
	return reg " = (" splt[3] ");\n" splt[2] " = " c[1] rtype c[2] reg1 stmt_end;
}

########################################################################
#
# Output the specified write, using a scratch register if needed.
#
function output_write(proc_num, wtype, splt,  reg, reg1, stmt_end, stmt_mid) {
	if (wtype == "*") {
		stmt_mid = " = ";
		stmt_end = ";";
	} else {
		stmt_mid = ", ";
		stmt_end = ");";
	}
	if (splt[2] ~ /^[a-zA-Z0-9_]+$/)
		return wtype splt[2] stmt_mid splt[3] stmt_end;
	reg = get_scratch_reg(proc_num);
	reg1 = reg;
	if (reg1 ~ / /)
		gsub("^[^ ]+ +", "", reg1);
	return reg " = (" splt[2] ");\n" wtype reg1 stmt_mid splt[3] stmt_end;
}

########################################################################
#
# Translate one statement from the specified process from LISA to C.
#
function translate_statement(proc_num, stmt,  n, reg, rel, splt) {
	if (stmt ~ /^P[0-9]*/)
		return ""
	if (stmt ~ /^[A-Za-z][A-Za-z0-9]*:/)
		return "}";
	if (stmt ~ /^b\[] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return "if (" splt[2] ") {"
	}
	if (stmt == "f[rcu_read_lock]")
		return "rcu_read_lock();"
	if (stmt == "f[mb]")
		return "smp_mb();"
	if (stmt == "f[rbdep]")
		return "smp_read_barrier_depends();"
	if (stmt == "f[rb_dep]")
		return "smp_read_barrier_depends();"
	if (stmt == "f[rmb]")
		return "smp_rmb();"
	if (stmt == "f[sync]")
		return "synchronize_rcu();"
	if (stmt == "f[rcu_read_unlock]")
		return "rcu_read_unlock();"
	if (stmt == "f[wmb]")
		return "smp_wmb();"
	if (stmt ~ /^mov /) {
		n = split(stmt, splt, " ");
		if (n != 5)
			return "???" stmt;
		gsub(")", "", splt[5]);
		if (splt[3] == "(add")
			rel = " + ";
		else if (splt[3] == "(and")
			rel = " & ";
		else if (splt[3] == "(eq")
			rel = " != ";
		else if (splt[3] == "(neq")
			rel = " == ";
		else if (splt[3] == "(xor")
			rel = " ^ ";
		else
			return "???" stmt;
		reg = reg_first_use(proc_num, splt[2])
		return reg " = (" splt[4] rel splt[5] ");";
	}
	if (stmt ~ /^r\[acquire] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return output_read(proc_num, "smp_load_acquire(", splt,
				   ",(intptr_t *),");
	}
	if (stmt ~ /^r\[l?deref] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return output_read(proc_num, "rcu_dereference(*", splt,
				   "(intptr_t),(intptr_t **),(intptr_t **)");
	}
	if (stmt ~ /^r\[once] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return output_read(proc_num, "READ_ONCE(*", splt,
				   ",(intptr_t *),");
	}
	if (stmt ~ /^r\[] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return output_read(proc_num, "*", splt, ",(intptr_t *),");
	}
	if (stmt ~ /^w\[assign] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return output_write(proc_num, "rcu_assign_pointer(*", splt);
	}
	if (stmt ~ /^w\[once] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return output_write(proc_num, "WRITE_ONCE(*", splt);
	}
	if (stmt ~ /^w\[release] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return output_write(proc_num, "smp_store_release(", splt);
	}
	if (stmt ~ /^w\[] /) {
		n = split(stmt, splt, " ");
		if (n != 3)
			return "???" stmt;
		return output_write(proc_num, "*", splt);
	}
	if (stmt ~ /^rmw\[once]/) {
		n = split(stmt, splt, " ");
		if (n != 4)
			return "???" stmt;
		reg = reg_first_use(proc_num, splt[2])
		return reg " = xchg_relaxed(" splt[4] ", " splt[3] ");"
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
# gvars[proc_num ":" varname]: Array containing global-variable/function usage.
# stmts[proc_num ":" line_out]: Array of LISA statements.
# exists: String containing exists clause, optionally with embedded "\n".
#	The outermost set of parentheses are supplied by output_litmus.
# exists_paren: True if the exists clause is already fully parenthisized,
#	false otherwise.  Note that an empty argument evaluates to false.
#
function output_C_litmus(litname, comments, varinit, gvars, stmts, exists, exists_paren,  arglists, aux_max_line, comment, curvar, fn, i, line_out, max_length, max_stmts, nproc, nstmts, pad, proc_num, stmt, stmt_list, stmt_splt, tabs, varinit_noregs) {
	delete gvars_init;
	delete reg_init;
	delete reg_table;
	delete scratch_regs;
	fn = litname;
	gsub("[^/]*$", "", fn);
	pad = litname;
	gsub("^.*/", "", pad);
	pad = fn "C-" pad;
	fn = pad ".litmus";
	# Output file header.
	print "C " pad > fn;

	# Process and output comments
	output_comments(comments, fn);

	# Output initialization.
	varinit_noregs = filter_varinit(varinit);
	print "{" > fn;
	if (varinit_noregs != "")
		print varinit_noregs "}" > fn;
	else
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

	# Form each process's parameter list, pulling in initialization
	for (i in gvars)
		gvars_init[i] = gvars[i];
	for (i in gvars_init) {
		proc_num = i;
		gsub(/:.*$/, "", proc_num);
		curvar = i;
		gsub(/^.*:/, "", curvar);
		if (arglists[proc_num] != "")
			arglists[proc_num] = arglists[proc_num] ", ";
		arglists[proc_num] = arglists[proc_num] "intptr_t *" curvar;
	}

	# Find a scratch register for each process, just in case.
	find_scratch_regs(stmts);

	# Output each process
	for (proc_num = 1; proc_num <= nproc; proc_num++) {
		print "" > fn;
		print "P" proc_num - 1 "(" arglists[proc_num] ")" > fn;
		if (reg_init[proc_num] ~ "intptr_t")
			print "{" reg_init[proc_num] "\n" > fn;
		else
			print "{" > fn;
		tabs = "\t"
		for (line_out = 0; line_out <= aux_max_line; line_out++) {
			stmt = stmts[proc_num ":" line_out];
			if (stmt == "")
				continue;
			stmt_list = translate_statement(proc_num, stmt);
			nstmts = split(stmt_list, stmt_splt, "\n");
			for (i = 1; i <= nstmts; i++) {
				if (stmt_splt[i] == "")
					continue;
				if (stmt_splt[i] == "}")
					tabs = substr(tabs, 2);
				print tabs stmt_splt[i] > fn;
				if (stmt_splt[i] ~ /^if /)
					tabs = tabs "\t";
			}
		}
		print "}\n" > fn;
	}

	# exists clause.
	if (exists_paren)
		printf "exists\n%s\n", exists > fn;
	else
		printf "exists\n(%s)\n", exists > fn;
	close(fn);
}
