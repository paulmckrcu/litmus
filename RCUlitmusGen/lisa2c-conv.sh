#! /bin/sh
#
# Convert LISA litmus test to C-language version, which is put in the
# same directory with a "C-" prefix.
#
# Usage: sh lisa2c-conv lisa.litmus
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

if grep -q '^LISA' $1
then
	:
else
	echo Bad format, need LISA
	exit 3
fi
cname=`echo $1 | sed -e 's,^.*/,,'`
dname=`echo $1 | sed -e 's,/[^/]*$,,'`
if test -e "$dname/C-$cname"
then
	echo Output file $dname/C-$cname already exists, not overwriting.
	exit 1
fi
sh lisa2c.sh < $1 > $dname/C-$cname
