#!/bin/sh

for n in 1 2 3 4 5 6 7 8 9 10
do
	for i in litmus-tests/absperf/*.litmus
	do
		echo $i
		time timeout 15m herd7 -conf linux-kernel.cfg $i
	done
done
