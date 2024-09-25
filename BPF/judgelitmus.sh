#!/bin/sh
# SPDX-License-Identifier: GPL-2.0+
#
# Given a .litmus test and the corresponding litmus output file, check
# the specified output file against the "Result:" comment to judge whether
# the test ran correctly.  The result from the output file may be stronger
# than that of the "Result:" comment, that is to say, a Sometimes comment
# is satisfied by a Never run.  This is appropriate for the case where
# a C-language litmus test has been translated to assembly language and
# then run.
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
# Exit codes:
#
# 0:	Compatible results.
# 1:	The C-language .litmus file does not have a "Result:" comment.
# 2:	The BPF-language herd7 output file does not have an Observation
#	line, and thus does not specify a result.
#
# Copyright Meta Platforms, Inc, 2024
#
# Author: Paul E. McKenney <paulmck@kernel.org>

litmus=$1
litmusout=$2

if test -f "$litmus" -a -r "$litmus"
then
	:
else
	echo ' --- ' error: \"$litmus\" is not a readable file
	exit 255
fi
if test -f "$litmusout" -a -r "$litmusout"
then
	:
else
	echo ' --- ' error: \"$litmusout\" is not a readable file
	exit 255
fi

# Extract expectations and test results.
litmusresult="`grep '^[( ]\* Result: ' $litmus | awk '{ print $NF; }'`"
testresult="`grep '^Observation' $litmusout | awk '{ fn = NF - 2; print $fn; }'`"

# Did we get both expectations and results?
if test -z "$litmusresult"
then
	echo "No Result: clause in .litmus file.
	exit 1
fi
if test -z "$testresult"
then
	echo "No Result: clause in .out file.
	exit 2
fi

# Got results from both files, check them.
if test "$litmusresult" = "$testresult"
then
	exit 0
fi
if test "$litmusresult" = Sometimes && test "$testresult" = Never
then
	echo Tighter BPF result "(OK)".
	exit 0
fi
echo BPF result mismatch "$litmusresult" vs. "$testresult".
exit 3
