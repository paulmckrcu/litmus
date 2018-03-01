#!/bin/bash
#
# Run the automatically generated litmus tests specified on stdin.
#
# Usage:
#	bash RunAllLitmus.sh [ ncpus ] < makelitmustests.sh.out
#
# The value of ncpus defaults to all online CPUs on the system.
#
# Can specify LINUX_HERD_OPTIONS environment variable to specify
# command-line options to herd.
#
# You could also do this:
#
#	sh makelitmustests.sh | sh RunAllLitmus.sh [ ncpus ]
#
# However, it is convenient to have the makelitmustests.sh output handy.
#
# Running all the automatically generated tests can take days.  To
# run only those with five or fewer processes on the automatically
# generated tests using the strong model on Paul's laptop:
#
# grep -v '\(+.*\)\{6\}' auto/makelitmustests.sh.out | LINUX_HERD_OPTIONS="-I /home/git/linux-2.6-tip/tools/memory-model/ -conf linux-kernel.cfg" bash RunAllLitmus.sh 6 > /tmp/RunAllLitmus.sh.out 2>&1
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
		echo ' ... ' RunLitmus.sh $1.litmus $2
		if RunLitmus.sh $1.litmus $2
		then
___EOF___
			echo 'echo "$asExpected $1:($2)" >> ' $T/asExpected.$i >> $T/$i.sh
		echo else >> $T/$i.sh
			echo 'echo "$notAsExpected $1:($2)" >> ' $T/notAsExpected.$i >> $T/$i.sh
		echo fi >> $T/$i.sh
	echo } >> $T/$i.sh
done

# Sort by number of processes to minimize parallelism skew
sed -e 's/\.litmus//' |
awk -F+ '{ print NF, $0 }' |
sort -k1n |
sed -e 's/^[0-9]* //' |
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
