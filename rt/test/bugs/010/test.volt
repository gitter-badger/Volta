//T compiles:yes
//T retval:0
// Auto bug
module test;


void* funcReturnsPointer() { void* ptr; return ptr; }

int main()
{
	auto ptr = funcReturnsPointer();

	return 0;
}
