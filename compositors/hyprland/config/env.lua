local function detect_nvidia()
  local scan = io.popen("grep -lix 0x10de /sys/bus/pci/devices/*/vendor 2>/dev/null")
  if scan then
    local hit = scan:read("*l")
    scan:close()
    if hit and hit ~= "" then
      return true
    end
  end

  local lspci = io.popen("lspci -nn 2>/dev/null")
  if not lspci then
    return false
  end
  local output = lspci:read("*a") or ""
  lspci:close()
  return output:lower():find("nvidia", 1, true) ~= nil
end

_G.AETHER_NVIDIA = detect_nvidia()

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

if _G.AETHER_NVIDIA then
  hl.env("LIBVA_DRIVER_NAME", "nvidia")
  hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
end
