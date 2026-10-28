#include <execinfo.h>
#include <stdio.h>

__attribute__((noinline)) static void level_3(void) {
	void *frames[32];
	int count = backtrace(frames, 32);
	printf("backtrace() returned %d frames:\n", count);
	fflush(stdout);
	backtrace_symbols_fd(frames, count, 1);
}
__attribute__((noinline)) static void level_2(void) { level_3(); }
__attribute__((noinline)) static void level_1(void) { level_2(); }
int main(void) { level_1(); return 0; }
