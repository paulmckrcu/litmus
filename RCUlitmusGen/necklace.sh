#! /bin/sh
#
# Test generation of necklaces.
#
# Usage:
#	sh necklace.sh ncolors maxbeads
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

ncolors=${1-2}
maxbeads=${2-4}

gawk -v ncolors=$ncolors -v maxbeads=$maxbeads '

########################################################################
#
# Data structures:
#
# necklacebag[necklace]: Array of necklaces generated thus far

########################################################################
#
# Convert necklace to string
#
function necklace2str(curnecklace, nbeads,  strnecklace, i) {
	strnecklace="";
	for (i = 0; i < nbeads; i++)
		strnecklace = sprintf("%s %d", strnecklace, curnecklace[i]);
	return strnecklace;
}

########################################################################
#
# Check all rotations of the necklace, return 1 if new.
#
function checknecklace(curnecklace, nbeads,  rotnecklace, i, j, ns) {
	for (i = 0; i < nbeads; i++) {
		for (j = 0; j < i; j++) {
			rotnecklace[j + nbeads - i] = curnecklace[j];
		}
		for (j = i; j < nbeads; j++) {
			rotnecklace[j - i] = curnecklace[j];
		}
		ns = necklace2str(rotnecklace, nbeads);
		print "Checking necklace rotation " ns;
		if (necklacebag[ns])
			return 0;
		print "Necklace rotation " ns " not found";
	}
	ns = necklace2str(curnecklace, nbeads);
	print "Adding necklace: " ns;
	necklacebag[ns] = 1;
	return 1;
}

########################################################################
#
# Recursive necklace construction
#
function necklace(curnecklace, nbeads, ncolors, maxbeads,  newnecklace, i, j, k, ns) {
	print "Entering necklace with " necklace2str(curnecklace, nbeads) " nbeads=" nbeads " ncolors=" ncolors " maxbeads=" maxbeads;
	if (nbeads >= maxbeads)
		return;
	print "Trying necklaces..."
	for (i = nbeads; i >= (nbeads == 0 ? 0 : 1); i--) {
		for (j = 0; j < i; j++)
			newnecklace[j] = curnecklace[j];
		for (j = i + 1; j < maxbeads; j++)
			newnecklace[j] = curnecklace[j - 1];
		for (k = 0; k < ncolors; k++) {
			print "color=" k " i=" i " nbeads=" nbeads;
			if (i + 1 < nbeads && curnecklace[i + 1] == k)
				continue;
			newnecklace[i] = k;
			if (checknecklace(newnecklace, nbeads + 1))
				necklace(newnecklace, nbeads + 1, ncolors, maxbeads);
		}
	}
}

BEGIN {
	print "ncolors = " ncolors " maxbeads = " maxbeads;
	curnecklace["0"] = "";
	necklace(curnecklace, 0, ncolors, maxbeads);
	for (i in necklacebag)
		if (necklacebag[i])
			print i;
}'
