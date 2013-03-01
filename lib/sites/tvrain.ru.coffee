urlLib = require "url"
request = require('request')
$ = require("jquery")
xml = require("node-xml-lite")
qs = require "querystring"
async = require "async"

userAgent = 'Mozilla/5.0 (iPad; CPU OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5376e Safari/8536.25'

module.exports = tvrain = (smartGet, url, done, filename, isPart = no) ->
  url = urlLib.parse url
  console.log "TVRain.ru - looking for video files"
  unless filename?
    url.path += "/" unless url.path[url.path.length-1] is "/"
    a = url.path.split("/")
    [name, id] = a[a.length-2].split("-")
    filename = name

  opts =
    url: url.href
    headers: {'User-Agent': userAgent}

  request opts, (err, res, body) ->
    console.log err if err?
    $body = $(body)
    url = $body.find("div.tv iframe").attr("src") or $body.find('div.tv param[name="flashvars"]').attr("value")

    return console.log "Video is not found" unless url?

    isGettingParts = no

    unless isPart
      $episodes = $body.find('#episodes a')

      if $episodes.length
        console.log "TVRain.ru - found #{$episodes.length} additional parts of the video"
        isGettingParts = yes
        filename += "-1"
        epid = 1

        get = (el, done) ->
          link = "http://tvrain.ru" + $(el).attr("href")
          tvrain smartGet, link, done, "#{name}-#{++epid}", yes

        async.forEach $episodes, get, (err) -> done()

    query = qs.parse urlLib.parse(url).query or url
    apiUrl = "http://pub.tvigle.ru/xml/index.php?prt=#{query.prt}&id=#{query.id}&mode=1"

    opts =
      url: apiUrl
      headers:
        'User-Agent': userAgent
        "Referer": "http://tvrain.ru/"

    request opts, (err, res, body) ->
      console.log err, apiUrl if err?
      body = xml.parseString body

      if body.childs[0].childs?
        url = body.childs[0].childs[0].attrib.mp4

        smartGet.addTask
          url: urlLib.parse url
          filename: "#{filename}.mp4"

        done() unless isGettingParts
      else
        console.log "unknown error"