#!/bin/sh
# SPDX-License-Identifier: GPL-2.0+
#
# Given a path to a tree of LKMM litmus-test files and a destination
# directory, extract the pathnames of the BPF-convertible litmus tests and
# pass it to runlitmus.sh to convert, run, and check the results against
# the original .litmus file's Results: comment.
#
# Usage:
#	runlitmustree.sh /path/to/litmus/tests destdir
#
# See the runlitmus.sh comment header for the structure of the tree
# placed in destdir, but please be advised that anything previously
# in destdir will be removed.
#
# Run this in the directory containing this script.
#
# Copyright Meta Platforms, Inc, 2024
#
# Author: Paul E. McKenney <paulmck@kernel.org>

testdir="$1"
destdir="$2"
if ! test -d "$testdir" || ! test -r "$testdir" || ! test -x "$testdir"
then
	echo ${0}: Cannot find litmus tests in $testdir.
	exit 1
fi
# Let runlitmus.sh do the checking of destdir.

sh findbpfreadytests.sh "$testdir" | sh runlitmus.sh "$destdir"
