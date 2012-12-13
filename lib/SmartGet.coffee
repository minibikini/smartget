Array::last = (n = 1) -> if n is 1 then @[@length-1] else @slice -n

fs = require 'fs'
http = require "http"
urlLib = require "url"
ProgressBar = require 'progress'
EventEmitter = require('events').EventEmitter
async = require "async"

plugins = ["soundcloud.com", "tvrain.ru"]

module.exports = class SmartGet extends EventEmitter
  isWorking: yes
  tasks: []
  constructor: (urls) ->
    @on "ready", @get

    add = (url, done) =>
      for site in plugins when url.indexOf(site) > 0
        return require("./sites/#{site}")(@, url, done)
      @addTask url
      done()

    async.forEach urls, add, (err) =>
      @emit "ready" unless err?
      console.log err if err?


  addTask: (task) ->
    if typeof task is "string"
      url = urlLib.parse task
      filename = url.path.split("/").last()
      task =
        url: url
        filename: filename

    task.filename = "index.html" if task.filename is ""

    @tasks.push task

  exit: ->
    console.log "All jobs are done."
    console.log "Bye!"
    # process.exit()

  get: (task = null) ->
    unless task?
      return @exit() unless @tasks.length
      task = @tasks.shift()

    options =
      hostname: task.url.hostname
      port: task.url.port
      path: task.url.path

    task.hasBytes = if fs.existsSync task.filename
      fs.statSync(task.filename).size
    else 0

    console.log "\n => Getting #{task.filename}"
    if task.hasBytes
      options.headers = "Range": "bytes=#{task.hasBytes}-"
      console.log "    Resuming previous download."

    http.get(options, @onServerResponse(task)).on 'error', (e) =>
      task.error ?= 0
      @get task if ++task.error < 100
      console.log 'problem with request: ' + e.message

  onServerResponse: (task) -> (res) =>
    dl = (code) =>
      opts = flags: "w"
      if res.statusCode is 206
        opts.flags = "r+"
        opts.start = task.hasBytes
      file= fs.createWriteStream task.filename, opts
      res.pipe fs.createWriteStream task.filename, opts

      len = parseInt(res.headers['content-length'], 10)
      console.log "size: #{(len/1024/1024).toFixed(2)} Mb"
      bar = new ProgressBar '  downloading [:bar] :percent :eta'
        complete: '='
        incomplete: ' '
        width: 100
        total: len
      res.on 'data', (chunk) ->
        bar.tick chunk.length

      res.on 'end', (chunk) =>
        console.log "\nSaved to #{task.filename}\n"

        done = => @emit "ready"

        if task.onDone?
          task.onDone done
        else done()


    switch res.statusCode
      when 200, 206 then dl()
      when 416
        console.log "The file is already downloaded."
        @emit "ready"
      when 302
        task.url = urlLib.parse res.headers.location
        console.log "Redirect ro #{task.url.href}"
        @get task
      else console.log "code", res.statusCode, res.headers