#! /bin/sh
#
# Generate all combinations of directives given specified list of
# directives and maximum number of processes.
#
# Usage:
#	sh gendir.sh [ directive-list [ nproc ] ]
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

dlist="${1-RW-R RW-G}"
nproc=${2-4}

echo "$dlist" | gawk -v nproc=$nproc -f necklace.awk -e '
{
	necklace($0, nproc);
	necklace_print();
}' | sort
