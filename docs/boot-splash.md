# Loiterix Boot Splash

This document describes the boot splash implementation for Loiterix devices, which displays the authentic horizontal Loiterix logo during system boot with a quiet, professional user experience.

## Overview

The boot splash system consists of two coordinated components:

1. **Kernel-side**: Framebuffer console with embedded Loiterix logo
2. **Userspace-side**: Quiet boot configuration and optional PSplash for extended splash

Together, these provide a seamless boot experience with the Loiterix branding while preserving diagnostic capabilities.

## Features

- ✓ Authentic Loiterix horizontal logo (824×144, aspect ratio 103:18)
- ✓ Displayed proportionally on black background during kernel boot
- ✓ Quiet boot - kernel messages hidden from display
- ✓ Serial console diagnostics preserved (ttyS0)
- ✓ Boot logs accessible via journalctl
- ✓ Debug/recovery mode accessible
- ✓ Smooth transition to application

## Architecture

### Boot Phases

```
┌──────────────┐
│   U-Boot     │ ← Bootloader (optional splash)
└──────┬───────┘
       │
┌──────▼───────┐
│  Linux Kernel│ ← Framebuffer initialized
│   + Logo     │ ← Loiterix logo displayed
└──────┬───────┘
       │
┌──────▼───────┐
│   Systemd    │ ← Quiet init (no status messages)
│ + PSplash    │ ← Optional: extended splash screen
└──────┬───────┘
       │
┌──────▼───────┐
│ Application  │ ← Takes over display
└──────────────┘
```

## Kernel Configuration

### Logo Asset

The Loiterix logo has been integrated as the kernel boot logo:

- **Source**: Figma Logo Kit (node 1:6)
- **Original dimensions**: 824×144 px
- **Aspect ratio**: 103:18 (preserved in conversion)
- **Kernel format**: CLUT224 PPM (224-color palette)
- **Embedded size**: 512×89 px (scaled proportionally)
- **File**: `src/drivers/video/logo/logo_linux_clut224.ppm`

The logo is embedded directly in the kernel image and displayed automatically when framebuffer console is active.

### Kernel Config Options

File: `src/arch/arm64/configs/radxa_splash.config`

Key configuration options enabled:

```kconfig
# Framebuffer and console
CONFIG_FB=y
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y

# DRM/KMS for Allwinner display
CONFIG_DRM=y
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_DRM_SUN4I=y
CONFIG_DRM_SUN8I_MIXER=y

# Kernel boot logo
CONFIG_LOGO=y
CONFIG_LOGO_LINUX_CLUT224=y
```

This configuration is automatically included in the kernel build via `KERNEL_DEFCONFIG` in `Makefile.extra`.

## Boot Parameters

### Required Parameters

Add these parameters to your boot configuration (`/boot/extlinux/extlinux.conf` or device tree):

```
console=tty1 console=ttyS0,115200n8 quiet loglevel=3 vt.global_cursor_default=0
```

**Parameter explanation:**

- `console=tty1` - Primary console on display (for logo)
- `console=ttyS0,115200n8` - Serial console for diagnostics (always available)
- `quiet` - Suppress most kernel boot messages on display
- `loglevel=3` - Show only errors and critical messages
- `vt.global_cursor_default=0` - Hide cursor during boot

### Debug/Recovery Mode

To access verbose boot output for troubleshooting:

1. **Via U-Boot**: Interrupt U-Boot countdown (press any key)
2. **Edit boot command**: Remove `quiet` parameter, or add `debug`
3. **For systemd debug**: Add `systemd.log_level=debug`

Example debug boot parameters:
```
console=tty1 console=ttyS0,115200n8 loglevel=7 debug systemd.log_level=debug
```

## Userspace Configuration

**Note**: The userspace configuration must be implemented in the `loiterix-platform` repository's Ansible playbooks.

### Overview

The userspace component maintains a quiet boot experience after the kernel phase, ensuring no systemd or getty messages overwrite the display until the application is ready.

### Components Required

1. **Boot Parameter Configuration**
   - Ansible task to configure kernel boot parameters in bootloader config
   - File: typically `/boot/extlinux/extlinux.conf` or `/boot/armbianEnv.txt`

