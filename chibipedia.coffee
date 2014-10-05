request = require("request")
cheerio = require('cheerio')
fs = require("fs")
async = require("async")
colors = require('colors')

DOWNLOADED = "downloaded" # Hacky custom error
PAGE_NAME = "Hatsune_Miku"
HTML_PATH = "tmp/#{PAGE_NAME}.html"
CSS_PATH = "tmp/#{PAGE_NAME}.css"

sanitizeUrl = (url) ->
  if !url.match(/^http:/)
    "http:#{url}"
  else
    url

downloadFile = (url, outputFile, append, callback) ->
  url = sanitizeUrl(url)
  console.log "Downloading".green, "#{url}", "to".green, outputFile
  request url, (err, response, body) ->
    if !err && response.statusCode == 200
      if append
        fs.appendFile outputFile, body, (err) ->
          callback(err)
      else
        fs.writeFile outputFile, body, (err) ->
          callback(err)
    else
      callback(err)

checkDownloaded = (path, callback) ->
  fs.exists path, (exists) ->
    if exists
      console.log "#{path} exists. Skipping download...".yellow
      callback(DOWNLOADED)
    else
      callback(null)

readFile = (path, callback) ->
  console.log "Reading from".green, path
  fs.readFile path, (err, data) ->
    callback(err, data)

reportErrorUnlessDownloaded = (callback) ->
  (err) ->
    if err == DOWNLOADED
      callback(null)
    else
      callback(err)

checkPageDownloaded = (callback) ->
  checkDownloaded(HTML_PATH, callback)

downloadPageUnlessDownloaded = (callback) ->
  downloadFile(
    "http://en.wikipedia.org/wiki/#{PAGE_NAME}",
    HTML_PATH,
    false,
    callback)

readPage = (callback) ->
  readFile(HTML_PATH, callback)

extractCssFilesFromData = (data, callback) ->
  $ = cheerio.load(data);
  results = $("link[rel='stylesheet']").map ->
    $(@).attr("href")
  .get()
  console.log "Found CSS:\n".green + results.join("\n")
  callback(null, results)

checkCssDownloaded = (callback) ->
  checkDownloaded(CSS_PATH, callback)

downloadCssUnlessDownloaded = (urls, callback) ->
  async.series urls.map (url) ->
    (_callback) ->
      downloadFile(url,
        CSS_PATH,
        true,
        _callback)
  , (err) ->
    callback(err)

readCssFile = (callback) ->
  readFile(CSS_PATH, callback)

downloadPage = (callback) ->
  console.log "Beginning downloadPage...".blue
  async.waterfall [checkPageDownloaded, downloadPageUnlessDownloaded],
  reportErrorUnlessDownloaded(callback)

downloadCssFiles = (callback) ->
  console.log "Beginning downloadCssFiles...".blue
  async.waterfall [
    checkCssDownloaded,
    readPage,
    extractCssFilesFromData,
    downloadCssUnlessDownloaded,
    readCssFile],
  (err) ->
    reportErrorUnlessDownloaded(err, callback)

async.series [
  downloadPage,
  downloadCssFiles
]
