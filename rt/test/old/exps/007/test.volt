//T compiles:yes
//T retval:42
// @property assignment.
module test;


global int mX;

@property void x(int _x)
{
	mX = _x;
	return;
}

int main()
{
	x = 42;
	return mX;
}