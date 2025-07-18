#!/bin/sh
# SPDX-License-Identifier: GPL-2.0+
#
# Given the pathname of an LKMM .litmus file lacking a "Results:" comment,
# run the test and, if the results are unambiguous, add the indicated
# "Results:" comment.  Litmus tests that flag data races or contain other
# errors are left untouched.  The updated litmus test replaces the original,
# so you had best be using source-code control on your litmus tests!
#
# Usage:
#	resultify1.sh file.litmus
#
# Run this in a Linux kernel's tools/memory-model directory.

T="`mktemp -d ${TMPDIR-/tmp}/resultify1.sh.XXXXXX`"
trap 'rm -rf $T' 0 2

if grep -E -q '^.\* Result: (Never|Sometimes|Always)$' < "${1}"
then
	exit 0 # There already is a "Result:" comment.
fi

scripts/runlitmus.sh "${1}"
ret=$?
if test "${ret}" -ne 0
then
	exit ${ret}
fi

litmusbase="`basename "${1}"`"
if ! grep -E '^Observation .* (Never|Sometimes|Always) [0-9]+ [0-9]+' < "${1}".out > $T/"${litmusbase}.result"
then
	exit 1 # There is not an unambiguous "Result:" comment. 
fi
result="`awk '{ print $(NF - 2); }' < $T/"${litmusbase}.result"`"
awk < "${1}" > $T/"${litmusbase}" -v result="${result}" '
BEGIN {
	printedresult = 0;
}

/^\(\*$/ && !printedresult {
	print "(* Result: " result;
	printedresult = 1;
	next;
}

/^\(\*/ && !printedresult {
	print "(* Result: " result;
	line = $0;
	sub(/^\(/, " ", line);
	print line;
	printedresult = 1;
	next;
}

/^{/ && !printedresult {
	print "(* Result: " result " *)";
	print $0;
	printedresult = 1;
	next;
}

{
	print $0;
}'

# The copy to $T and back prevents overwriting the file before it can
# be read.  ;-)

cp "$T/${litmusbase}" "${1}"
