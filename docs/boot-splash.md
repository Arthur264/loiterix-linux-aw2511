# Boot Splash

Displays Loiterix horizontal logo during kernel boot.

## Changes

**Logo**: Replaced `drivers/video/logo/logo_linux_clut224.ppm` with Loiterix logo
- Source: Figma Logo Kit node 1:6 (authentic export)
- Format: P3 ASCII, CLUT224 (224 colors), 512×89 (from 824×144, aspect 103:18)
- Original: `docs/assets/loiterix-horizontal-on-dark-original_20e5.svg`

**Config**: Added `radxa_splash.config` with framebuffer console + logo support

## Boot Parameters

Add to bootloader config:
```
console=tty1 console=ttyS0,115200n8 quiet vt.global_cursor_default=0
```

- `quiet` - suppress kernel messages on display
- `console=ttyS0` - serial output preserved
- Logs in ring buffer: `dmesg` / `journalctl -b`
- Recovery: remove `quiet` or add `loglevel=7`

## Status

**UNTESTED on hardware** - requires A733 + display + serial console validation.

Patch verified: P3 ASCII format, applies cleanly. Build/hardware tests pending.

## Userspace

Separate implementation (systemd quiet, getty mask, boot params) in loiterix-platform by agent: https://cursor.com/agents/bc-3aaf84b5-4550-5f7f-8d59-c46925299652
