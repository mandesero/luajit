/*
** Miscellaneous Lua extensions library.
**
** Major portions taken verbatim or adapted from the LuaVela interpreter.
** Copyright (C) 2015-2019 IPONWEB Ltd.
*/

#define lib_misc_c
#define LUA_LIB

#include "lua.h"
#include "lmisclib.h"
#include "lauxlib.h"

#include "lj_obj.h"
#include "lj_str.h"
#include "lj_tab.h"
#include "lj_lib.h"
#include "lj_gc.h"
#include "lj_err.h"

#include "lj_memprof.h"

#include <errno.h>
#include <fcntl.h>
#if !LJ_TARGET_WINDOWS
#include <unistd.h>
#endif

/* ------------------------------------------------------------------------ */

static LJ_AINLINE void setnumfield(struct lua_State *L, GCtab *t,
				   const char *name, int64_t val)
{
  setnumV(lj_tab_setstr(L, t, lj_str_newz(L, name)), (double)val);
}

#define LJLIB_MODULE_misc

LJLIB_CF(misc_getmetrics)
{
  struct luam_Metrics metrics;
  GCtab *m;

  lua_createtable(L, 0, 19);
  m = tabV(L->top - 1);

  luaM_metrics(L, &metrics);

  setnumfield(L, m, "strhash_hit", metrics.strhash_hit);
  setnumfield(L, m, "strhash_miss", metrics.strhash_miss);

  setnumfield(L, m, "gc_strnum", metrics.gc_strnum);
  setnumfield(L, m, "gc_tabnum", metrics.gc_tabnum);
  setnumfield(L, m, "gc_udatanum", metrics.gc_udatanum);
  setnumfield(L, m, "gc_cdatanum", metrics.gc_cdatanum);

  setnumfield(L, m, "gc_total", metrics.gc_total);
  setnumfield(L, m, "gc_freed", metrics.gc_freed);
  setnumfield(L, m, "gc_allocated", metrics.gc_allocated);

  setnumfield(L, m, "gc_steps_pause", metrics.gc_steps_pause);
  setnumfield(L, m, "gc_steps_propagate", metrics.gc_steps_propagate);
  setnumfield(L, m, "gc_steps_atomic", metrics.gc_steps_atomic);
  setnumfield(L, m, "gc_steps_sweepstring", metrics.gc_steps_sweepstring);
  setnumfield(L, m, "gc_steps_sweep", metrics.gc_steps_sweep);
  setnumfield(L, m, "gc_steps_finalize", metrics.gc_steps_finalize);

  setnumfield(L, m, "jit_snap_restore", metrics.jit_snap_restore);
  setnumfield(L, m, "jit_trace_abort", metrics.jit_trace_abort);
  setnumfield(L, m, "jit_mcode_size", metrics.jit_mcode_size);
  setnumfield(L, m, "jit_trace_num", metrics.jit_trace_num);

  return 1;
}

/* ------------------------------------------------------------------------ */

#include "lj_libdef.h"

/* --------- profile common section --------------------------------------- */

#if !LJ_TARGET_WINDOWS
/*
** Yep, 8Mb. Tuned in order not to bother the platform with too often flushes.
*/
#define STREAM_BUFFER_SIZE (8 * 1024 * 1024)

/* Structure given as ctx to memprof writer and on_stop callback. */
struct profile_ctx {
  /* Output file descriptor for data. */
  int fd;
  /* Profiled global_State for lj_mem_free at on_stop callback. */
  global_State *g;
  /* Buffer for data. */
  uint8_t buf[STREAM_BUFFER_SIZE];
};

