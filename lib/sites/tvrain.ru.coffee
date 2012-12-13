urlLib = require "url"
request = require('request')
jsdom = require "jsdom"
jquery = require("jquery")
xml = require("node-xml-lite")
qs = require "querystring"
async = require "async"

module.exports = tvrain = (smartGet, url, done, filename, isPart = no) ->
  url = urlLib.parse url
  console.log "TVRain.ru - looking for videos..."
  unless filename?
    url.path += "/" unless url.path[url.path.length-1] is "/"
    a = url.path.split("/")
    [name, id] = a[a.length-2].split("-")
    filename = name

  jsdom.env
    html: url.href
    done: (err, win) ->
      console.log err, url.href if err?
      $ = jquery.create win
      return unless url = $("#player").attr("src")

      isGettingParts = no

      unless isPart
        $episodes = $('#episodes a')

        if $episodes.length
          console.log "TVRain.ru - found parts of the video"
          isGettingParts = yes
          filename += "-1"
          epid = 1

          get = (el, done) ->
            link = "http://tvrain.ru" + $(el).attr("href")
            tvrain smartGet, link, done, "#{name}-#{++epid}", yes

          async.forEach $episodes, get, (err) -> done()

      query = qs.parse urlLib.parse(url).query

      apiUrl = "http://pub.tvigle.ru/xml/index.php?prt=#{query.prt}&id=#{query.id}&mode=1"

      request apiUrl, (err, res, body) ->
        console.log err, apiUrl if err?
        body = xml.parseString body
        url = body.childs[0].childs[0].attrib.mp4

        smartGet.addTask
          url: urlLib.parse url
          filename: "#{filename}.mp4"

        done() unless isGettingParts