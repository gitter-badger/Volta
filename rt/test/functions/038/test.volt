//T compiles:no
module test;

import core.stdc.stdio;

fn case1(dg: void delegate(string))
{
}

fn main() i32
{
	fn f1(s: char[]) {
	}

	case1(f1);

	return 0;
}