/*
** Default buffer writer function.
** Just call write to the corresponding descriptor.
*/
static size_t buffer_writer_default(const void **buf_addr, size_t len,
				    void *opt)
{
  struct profile_ctx *ctx = opt;
  const int fd = ctx->fd;
  const void * const buf_start = *buf_addr;
  const void *data = *buf_addr;
  size_t write_total = 0;

  lua_assert(len <= STREAM_BUFFER_SIZE);

  for (;;) {
    const ssize_t written = write(fd, data, len - write_total);

    if (LJ_UNLIKELY(written == -1)) {
      /* Re-tries write in case of EINTR. */
      if (errno != EINTR) {
  /* Will be freed as whole chunk later. */
  *buf_addr = NULL;
  return write_total;
      }

      errno = 0;
      continue;
    }

    write_total += written;
    lua_assert(write_total <= len);

    if (write_total == len)
      break;

    data = (uint8_t *)data + (ptrdiff_t)written;
  }

  *buf_addr = buf_start;
  return write_total;
}

/* Default on stop callback. Just close the corresponding descriptor. */
static int on_stop_cb_default(void *opt, uint8_t *buf)
{
  struct profile_ctx *ctx = NULL;
  int fd = 0;

  if (opt == NULL) {
    /* Nothing to do. */
    return 0;
  }

  ctx = opt;
  fd = ctx->fd;
  UNUSED(buf);
  lj_mem_free(ctx->g, ctx, sizeof(*ctx));
  return close(fd);
}

/* ----- misc.sysprof module ---------------------------------------------- */

#define LJLIB_MODULE_misc_sysprof

/* The default profiling interval equals to 11 ms. */
#define SYSPROF_DEFAULT_INTERVAL 10
#define SYSPROF_DEFAULT_OUTPUT "sysprof.bin"

static int set_output_path(const char *path, struct luam_Sysprof_Options *opt) {
  struct profile_ctx *ctx = opt->ctx;
  int fd = 0;
  lua_assert(path != NULL);
  fd = open(path, O_CREAT | O_WRONLY | O_TRUNC, 0644);
  if(fd == -1) {
    return PROFILE_ERRIO;
  }
  ctx->fd = fd;
  return PROFILE_SUCCESS;
}

static int parse_sysprof_opts(lua_State *L, struct luam_Sysprof_Options *opt, int idx) {
  GCtab *options = lj_lib_checktab(L, idx);

  /* Get profiling mode. */
  {
    const char *mode = NULL;

    cTValue *mode_opt = lj_tab_getstr(options, lj_str_newlit(L, "mode"));
    if (!mode_opt || !tvisstr(mode_opt)) {
      return PROFILE_ERRUSE;
    }

    mode = strVdata(mode_opt);
    if (mode[1] != '\0')
      return PROFILE_ERRUSE;

    switch (*mode) {
      case 'D':
        opt->mode = LUAM_SYSPROF_DEFAULT;
        break;
      case 'L':
        opt->mode = LUAM_SYSPROF_LEAF;
        break;
      case 'C':
        opt->mode = LUAM_SYSPROF_CALLGRAPH;
        break;
      default:
        return PROFILE_ERRUSE;
    }
  }

  /* Get profiling interval. */
  {
    cTValue *interval = lj_tab_getstr(options, lj_str_newlit(L, "interval"));
    opt->interval = SYSPROF_DEFAULT_INTERVAL;
    if (interval && tvisnumber(interval)) {
      int32_t signed_interval = numberVint(interval);
      if (signed_interval < 1)
        return PROFILE_ERRUSE;
      opt->interval = signed_interval;
    }
  }

  /* Get output path. */
  if (opt->mode != LUAM_SYSPROF_DEFAULT)
  {
    const char *path = NULL;
    struct profile_ctx *ctx = NULL;
    int status = 0;

    cTValue *pathtv = lj_tab_getstr(options, lj_str_newlit(L, "path"));
    if (!pathtv)
      path = SYSPROF_DEFAULT_OUTPUT;
    else if (!tvisstr(pathtv))
      return PROFILE_ERRUSE;
    else
      path = strVdata(pathtv);

    ctx = lj_mem_new(L, sizeof(*ctx));
    ctx->g = G(L);
    opt->ctx = ctx;
    opt->buf = ctx->buf;
    opt->len = STREAM_BUFFER_SIZE;

    status = set_output_path(path, opt);
    if (status != PROFILE_SUCCESS) {
      lj_mem_free(ctx->g, ctx, sizeof(*ctx));
      return status;
    }
  }

  return PROFILE_SUCCESS;
}

