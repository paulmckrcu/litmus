#!/bin/sh
#
# Run a bunch of herd tests given specified outcomes in this script
#
# Usage:
#	sh runAllCat.sh
#
# Can specify LINUX_HERD_OPTIONS environment variable.  This will
# normally have "-I" to specify the memory-model directory and
# "-conf" to specify the .cfg file.
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

asExpected=
notAsExpected=

# Run herd on the file with the specified expected outcome.
runtestCat () {
	echo ' ... ' sh RunLitmus.sh $1.litmus $2
	if sh RunLitmus.sh $1.litmus $2
	then
		asExpected="$asExpected $1:($2)"
	else
		notAsExpected="$notAsExpected $1:($2)"
	fi
}

runtest () {
	runtestCat $1 $2
}

. ./shortlitmus.sh
. ./longlitmus.sh

. ./RunReduce.sh
