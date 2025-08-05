#!/bin/sh
#
# Usage: findbpfreadytests.sh [ litmus-tree ]
#
# Searches the directory specified by litmus-tree (or the current
# directory if none specfiied) for C-language litmus tests suitable for
# conversion to BPF assembly language, and outputs their pathnames one
# per line on stdout.  Run in the directory containing this script.

T="`mktemp -d ${TMPDIR-/tmp}/findbpfreadytests.sh.XXXXXX`"
trap 'rm -rf $T' 0

litmus_tree=${1-.}

# Find all C-language litmus tests.
find ${litmus_tree} -name '*.litmus' -print | grep -ve '-BPF\.litmus$' | mselect7 -arch C > $T/list-C

# Discard tests using RCU, locking, or specialty barriers.
xargs < $T/list-C -r grep -L 'rcu_read_lock();\|rcu_read_unlock();\|rcu_dereference(.*);\|rcu_assign_pointer(.*);\|synchronize_rcu();\|synchronize_rcu_expedited();\|srcu_read_lock([^)]*);\|srcu_read_unlock([^)]*);\|srcu_down_read([^)]*);\|srcu_up_read([^)]*);\|synchronize_srcu([^)]*);\|synchronize_srcu_expedited([^)]*);\|smp_rmb();\|smp_wmb();\|smp_mb__after_spinlock();\|smp_mb__after_unlock_lock();\|smp_mb__after_srcu_read_unlock();\|spin_lock([^)]*);\|spin_unlock([^)]*);\|spin_trylock([^)]*);spin_is_locked([^)]*);\|smp_memb();' > $T/list-C-bpf1

# Discard tests using things to be implemented later on.
xargs < $T/list-C-bpf1 -r grep -L '^[ 	]*if *(.*{\|\^[	 ]*}* else\>\|smp_store_mb(.*);' > $T/list-C-bpf2

# Take only tests with a "Result:" specified that is consistent with BPF
# assembly language: No data races and no deadlocks.
xargs < $T/list-C-bpf2 -r grep -E -l '^[( ]\* Result: (Never|Sometimes|Always)\>' > $T/list-C-bpf3

cat $T/list-C-bpf3
