-- Version constants shared by the mod, the handshake and the build gate.
local M = {}

M.mod = "0.1.0-dev"

-- Side-channel protocol version. Bump on any incompatible message change.
M.protocol = 1

-- Steam build IDs of Monster Hunter Wilds this mod version was verified on (ISteamApps::GetAppBuildId).
M.verified_builds = {
    [24705561] = "Ver.1.042 (2026-08)",
}

-- REFramework nightly the mod and seamless_net.dll are built and tested against.
M.reframework = "nightly-01433 (d4611ae)"

-- "major.minor" part used for handshake compatibility (patch releases interoperate).
function M.compat_key(version)
    local major, minor = tostring(version or ""):match("^(%d+)%.(%d+)")
    if not major then return nil end
    return major .. "." .. minor
end

return M
