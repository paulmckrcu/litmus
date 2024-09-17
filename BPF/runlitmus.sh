#!/bin/sh
# SPDX-License-Identifier: GPL-2.0+
#
# Given a path-per-line list of LKMM litmus-test files on standard input,
# run c2bpf.sh to convert them to BPF litmus tests.
#
# Usage:
#	runlitmus.sh destdir < list-of-LKMM-litmus-tests
#
# The path name for each successfully converted litmus test is placed in
# the file named "0" (as in the numeral zero) in the specified directory.
# For each litmus test that was not successfully converted, its name
# followed by any stderr emited during conversion is placed on a line in
# a file whose name is the exit code (as in "1", "2", and so on).
#
# The -BPF.litmus file will be deposited in the same directory occupied
# by the source .litmus file.
#
# Run this in the directory containing this script.
#
# Copyright Meta Platforms, Inc, 2024
#
# Author: Paul E. McKenney <paulmck@kernel.org>

destdir="$1"
if ! test -d "$destdir" || ! test -w "$destdir" || ! test -x "$destdir"
then
	if test -e "$destdir"
	then
		echo ${0}: $destdir is not a usable directory.
		exit 1
	elif ! mkdir -p "$destdir"
	then
		echo ${0}: $destdir does not exist and cannot be created.
		exit 1
	fi
fi
rm -rf "$destdir"/*

T="`mktemp -d ${TMPDIR-/tmp}/runlitmus.sh.XXXXXX`"
trap 'rm -rf $T' 0

# convert_a_test(path)
convert_a_test()
{
	sh ./c2bpf.sh "$1" > $T/stdout 2> $T/stderr
	run_a_test_ret=$?
	if test $run_a_test_ret -eq 0
	then
		echo $1 >> "$destdir/0"
	else
		echo ${1}: `cat $T/stderr` >> "$destdir/$run_a_test_ret"
	fi
}

# Convert the tests.
sed -e 's/^/convert_a_test /' > $T/script
. $T/script

# run_a_test(path-BPF.litmus)
run_a_test()
{
	herd7 "$1" > "$1".out
	run_a_test_ret=$?
	if test $run_a_test_ret -eq 0
	then
		echo $1 >> "$destdir/herd7/0"
	else
		echo ${1}: `cat $T/stderr` >> "$destdir/herd7/$run_a_test_ret"
	fi
}

# Run the tests that were successfully converted.
mkdir "$destdir"/herd7 || :
sed < "$destdir/0" -e 's/^/run_a_test /' -e 's/\.litmus/\-BPF\.litmus/' > $T/runscript
. $T/runscript
wc -l "$destdir"/herd7/*

# judge_a_test(path-BPF.litmus)
judge_a_test()
{
	pathbpflitmus="$1"
	pathlitmus="`echo $pathbpflitmus | sed -e 's/-BPF//'`"
	sh judgelitmus.sh "$pathlitmus" "${pathbpflitmus}.out" > $T/judgelitmus.out
	judge_a_test_ret=$?
	echo $pathbpflitmus `cat $T/judgelitmus.out` >> "$destdir/judgelitmus/$judge_a_test_ret"
}

mkdir "$destdir"/judgelitmus || :
sed < "$destdir/herd7/0" -e 's/^/judge_a_test /' > $T/judgescript
. $T/judgescript
