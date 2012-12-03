urlLib = require "url"
request = require('request')
spawn = require("child_process").spawn

module.exports = (smartGet, url, done) ->
  console.log "SoundCloud: looking for tracks..."

  request url, (err, res, body)->
    lines = body.split '\n'
    tracks = []
    # TODO: rewrite with regexp
    for line in lines when line[0..26] is 'window.SC.bufferTracks.push'
      tracks.push JSON.parse line[28..-3]

    tracks.forEach (track) ->
      # if cli.all or track.uri is path
        fileName = "#{track.user.permalink}-#{track.name}.mp3"
        console.log "SoundCloud - found track:  #{track.user.username} - #{track.title}"
        smartGet.addTask
          url: urlLib.parse track.streamUrl
          filename: fileName
          onDone: (done)->
            id3tool = spawn 'id3tool', ['-t', track.title, '-r', track.user.username, __dirname+'/'+fileName]
            done()

    done()