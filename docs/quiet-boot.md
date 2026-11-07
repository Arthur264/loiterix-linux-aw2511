# Quiet Boot Configuration

Kernel config defaults for reduced console output. No custom logo or cursor modifications.

## Kernel Config Only

`.github/local/configs/loiterix_quiet.config`:
- `CONFIG_CONSOLE_LOGLEVEL_DEFAULT=4` - print priority < 4 only
- `CONFIG_LOGO=n` - disable built-in penguin logo

### Console Loglevel Behavior

**Loglevel=4 prints:**
- EMERG(0) - system unusable
- ALERT(1) - immediate action required
- CRIT(2) - critical conditions
- ERR(3) - error conditions

**Suppressed:**
- WARNING(4), NOTICE(5), INFO(6), DEBUG(7)

**Important:**
- Applies globally to ALL consoles including serial
- Ring buffer (`dmesg`) preserves complete log
- Bootloader can override: `loglevel=7` or `debug` for verbose console
- Critical errors still print to console

### Logo Behavior

`CONFIG_LOGO=n` disables stock Linux penguin display, allowing:
- Faster boot (no kernel logo rendering)
- Userspace controls first visual (Plymouth, custom splash)
- No kernel framebuffer logo delay

### No Bootloader Configuration Required

Kernel provides baseline quiet defaults. No Ansible extlinux.conf edits needed for:
- Console loglevel (kernel default)
- Logo suppression (kernel config)

### Userspace Responsibility

Platform must provide:
- Actual Loiterix logo rendering (userspace tool/Plymouth)
- Early cursor visible during boot (kernel default, no patch applied)
- Application startup clearing/transition

### Override Capability

Bootloader can pass:
- `loglevel=X` - explicit console verbosity
- `debug` - maximum verbosity
- `ignore_loglevel` - print all levels

### Limitations

- ERROR messages still print if errors occur
- Early printk/console messages before config applied
- VT cursor visible (no kernel modification, user accepted)
- Vendor-specific Allwinner console behavior unverified
- Hardware testing required to confirm quiet effectiveness
