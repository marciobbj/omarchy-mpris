import QtQuick
import QtTest
import "../MpdParse.js" as MpdParse

TestCase {
  id: testCase
  name: "MpdParse"
  when: windowShown
  visible: true

  readonly property string sep: "\x1f"

  // --- parseStatus tests ----------------------------------------------------

  function test_emptyOutput() {
    var r = MpdParse.parseStatus("", sep)
    compare(r.title, "")
    compare(r.artist, "")
    compare(r.album, "")
    compare(r.file, "")
    compare(r.playing, false)
    compare(r.stopped, true)
    compare(r.available, false)
  }

  function test_playingTrack() {
    var meta = sep + "Pink Floyd" + sep + "Comfortably Numb" + sep + "The Wall"
      + sep + "music/pink_floyd/wall/comfortably_numb.flac"
    var status = "[playing] #3/12   6:23/6:53 (92%)"
    var r = MpdParse.parseStatus(meta + "\n" + status, sep)

    compare(r.artist, "Pink Floyd")
    compare(r.title, "Comfortably Numb")
    compare(r.album, "The Wall")
    compare(r.file, "music/pink_floyd/wall/comfortably_numb.flac")
    compare(r.playing, true)
    compare(r.stopped, false)
    compare(r.available, true)
  }

  function test_pausedTrack() {
    var meta = sep + "Artist" + sep + "Title" + sep + "Album" + sep + "file.mp3"
    var status = "[paused]  #1/5   1:30/4:00 (37%)"
    var r = MpdParse.parseStatus(meta + "\n" + status, sep)

    compare(r.artist, "Artist")
    compare(r.title, "Title")
    compare(r.playing, false)
    compare(r.stopped, false)
    compare(r.available, true)
  }

  function test_stoppedState() {
    // When stopped, mpc current still shows the queued track but the status
    // line has no [playing]/[paused] marker.
    var meta = sep + "Artist" + sep + "Title" + sep + "Album" + sep + "file.mp3"
    var status = "volume: 80   repeat: off   random: off   single: off   consume: off"
    var r = MpdParse.parseStatus(meta + "\n" + status, sep)

    compare(r.title, "Title")
    compare(r.playing, false)
    compare(r.stopped, true)
    // Stopped tracks are not considered available.
    compare(r.available, false)
  }

  function test_missingMetadataFields() {
    // Title present but artist/album empty.
    var meta = sep + "" + sep + "Unknown Track" + sep + "" + sep + "some/file.ogg"
    var status = "[playing] #1/1   0:10/3:00 (5%)"
    var r = MpdParse.parseStatus(meta + "\n" + status, sep)

    compare(r.artist, "")
    compare(r.title, "Unknown Track")
    compare(r.album, "")
    compare(r.playing, true)
    compare(r.available, true)
  }

  function test_resetAfterEmpty() {
    // First parse a playing track.
    var meta = sep + "A" + sep + "B" + sep + "C" + sep + "f.mp3"
    var status = "[playing] #1/1   0:01/3:00 (0%)"
    var r = MpdParse.parseStatus(meta + "\n" + status, sep)
    compare(r.available, true)

    // MPD returns nothing when the queue is cleared.
    var r2 = MpdParse.parseStatus("", sep)
    compare(r2.title, "")
    compare(r2.artist, "")
    compare(r2.playing, false)
    compare(r2.available, false)
  }

  function test_fileOnlyNoTitleOrArtist() {
    // Some files have no metadata tags, only a file path.
    var meta = sep + "" + sep + "" + sep + "" + sep + "radio/stream.m3u"
    var status = "[playing] #1/1   0:05/0:00 (0%)"
    var r = MpdParse.parseStatus(meta + "\n" + status, sep)

    compare(r.artist, "")
    compare(r.title, "")
    compare(r.file, "radio/stream.m3u")
    compare(r.playing, true)
    // Available because file is non-empty and not stopped.
    compare(r.available, true)
  }

  function test_noStatusLine() {
    // Only the metadata line, no status line at all.
    var meta = sep + "A" + sep + "B" + sep + "C" + sep + "f.mp3"
    var r = MpdParse.parseStatus(meta, sep)

    compare(r.title, "B")
    compare(r.playing, false)
    compare(r.stopped, true)
    compare(r.available, false)
  }

  function test_whitespaceOnlyOutput() {
    var r = MpdParse.parseStatus("   \n  \n  ", sep)
    compare(r.available, false)
    compare(r.stopped, true)
  }

  function test_specialCharactersInMetadata() {
    // Artist and title containing quotes, dashes, and unicode.
    var meta = sep + "Sigur Rós" + sep + "Hoppípolla" + sep + "Takk..." + sep + "sigur_ros/hoppipolla.flac"
    var status = "[playing] #5/11   0:30/4:28 (11%)"
    var r = MpdParse.parseStatus(meta + "\n" + status, sep)

    compare(r.artist, "Sigur Rós")
    compare(r.title, "Hoppípolla")
    compare(r.album, "Takk...")
    compare(r.playing, true)
  }
}