2. **Systemd Quiet Mode**
   - Suppress systemd status messages: `ShowStatus=no`
   - Reduce log verbosity: `LogLevel=warning`
   - File: `/etc/systemd/system.conf`

3. **Getty Suppression**
   - Mask getty@tty1 until application starts
   - Prevents login prompt from overwriting splash

4. **Optional: PSplash**
   - Extended splash screen during systemd initialization
   - Maintains logo display until application takes over
   - Package: `psplash` (lightweight, embedded-friendly)

### Example Ansible Tasks

Create `ansible/tasks/boot-splash.yml`:

```yaml
---
- name: Configure kernel boot parameters for quiet boot
  lineinfile:
    path: /boot/extlinux/extlinux.conf
    regexp: '^(\s*append.*)'
    line: '\1 quiet loglevel=3 vt.global_cursor_default=0'
    backrefs: yes
  notify: Reboot required

- name: Suppress systemd messages on console
  lineinfile:
    path: /etc/systemd/system.conf
    regexp: '^#?{{ item.key }}='
    line: '{{ item.key }}={{ item.value }}'
  loop:
    - { key: 'LogLevel', value: 'warning' }
    - { key: 'ShowStatus', value: 'no' }
  notify: Reload systemd

- name: Mask getty on tty1 until application starts
  systemd:
    name: getty@tty1
    masked: yes
```

### Integration with Application

The application service should:

1. Start after systemd initialization
2. Optionally dismiss PSplash (if used): `psplash-write "QUIT"`
3. Take over the framebuffer or display

## Building

### Kernel Build

From the repository root:

```bash
# Build kernel packages
make deb

# Output: ../linux-image-*-aw2511_*.deb
```

The patch is applied automatically during build via the debian/patches system.

### Verification

Check that the patch is applied during build:

```bash
# Verify patch series
cat debian/patches/series | grep boot-splash

# Should show:
# linux/0005-feat-loiterix-boot-splash.patch
```

## Installation

### On Target Device

```bash
# Copy built packages to device
scp ../linux-image-*-aw2511_*.deb target-device:~/

# Install on device
ssh target-device
sudo dpkg -i linux-image-*-aw2511_*.deb
sudo apt-get install -f  # Fix any dependencies
```

### Userspace Setup

```bash
# Deploy via Ansible (from loiterix-platform repository)
cd ansible/
ansible-playbook -i inventory site.yml --tags boot-splash
```

## Testing

### Visual Verification

1. Power on device
2. Observe boot sequence:
   - U-Boot messages (initial)
   - Brief initialization
   - **Loiterix logo appears** (kernel framebuffer initialized)
   - Logo remains visible (no kernel messages)
   - Application starts (logo replaced by app UI)

### Serial Console Testing

Connect to serial console to verify diagnostics are preserved:

```bash
# On development machine
sudo screen /dev/ttyUSB0 115200

# Or with minicom
sudo minicom -D /dev/ttyUSB0 -b 115200
```

You should see full kernel boot messages on serial console even with `quiet` enabled on display.

### Log Verification

After boot, verify logs are preserved:

```bash
# View current boot log
sudo journalctl -b

# View kernel messages
sudo dmesg

# Check for errors
sudo journalctl -p err -b
```

## Troubleshooting

### Logo Not Appearing

**Possible causes:**

1. **Framebuffer not initialized**
   - Check kernel config: `zcat /proc/config.gz | grep -E "CONFIG_FB|CONFIG_DRM"`
   - Verify Allwinner display drivers loaded: `lsmod | grep sun`

2. **Wrong console parameter**
   - Check: `cat /proc/cmdline`
   - Should include `console=tty1`

3. **Display not connected**
   - Connect HDMI/display before power-on
   - Some displays require early connection for detection

### Kernel Messages Still Visible

**Possible causes:**

1. **Missing 'quiet' parameter**
   - Check: `cat /proc/cmdline | grep quiet`
   - Add to boot parameters if missing

2. **Loglevel too high**
   - Check: `cat /proc/sys/kernel/printk`
   - Should be: `3 4 1 7` (or similar, first number ≤ 3)
   - Set via: `loglevel=3` boot parameter

### Getty Prompt Overwrites Display

**Possible causes:**

1. **getty@tty1 not masked**
   - Check: `systemctl status getty@tty1`
   - Mask: `sudo systemctl mask getty@tty1`

