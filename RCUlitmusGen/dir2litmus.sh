#! /bin/sh
#
# Given a list of directives on standard input, generate litmus files
# with the specified pathname prefix.
#
# Usage:
#	sh dir2litmus.sh [ prefix ]
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
#
# Authors: Paul E. McKenney <paulmck@linux.vnet.ibm.com>

prefix="${1-litmus/}"

gawk -v prefix=$prefix -f RCUlitmusgen.awk -e '
{
	gen_litmus(prefix, $0);
}'
