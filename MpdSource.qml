import QtQuick
import Quickshell
import Quickshell.Io
import "MpdParse.js" as MpdParse

Item {
  id: root

  // Player-compatible read-only properties consumed by Service.qml.
  readonly property string identity: "Music Player Daemon"
  readonly property string desktopEntry: "mpd"
  readonly property string dbusName: "org.mpris.MediaPlayer2.mpd"
  readonly property string uniqueId: "mpd-native"
  readonly property string trackTitle: _title
  readonly property string trackArtist: _artist
  readonly property string trackAlbum: _album
  readonly property string trackArtUrl: _artUrl
  readonly property bool isPlaying: _playing
  readonly property int playbackState: _playing ? 1 /* Playing */ : (_stopped ? 0 /* Stopped */ : 2 /* Paused */)
  readonly property bool canPlay: _available
  readonly property bool canPause: _available && _playing
  readonly property bool canGoNext: _available
  readonly property bool canGoPrevious: _available
  readonly property bool canTogglePlaying: _available
  readonly property bool canRaise: false

  // Whether mpc is reachable and MPD is responding.
  readonly property bool available: _available

  // --- Private state -------------------------------------------------------
  property string _title: ""
  property string _artist: ""
  property string _album: ""
  property string _artUrl: ""
  property string _file: ""
  property bool _playing: false
  property bool _stopped: true
  property bool _available: false
  property bool _mpcFound: true // assume true until proven otherwise

  // Track the file path so we only re-extract art on track change.
  property string _lastArtFile: ""

  readonly property string _artPath: {
    var dir = Quickshell.env("XDG_RUNTIME_DIR")
    if (!dir) dir = "/tmp"
    return dir + "/omarchy-mpris-art.jpg"
  }

  // Separator used for mpc output parsing (unlikely to appear in metadata).
  readonly property string _sep: "\x1f" // ASCII unit separator

  // --- Refresh logic -------------------------------------------------------

  // Long-lived watcher: `mpc idleloop player` emits a line on every player
  // event, letting us react immediately instead of polling.
  Process {
    id: idleProc
    command: ["mpc", "idleloop", "player"]
    running: root._mpcFound

    stdout: SplitParser {
      onRead: data => root._refresh()
    }

    onExited: (exitCode, exitStatus) => {
      // Restart after a short delay unless mpc is missing entirely.
      if (root._mpcFound) restartTimer.start()
    }
  }

  Timer {
    id: restartTimer
    interval: 3000
    onTriggered: {
      if (root._mpcFound) idleProc.running = true
    }
  }

  // Fallback timer: catches state changes if idleloop dies or is slow.
  Timer {
    id: pollTimer
    interval: 5000
    running: root._mpcFound
    repeat: true
    triggeredOnStart: true
    onTriggered: root._refresh()
  }

  // --- Status query --------------------------------------------------------

  // Runs `mpc current` with a structured format, followed by `mpc status`
  // output (the second line gives [playing]/[paused]/volume info).
  // We request both in a single shell invocation to avoid two processes.
  Process {
    id: statusProc
    property bool _running: false
    command: [
      "sh", "-c",
      "mpc current -f '" + root._sep + "%artist%" + root._sep + "%title%"
        + root._sep + "%album%" + root._sep + "%file%' 2>/dev/null; "
        + "mpc status 2>/dev/null | sed -n '2p'"
    ]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        root._parseStatus(this.text)
        statusProc._running = false
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 127) {
        // mpc not found — disable everything.
        root._mpcFound = false
        root._resetState()
      }
      statusProc._running = false
    }
  }

  function _refresh() {
    if (statusProc._running) return
    statusProc._running = true
    statusProc.running = true
  }

  function _parseStatus(raw) {
    var result = MpdParse.parseStatus(raw, _sep)

    var file = result.file
    _title   = result.title
    _artist  = result.artist
    _album   = result.album
    _file    = file
    _playing = result.playing
    _stopped = result.stopped
    _available = result.available

    // Extract art only on track change.
    if (file && file !== _lastArtFile) {
      _lastArtFile = file
      _extractArt(file)
    } else if (!file) {
      _artUrl = ""
      _lastArtFile = ""
    }
  }

  function _resetState() {
    _title = ""
    _artist = ""
    _album = ""
    _artUrl = ""
    _file = ""
    _playing = false
    _stopped = true
    _available = false
    _lastArtFile = ""
  }

  // --- Album art extraction ------------------------------------------------

  Process {
    id: artProc
    property bool _running: false
    command: [
      "sh", "-c",
      "mpc readpicture \"$1\" > \"" + root._artPath + "\" 2>/dev/null"
        + " && echo ok || echo fail",
      "sh" // $0
      // $1 is set dynamically via _extractArt()
    ]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        var result = String(this.text).trim()
        if (result === "ok") {
          // Force the Image to reload by busting its cache with a query param.
          root._artUrl = "file://" + root._artPath + "?t=" + Date.now()
        } else {
          root._artUrl = ""
        }
        artProc._running = false
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) root._artUrl = ""
      artProc._running = false
    }
  }

  function _extractArt(filePath) {
    if (artProc._running) return
    artProc._running = true
    artProc.command = [
      "sh", "-c",
      "mpc readpicture \"$1\" > '" + _artPath + "' 2>/dev/null"
        + " && echo ok || echo fail",
      "sh",
      filePath
    ]
    artProc.running = true
  }

  // --- Playback control (delegated to mpc) ---------------------------------

  function play()  { _mpcCommand(["mpc", "play"]) }
  function pause() { _mpcCommand(["mpc", "pause"]) }
  function togglePlaying() { _mpcCommand(["mpc", "toggle"]) }
  function previous() { _mpcCommand(["mpc", "prev"]) }
  function next()     { _mpcCommand(["mpc", "next"]) }
  function raise()    { /* MPD has no GUI to raise. */ }

  // Fire-and-forget helper for control commands.
  // We reuse a single Process, guarding against overlapping calls.
  Process {
    id: ctrlProc
    running: false
    stdout: StdioCollector {}
  }

  function _mpcCommand(cmd) {
    if (!_mpcFound) return
    ctrlProc.command = cmd
    ctrlProc.running = true
  }
}
