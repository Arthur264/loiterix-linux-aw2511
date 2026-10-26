# IMX415 camera on Radxa Cubie A7Z

This document covers the kernel changes that make the Waveshare IMX415 module
work on the Cubie A7Z (Allwinner A733, `vin` + ISP602). It also lists the
userspace pieces that go with them. All kernel changes live in the `bsp` and
`device-a733` submodules. The top-level repo only bumps them
(`81c45d8 Update bsp and device-a733: IMX415 camera support on Cubie A7Z`).

| Repo | Commit | Files |
|---|---|---|
| bsp | `7320e1d5` Enable IMX415 (earlier bring-up) | `imx415_mipi.c`, `sensor_helper.c`, `sunxi_isp.c`, `vin_tdm.c`, `vin_video.c` |
| bsp | `a7967e0e` vin: imx415: make IMX415 work on Cubie A7Z (gain/exposure, 1080p30) | `drivers/vin/modules/sensor/imx415_mipi.c`, `drivers/vin/modules/sensor/sensor_helper.c`, `drivers/vin/vin-video/vin_video.c` |
| device-a733 | `0f6d9c3` cubie_a7z: IMX415 camera on i2c-gpio bus, disable twi3 | `configs/cubie_a7z/linux-6.6/board.dts` |

## Hardware

- Board: Radxa Cubie A7Z.
- Sensor: Waveshare IMX415-98 module on its own 37.125 MHz oscillator. It
  connects through the Radxa AC020 camera cable/adapter to the 22-pin CSI
  connector, with 4-lane MIPI.
- Control I2C: PE3 = SCL, PE4 = SDA. Sensor address 7-bit `0x37` (8-bit
  write `0x6e`, `sensor0_twi_addr`).
- PE8 = `sensor0_pwdn`, active high. High means the sensor is enabled. Never
  drive PE8 low while streaming.
- PE9 = `sensor0_reset` (XCLR), active low.
- Supplies (`&sensor0` in `board.dts`): cameravdd dldo3 3.3 V, iovdd bldo1
  1.8 V, avdd aldo2 2.8 V, dvdd eldo4 1.2 V.

## Kernel changes

### board.dts (device-a733 `0f6d9c3`)

- Added an `i2c_gpio_cam` node: `i2c-gpio`, SCL PE3 / SDA PE4, open-drain,
  `i2c-gpio,delay-us = <5>` (about 100 kHz). It is aliased as `i2c3`, so the
  existing `sensor0_twi_cci_id = <3>` resolves to it.
- Set `&twi3` to `status = "disabled"`.
- Why: the hardware TWI3 controller times out on this bus with the IMX415
  module, so the sensor never probes. A bit-banged bus on the same pins works.

### imx415_mipi.c (bsp `a7967e0e`)

| Change | Reason / what it fixes |
|---|---|
| `MCLK` 37.125 MHz → 24 MHz | The module has its own oscillator. Requesting 24 MHz keeps csi-master on `sys24M`. With 37.125 MHz, `vin_set_mclk_freq()` reparents it onto `pll-video0`, which the running ISP/CSI clocks share. |
| Power-up order: MCLK on, then PWDN (PE8) high, then RESET (PE9) released, then 20–25 ms wait | The IMX415 needs INCK running before XCLR is released. |
| `sensor_s_exp()` rewritten | SHR0 = active-mode VMAX − exposure lines, clamped to `[8, VMAX-4]`. The old code used a wrong formula, and with `exp_val == 0` it wrote a bogus value. |
| `sensor_s_gain()` rewritten | Correct `gain2db[]` indexing (0.3 dB steps, +100 steps per extra 32x), clamped at 240 steps (72 dB). The old code had `&&` instead of `&` and indexed out of range. |
| `sensor_s_exp_gain()` | Removed the bogus `0x0340/0x0341` writes (not IMX415 registers). Exposure is clamped to VMAX − 8, and the exp/gain writes are wrapped in REGHOLD (`0x3001`). |
| `imx415_apply_exp_gain()` called from `sensor_reg_init()` | The register tables reset SHR0/gain to 0 dB, which gave a black picture without an AE server. At stream-on the driver now programs the user-set exposure/gain, or full exposure (SHR0 = 8) plus default gain `0x58` (26.4 dB). |
| `sensor_init()` no longer clears `info->gain` | A GAIN/EXPOSURE ctrl set before stream-on survives the power-on and gets applied. The values are cleared only at probe. |
| V4L2 GAIN range 16..96000 (16 = 1x) | Same units as the vin video node. `VOLATILE` + `EXECUTE_ON_WRITE` on GAIN/EXPOSURE so a write always reaches the sensor. |
| 1080p60 window fixed | `hts 550 / vts 2250`, `fps_fixed = 60` (HMAX 0x226, VMAX 0x8CA at 37.125 MHz). It was mislabelled as 30 fps with wrong timings. |
| New 1080p30 window `sensor_10bit_1080p30_regs` | 1080p60 timing with VMAX 4500 (`0x3024/0x3025 = 0x1194`), giving 30 fps. `intg_max = (4500-4)<<4`. |
| `sensor_s_stream()` NULL guard | Returns `-EINVAL` instead of oopsing when no window/format is selected. |
| `probe`: `not_detect_use_count = 1` | Allows I2C detect in `sensor_init` before the entity is in use. |

### sensor_helper.c (bsp `a7967e0e`)

- `sensor_find_frame_size()`: resolution-first matching. The fps match is
  honoured only if an fps-matching window is also the closest covering
  resolution. Before this, a 1920x1080 request with the default 30 fps tpf got
  the 3840x2160@30 window.
