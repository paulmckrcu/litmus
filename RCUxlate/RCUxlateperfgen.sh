#! /bin/sh
#
# Convert a few LISA LB RCU litmus tests to auxiliary-variable form,
# using both the "ghost" and non-"ghost" write-release and read-acquire
# instructions.
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
# Copyright (C) IBM Corporation, 2015
# Copyright (C) Alan Stern, 2016
#
# Authors: Paul E. McKenney <paulmck@linux.vnet.ibm.com>
#          Alan Stern <stern@rowland.harvard.edu>

for i in RW-G+RW-R \
	 RW-G+RW-R+RW-G+RW-R \
	 RW-G+RW-R+RW-G+RW-R+RW-G+RW-R \
	 RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R \
	 RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R \
	 RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R \
	 RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R \
	 RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R \
	 RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R+RW-G+RW-R
do
	sh RCUrelacq.sh < ../auto/$i.litmus > ../auto/$i-relacq.litmus
	sh RCUghostrelacq.sh < ../auto/$i.litmus > ../auto/$i-ghost.litmus
done
