#! /bin/sh
#
# Generate a suitable set of litmus tests for analysis.
#
# Usage:
#	sh makelitmustests.sh
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

{
	# Load-buffering RCU tests, and with added ordering.
	sh gendir.sh "RW-G RW-R" 8
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R/RW-RB/p'
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R/RW-RC/p'
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R RW-R/RW-Rr RW-Ra/p'
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R RW-R/RW-Rs RW-RD/p'

	# A few larger load-buffering RCU tests.
	sh gendir.sh "RW-G+RW-G+RW-G+RW-G RW-R+RW-R+RW-R+RW-R" 4 |
		awk '{ if (NF >= 3) print }' |
		tr '+' ' '

	# Load-buffering tests involving RCU grace periods and full barriers.
	sh gendir.sh "RW-G RW-B" 8
	sh gendir.sh "RW-G RW-B" 8 |
		sed -n -e 's/RW-B RW-B/RW-r RW-a/p'
	sh gendir.sh "RW-G RW-B" 8 |
		sed -n -e 's/RW-B RW-B/RW-r RW-C/p'
	sh gendir.sh "RW-G RW-B" 8 |
		sed -n -e 's/RW-B RW-B/RW-r RW-D/p'

	# Non-load-buffering RCU tests.
	sh gendir.sh "RW-G RW-RI" 8
	sh gendir.sh "RR-G RR-R" 8
	sh gendir.sh "WR-G WR-R" 8
	sh gendir.sh "WW-G WW-R" 8
	sh gendir.sh "WW-G WW-R" 8 |
		sed -n -e 's/WW-R/WW-B/p'
} | sh dir2litmus.sh litmus/
