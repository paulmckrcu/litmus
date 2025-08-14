#!/bin/sh
# SPDX-License-Identifier: GPL-2.0+
#
# Given a pair of .litmus and or .litmus.out files, check the the
# "Result:" comment and/or the "Observation" lineto judge whether the
# corresponding litmus tests are compatible.  The result from the second
# file may be stronger than that of the first file, for example, a Sometimes
# comment is satisfied by a Never run.  This is appropriate for the case
# where a C-language litmus test has been translated to assembly language
# and then run.
#
# The script does not deal with DEADLOCK or DATARACE Result: commments
# because assembly language does not have either locks or data races.
# For that sort of thing, look at tools/memory-model/scripts/judgelitmus.sh
# in a recent Linux-kernel source tree.
#
# The caller is expected to keep track of the pathnames, so error messages
# in this script omit them.
#
# Usage:
#	judgelitmus.sh file1.litmus file2.litmus.out
#
# Again, either file can be a .litmus or a .litmus.out file.
#
# Exit codes:
#
# 0:	Compatible results.
# 1:	The C-language .litmus file does not have a "Result:" comment.
# 2:	The herd7 output file does not have an Observation line, and
#	thus does not specify a result.
# 3:	Incompatible results.
# 255:	At least one of the files is unreadable.
#
# Copyright Meta Platforms, Inc, 2024
#
# Author: Paul E. McKenney <paulmck@kernel.org>

litmus1=$1
litmus2=$2

if test -f "$litmus1" -a -r "$litmus1"
then
	:
else
	echo ' --- ' error: \"$litmus1\" is not a readable file
	exit 255
fi
if test -f "$litmus2" -a -r "$litmus2"
then
	:
else
	echo ' --- ' error: \"$litmus2\" is not a readable file
	exit 255
fi

# get_result(path)
# Extracts the "Result:" comment expection (for .litmus files) or the
# "Observation" line (for .litmus.out files).
get_result()
{
	if echo $1 | grep -q '\.litmus$'
	then
		grep '^[( ]\* Result: ' $1 | head -1 | awk '{ print $3; }'
	elif echo $1 | grep -q '\litmus\.out$'
	then
		grep '^Observation' $1 | awk '{ fn = NF - 2; print $fn; }'
	fi
}

# Extract expectations and test results.
litmus1result="`get_result "$litmus1"`"
litmus2result="`get_result "$litmus2"`"

# Did we get both expectations and results?
if test -z "$litmus1result"
then
	echo "No Result: clause in .litmus file."
	exit 1
fi
if test -z "$litmus2result"
then
	echo "No Result: clause in .out file."
	exit 2
fi

# Got results from both files, check them.
if test "$litmus1result" = "$litmus2result"
then
	exit 0
fi
litmustype=LKMM
if echo $litmus2 | grep -qe '-BPF\.litmus'
then
	litmustype=BPF
elif echo $litmus2 | grep -qe '-PPC\.litmus'
then
	litmustype=PPC
fi
if test "$litmus1result" = Sometimes && test "$litmus2result" = Never
then
	echo Tighter $litmustype result "(OK)".
	exit 0
fi
echo Result mismatch "$litmus1result" vs. "$litmus2result".
exit 3
