module test;

fn foo(a: i32[]...) i32
{
	return 6;
}

fn bar(s: string[]) i32
{
	return 6;
}

fn foo(x: i32) i32
{
	return 7;
}

fn main() i32
{
	return foo(cast(i32[])null) + bar(cast(i32[])null) - 12;
}
