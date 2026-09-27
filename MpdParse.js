// Parse the combined output of `mpc current -f <format>` and `mpc status`.
// Returns an object with artist, title, album, file, playing, stopped,
// and available fields.
function parseStatus(raw, sep) {
  var text = String(raw || "").trim()
  if (!text) {
    return {
      artist: "", title: "", album: "", file: "",
      playing: false, stopped: true, available: false
    }
  }

  var lines = text.split("\n")

  // First line: <sep>artist<sep>title<sep>album<sep>file
  var meta = (lines[0] || "").split(sep)

  // The line starts with sep, so meta[0] is always empty.
  var artist = meta.length > 1 ? meta[1] : ""
  var title  = meta.length > 2 ? meta[2] : ""
  var album  = meta.length > 3 ? meta[3] : ""
  var file   = meta.length > 4 ? meta[4] : ""

  // Second line from `mpc status`: e.g. "[playing] #1/12   0:42/3:45 (18%)"
  var statusLine = lines.length > 1 ? lines[1] : ""
  var playing = statusLine.indexOf("[playing]") !== -1
  var paused  = statusLine.indexOf("[paused]")  !== -1
  var stopped = !playing && !paused

  return {
    artist: artist,
    title: title,
    album: album,
    file: file,
    playing: playing,
    stopped: stopped,
    available: !!(title || artist || file) && !stopped
  }
}
