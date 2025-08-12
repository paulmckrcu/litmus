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
	sh ./c2${cvscript}.sh "$1" > $T/stdout 2> $T/stderr
	ret=$?
	if test $ret -eq 0
	then
		echo $1 >> "$2/$3/0"
	else
		echo ${1}: `cat $T/stderr` >> "$2/$3/$ret"
	fi
}

# Copy the input and convert the tests.
cat > $T/inputlist
mkdir -p "$destdir"/BPF || :
sed -e 's/^/convert_a_test /' -e 's?$? '$destdir' BPF?' < $T/inputlist > $T/script-BPF
. $T/script-BPF
mkdir -p "$destdir"/PPC || :
sed -e 's/^/convert_a_test /' -e 's?$? '$destdir' PPC?' < $T/inputlist > $T/script-PPC
. $T/script-PPC

# run_a_test(path-XXX.litmus, destdir, suffix)
# The path is to the (assembly language) litmus test, the destdir is
# the place to put the output file sans suffix, and the suffix is "BPF"
# or "PPC".
run_a_test()
{
	local run_a_test_ret

	herd7 "$1" > "$1".out
	run_a_test_ret=$?
	if test $run_a_test_ret -eq 0
	then
		echo $1 >> "$2/$3/herd7/0"
	else
		echo ${1}: `cat $T/stderr` >> "$2/$3/herd7/$run_a_test_ret"
	fi
}

# Run the tests that were successfully converted.
mkdir -p "$destdir"/BPF/herd7 || :
sed < "$destdir/BPF/0" -e 's/^/run_a_test /' -e 's?\.litmus?\-BPF\.litmus '$destdir' BPF?' > $T/runscript-BPF
. $T/runscript-BPF
wc -l "$destdir"/BPF/herd7/*
sed -e 's/-BPF\.litmus$/.litmus/' < "$destdir"/BPF/herd7/0 | sort > "$destdir"/BPF/herd7/0-sorted
mkdir -p "$destdir"/PPC/herd7 || :
sed < "$destdir/PPC/0" -e 's/^/run_a_test /' -e 's?\.litmus?\-PPC\.litmus '$destdir' PPC?' > $T/runscript-PPC
. $T/runscript-PPC
wc -l "$destdir"/PPC/herd7/*
sed -e 's/-PPC\.litmus$/.litmus/' < "$destdir"/PPC/herd7/0 | sort > "$destdir"/PPC/herd7/0-sorted

# judge_a_test(path-BPF.litmus)
judge_a_test()
{
	local pathbpflitmus="$1"
	local pathlitmus="`echo $pathbpflitmus | sed -e 's/-BPF//'`"

	sh judgelitmus.sh "$pathlitmus" "${pathbpflitmus}.out" > $T/judgelitmus.out
	judge_a_test_ret=$?
	echo $pathbpflitmus `cat $T/judgelitmus.out` >> "$destdir/judgelitmus/$judge_a_test_ret"
}

# Judge -BPF litmus test results against the corresponding LKMM "Results:"
# comment.
mkdir "$destdir"/judgelitmus || :
sed < "$destdir/BPF/herd7/0" -e 's/^/judge_a_test /' > $T/judgescript
. $T/judgescript

# judge_an_asm_test(path.litmus, suffix1, suffix2)
judge_an_asm_test()
{
	local path1
	local path2
	local ret
	local suffix1="$2"
	local suffix2="$3"
	local TJ=$T/judgelitmus."$suffix1"-"$suffix2".out

	local path1="`echo $1 | sed -e 's?\.litmus$?\-'$suffix1'.litmus.out?'`"
	local path2="`echo $1 | sed -e 's?\.litmus$?\-'$suffix2'.litmus.out?'`"
	sh judgelitmus.sh "$path1" "$path2" > $TJ
	ret=$?
	echo $1 `cat $TJ` >> "$destdir/judgelitmus/${suffix1}-${suffix2}/$judge_a_test_ret"
}

# Judge -BPF litmus test results against the corresponding PPC litmus
# test results.
mkdir -p "$destdir"/judgelitmus/BPF-PPC
join "$destdir"/BPF/herd7/0-sorted "$destdir"/PPC/herd7/0-sorted > $T/BPF-PPC
sed -e 's/^/judge_an_asm_test /' -e 's/$/ BPF PPC/' < $T/BPF-PPC > $T/judgescript-BPF-PPC.sh
. $T/judgescript-BPF-PPC.sh
wc -l "$destdir"/judgelitmus/BPF-PPC/*
