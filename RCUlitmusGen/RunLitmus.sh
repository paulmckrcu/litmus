#!/bin/sh
#
# Run a herd test specifying an expected outcome (Sometimes, Always, Never).
#
# Usage:
#	sh RunLitmus.sh file.litmus outcome
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

litmus=$1
outcome=${2-specified}
herdoptions=${LINUX_HERD_OPTIONS-}

if test -f $litmus -a -r $litmus
then
	:
else
	echo ' --- ' error: $litmus is not a readable file
	exit 255
fi

echo Herd options: $herdoptions > $litmus.out
/usr/bin/time herd7 -o ~/tmp $herdoptions $litmus >> $litmus.out 2>&1
grep "Herd options:" $litmus.out
grep '^Observation' $litmus.out
if grep -q '^Observation' $litmus.out
then
	:
else
	cat $litmus.out
	echo ' ^^^ Verification error'
	exit 255
fi
if test "$outcome" = DEADLOCK
then
	echo grep 3 and 4
	if grep '^Observation' $litmus.out | grep -q 'Never 0 0$'
	then
		ret=0
	else
		echo " ^^^ Unexpected non-$outcome verification"
		ret=1
	fi
elif grep '^Observation' $litmus.out | grep -q $outcome || test "$outcome" = Maybe
then
	ret=0
else
	echo " ^^^ Unexpected non-$outcome verification"
	ret=1
fi
tail -2 $litmus.out | head -1
exit $ret