2. **Systemd status messages**
   - Check `/etc/systemd/system.conf`
   - Set: `ShowStatus=no`

### Serial Console Not Working

**Possible causes:**

1. **Wrong serial device**
   - Try: `/dev/ttyS0`, `/dev/ttyS1`, etc.
   - Check: `dmesg | grep ttyS`

2. **Wrong baud rate**
   - Verify boot parameter: `console=ttyS0,115200n8`
   - Match in terminal emulator: `115200 8N1`

3. **Serial cable not connected**
   - Verify physical connection
   - Check TX/RX orientation

## Logo Customization

### Updating the Logo

To update the logo with a new design:

1. **Export from Figma**
   ```bash
   # Export as PNG (maintain 103:18 aspect ratio)
   # Recommended: 824×144 or higher resolution
   ```

2. **Convert to kernel format**
   ```bash
   # Scale to appropriate size
   convert new-logo.png \
     -resize 512x89 \
     -background black -gravity center \
     -colors 224 -depth 8 -type Palette \
     logo_new.png

   # Convert to PPM
   convert logo_new.png logo_new.ppm
   ```

3. **Update kernel**
   ```bash
   # Replace logo file
   cp logo_new.ppm src/drivers/video/logo/logo_linux_clut224.ppm
   
   # Rebuild kernel
   make clean-deb
   make deb
   ```

4. **Test and deploy**

### Logo Dimensions

The kernel logo system expects:

- **Format**: PPM (Portable Pixmap)
- **Color depth**: 8-bit indexed color (CLUT224 = 224 colors)
- **Recommended sizes**: 
  - VGA (640×480): 512×89 logo
  - HD (1920×1080): 720×126 logo
  - Preserve 103:18 aspect ratio

**Important**: Always preserve the original 103:18 aspect ratio. The Figma SVG has `preserveAspectRatio=none`, so aspect ratio must be maintained explicitly during conversion.

## Serial Console Access

### Physical Connection

For Allwinner A7/A733 devices:

- **UART**: UART0 (typically ttyS0)
- **Pinout**: Check device-specific documentation
- **Baud rate**: 115200
- **Format**: 8N1 (8 data bits, no parity, 1 stop bit)

### Software

**Linux/macOS:**
```bash
screen /dev/ttyUSB0 115200
# Or
minicom -D /dev/ttyUSB0 -b 115200
```

**Windows:**
- PuTTY, TeraTerm, or similar
- Select COM port, 115200 baud, 8N1

## Technical Details

### Framebuffer Device

- **Device node**: `/dev/fb0`
- **Driver**: sun4i-drm (Allwinner Display Engine)
- **Mode**: Set by display detection (EDID) or device tree

### Display Pipeline

```
Kernel Logo → Framebuffer Console (/dev/fb0) → DRM/KMS → Display Engine → HDMI/LCD
```

### Memory Layout

The kernel logo is compiled into the kernel image:

```
vmlinuz
├── Kernel code
├── Built-in drivers
└── Embedded data
    └── logo_linux_clut224.ppm (as C array)
```

No runtime filesystem access required - logo is available immediately after framebuffer initialization.

## References

- Figma Logo Kit: https://www.figma.com/design/vsVP8uRloZi2OKnKur7A1B/Loiterix-Logo-Kit?node-id=1-6
- Kernel logo system: `drivers/video/logo/`
- Framebuffer console: `drivers/video/fbdev/core/fbcon.c`
- Allwinner display driver: `drivers/gpu/drm/sun4i/`

## Support

### Diagnostic Information

When reporting issues, provide:

```bash
# Kernel version
uname -a

# Boot parameters
cat /proc/cmdline

# Kernel config (framebuffer/logo)
zcat /proc/config.gz | grep -E "CONFIG_FB|CONFIG_LOGO|CONFIG_DRM"

# Framebuffer info
cat /sys/class/graphics/fb0/modes
cat /sys/class/graphics/fb0/name

# Display driver
dmesg | grep -E "fb0|drm|sun4i"

# Boot log (for serial console issues)
sudo journalctl -b
```

---

**Note**: This implementation is designed for Loiterix embedded devices running Allwinner A7/A733 SoCs. Adaptation may be required for other hardware platforms.
