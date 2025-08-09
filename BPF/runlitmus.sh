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

# convert_a_test(path, destdir, suffix)
# The path is to the litmus test, the destdir is the place to put the
# output file sans suffix, and the suffix is "BPF" or "PPC".
convert_a_test()
{
	local ret
	local cvscript

	cvscript="`echo $3 | tr '[A-Z]' '[a-z]'`"
	echo sh ./c2${cvscript}.sh "$1" ">" $T/stdout "2>" $T/stderr
	sh ./c2${cvscript}.sh "$1" > $T/stdout 2> $T/stderr
	ret=$?
	if test $ret -eq 0
	then
		echo $1 >> "$2/$3/0"
	else
		echo ${1}: `cat $T/stderr` >> "$2/$3/$ret"
	fi
}

# Convert the tests.
mkdir -p "$destdir"/BPF || :
sed -e 's/^/convert_a_test /' -e 's?$? '$destdir' BPF?' > $T/script-BPF
. $T/script-BPF

# run_a_test(path-BPF.litmus)
run_a_test()
{
	herd7 "$1" > "$1".out
	run_a_test_ret=$?
	if test $run_a_test_ret -eq 0
	then
		echo $1 >> "$destdir/BPF/herd7/0"
	else
		echo ${1}: `cat $T/stderr` >> "$destdir/BPF/herd7/$run_a_test_ret"
	fi
}

# Run the tests that were successfully converted.
mkdir -p "$destdir"/BPF/herd7 || :
sed < "$destdir/BPF/0" -e 's/^/run_a_test /' -e 's/\.litmus/\-BPF\.litmus/' > $T/runscript
. $T/runscript
wc -l "$destdir"/BPF/herd7/*

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
sed < "$destdir/BPF/herd7/0" -e 's/^/judge_a_test /' > $T/judgescript
. $T/judgescript
