# Boot Splash Assets

## Source

Figma Logo Kit: https://www.figma.com/design/vsVP8uRloZi2OKnKur7A1B/Loiterix-Logo-Kit?node-id=1-6

- `loiterix-horizontal-on-dark-original_20e5.svg` - Original vector (824×144, aspect 103:18)
- `loiterix-horizontal-on-dark-transparent_8b69.png` - Raster reference

## Kernel Logo Conversion

Final logo embedded in `debian/patches/linux/0005-feat-loiterix-boot-splash.patch` as `drivers/video/logo/logo_linux_clut224.ppm` (512×89 P3 ASCII, ≤224 colors).

To regenerate:

```bash
convert loiterix-horizontal-on-dark-transparent_8b69.png \
  -background black -flatten \
  -resize 512x89! \
  -colors 224 \
  -compress none \
  logo_loiterix_clut224.ppm

file logo_loiterix_clut224.ppm  # Must show "ASCII text"
```

P3 ASCII format required for kernel's `pnmtologo` tool.
