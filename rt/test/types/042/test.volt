//T compiles:yes
//T retval:0
module test;

fn main() i32
{
	a: string = "hello";
	b: const(char)[] = "hello";
	return a == b ? 0 : 1;
}

