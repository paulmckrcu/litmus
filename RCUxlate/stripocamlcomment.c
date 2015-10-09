/*
 * stripocamlcomment.c: Remove ocaml (* *) comments from stdin to stdout
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, you can access it online at
 * http://www.gnu.org/licenses/gpl-2.0.html.
 *
 * Copyright (c) 2015 Paul E. McKenney, IBM Corporation.
 */

#include <stdio.h>

#define NO_COMMENT	0
#define START_COMMENT	1
#define IN_COMMENT	2
#define END_COMMENT	3

int main(int argc, char *argv[])
{
	int state;
	int c;

	while ((c = getchar()) != EOF) {
		switch (state) {
		case NO_COMMENT:

			if (c == '(')
				state = START_COMMENT;
			else
				putchar(c);
			break;

		case START_COMMENT:

			if (c == '*') {
				state = IN_COMMENT;
			} else {
				putchar('(');
				putchar(c);
				state = NO_COMMENT;
			}
			break;

		case IN_COMMENT:

			if (c == '*')
				state = END_COMMENT;
			break;

		case END_COMMENT:

			if (c == ')')
				state = NO_COMMENT;
			else
				state = IN_COMMENT;
			break;

		}
	}

	return 0;
}
