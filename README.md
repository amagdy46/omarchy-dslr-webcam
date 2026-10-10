# DSLR Webcam for Omarchy

Use a Canon, Nikon, Sony, or other [gphoto2-supported](http://www.gphoto.org/proj/libgphoto2/support.php) camera as an always-on webcam on [Omarchy](https://omarchy.org), with a toggle in the bar.

Plug the camera in and it shows up as a normal webcam (`/dev/videoN`) in Chrome, Firefox, Zoom, Discord, and OBS. It starts by itself when you plug the camera in, comes back after reboots, and recovers from the PTP timeouts that otherwise kill gphoto2 streams.

Tested with a Canon EOS 4000D (Rebel T100).

## How it works

```
camera ──USB/PTP──▶ gphoto2 --capture-movie ──MJPEG──▶ ffmpeg (crop 16:9, scale) ──▶ v4l2loopback /dev/videoN ──▶ apps
```

- **`dslr-webcam`** (bash CLI) runs the pipeline and restarts it if it breaks, resetting the camera's USB session between tries.
- **`dslr-webcam.service`** (systemd user unit) keeps it running.
- **A udev rule** starts the service whenever a gphoto2 camera is plugged in.
- **A bar widget** shows the state and lets you control it:

| Icon | Meaning |
|------|---------|
| 󰖠 | Streaming |
| 󰖠 (highlighted) | Streaming, and an app is reading the camera (the tooltip names it) |
| 󰄀 | Camera connected, starting |
| 󰗟 | Turned off, or live view failed |

Left-click toggles on/off (the setting survives replugs and reboots). Right-click opens a low-latency preview. Middle-click restarts the stream.

## Install

```bash
omarchy plugin add https://github.com/amagdy46/omarchy-dslr-webcam.git --enable
~/.config/omarchy/plugins/amagdy46.dslr-webcam/install.sh
```

`install.sh` installs `gphoto2 ffmpeg v4l-utils psmisc v4l2loopback-dkms`, links `dslr-webcam` into `~/.local/bin`, writes the v4l2loopback config (it keeps yours if you already have one), adds the udev rule, and enables the user service. It asks for sudo. You can run it again safely.

Check the setup with:

```bash
dslr-webcam doctor
```

## Camera setup

- Set the mode dial to a photo mode (P/Av/M), not movie mode.
- Turn **Auto power off** off in the camera menu. The service also sets `autopoweroff=0` over USB, but some bodies ignore it.
- For all-day use, power the camera with an AC dummy battery (Canon ACK-E10 for the 4000D/2000D/1300D). Live view drains a battery in about an hour.
- Use manual focus or face-tracking AF, depending on what your body supports in live view.

## Usage

```bash
dslr-webcam status        # camera, service, device, and which apps are using it
dslr-webcam off           # stop, and stay off until 'on'
dslr-webcam on
dslr-webcam preview       # mpv/ffplay preview window
journalctl --user -u dslr-webcam -f
```

## Configuration

`~/.config/dslr-webcam/config` (shell syntax):

```bash
DSLR_WEBCAM_RESOLUTION=1280x720   # or 1920x1080 (upscaled), or "native" for the camera's 3:2 frame
DSLR_WEBCAM_MIRROR=1              # flip horizontally
DSLR_WEBCAM_FPS=30
DSLR_WEBCAM_DEVICE=/dev/video9    # pin a specific loopback device
DSLR_WEBCAM_EXTRA_FILTERS="eq=brightness=0.05"
DSLR_WEBCAM_PATCH_ROWS="596:4"   # hide a bright line the camera burns into live view ("auto" = known models)
```

Then run `dslr-webcam restart`.

The bar widget's settings (`hideWhenDisconnected`, `pollIntervalSec`) go in its entry in `~/.config/omarchy/shell.json`.

## Limitations

- **Resolution is limited by the camera's USB live view**, not by its sensor. Most entry-level Canons send about 1056×704 MJPEG at 25–30 fps. Clean HDMI out with a capture card gives a better image, if your body supports it.
- **Some bodies have a bad sensor row that shows only in live view.** The test EOS 4000D shows a bright line at rows 597–598 of its 1056×704 live view. Zooming in live view shows it is one sensor row read out wrong in live view mode. Full-resolution stills are clean because Canon's still pipeline maps such defects out. In 16:9 mode the crop window slides up 53 px so the row falls outside it, and no pixels are invented. In `native` mode the rows are covered with their neighbors. It's on by default for the 4000D. For another body, set `DSLR_WEBCAM_PATCH_ROWS="Y:H"` (even values) and please open an issue.
- **One reader at a time.** Two apps opening the loopback device at once fight over the format. If OBS is using the DSLR, use OBS's Virtual Camera for everything else.
- **Don't run other `gphoto2` commands while streaming.** The camera allows one PTP session. Run `dslr-webcam off` first.
- If GNOME/gvfs auto-mounts the camera, the service unmounts it before streaming.

## Uninstall

```bash
~/.config/omarchy/plugins/amagdy46.dslr-webcam/uninstall.sh
omarchy plugin remove amagdy46.dslr-webcam
```

## Related

- [webcamize](https://github.com/cowtoolz/webcamize): a standalone C tool for the same pipeline, without the service and Omarchy integration.
- [omarchy-webcam](https://github.com/kristoferlund/omarchy-webcam): preview and V4L2 controls for regular webcams.

## License

MIT
