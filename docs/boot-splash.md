# Boot Splash

Displays Loiterix horizontal logo on HDMI during kernel boot with quiet defaults.

## Changes

### Patch: Logo + Cursor Default
`debian/patches/linux/0005-feat-loiterix-boot-splash.patch` modifies:
- `drivers/video/logo/logo_linux_clut224.ppm` - Loiterix logo (512×89 P3 ASCII, ≤224 colors)
- `drivers/tty/vt/vt.c` - Change `global_cursor_default` from `-1` to `0` (cursor off)

Source: Figma Logo Kit node 1:6 (824×144, aspect 103:18)

### Config: Quiet Boot Default
`.github/local/configs/loiterix_quiet.config`:
- `CONFIG_CONSOLE_LOGLEVEL_DEFAULT=3` - Show errors/warnings only (KERN_ERR+)
- `CONFIG_CONSOLE_LOGLEVEL_QUIET=3` - Same level when bootloader passes "quiet"

Integrated via `Makefile.local` config merge.

### Existing Config (No Changes)
- CONFIG_LOGO=y (defconfig)
- CONFIG_LOGO_LINUX_CLUT224=y (auto-enabled)
- CONFIG_AW_FB_CONSOLE=y (bsp.config)

## Boot Behavior

### Quiet Boot - Kernel Native Defaults

1. **Loglevel Default** (config): `CONFIG_CONSOLE_LOGLEVEL_DEFAULT=3`
   - Console prints messages with priority **< 3**: EMERG(0), ALERT(1), CRIT(2) only
   - Does NOT print KERN_ERR(3), KERN_WARNING(4), or lower-priority messages
   - Bootloader can override with explicit `loglevel=X`, `debug`, or `ignore_loglevel`
   - Applies globally to ALL consoles including serial (`ttyS0`)
   - Ring buffer (`dmesg`/`journalctl -b`) preserves complete log regardless

2. **Cursor Default** (code patch): `global_cursor_default = 0`
   - VT cursor off by default
   - Bootloader can override with `vt.global_cursor_default=1` for debug

3. **Logo Display**: Shows during framebuffer init before console takeover
   - Application clears framebuffer when ready

**Config merge**: defconfig → radxa.config → radxa_custom.config → loiterix_quiet.config

**Limitations:**
- Loglevel=3 prints only critical system failures (EMERG/ALERT/CRIT)
- Vendor-specific console/fbcon initialization order unknown - hardware testing required
- Userspace systemd/Plymouth configuration may still be needed for complete quiet boot
- No guarantee of text-free logo display without hardware verification

## Application Coordination

**Kernel**: Displays logo on HDMI after framebuffer init  
**Platform**: Clears framebuffer when application ready (see PR #12)

No kernel hooks for application - userspace handles clearing via existing HDMI framebuffer.

## Status

**UNTESTED** - requires A733 + HDMI display validation.

Patch verified: P3 ASCII format, applies cleanly, minimal delta.
