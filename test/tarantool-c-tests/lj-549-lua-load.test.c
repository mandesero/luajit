#include "test.h"
#include "utils.h"

#include "lj_def.h"

#define UNUSED(x) ((void)(x))

/*
 * Function generates a huge chunk of "bytecode" with a size
 * bigger than LJ_MAX_BUF. The generated chunk must enable
 * endmark in a Lex state.
 */
static const char *
bc_reader_with_endmark(lua_State *L, void *data, size_t *size)
{
	UNUSED(data);
	*size = ~(size_t)0;

	return NULL;
}

static int bc_loader_with_endmark(void *test_state)
{
	lua_State *L = test_state;
	void *ud = NULL;
	int res = lua_load(L, bc_reader_with_endmark, ud, "endmark");

	/*
	 * Make sure we passed the condition with lj_err_mem
	 * in the function `lex_more`.
	 */
	assert_true(res != LUA_ERRMEM);
	assert_true(lua_gettop(L) == 1);
	lua_settop(L, 0);

	return TEST_EXIT_SUCCESS;
}

enum bc_emission_state {
	EMIT_BC,
	EMIT_EOF,
};

typedef struct {
	enum bc_emission_state state;
} dt;

/*
 * Function returns the bytecode chunk on the first call and NULL
 * and size equal to zero on the second call. Triggers the flag
 * `END_OF_STREAM` in the function `lex_more`.
 */
static const char *
bc_reader_with_eof(lua_State *L, void *data, size_t *size)
{
	UNUSED(L);
	dt *test_data = (dt *)data;
	if (test_data->state == EMIT_EOF) {
		*size = 0;
		return NULL;
	}

	static char *bc_chunk = NULL;

	/*
	 * Minimal size of a buffer with bytecode:
	 * signature (1 byte) and a bytecode itself (1 byte).
	 */
	size_t sz = 2;
	free(bc_chunk);
	bc_chunk = malloc(sz);
	/*
	 * `lua_load` automatically detects whether the chunk is text
	 * or binary and loads it accordingly. We need a trace for
	 * *bytecode* input, so it is necessary to deceive a check in
	 * `lj_lex_setup`, that makes a sanity check and detects
	 * whether input is bytecode or text by the first char.
	 * Put `LUA_SIGNATURE[0]` at the beginning of the allocated
	 * region.
	 */
	bc_chunk[0] = LUA_SIGNATURE[0];
	*size = sz;
	test_data->state = EMIT_EOF;

	return bc_chunk;
}

static int bc_loader_with_eof(void *test_state)
{
	lua_State *L = test_state;
	dt test_data = {0};
	test_data.state = EMIT_BC;
	int res = lua_load(L, bc_reader_with_eof, &test_data, "eof");
	assert_true(res == LUA_ERRSYNTAX);
	lua_settop(L, 0);

	return TEST_EXIT_SUCCESS;
}

int main(void)
{
	lua_State *L = utils_lua_init();
	const struct test_unit tgroup[] = {
		test_unit_def(bc_loader_with_endmark),
		test_unit_def(bc_loader_with_eof)
	};

	const int test_result = test_run_group(tgroup, L);
	utils_lua_close(L);
	return test_result;
}
