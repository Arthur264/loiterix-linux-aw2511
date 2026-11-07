# Loiterix Boot Splash

This document describes the boot splash implementation for Loiterix devices, which displays the authentic horizontal Loiterix logo during system boot.

**STATUS**: Kernel implementation complete. **UNTESTED on actual hardware**.  
Requires hardware validation with display and serial console before production use.

## Overview

The boot splash system provides:

1. **Kernel-side** (this repo): Framebuffer console with embedded Loiterix logo - **implemented, untested**
2. **Userspace-side** (loiterix-platform repo): Quiet boot configuration - **separate implementation in progress**

## Kernel Implementation

Provides authentic Loiterix horizontal logo embedded in kernel image:
- Logo: 824×144 original, scaled to 512x89, aspect ratio 103:18 maintained
- Format: P3 ASCII PPM, CLUT224 (224-color palette)
- Displays on black background after framebuffer initialization
- Relies on Allwinner BSP framebuffer console (CONFIG_AW_FB_CONSOLE from bsp.config)

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

Configuration added:

```kconfig
# Framebuffer console (relies on CONFIG_AW_FB_CONSOLE from bsp.config)
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y

# VT console
CONFIG_VT=y
CONFIG_VT_CONSOLE=y

# Kernel boot logo
CONFIG_LOGO=y
CONFIG_LOGO_LINUX_CLUT224=y
```

**Note**: A733 uses Allwinner BSP drivers (CONFIG_AW_DRM, CONFIG_AW_FB_CONSOLE) already enabled in `bsp.config`, not mainline sun4i drivers.

Automatically included in kernel build via `KERNEL_DEFCONFIG` in `Makefile.extra`.

## Boot Parameters

### Required Parameters

Add to boot configuration (`/boot/extlinux/extlinux.conf` or bootloader config):

```
console=tty1 console=ttyS0,115200n8 quiet vt.global_cursor_default=0
```

**Parameter explanation:**

- `console=tty1` - Primary console on display (for logo)
- `console=ttyS0,115200n8` - Serial console output
- `quiet` - Suppress most kernel boot messages on display
- `vt.global_cursor_default=0` - Hide cursor during boot

**IMPORTANT - loglevel behavior:**

`loglevel=N` applies **globally to ALL consoles**, not per-console. The kernel ring buffer always preserves all messages regardless of console loglevel (accessible via `dmesg` and `journalctl`).

For full serial output during boot, loglevel must be high (7 or 8), which also shows on display unless `quiet` suppresses some categories. Trade-off between live serial verbosity and display quiet.

**Recovery options:**
- Full verbosity all consoles: `loglevel=7 debug` (removes quiet)
- Display verbose + serial: Remove `quiet` parameter (keeps default loglevel)
- Boot parameter editing: Via U-Boot interrupt or bootloader menu

## Userspace Configuration

**Note**: Userspace implementation is separate, being handled in `loiterix-platform` repository by dedicated agent: https://cursor.com/agents/bc-3aaf84b5-4550-5f7f-8d59-c46925299652

The userspace component should maintain quiet boot after kernel phase, preventing systemd/getty messages from overwriting display until application starts.

### Requirements Overview

Userspace should provide:

1. **Boot Parameter Configuration**: Set kernel boot parameters in bootloader config
2. **Systemd Quiet Mode**: Suppress status messages during init
3. **Getty Suppression**: Prevent login prompt until application ready
4. **Optional PSplash**: Extended splash during userspace init

Implementation details and safe Ansible code handled by separate platform agent.

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

## Testing Status

### Completed
- ✅ Patch format verified (P3 ASCII, <=224 colors)
- ✅ Patch applies cleanly on clean checkout
- ✅ Logo file format correct for pnmtologo
- ✅ Config fragment syntax valid
- ✅ Build system integration correct (Makefile.extra)

### NOT Tested (Hardware Required)
- ❌ Framebuffer initialization with AW_DRM/AW_FB_CONSOLE
- ❌ Logo display on actual A733 device
- ❌ Console output routing (tty1 vs ttyS0)
- ❌ Boot parameter effect verification
- ❌ Serial console behavior with loglevel
- ❌ Display resolution and logo scaling
- ❌ Recovery/debug mode functionality

### Hardware Testing Required

Before production use, validate on actual A733 hardware:

1. **Display initialization**: Connect display, verify framebuffer active
2. **Logo display**: Confirm logo appears after FB init, correct proportions
3. **Console routing**: Verify tty1 shows logo, ttyS0 shows messages
4. **Loglevel behavior**: Test different loglevel values, measure serial output
5. **Recovery mode**: Test removing quiet parameter, verify full output
6. **Boot timing**: Measure logo appearance timing vs kernel init
7. **Error handling**: Test with no display, wrong resolution, etc.

Connect serial console BEFORE testing to capture all output.

## Build Testing (Cloud-Feasible)

Test patch application and kernel config:

```bash
# Clean checkout test
cd /workspace
git clean -fdx
git submodule update --init --recursive

# Apply patches
cd src
for patch in ../debian/patches/linux/*.patch; do
  git apply "$patch" || echo "Patch $patch failed"
done

# Verify files
file drivers/video/logo/logo_linux_clut224.ppm
# Should show: ASCII text

ls arch/arm64/configs/radxa_splash.config
# Should exist

# Test kernel config merge (requires kernel build tools)
make ARCH=arm64 defconfig radxa.config radxa_splash.config
grep "CONFIG_LOGO=y" .config
grep "CONFIG_FRAMEBUFFER_CONSOLE=y" .config
```

Build test (requires cross-compile toolchain):
```bash
make deb
# Verify linux-image-*-aw2511_*.deb created
```

