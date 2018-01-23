#! /bin/sh
#
# Convert LISA litmus test to C-language version and verify that they
# produce the same results.  The C-language version is discarded.
#
# Usage: sh lisa2c-check.sh herd-args lisa.litmus
#
# Note that a C-language litmus test might not be semantically equivalent
# to its LISA-language counterpart.  For example, LISA and C have slightly
# different semantics for control dependencies.  The verification ignores
# such details.
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

T=/tmp/lisa2c-check.sh.$$
mkdir $T
trap 'rm -rf $T' 0

cname=`echo $2 | sed -e 's,^.*/,,'`
sh lisa2c.sh < $2 > $T/$cname
herd7 $1 $2 > $T/lisa.out
herd7 $1 $T/$cname > $T/c.out
lisa_result=`grep '^Observation' $T/lisa.out | awk '{ print $3, $4, $5 }'`
c_result=`grep '^Observation' $T/c.out | awk '{ print $3, $4, $5 }'`
if test "$lisa_result" = "$c_result"
then
	echo OK: LISA: $lisa_result C: $c_result
	exit 0
fi
echo MISMATCH: LISA: $lisa_result C: $c_result
