import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// DSLR webcam status in the bar. The dslr-webcam CLI (installed by install.sh)
// does the work; this widget polls `dslr-webcam status --json` and drives it.
//
//   left click    toggle the stream on/off (persists across replugs)
//   right click   open a low-latency preview window
//   middle click  restart the stream
BarWidget {
  id: root
  moduleName: "amagdy46.dslr-webcam"

  readonly property string cli: Quickshell.env("HOME") + "/.local/bin/dslr-webcam"
  readonly property bool hideWhenDisconnected: setting("hideWhenDisconnected", true) === true
  readonly property int pollIntervalSec: Math.max(1, Number(setting("pollIntervalSec", 3)) || 3)

  property var status: ({ installed: false })
  readonly property bool installed: status.installed === true
  readonly property bool camera: status.camera === true
  readonly property bool enabled: status.enabled !== false
  readonly property bool streaming: status.service === "active"
  readonly property bool failed: status.service === "failed"
  readonly property string consumers: status.consumers || ""
  readonly property bool inUse: streaming && consumers !== ""

  visible: !installed || camera || streaming || !hideWhenDisconnected
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function runCli(args) {
    actionProc.command = [root.cli].concat(args)
    actionProc.running = true
  }

  function tooltip() {
    if (!installed) return "DSLR webcam: run install.sh from the plugin folder"
    var model = status.model || "Camera"
    if (!camera) return enabled ? "DSLR webcam: no camera connected" : "DSLR webcam: off"
    if (!enabled) return model + ": webcam off (click to turn on)"
    if (failed) return model + ": live view failed (middle-click to retry)"
    if (inUse) return model + ": live on " + status.device + ", in use by " + consumers
    if (streaming) return model + ": live on " + status.device
    return model + ": starting…"
  }

  Process {
    id: statusProc
    command: [root.cli, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.status = JSON.parse(String(text || "")) }
        catch (e) { root.status = { installed: false } }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.status = { installed: false }
    }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  Timer {
    interval: root.pollIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-md-webcam / nf-md-camera_off / nf-md-camera
    text: !root.installed || !root.enabled || root.failed ? "󰗟" : (root.streaming ? "󰖠" : "󰄀")
    active: root.inUse || root.failed
    dimmed: !root.installed || !root.enabled || !root.camera
    tooltipText: root.tooltip()
    onPressed: function(b) {
      if (!root.installed) return
      if (b === Qt.RightButton) Quickshell.execDetached([root.cli, "preview"])
      else if (b === Qt.MiddleButton) root.runCli(["restart"])
      else root.runCli(["toggle"])
    }
  }
}
