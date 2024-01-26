#include "lua.h"

#include "test.h"
#include "utils.h"

#include "lj_alloc.c"

#define MALLOC(size) mmap_probe(size)
#define FREE(ptr, size) CALL_MUNMAP(ptr, size)
#define REALLOC(ptr, osz, nsz) CALL_MREMAP_(ptr, osz, nsz, 0)

static lua_State *main_L = NULL;

static int mmap_ui8_test(void *test_state)
{
    size_t size = 20;
    void *p = MALLOC(size);
    if (p == MFAIL)
        return TEST_EXIT_FAILURE;
    
    uint8_t *arr = (uint8_t *)p;
    for (int i=0; i < 20 / sizeof(uint8_t); ++i) {
        /* нет ошибок */
        arr[i] = 'a' + i;
    }

    /* ошибка (выход за границу слева) */
    // *(arr - 1) = 'a';
    /* ошибка (выход за границу справа) */
    arr[size / sizeof(uint8_t) + 1] = 'a';

    return TEST_EXIT_SUCCESS;
}

static int mmap_ui16_test(void *test_state)
{
    size_t size = 40;
    void *p = MALLOC(size);
    if (p == MFAIL)
        return TEST_EXIT_FAILURE;
    
    uint16_t *arr = (uint16_t *)p;
    for (int i=0; i < size / sizeof(uint16_t); ++i) {
        /* нет ошибок */
        arr[i] = 'a' + i;
    }

    /* ошибка (выход за границу слева) */
    // *(arr - 1) = 'a';
    /* ошибка (выход за границу справа) */
    // arr[size / sizeof(uint16_t) + 1] = 'a';

    return TEST_EXIT_SUCCESS;
}

static int mmap_ui32_test(void *test_state)
{
    size_t size = 80;
    void *p = MALLOC(size);
    if (p == MFAIL)
        return TEST_EXIT_FAILURE;
    
    uint32_t *arr = (uint32_t *)p;
    for (int i=0; i < size / sizeof(uint32_t); ++i) {
        /* нет ошибок */
        arr[i] = 'a' + i;
    }

    /* ошибка (выход за границу слева) */
    // *(arr - 1) = 'a';
    /* ошибка (выход за границу справа) */
    // arr[size / sizeof(uint32_t) + 1] = 'a';

    return TEST_EXIT_SUCCESS;
}

static int mmap_ui64_test(void *test_state)
{
    size_t size = 160;
    void *p = MALLOC(size);
    if (p == MFAIL)
        return TEST_EXIT_FAILURE;
    
    uint64_t *arr = (uint64_t *)p;
    for (int i=0; i < size / sizeof(uint64_t); ++i) {
        /* нет ошибок */
        arr[i] = 'a' + i;
    }

    /* ошибка (выход за границу слева) */
    // *(arr - 1) = 'a';
    /* ошибка (выход за границу справа) */
    // arr[size / sizeof(uint64_t) + 1] = 'a';

    return TEST_EXIT_SUCCESS;
}


static int munmap_use_after_free_test(void *test_state)
{
    size_t size = 20;
    void *p = MALLOC(size);
    if (p == MFAIL)
        return TEST_EXIT_FAILURE;

    uint8_t *arr = (uint8_t *)p;
    FREE(p, size);
    
    /* use after free */
    arr[25] = arr[25];
    return TEST_EXIT_SUCCESS;
}

static int munmap_double_free_test(void *test_state)
{
    size_t size = 20;
    void *p = MALLOC(size);
    if (p == MFAIL)
        return TEST_EXIT_FAILURE;

    FREE(p, size);

    // /* double free */
    // FREE(p, size);
    return TEST_EXIT_SUCCESS;
}

static int munmap_free_upper_size_test(void *test_state)
{
    size_t size = 20;
    void *p = MALLOC(size);
    if (p == MFAIL)
        return TEST_EXIT_FAILURE;

    /* free upper size */
    // FREE(p, size + 2);
    return TEST_EXIT_SUCCESS;
}

/* false positive */
static int munmap_f_n_test(void *test_state)
{
    size_t size = 8;
    void *p = MALLOC(size);
    if (p == MFAIL)
        return TEST_EXIT_FAILURE;

    uint8_t *ptr = (uint8_t *)p;
    ptr = ptr + 7;
    uint8_t value = 0x11;
    *ptr = value;

    return TEST_EXIT_SUCCESS;
}


static int mremap_test_1(void *test_state)
{
    size_t size = 20;
    void *p = MALLOC(size);
    if (p == MFAIL)
        return TEST_EXIT_FAILURE;

    uint8_t *ptr = (uint8_t *)p;
    for (size_t i=0; i < size; ++i)
    {
        ptr[i] = 'a' + i;
    }
    
    uint8_t *new_ptr = (uint8_t *)REALLOC(ptr, size, size + 10);

    /* к старой памяти обращаться нельзя */
    for (size_t i=0; i < size; ++i)
    {
        ptr[i] = 'a' + i;
    }

    for (size_t i=0; i < size; ++i)
    {
        if (new_ptr[i] != 'a' + i)
            return TEST_EXIT_FAILURE;
    }

    return TEST_EXIT_SUCCESS;
}

#include "lj_gc.h"
int main(void)
{
	lua_State *L = utils_lua_init();
	main_L = L;
    size_t size = 39;
    void* p = lj_mem_new(L, size);
    uint8_t *ptr = (uint8_t *)p;
    uint8_t a = ptr[size + 1];

	// const struct test_unit tgroup[] = {
	// 	// test_unit_def(mmap_ui8_test),
    //     // test_unit_def(mmap_ui16_test),
    //     // test_unit_def(mmap_ui32_test),
    //     // test_unit_def(mmap_ui64_test),
        
    //     // test_unit_def(munmap_use_after_free_test)
    //     // test_unit_def(munmap_double_free_test),
    //     // test_unit_def(munmap_free_upper_size_test),
    //     // test_unit_def(munmap_f_n_test),
    //     test_unit_def(mremap_test_1)

	// };

	// const int test_result = test_run_group(tgroup, L);
    utils_lua_close(L);
	return 0;
}
