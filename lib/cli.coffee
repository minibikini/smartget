process.title = 'SmartGet'

cli = require 'commander'
SmartGet = require "./SmartGet"

cli.option '-a, --all', "download all tracks from given url"

cli.parse process.argv

new SmartGet cli.args