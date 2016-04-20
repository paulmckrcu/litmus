#!/bin/bash
#
# Run the automatically generated litmus tests in the litmus/ directory.
#
# Usage:
#	sh RunAllLitmus.sh [ ncpus ] < makelitmustests.sh.out
#
# The value of ncpus defaults to all online CPUs on the system.
#
# Can specify LINUX_BELL_FILE and LINUX_CAT_FILE environment variables.
#
# You could also do this:
#
#	sh makelitmustests.sh | sh RunAllLitmus.sh [ ncpus ]
#
# However, it is convenient to have the makelitmustests.sh output handy.
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

nonline=`getconf _NPROCESSORS_ONLN`
ncpu=${1-$nonline}

T=/tmp/RunAllLitmus.sh.$$
trap 'rm -rf $T' 0
mkdir $T

for ((i=0;i<$ncpu;i++))
do
	touch $T/asExpected.$i
	touch $T/notAsExpected.$i
	echo T=$T > $T/$i.sh
	cat << '___EOF___' >> $T/$i.sh
	runtest () {
		echo ' ... ' sh RunLitmus.sh $1.litmus $2
		if sh RunLitmus.sh $1.litmus $2
		then
___EOF___
			echo 'echo "$asExpected $1:($2)" >> ' $T/asExpected.$i >> $T/$i.sh
		echo else >> $T/$i.sh
			echo 'echo "$notAsExpected $1:($2)" >> ' $T/notAsExpected.$i >> $T/$i.sh
		echo fi >> $T/$i.sh
	echo } >> $T/$i.sh
done

sed -e 's/\.litmus//' |
awk -v ncpu=$ncpu -v t=$T '
{
	print "runtest " $2 " " $4 >> t "/" NR % ncpu ".sh";
}

END {
	for (i = 0; i < ncpu; i++) {
		print "sh " t "/" i ".sh > " t "/" i ".sh.out 2>&1 &";
		close(t "/" i ".sh")
	}
	print "wait";

}' | sh
asExpected=`cat $T/asExpected.*`
notAsExpected=`cat $T/notAsExpected.*`
cat $T/*.sh.out
. ./RunReduce.sh
ls $T
