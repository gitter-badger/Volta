module test;

struct S {
	x: i32;
}

fn main() i32
{
	s: S;
	s.x = 32;
	s = S.init;
	return s.x;
}
