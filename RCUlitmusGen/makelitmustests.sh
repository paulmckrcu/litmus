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

# RCU-related tests
{
	# Load-buffering RCU tests, and with added ordering.
	sh gendir.sh "RW-G RW-R" 8
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R/RW-RB/p'
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R RW-R/RW-Rr RW-Ra/p'
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R RW-R/RW-Rr RW-RC/p'
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R RW-R/RW-Rs RW-RD/p'
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R RW-R/RW-Rs RW-RCD/p'
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R RW-R/RW-Rrd RW-Rl/p'
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R RW-R/RW-Rrd RW-RCl/p'
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R RW-R/RW-Rrd RW-l/p'
	sh gendir.sh "RW-G RW-R" 8 |
		sed -n -e 's/RW-R RW-R/RW-Rrd RW-Cl/p'
	echo "RW-G RW-R RW-G RW-R RW-G RW-R"
	echo "RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R"
	echo "RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R"
	echo "RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R"
	echo "RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R"
	echo "RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R"
	echo "RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R RW-G RW-R"

	# Load-buffering RCU tests with partial or multiple critical sections
	sh gendir.sh "RW-G RW-R1" 4 | grep -e -R
	sh gendir.sh "RW-G RW-R2" 4 | grep -e -R
	sh gendir.sh "RW-G RW-R3" 4 | grep -e -R
	sh gendir.sh "RW-G RW-R1I" 4 | grep -e -R
	sh gendir.sh "RW-G RW-R2I" 4 | grep -e -R
	sh gendir.sh "RW-G RW-R3I" 4 | grep -e -R

	# A few larger load-buffering RCU tests.
	sh gendir.sh "RW-G+RW-G+RW-R+RW-R+RW-R+RW-R+RW-G+RW-G RW-G RW-R" 5 |
		tr '+' ' ' |
		awk '{ if (NF < 20) print }'
	sh gendir.sh "RW-R+RW-R+RW-G+RW-G+RW-G+RW-G+RW-R+RW-R RW-G RW-R" 5 |
		tr '+' ' ' |
		awk '{ if (NF < 20) print }'

	# Load-buffering tests involving RCU grace periods and full barriers.
	sh gendir.sh "RW-G RW-B" 8
	sh gendir.sh "RW-G RW-B" 8 |
		sed -n -e 's/RW-B RW-B/RW-r RW-a/p'
	sh gendir.sh "RW-G RW-B" 8 |
		sed -n -e 's/RW-B RW-B/RW-r RW-C/p'
	sh gendir.sh "RW-G RW-B" 8 |
		sed -n -e 's/RW-B RW-B/RW-rd RW-l/p'

	# Non-load-buffering RCU tests.
	sh gendir.sh "RW-G RW-RI" 8
	sh gendir.sh "RR-G RR-R" 8
	sh gendir.sh "WR-G WR-R" 8
	sh gendir.sh "WW-G WW-R" 8
	sh gendir.sh "WW-G WW-R" 8 |
		sed -n -e 's/WW-R/WW-B/p'

	# Combinations of grace periods and critical sections on one thread
	for i in RR RW WR WW
	do
		echo $i-GR $i-R
		echo $i-GR1 $i-R
		echo $i-GR2 $i-R
		echo $i-GR3 $i-R
		echo $i-GR $i-R $i-R
		echo $i-GR1 $i-R $i-R
		echo $i-GR2 $i-R $i-R
		echo $i-GR3 $i-R $i-R
		echo $i-H $i-R
		echo $i-H $i-R $i-R
		echo $i-H $i-R $i-R $i-R
		echo $i-H $i-R $i-R $i-G $i-R
		echo $i-H $i-R $i-R $i-G $i-R $i-R
		echo $i-GH $i-R
		echo $i-GH $i-R $i-R
		echo $i-GH $i-R $i-R $i-R
		echo $i-GH $i-R $i-R $i-R $i-R
		echo $i-GH $i-R $i-R $i-R $i-G $i-R
		echo $i-GH $i-R $i-R $i-R $i-G $i-R $i-R
	done
} | sort -u | sh dir2litmus.sh auto/

