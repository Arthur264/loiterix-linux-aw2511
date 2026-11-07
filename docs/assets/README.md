# Boot Splash Assets

## Source

Figma Logo Kit: https://www.figma.com/design/vsVP8uRloZi2OKnKur7A1B/Loiterix-Logo-Kit?node-id=1-6

- `loiterix-horizontal-on-dark-original_20e5.svg` - Original (824×144)
- `loiterix-horizontal-on-dark-black_42a3.png` - Black background raster
- `loiterix-horizontal-on-dark-transparent_8b69.png` - Transparent raster
- `logo_loiterix_clut224.ppm` - Kernel format (P3 ASCII, embedded in patch)

Aspect ratio: 103:18

## Conversion (if updating logo)

```bash
convert source.png -resize 512x89! -colors 224 -compress none output.ppm
file output.ppm  # Must show "ASCII text" not "binary"
```

P3 ASCII format required for kernel's pnmtologo tool.
