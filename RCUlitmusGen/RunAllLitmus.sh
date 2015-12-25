#!/bin/sh
#
# Run the automatically generated litmus tests in the litmus/ directory.
#
# Usage:
#	sh RunAllLitmus.sh < makelitmustests.sh.out
#
# Can specify LINUX_BELL_FILE and LINUX_CAT_FILE environment variables.
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

sed -e 's/\.litmus//' |
	awk '{ print "runtest " $2 " " $4; }' > shortlitmus.sh
sh runAllCat.sh
