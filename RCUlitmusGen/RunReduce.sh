#!/bin/sh
#
# Print out lists of test results as success/failures.
# Use the "." command to source this into some other script.
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
# Copyright IBM Corporation, 2015
#
# Author: Paul E. McKenney <paulmck@linux.vnet.ibm.com>

echo Tests that ran as expected:
echo "$asExpected" | tr -s ' ' '\012' | grep -v '^$' | sort | sed -e 's/^/\t/' | fmt
n_succ=`echo "$asExpected" | wc -w`

if test -n "$notAsExpected"
then
	echo ' --- Error: Tests with unexpected results:'
	echo "$notAsExpected" | tr -s ' ' '\012' | grep -v '^$' | sort | sed -e 's/^/\t/' | fmt
	n_fail=`echo "$notAsExpected" | wc -w`
	echo Number that ran as expected: $n_succ
	echo Number of unexpected results: $n_fail
	exit 1
fi
echo All $n_succ ran as expected
exit 0
