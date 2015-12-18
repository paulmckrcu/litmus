# Generate necklaces.
#
# Usage:
#	awk -f necklace.awk ...
#
# This is the part where I should credit the source of the algorithm.
# And I did do the usual web search, but found only implementations
# in strange languages on the one hand and papers with incomprehensible
# pseudo-code documented only by formal proofs on the other.  It was late,
# and I was tired, so rather than hammer throught the proofs, I shut down
# my browser in disgust and went to bed.
#
# I woke up the next morning with a clear understanding of a reasonably
# efficient algorithm and of how to implement it.  I am sure that my
# bleary-eyed scanning of the pseudo-code and proofs had a lot to do
# with my morning enlightenment, but I have no idea what papers I looked
# at.  So I will simply acknowledge an enduring debt to Internet.  ;-)
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

########################################################################
#
# Data structures:
#
# necklacebag[necklace]: Array of necklaces generated thus far

########################################################################
#
# Convert necklace to string
#
function necklace2str(curnecklace, nbeads, colors,  strnecklace, i) {
	strnecklace="";
	for (i = 0; i < nbeads; i++)
		strnecklace = strnecklace " " colors[curnecklace[i] + 1];
	return strnecklace;
}

########################################################################
#
# Check all rotations of the necklace, return 1 if new.
#
function checknecklace(curnecklace, nbeads, colors,  rotnecklace, i, j, ns) {
	for (i = 0; i < nbeads; i++) {
		for (j = 0; j < i; j++) {
			rotnecklace[j + nbeads - i] = curnecklace[j];
		}
		for (j = i; j < nbeads; j++) {
			rotnecklace[j - i] = curnecklace[j];
		}
		ns = necklace2str(rotnecklace, nbeads, colors);
		if (necklacebag[ns])
			return 0;
	}
	ns = necklace2str(curnecklace, nbeads, colors);
	necklacebag[ns] = 1;
	return 1;
}

########################################################################
#
# Recursive necklace construction, to be invoked from necklace().
#
function __ncklc(curnecklace, nbeads, ncolors, maxbeads, colors,  newnecklace, i, j, k, ns) {
	if (nbeads >= maxbeads)
		return;
	for (i = nbeads; i >= (nbeads == 0 ? 0 : 1); i--) {
		for (j = 0; j < i; j++)
			newnecklace[j] = curnecklace[j];
		for (j = i + 1; j < maxbeads; j++)
			newnecklace[j] = curnecklace[j - 1];
		for (k = 0; k < ncolors; k++) {
			if (i + 1 < nbeads && curnecklace[i + 1] == k)
				continue;
			newnecklace[i] = k;
			if (checknecklace(newnecklace, nbeads + 1, colors))
				__ncklc(newnecklace, nbeads + 1, ncolors, maxbeads, colors);
		}
	}
}

########################################################################
#
# Recursive necklace construction.  Fills necklacebag with corresponding
# string representations of the necklaces.  The colors string is a
# blank-separated list of the names of the desired colors.
#
function necklace(colorstr, maxbeads, necklacebag,  curnecklace, i, ncolors, colors) {
	ncolors = split(colorstr, colors, " "); 
	for (i in necklacebag)
		if (necklacebag[i])
			delete necklacebag[i];
	curnecklace["0"] = "";
	__ncklc(curnecklace, 0, ncolors, maxbeads, colors);
}

########################################################################
#
# Recursive integer necklace construction.  Fills necklacebag with
# corresponding string representations of the necklaces.
#
function necklace_int(ncolors, maxbeads, necklacebag,  curnecklace, i, colors) {
	for (i = 1; i <= ncolors; i++)
		colors[i] = (i - 1) "";
	for (i in necklacebag)
		if (necklacebag[i])
			delete necklacebag[i];
	curnecklace["0"] = "";
	__ncklc(curnecklace, 0, ncolors, maxbeads, colors);
}

########################################################################
#
# Necklace print.
#
function necklace_print(necklacebag,  i) {
	for (i in necklacebag)
		if (necklacebag[i])
			print i;
}