# LB tests
{
	# Properly paired tests
	sh gendir.sh "R-Dd R-A R-Oc OB-O" 4 |
		sed -e 's/OB-O$/OB-OB/'
} | {
awk '{
    	if (NF > 1) {
		print "LRR " $0;
		print "LRW " $0;
		print "LWR " $0;
		print "LWW " $0;
		if ($0 ~ / OB-O OB-O /) {
			# Produce a few once-once examples
			dir = $0;
			sub(/ OB-O /, " O-O ", dir);
			print "LRW " dir;
		}
		if ($0 ~ / R-Dd R-Dd /) {
			# Produce a few with dependency, but no deref
			dir = $0;
			sub(/ R-Dd /, " R-Od ", dir);
			print "LRW " dir;
		}
		if ($0 ~ / R-Dd$/) {
			# Produce a few at end with deref, but no dependency
			dir = $0;
			sub(/ R-Dd$/, " R-D", dir);
			print "LRW " dir;
		}
		if ($0 ~ / R-Dd$/) {
			# Produce a few at end with dependency, but no deref 
			dir = $0;
			sub(/ R-Dd$/, " R-Od", dir);
			print "LRR " dir;
			# Produce a few at end with both control and dependency
			dir = $0;
			sub(/ R-Dd$/, " R-Dcd", dir);
			print "LRW " dir;
		}
		if ($0 ~ / R-Dd R-Dd /) {
			# Produce a few with value dependency, but no deref
			dir = $0;
			sub(/ R-Dd /, " R-Ov R-OC ", dir);
			print "LRW " dir;
		}
		if ($0 ~ / R-Dd$/) {
			# Produce a few at end with value dep, but no deref 
			dir = $0;
			sub(/ R-Dd$/, " R-Ov", dir);
			print "LRW " dir;
			# Produce a few at end with both control and value
			dir = $0;
			sub(/ R-Dd$/, " R-Dcv", dir);
			print "LRW " dir;
		}
		if ($0 ~ / R-Oc /) {
			# Produce a few with combined control/rmb
			dir = $0;
			sub(/ R-Oc /, " R-OC ", dir);
			print "LRW " dir;
		}
		if ($0 ~ / R-Oc$/) {
			# Ditto, but with trailing read
			dir = $0;
			sub(/ R-Oc$/, " R-OC", dir);
			print "LRR " dir;
		}
		if ($0 ~ / R-Oc$/) {
			# Produce a few with fake control dependency at end
			dir = $0;
			sub(/ R-Oc$/, " R-Ok", dir);
			print "LRW " dir;
		}
		if ($0 ~ / R-A$/) {
			# Produce a few with C11 release sequence at end
			dir = $0;
			sub(/ R-A$/, " RQ-A", dir);
			print "LRW " dir;
		}
		if ($0 ~ / R-A R-A$/) {
			# Produce a few with C11 release sequence near end
			dir = $0;
			sub(/ R-A R-A$/, " RQ-A R-A", dir);
			print "LRW " dir;
		}
		if ($0 ~ / R-A R-A$/) {
			# Produce a few with non-control-dependency-protected
			# C11 release sequence near end
			dir = $0;
			sub(/ R-A R-A$/, " R-Oc Oq-A", dir);
			print "LRW " dir;
		}
	}
    	print "GRR " $0;
    	print "GRW " $0;
    	print "GWR " $0;
    	print "GWW " $0;
    }'
for i in GRR GRW GWR GWW LRR LRW LWR LWW
do
	echo $i R-A O-Dd
	echo $i R-A R-Dd
	echo $i R-A OB-Dd
done
echo LRW OB-Dv
} | sort -u |
    awk -f RCULBlitmusgen.awk -e '{ gen_lb_litmus("auto/", $0); }'
