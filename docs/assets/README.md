# Loiterix Boot Splash Assets

This directory contains the logo assets for the Loiterix boot splash system.

## Original Assets (From Figma)

**Source**: [Figma Logo Kit](https://www.figma.com/design/vsVP8uRloZi2OKnKur7A1B/Loiterix-Logo-Kit?node-id=1-6)  
**Node**: 1:6 Logo/Wordmark/On Dark  
**Exported**: November 7, 2026

### Files

- `loiterix-horizontal-on-dark-original_20e5.svg` - Original SVG from Figma (824×144)
- `loiterix-horizontal-on-dark-transparent_8b69.png` - Transparent PNG rasterization (824×144)
- `loiterix-horizontal-on-dark-black_42a3.png` - Black background PNG (824×144)

### Properties

- **Dimensions**: 824 × 144 pixels
- **Aspect Ratio**: 103:18 (≈5.72:1)
- **Colors**: White wordmark with red accent on dark background
- **Note**: Original SVG has `preserveAspectRatio=none` - aspect ratio must be maintained explicitly during conversion

## Converted Assets

### Kernel Logo (CLUT224 Format)

Used as the Linux kernel boot logo, embedded in kernel image.

- `logo_loiterix_clut224.ppm` - Kernel logo in PPM format (512×89, 224-color palette)
- `logo_loiterix_clut224.png` - PNG preview of kernel logo (512×89)

**Conversion**:
```bash
convert loiterix-horizontal-on-dark-black_42a3.png \
  -resize 512x89! \
  -background black -gravity center \
  -colors 224 -depth 8 -type Palette \
  logo_loiterix_clut224.png

convert logo_loiterix_clut224.png logo_loiterix_clut224.ppm
```

**Installed to**: `src/drivers/video/logo/logo_linux_clut224.ppm` (replaces default Linux logo)

### PSplash Assets (Optional)

For userspace PSplash extended splash screen (if enabled).

- `psplash-loiterix-640x480.png` - VGA resolution
- `psplash-loiterix-800x600.png` - SVGA resolution
- `psplash-loiterix-1024x768.png` - XGA resolution
- `psplash-loiterix-1920x1080.png` - Full HD resolution

**Conversion**:
```bash
# Example for 1024×768
convert loiterix-horizontal-on-dark-transparent_8b69.png \
  -resize 720x126! \
  -background black -gravity center -extent 1024x768 \
  psplash-loiterix-1024x768.png
```

**Usage**: Copy to `loiterix-platform/ansible/files/` for PSplash deployment

## Aspect Ratio Preservation

The Loiterix logo has a specific aspect ratio of **103:18** that must be preserved during scaling.

### Calculation

```
Original: 824 × 144
Aspect: 824/144 = 5.722...
Ratio: 103:18 (exact)
```

### Scaling Guidelines

When creating new sizes, maintain the aspect ratio:

| Width | Height (103:18) | Use Case |
|-------|-----------------|----------|
| 412   | 72             | Small/thumbnail |
| 515   | 90             | Medium |
| 618   | 108            | Large |
| 720   | 126            | HD (720p) |
| 824   | 144            | Original |
| 1030  | 180            | Large display |
| 1236  | 216            | Extra large |

**ImageMagick command** (maintaining exact aspect):
```bash
convert input.png -resize WIDTHxHEIGHT! output.png
# Note: ! forces exact dimensions, use with calculated heights
```

## Asset Usage

### Kernel Build

The kernel logo (`logo_loiterix_clut224.ppm`) is:
1. Embedded during kernel compilation
2. Compiled into the kernel image as a C array
3. Displayed automatically when framebuffer console initializes
4. No runtime files needed - logo is in-memory

### Userspace Deployment (PSplash)

PSplash assets should be:
1. Copied to `loiterix-platform/ansible/files/`
2. Deployed via Ansible to `/usr/share/loiterix/psplash/`
3. Referenced by PSplash service during boot

See `docs/userspace-boot-splash.md` for complete Ansible configuration.

## Updating Assets

### 1. Export from Figma

Export the logo from Figma Logo Kit:
- Node: 1:6 (Logo/Wordmark/On Dark)
- Format: PNG at native resolution (824×144)
- Or: SVG for vector source

### 2. Convert for Kernel

```bash
# Scale to kernel logo size (adjust as needed)
convert new-logo.png \
  -resize 512x89! \
  -background black -gravity center \
  -colors 224 -depth 8 -type Palette \
  logo_new.png

# Convert to PPM
convert logo_new.png logo_new.ppm

# Replace kernel logo
cp logo_new.ppm src/drivers/video/logo/logo_linux_clut224.ppm
```

### 3. Convert for PSplash (Optional)

```bash
# Generate multiple resolutions
for res in 640x480 800x600 1024x768 1920x1080; do
  # Calculate logo size maintaining aspect ratio
  width=$(echo "$res" | cut -d'x' -f1)
  logo_width=$((width * 62 / 100))  # ~60% of screen width
  logo_height=$((logo_width * 18 / 103))  # Maintain 103:18 aspect
  
  convert new-logo-transparent.png \
    -resize ${logo_width}x${logo_height}! \
    -background black -gravity center -extent $res \
    psplash-loiterix-$res.png
done
```

### 4. Rebuild and Deploy

```bash
# Rebuild kernel
cd loiterix-linux-aw2511
make clean-deb
make deb

# Update userspace assets
cd loiterix-platform/ansible
cp /path/to/new/psplash-*.png files/

# Deploy
ansible-playbook -i inventory site.yml --tags boot-splash
```

## Technical Details

### CLUT224 Format

- **CLUT**: Color Look-Up Table (indexed color)
- **224 colors**: Kernel logo system uses fixed 224-color palette
- **Format**: PPM (Portable Pixmap) - simple raster format
- **Advantages**: 
  - Small file size
  - Fast display (no decompression)
  - Platform-independent
  - Embedded in kernel binary

### Why Replace logo_linux_clut224.ppm?

The Linux kernel has several built-in logos selected based on architecture:
- `logo_linux_clut224.ppm` - Standard 224-color logo (most common)
- `logo_linux_mono.pbm` - Monochrome logo
- `logo_linux_vga16.ppm` - 16-color logo

For arm64 with framebuffer, `logo_linux_clut224.ppm` is used. By replacing this file, the Loiterix logo appears automatically without additional code changes.

### PPM Format Structure

```
P6                    # Magic number (P6 = binary PPM)
512 89                # Width Height
255                   # Max color value
<binary RGB data>     # Raw pixel data
```

## Asset Provenance

All assets derived from the official Loiterix Logo Kit:

**Figma File**: [Loiterix Logo Kit](https://www.figma.com/design/vsVP8uRloZi2OKnKur7A1B/Loiterix-Logo-Kit?node-id=1-6)  
**Node**: 1:6 - Logo/Wordmark/On Dark  
**Exported**: November 7, 2026  
**Artwork Node**: 9:2 (child of 1:6)  
**Original Resolution**: 824×144  
**Aspect Ratio**: 103:18 (exact)

### Conversion Script

The complete conversion script is preserved at `/tmp/splash-work/convert-logos.sh` during development and can be recreated from this documentation.

## License

The Loiterix logo and associated assets are proprietary to Loiterix and subject to their trademark and copyright. This conversion is for authorized use in Loiterix products only.

## References

- Figma Source: https://www.figma.com/design/vsVP8uRloZi2OKnKur7A1B/Loiterix-Logo-Kit?node-id=1-6
- Kernel Documentation: `Documentation/fb/fbcon.rst` in Linux kernel
- Logo System: `drivers/video/logo/` in Linux kernel
- PSplash: https://git.yoctoproject.org/psplash/

---

**Last Updated**: November 7, 2026  
**Maintained By**: Loiterix Development Team