- `sensor_s_parm()`: also accepts `V4L2_BUF_TYPE_VIDEO_CAPTURE`, because the
  v4l2 core can pass the single-planar type for an mplane node. A zero
  `timeperframe` is ignored instead of overwriting the tpf.

### vin_video.c (bsp `a7967e0e`)

- `vin_g_volatile_ctrl()` / `vin_s_ctrl()`: return `-ENODEV` when the sensor or
  ISP subdev or the flash is not linked yet. `v4l2-ctl --all` or wireplumber
  before input selection used to dereference NULL.
- GAIN/EXPOSURE are passed straight to the sensor ctrls when the ISP h3a
  stats (the userspace AE server) are not running. Otherwise nothing ever
  reached the sensor.

## Module parameters

The committed driver has **no module parameters**.

`bin12` / `bin12_blv` exist only in an experimental, uncommitted build
(`patches/imx415-bin12-experimental.diff`, against the committed
`imx415_mipi.c`):

- `bin12=1` exposes only a 1920x1080@30 mode from 2x2 binned readout
  (1944x1097 centre crop), 12-bit output, 594 Mbps x 4 lanes. Timings come from
  Rockchip `imx415.c` (VMAX 3165, HMAX 782).
- `bin12_blv` overrides BLKLEVEL (`0x30E2/0x30E3`). `-1` (the default) leaves it
  unchanged.
- It is **not the default** because with the Allwinner ISP's built-in imx415
  profile, which is tuned for the 10-bit modes, the picture comes out magenta.
- The board config sets `options imx415_mipi bin12=0`
  (`/etc/modprobe.d/imx415.conf`). That is harmless with the committed module,
  which has no such parameter. Remove it if modprobe complains.

## Known limitations

- 1080p60 cannot be selected through the normal path. The 1080p30 window wins
  for the 1080p request.
- The IR-cut filter cannot be controlled through the AC020 cable. Never use
  `ircut_probe=2`.
- Raw Bayer capture through vin (without the ISP) does not work. Use
  `en-awisp=1`.
- In the old (vendor) 1080p mode the window's SYS_MODE/`mipi_bps` (720 Mbps)
  were inconsistent with the register table. The 1080p30 window reuses the
  fixed 1080p60 timing.
- Without the AE server (plain V4L2 capture) exposure/gain are fixed at the
  stream-on defaults unless set through V4L2 ctrls.

## Userspace (loiterix-platform)

Deployed by `ansible/tasks/boards/radxa_cubie_a7z.yml` (tag `camera`), with
files in `ansible/files/camera/`:

- `imx415.conf` → `/etc/modprobe.d/imx415.conf` (`options imx415_mipi bin12=0`),
  followed by an initramfs update.
- `imx415_isp0_1920_1080_30_cfg.bin` → `/usr/share/loiterix/camera/`. This is
  the custom ISP tuning (md5 `b12606282c6e529e9a188cce4a9013bb`):
  - metering mode 2
  - sharpen x1.15
  - high-ISO denoise down to x0.85
  - AE capped at 1/30 s, max gain about 62x
- `isp-tuning-apply.sh` + `isp-tuning.service`:
  - On each stream start libisp dumps its built-in cfg to
    `/data/vendor/camera/isp0_1920_1080_30_0/cfg` and sets
    `/data/vendor/camera/isp_tuning_isp0` to 1.
  - The service atomically replaces `cfg` with the custom file and writes 0 to
    the flag.
  - libisp then logs `read ini tuning cfg OK!` and applies it.
  - **Permission fix:** `cfg` must stay writable by the streaming user
    (mode 0666). A root-owned 0644 `cfg` makes libisp segfault in
    `isp_ini_tuning_run()` on the next stream start.
- GStreamer source (`configs/vidlik/config.json`, `imx415_1080*`):
  `v4l2src device=/dev/video0 en-awisp=1 en-largemode=0 ! video/x-raw,format=NV12,width=1920,height=1080,framerate=30/1 ! videoconvert ! video/x-raw,format=RGB,...`

## Verification (Oct 26–27, 2026)

- Sensor probes over i2c-gpio, and `/dev/video0` streams 1920x1080 NV12 at
  30.0 fps through the ISP (fakesink, 1087 frames in 36 s, 0 dropped).
- Indoor night scene (Y mean / temporal noise / laplacian):

  | Profile | Y mean | Temporal noise | Laplacian |
  |---|---|---|---|
  | Built-in ISP profile | 93.3 | 0.32 | 88.6 |
  | Custom cfg | 96.0 | 0.36 | 81.4 |

  Clip about 0.15% in both.
- isp-tuning with the permission fix: 13 consecutive stream starts, including
  2 SIGKILLs mid-stream. All logged `read ini tuning cfg OK!`, had no
  segfault, ran at 30.1–30.2 fps, and the live cfg matched the custom md5.
  Control run: a root 0644 `cfg` reproduces the segfault with the service
  stopped.
- Microphone (ics43434, card 0) records with `arecord -D plughw:0,0`.

## Rollback

- Kernel: install the previous `linux-image-*-aw2511` package (or select the
  older kernel at boot) and reboot. Alternatively revert bsp `a7967e0e` /
  device-a733 `0f6d9c3` and rebuild (`./scripts/orbstack-build.sh deb`).
- Tuning only: `systemctl disable --now isp-tuning`. The next stream start then
  uses libisp's built-in profile.
- Remove `/etc/modprobe.d/imx415.conf` and run `update-initramfs -u` if needed.
