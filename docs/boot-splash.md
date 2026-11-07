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

Boot parameters configured via loiterix-platform (not kernel):
```
console=tty1 console=ttyS0,115200n8 quiet vt.global_cursor_default=0
```

## Application Coordination

**Kernel**: Displays logo on HDMI after framebuffer init  
**Platform**: Clears framebuffer when application ready (see PR #12)

No kernel hooks for application - userspace handles clearing via existing HDMI framebuffer.

## Status

**UNTESTED** - requires A733 + HDMI display validation.

Patch verified: P3 ASCII format, applies cleanly, minimal delta.
