#! /bin/sh
#
# Given a list of litmus tests with model determinations on standard
# input, list the tests, determinations, and prediction reason on
# standard output.
#
# Usage:
#	sh getreason.sh
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
# Copyright (C) IBM Corporation, 2016
#
# Authors: Paul E. McKenney <paulmck@linux.vnet.ibm.com>

gawk '
{
	print "echo " $0;
	print "grep -e \"->Maybe\" " $1 ".litmus";
	print "if ! grep -q -e \"->Maybe\" " $1 ".litmus";
	print "then";
	print "\tgrep Result: " $1 ".litmus";
	print "\tresult=`grep Result: " $1 ".litmus | awk '\''{ print $3 }'\''`";
	print "\tif test " $2 " = Allow -a \"$result\" = Never";
	print "\tthen";
	print "\t\techo -- Conflict: \"Never\" prediction vs. model \"Allow\"!!!"
	print "\tfi";
	print "fi";
}' | sh
