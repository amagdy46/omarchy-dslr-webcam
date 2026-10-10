# DSLR Webcam for Omarchy

Use a Canon, Nikon, Sony, or other [gphoto2-supported](http://www.gphoto.org/proj/libgphoto2/support.php) camera as an always-on webcam on [Omarchy](https://omarchy.org), with a toggle in the bar.

Plug the camera in and it shows up as a normal webcam (`/dev/videoN`) in Chrome, Firefox, Zoom, Discord, and OBS. It starts by itself when you plug the camera in, comes back after reboots, and recovers from the PTP timeouts that otherwise kill gphoto2 streams.

Tested with a Canon EOS 4000D (Rebel T100).

## How it works

```
camera ──USB/PTP──▶ gphoto2 --capture-movie ──MJPEG──▶ ffmpeg (crop 16:9, scale) ──▶ v4l2loopback /dev/videoN ──▶ apps
```

- **`dslr-webcam`** (bash CLI) runs the pipeline and restarts it if it breaks, resetting the camera's USB session between tries.
- **`dslr-webcam.service`** (systemd user unit) keeps it running. A path unit restarts it whenever you save the settings file.
- **A udev rule** starts the service whenever a gphoto2 camera is plugged in.
- **A bar widget** shows the state and lets you control it:

| Icon | Meaning |
|------|---------|
| 󰖠 | Streaming |
| 󰖠 (highlighted) | Streaming, and an app is reading the camera (the tooltip names it) |
| 󰄀 | Camera connected, starting |
| 󰗟 | Turned off, or live view failed |

Left-click toggles on/off (the setting survives replugs and reboots). Right-click opens a low-latency preview. Middle-click opens the settings file. Hover for status.

## Install

```bash
omarchy plugin add https://github.com/amagdy46/omarchy-dslr-webcam.git --enable
~/.config/omarchy/plugins/amagdy46.dslr-webcam/install.sh
```

`install.sh` installs `gphoto2 ffmpeg v4l-utils psmisc v4l2loopback-dkms`, links `dslr-webcam` into `~/.local/bin`, writes the v4l2loopback config (it keeps yours if you already have one), adds the udev rule, enables the user service, and creates a settings file at `~/.config/dslr-webcam/config`. It asks for sudo. You can run it again safely.

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
dslr-webcam preview       # low-latency preview window
dslr-webcam config        # edit settings
dslr-webcam scan          # find a fixed line in the video (see Troubleshooting)
dslr-webcam doctor        # check the setup
journalctl --user -u dslr-webcam -f
```

## Settings

Open the settings file with `dslr-webcam config` or a middle-click on the bar icon. Each option is explained in the file. Uncomment a line to change it. The stream restarts as soon as you save.

| Setting | Default | What it does |
|---------|---------|--------------|
| `DSLR_WEBCAM_RESOLUTION` | `1280x720` | Output size. The 3:2 camera frame is cropped to this aspect ratio and scaled. `native` sends the frame unchanged. |
| `DSLR_WEBCAM_CROP` | `center` | Which part of the frame to keep when cropping: `center`, `top`, or `bottom`. |
| `DSLR_WEBCAM_MIRROR` | `0` | `1` flips the image horizontally for everyone who sees it. |
| `DSLR_WEBCAM_FPS` | camera rate | Frame-rate cap. |
| `DSLR_WEBCAM_HIDE_ROWS` | off | Hides a fixed horizontal line, as `FIRST_ROW:NUMBER_OF_ROWS`. `dslr-webcam scan` finds and saves it. |
| `DSLR_WEBCAM_EXTRA_FILTERS` | none | Extra ffmpeg filters, e.g. `eq=brightness=0.04:saturation=1.1`. |
| `DSLR_WEBCAM_KEEP_AWAKE` | `1` | Sets the camera's auto power-off to never over USB. `0` leaves it alone. |
| `DSLR_WEBCAM_DEVICE` | auto | Pins a loopback device, e.g. `/dev/video9`. |
| `DSLR_WEBCAM_LABEL` | `DSLR Webcam` | The loopback device to prefer, by its name in apps. |

`dslr-webcam config --show` prints the values in effect. `dslr-webcam config --reset` backs up your file and starts over from the defaults.

The bar widget has two settings of its own (`hideWhenDisconnected`, `pollIntervalSec`) in its entry in `~/.config/omarchy/shell.json`.

## Troubleshooting

**A thin horizontal line across the video that never moves.** Some cameras have a sensor row that misbehaves only in live view, so photos look fine but the webcam shows a line. Aim the camera at a plain wall and run `dslr-webcam scan`. It finds the line and offers to save `DSLR_WEBCAM_HIDE_ROWS`. With a cropped resolution the crop window moves just enough that the line falls outside it, so every pixel you see is real. With `native` the line's rows are filled in from their neighbors.

**The webcam doesn't show up in an app.** Run `dslr-webcam doctor`. Apps list the device only while the stream is running. If another app is already using the camera, close it (see Limitations).

**The stream stops or keeps restarting.** Check that the camera is on and set to a photo mode, then run `journalctl --user -u dslr-webcam -n 50`. After 5 failures in a row the service gives up and sends a notification. Click the bar icon twice to try again.

## Limitations

- **Resolution is limited by the camera's USB live view**, not by its sensor. Most entry-level Canons send about 1056×704 MJPEG at 25–30 fps. Clean HDMI out with a capture card gives a better image, if your body supports it.
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
