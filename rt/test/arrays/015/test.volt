//T macro:expect-failure
// Test appending to an array, expected to fail.
module test;


fn main() i32
{
	s: i16[];
	i: i32 = 3;
	s = s ~ i;
	return 0;
}
