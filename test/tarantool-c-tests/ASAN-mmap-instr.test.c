#include "lua.h"
#include "test.h"
#include "utils.h"
#include "lj_alloc.c"
#include <sanitizer/asan_interface.h>
#include "lj_gc.h"

#define MALLOC(size) mmap_probe(size)
#define FREE(ptr, size) CALL_MUNMAP(ptr, size)
#define REALLOC(ptr, osz, nsz) CALL_MREMAP_(ptr, osz, nsz, CALL_MREMAP_NOMOVE)
#define IS_POISONED(ptr) __asan_address_is_poisoned(ptr)

static lua_State *main_LS = NULL;

int IS_POISONED_REGION(void *ptr, size_t size)
{
	int res = 1;
	int i = 0;
	do {
		res *= IS_POISONED(ptr + i);
	} while (res == 1 && ++i < size);
	return res;
}

static int mmap_probe_test(void *test_state)
{
	size_t size = DEFAULT_GRANULARITY - FREDZONE_SIZE;
	void *p = MALLOC(size);
	size_t algn = (size_t)align_up((void *)size, SIZE_ALIGNMENT) - size;

	if (p == MFAIL)
		return TEST_EXIT_FAILURE;

	if (IS_POISONED_REGION(p - REDZONE_SIZE, REDZONE_SIZE) &&
	    !IS_POISONED_REGION(p, size) &&
	    IS_POISONED_REGION(p + size, algn + REDZONE_SIZE))
		return TEST_EXIT_SUCCESS;

	return TEST_EXIT_FAILURE;
}

static int munmap_test(void *test_state)
{
	size_t size = DEFAULT_GRANULARITY - FREDZONE_SIZE;
	size_t algn = (size_t)align_up((void *)size, SIZE_ALIGNMENT) - size;
	void *p = MALLOC(size);

	if (p == MFAIL)
		return TEST_EXIT_FAILURE;

	FREE(p, size);
	if (IS_POISONED_REGION(p - REDZONE_SIZE, FREDZONE_SIZE + size + algn))
		return TEST_EXIT_SUCCESS;

	return TEST_EXIT_FAILURE;
}

static int mremap_test(void *test_state)
{
	size_t size = DEFAULT_GRANULARITY - FREDZONE_SIZE;
	size_t new_size = (DEFAULT_GRANULARITY << 1) - FREDZONE_SIZE;
	size_t new_algn = (size_t)align_up((void *)new_size, SIZE_ALIGNMENT) - new_size;
	void *p = MALLOC(size);

	if (p == MFAIL)
		return TEST_EXIT_FAILURE;

	void *newptr = REALLOC(p, size, new_size);
	if (newptr == MFAIL)
		return TEST_EXIT_FAILURE;

	if (IS_POISONED_REGION(newptr - REDZONE_SIZE, REDZONE_SIZE) &&
	    !IS_POISONED_REGION(newptr, new_size) &&
	    IS_POISONED_REGION(newptr + new_size, new_algn + REDZONE_SIZE))
		return TEST_EXIT_SUCCESS;

	return TEST_EXIT_FAILURE;
}

int main(void)
{
	lua_State *L = utils_lua_init();
	main_LS = L;

	const struct test_unit tgroup[] = {
		test_unit_def(mmap_probe_test),
		test_unit_def(munmap_test),
		test_unit_def(mremap_test)
	};

	const int test_result = test_run_group(tgroup, L);
	utils_lua_close(L);
	return test_result;
}
