#! /bin/sh
#
# Test output of LISA litmus tests.
#
# Usage:
#	sh RCUlitmusout-test.sh
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


gawk -f RCUlitmusout.awk -e '
BEGIN {
	aux[1 ":" 1] = "w[once] x1 1";
	aux[1 ":" 2] = "f[sync]";
	aux[1 ":" 3] = "w[once] x2 1";
	aux[2 ":" 1] = "f[lock]";
	aux[2 ":" 2] = "r[once] r1 x1";
	aux[2 ":" 3] = "r[once] r2 x2";
	aux[2 ":" 4] = "f[unlock]";
	output_lisa("test", "This is a\nmulti-line comment", "x=0; y=0;\n1:r1=42; 1:r2=43;", aux, "1:r2=1 /\\ 1:r1=0");
}'
