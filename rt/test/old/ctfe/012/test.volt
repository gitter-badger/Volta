//T compiles:yes
//T retval:60
module test;

i32 thirty(int mult)
{
	return 30 * mult;
}

i32 sixty(int n)
{
	i32 two = 1 + n;
	return thirty(two);
}

i32 main()
{
	i64 bigSixty = cast(i64)#run sixty(1);
	return cast(i32)bigSixty;
}