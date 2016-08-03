#! /bin/sh
#
# Convert LISA litmus test to pseudo-C-language form.  This script
# makes no attempt to produce type-safe C.
#
# Usage: sh LISA2C.sh < lisa.litmus
#
#	The output file is controlled by the litmus test name.  So a
#	LISA file with header "LISA /tmp/argh.litmus" would have its
#	pseudo-C-language output in "/tmp/C-argh.litmus".
#
# Note that the pseudo-C code is just that.  In particular, the current
# version of this script makes no attempt to respect C types, instead
# relying on the type-oblivious nature of herd.
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

../RCUxlate/stripocamlcomment |
gawk '

@include "RCUlitmusCout.awk"

########################################################################
#
# Data structures:
#
# lisa[proc ":" line]: Input litmus-test statements.
# nproc: Number of processes
# vars[proc ":" name]: Global variable used by specified process.

########################################################################
#
# Do-nothing output_comments() function.
function output_comments(comments, fn) {
}

########################################################################
#
# Do-nothing output_comments() function.
function extract_global_vars(p, expr,  i, operands, operators) {
	patsplit(expr, operators, /[- ()+*/]/, operands);
	for (i in operands)
		if (operands[i] == "" || operands[i] !~ /^r[0-9]+$/)
			vars[p ":" operands[i]] = 1;
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
	litname = $2;
	inpreamble = 1;
	next;
}

# String and comments.
inpreamble == 1 {
	if ($0 ~ /{/) {
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
		varinit = varinit $0;
	}
	next;
}

# The "exists" statement at the end.  Handled first due to terminal laziness.
incode == 1 && $1 ~ /^exists/ {
	incode = 0;
	inexists = 1;
	exists = $0;
	gsub("^ *exists *", "", exists);
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
		if (cur_line[i] == "")
			continue;
		max_line[i]++;

		if (cur_line[i] ~ /r\[/ || cur_line[i] ~ /w\[/) {
			split(cur_line[i], operands, " ");
			if (cur_line[i] ~ /r\[/)
				extract_global_vars(i, operands[3]);
			else
				extract_global_vars(i, operands[2]);
		}

		lisa[i ":" max_line[i]] = cur_line[i];
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
	output_C_litmus(litname, "", varinit, vars, lisa, exists);
}
'
