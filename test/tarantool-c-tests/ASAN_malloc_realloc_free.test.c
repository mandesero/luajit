#include "lua.h"
#include "test.h"
#include "utils.h"
#include "lj_alloc.c"
#include "lj_gc.h"
#include <sanitizer/asan_interface.h>

static lua_State *main_LS = NULL;
static global_State *main_GS = NULL;

#define IS_POISONED(ptr) __asan_address_is_poisoned(ptr)

int IS_POISONED_REGION(void *ptr, size_t size)
{
    int res = 1;
    int i = 0;
    do {
        res *= IS_POISONED(ptr + i);
    } while (res == 1 && ++i < size);
    return res;
}

static int small_malloc_test(void *test_state)
{
    size_t size = 30;
    void *p = lj_mem_new(main_LS, size);
    size_t algn = (ADDR_ALIGNMENT - size % ADDR_ALIGNMENT) % ADDR_ALIGNMENT;

    if (IS_POISONED_REGION(p - REDZONE_SIZE, REDZONE_SIZE) &&
        !IS_POISONED_REGION(p, size) &&
        IS_POISONED_REGION(p + size, algn + REDZONE_SIZE))
    {
        return TEST_EXIT_SUCCESS;
    }
    return TEST_EXIT_FAILURE;
}

static int large_malloc_test(void *test_state)
{
    size_t size = 1234;
    void *p = lj_mem_new(main_LS, size);
    size_t algn = (ADDR_ALIGNMENT - size % ADDR_ALIGNMENT) % ADDR_ALIGNMENT;

    if (IS_POISONED_REGION(p - REDZONE_SIZE, REDZONE_SIZE) &&
        !IS_POISONED_REGION(p, size) &&
        IS_POISONED_REGION(p + size, algn + REDZONE_SIZE))
    {
        return TEST_EXIT_SUCCESS;
    }
    return TEST_EXIT_FAILURE;
}

static int free_test(void *test_state)
{
    size_t size = 1234;
    void *p = lj_mem_new(main_LS, size);
    size_t algn = (ADDR_ALIGNMENT - size % ADDR_ALIGNMENT) % ADDR_ALIGNMENT;
    lj_mem_free(main_GS, p, size);

    if (IS_POISONED_REGION(p - REDZONE_SIZE, FREDZONE_SIZE + size + algn))
    {
        return TEST_EXIT_SUCCESS;
    }
    return TEST_EXIT_FAILURE;
}

static int realloc_test(void *test_state)
{
    size_t size = 150;
    size_t new_size = size * 2;
    void *p = lj_mem_new(main_LS, size);
    uint8_t *ptr = (uint8_t *)p;
    size_t algn = (ADDR_ALIGNMENT - size % ADDR_ALIGNMENT) % ADDR_ALIGNMENT;
    size_t new_algn = (ADDR_ALIGNMENT - new_size % ADDR_ALIGNMENT) % ADDR_ALIGNMENT;

    for (size_t i = 0; i < size; ++i)
    {
        ptr[i] = i;
    }

    void *newptr = lj_mem_realloc(main_LS, p, size, new_size);

    if (IS_POISONED_REGION(ptr - REDZONE_SIZE, FREDZONE_SIZE + size + algn))
    {
        ASAN_UNPOISON_MEMORY_REGION(ptr, size);
        int res = memcmp(ptr, newptr, size);
        if (res != 0)
        {
            return TEST_EXIT_FAILURE;
        }

        if (IS_POISONED_REGION(newptr - REDZONE_SIZE, REDZONE_SIZE) &&
            !IS_POISONED_REGION(newptr, new_size) &&
            IS_POISONED_REGION(newptr + new_size, new_algn + REDZONE_SIZE))
        {
            return TEST_EXIT_SUCCESS;
        }
    }
    return TEST_EXIT_FAILURE;
}

int main(void)
{
    lua_State *L = utils_lua_init();
    global_State *g = G(L);
    main_LS = L;
    main_GS = g;

    const struct test_unit tgroup[] = {
        test_unit_def(small_malloc_test),
        test_unit_def(large_malloc_test),
        test_unit_def(free_test),
        test_unit_def(realloc_test),
    };

    const int test_result = test_run_group(tgroup, L);
    utils_lua_close(L);
    return test_result;
}