static int parse_options(lua_State *L, struct luam_Sysprof_Options *opt)
{
  if (lua_gettop(L) != 1)
    return PROFILE_ERRUSE;

  if (!lua_istable(L, 1))
    return PROFILE_ERRUSE;

  return parse_sysprof_opts(L, opt, 1);
}

static int sysprof_error(lua_State *L, int status)
{
  switch (status) {
    case PROFILE_ERRUSE:
      lua_pushnil(L);
      lua_pushstring(L, err2msg(LJ_ERR_PROF_MISUSE));
      lua_pushinteger(L, EINVAL);
      return 3;
#if LJ_HASSYSPROF
    case PROFILE_ERRRUN:
      lua_pushnil(L);
      lua_pushstring(L, err2msg(LJ_ERR_PROF_ISRUNNING));
      lua_pushinteger(L, EINVAL);
      return 3;
    case PROFILE_ERRIO:
      return luaL_fileresult(L, 0, NULL);
#endif
    default:
      lua_assert(0);
      return 0;
  }
}

/* local res, err, errno = sysprof.start(options) */
LJLIB_CF(misc_sysprof_start)
{
  int status = PROFILE_SUCCESS;

  struct luam_Sysprof_Options opt = {};

  status = parse_options(L, &opt);
  if (LJ_UNLIKELY(status != PROFILE_SUCCESS))
    return sysprof_error(L, status);

  status = luaM_sysprof_start(L, &opt);
  if (LJ_UNLIKELY(status != PROFILE_SUCCESS))
    /* Allocated memory will be freed in on_stop callback. */
    return sysprof_error(L, status);

  lua_pushboolean(L, 1);
  return 1;
}

/* local res, err, errno = profile.sysprof_stop() */
LJLIB_CF(misc_sysprof_stop)
{
  int status = luaM_sysprof_stop(L);
  if (LJ_UNLIKELY(status != PROFILE_SUCCESS))
    return sysprof_error(L, status);

  lua_pushboolean(L, 1);
  return 1;
}

/* local counters, err, errno = sysprof.report() */
LJLIB_CF(misc_sysprof_report)
{
  struct luam_Sysprof_Counters counters = {};
  GCtab *data_tab = NULL;
  GCtab *count_tab = NULL;

  int status = luaM_sysprof_report(&counters);
  if (status != PROFILE_SUCCESS)
    return sysprof_error(L, status);

  lua_createtable(L, 0, 3);
  data_tab = tabV(L->top - 1);

  setnumfield(L, data_tab, "samples", counters.samples);

  lua_createtable(L, 0, LJ_VMST__MAX + 1);
  count_tab = tabV(L->top - 1);

  setnumfield(L, count_tab, "INTERP", counters.vmst_interp);
  setnumfield(L, count_tab, "LFUNC",  counters.vmst_lfunc);
  setnumfield(L, count_tab, "FFUNC",  counters.vmst_ffunc);
  setnumfield(L, count_tab, "CFUNC",  counters.vmst_cfunc);
  setnumfield(L, count_tab, "GC",     counters.vmst_gc);
  setnumfield(L, count_tab, "EXIT",   counters.vmst_exit);
  setnumfield(L, count_tab, "RECORD", counters.vmst_record);
  setnumfield(L, count_tab, "OPT",    counters.vmst_opt);
  setnumfield(L, count_tab, "ASM",    counters.vmst_asm);
  setnumfield(L, count_tab, "TRACE",  counters.vmst_trace);

  lua_setfield(L, -2, "vmstate");

  return 1;
}

/* ----- misc.memprof module ---------------------------------------------- */

