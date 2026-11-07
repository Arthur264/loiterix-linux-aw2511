# Boot Splash

Displays Loiterix horizontal logo on HDMI during kernel boot. Logo clears when loiterix-platform application starts.

## Changes

**Single file**: `drivers/video/logo/logo_linux_clut224.ppm` (logo replacement only)

- Source: Figma Logo Kit node 1:6 (authentic export)
- Format: P3 ASCII, CLUT224 (224 colors), 512×89
- Original: 824×144, aspect 103:18 preserved
- Asset: `docs/assets/loiterix-horizontal-on-dark-original_20e5.svg`

**No kernel config changes** - uses existing:
- CONFIG_LOGO=y (defconfig) - base logo support
- CONFIG_LOGO_LINUX_CLUT224=y (default when LOGO=y)
- CONFIG_AW_FB_CONSOLE=y (bsp.config) - Allwinner framebuffer

## Boot Parameters

Quiet boot parameters must be configured via bootloader/userspace (not kernel config).

### Kernel CMDLINE Limitation

ARM64 kernel `CONFIG_CMDLINE` options in this tree:
- `CONFIG_CMDLINE_FROM_BOOTLOADER` (default) - uses bootloader args OR falls back to CMDLINE if bootloader empty
- `CONFIG_CMDLINE_FORCE` - always uses CMDLINE, ignores bootloader (unsafe - breaks root= etc)

**No `CONFIG_CMDLINE_EXTEND` available** - cannot safely append kernel defaults to bootloader args.

Setting kernel CMDLINE would either:
1. Only apply when bootloader provides NO args (unlikely)
2. Override critical bootloader settings (root device, console config)

### Platform Configuration

Boot parameters configured via loiterix-platform bootloader config:
```
console=tty1 console=ttyS0,115200n8 quiet loglevel=3 vt.global_cursor_default=0
```

- `quiet` - suppresses most kernel messages on consoles (not serial)
- `loglevel=3` - limits console output to errors/warnings
- `vt.global_cursor_default=0` - hides blinking cursor
- Serial console `ttyS0` still receives full output for debugging
- Kernel ring buffer (`dmesg`) always retains complete log

## Application Coordination

**Kernel**: Displays logo on HDMI after framebuffer init  
**Platform**: Clears framebuffer when application ready (see PR #12)

No kernel hooks for application - userspace handles clearing via existing HDMI framebuffer.

## Status

**UNTESTED** - requires A733 + HDMI display validation.

Patch verified: P3 ASCII format, applies cleanly, minimal delta.
