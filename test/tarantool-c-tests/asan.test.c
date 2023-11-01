#include "lua.h"

#include "test.h"
#include "utils.h"

#include "lj_alloc.c"

#define MALLOC(size) mmap_probe(size)
#define FREE(ptr, size) CALL_MUNMAP(ptr, size)
// #define REALLOC()

static lua_State *main_L = NULL;

static int mmap_test(void *test_state)
{
    size_t size = 20;
    void *p = MALLOC(size);
    if (p == MFAIL)
        return TEST_EXIT_FAILURE;
    
    /* нет ошибок */
    char *arr = (char *)p;
    for (int i=0; i < 20; ++i) {
        arr[i] = 'a' + i;
    }

    /* ошибка */
    // arr[20] = 'a';

    return TEST_EXIT_SUCCESS;
}

static int munmap_test(void *test_state)
{
    size_t size = 20;
    void *p = MALLOC(size);
    if (p == MFAIL)
        return TEST_EXIT_FAILURE;

    FREE(p, 0);
    return TEST_EXIT_SUCCESS;
}

int main(void)
{
	lua_State *L = utils_lua_init();
	main_L = L;

	const struct test_unit tgroup[] = {
		test_unit_def(mmap_test)
	};

	const int test_result = test_run_group(tgroup, L);
    utils_lua_close(L);
	return test_result;
}