#define LJLIB_MODULE_misc_memprof

/* local started, err, errno = misc.memprof.start(fname) */
LJLIB_CF(misc_memprof_start)
{
  struct lj_memprof_options opt = {0};
  const char *fname = strdata(lj_lib_checkstr(L, 1));
  struct profile_ctx *ctx;
  int memprof_status;

  /*
  ** FIXME: more elegant solution with ctx.
  ** Throws in case of OOM.
  */
  ctx = lj_mem_new(L, sizeof(*ctx));
  opt.ctx = ctx;
  opt.buf = ctx->buf;
  opt.writer = buffer_writer_default;
  opt.on_stop = on_stop_cb_default;
  opt.len = STREAM_BUFFER_SIZE;

  ctx->g = G(L);
  ctx->fd = open(fname, O_CREAT | O_WRONLY | O_TRUNC, 0644);

  if (ctx->fd == -1) {
    lj_mem_free(ctx->g, ctx, sizeof(*ctx));
    return luaL_fileresult(L, 0, fname);
  }

  memprof_status = lj_memprof_start(L, &opt);

  if (LJ_UNLIKELY(memprof_status != PROFILE_SUCCESS)) {
    switch (memprof_status) {
    case PROFILE_ERRUSE:
      lua_pushnil(L);
      lua_pushstring(L, err2msg(LJ_ERR_PROF_MISUSE));
      lua_pushinteger(L, EINVAL);
      return 3;
#if LJ_HASMEMPROF
    case PROFILE_ERRRUN:
      lua_pushnil(L);
      lua_pushstring(L, err2msg(LJ_ERR_PROF_ISRUNNING));
      lua_pushinteger(L, EINVAL);
      return 3;
    case PROFILE_ERRIO:
      return luaL_fileresult(L, 0, fname);
#endif
    default:
      lua_assert(0);
      return 0;
    }
  }
  lua_pushboolean(L, 1);
  return 1;
}

/* local stopped, err, errno = misc.memprof.stop() */
LJLIB_CF(misc_memprof_stop)
{
  int status = lj_memprof_stop(L);
  if (status != PROFILE_SUCCESS) {
    switch (status) {
    case PROFILE_ERRUSE:
      lua_pushnil(L);
      lua_pushstring(L, err2msg(LJ_ERR_PROF_MISUSE));
      lua_pushinteger(L, EINVAL);
      return 3;
#if LJ_HASMEMPROF
    case PROFILE_ERRRUN:
      lua_pushnil(L);
      lua_pushstring(L, err2msg(LJ_ERR_PROF_NOTRUNNING));
      lua_pushinteger(L, EINVAL);
      return 3;
    case PROFILE_ERRIO:
      return luaL_fileresult(L, 0, NULL);
#endif
    default:
      lua_assert(0);
      return 0;
    }
  }
  lua_pushboolean(L, 1);
  return 1;
}
#endif /* !LJ_TARGET_WINDOWS */

#include "lj_libdef.h"

/* ------------------------------------------------------------------------ */

LUALIB_API int luaopen_misc(struct lua_State *L)
{
#if !LJ_TARGET_WINDOWS
  luaM_sysprof_set_writer(buffer_writer_default);
  luaM_sysprof_set_on_stop(on_stop_cb_default);
  /*
  ** XXX: Passing NULL to the backtracer configuration handle sets the default
  ** backtracing function.
  */
  luaM_sysprof_set_backtracer(NULL);
#endif /* !LJ_TARGET_WINDOWS */

  LJ_LIB_REG(L, LUAM_MISCLIBNAME, misc);
#if !LJ_TARGET_WINDOWS
  LJ_LIB_REG(L, LUAM_MISCLIBNAME ".memprof", misc_memprof);
  LJ_LIB_REG(L, LUAM_MISCLIBNAME ".sysprof", misc_sysprof);
#endif /* !LJ_TARGET_WINDOWS */
  return 1;
}
