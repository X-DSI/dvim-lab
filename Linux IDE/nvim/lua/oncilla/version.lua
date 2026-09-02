-- Single source of truth for the Oncilla IDE version.
--
-- Semantic Versioning (https://semver.org): MAJOR.MINOR.PATCH
--   MAJOR  breaking change -- existing keymaps, commands or workflows change
--          or disappear, and the user has to relearn something.
--   MINOR  new capability, added compatibly (a new plugin, a new keymap on a
--          previously free key).
--   PATCH  fix only -- no new behaviour, nothing relearned.
--
-- Bumping resets the parts to its right: 0.1.3 -> minor -> 0.2.0.
-- While MAJOR is 0 the config is still finding its shape and anything may
-- change; 1.0.0 is the promise that it won't, without a MAJOR bump.
--
-- Tag every release in git so the number means something outside this file:
--   git tag -a v0.2.0 -m "OVIM v0.2.0"

local M = {
  major = 0,
  minor = 2,
  patch = 0,
  -- Pre-release tag, e.g. "beta.1" -> "0.1.0-beta.1". nil for a plain release.
  prerelease = nil,
}

---@return string  e.g. "0.1.0" or "0.1.0-beta.1"
function M.string()
  local v = ("%d.%d.%d"):format(M.major, M.minor, M.patch)
  return M.prerelease and (v .. "-" .. M.prerelease) or v
end

return M
