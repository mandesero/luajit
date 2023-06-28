local M = {}

function M.profilename(name)
  local vardir = os.getenv('LUAJIT_TEST_VARDIR')
  -- Replace pattern will change directory name of the generated
  -- profile to LUAJIT_TEST_VARDIR if it is set in the process
  -- environment. Otherwise, the original dirname is left intact.
  -- As a basename for this profile the test name is concatenated
  -- with the name given as an argument.
  local replacepattern = ('%s/%s-%s'):format(vardir or '%1', '%2', name)
  -- XXX: return only the resulting string.
  return (arg[0]:gsub('^(.+)/([^/]+)%.test%.lua$', replacepattern))
end

return M
