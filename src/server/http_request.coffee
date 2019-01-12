fs = require('fs');

exports.Class = class HttpRequest
  # only files listed here will be served!
  # you probably want nginx or something to handle this!
  SERVE_STATIC: [
    "/"
    "/index.html"
    "/favicon.ico"
    "/dist/client.js"
  ]

  debug: (a...) -> @server.debug("[HTTP]", a...)
  warn: (a...) -> @server.warn("[HTTP]", a...)
  error: (a...) -> @server.error("[HTTP]", a...)

  constructor: (@server) ->

  accept: (@request, @response) ->
    @ip = @request.connection.remoteAddress
    if @SERVE_STATIC.indexOf(@request.url) > -1
      file = "." + if @request.url == "/" then "/index.html" else @request.url
      @renderSuccess(file)
    else
      @renderBadRequest()

  reject: (@request, @response) -> @renderBadRequest()

  getMimeFromExtension: (file) ->
    if file.slice(-3) == ".js"
      type = "application/javascript"
    else if file.slice(-5) == ".html"
      "text/html"
    else if file.slice(-4) == ".jpg" || file.slice(-5) == ".jpeg"
      "image/jpeg"
    else if file.slice(-4) == ".gif"
      "image/gif"
    else if file.slice(-4) == ".png"
      "image/png"
    else
      "text/plain"

  renderSuccess: (file, headers = {}) ->
    return @renderNotFound() unless fs.existsSync(file)
    type = @getMimeFromExtension(file)
    @debug "200: served #{file} (#{type}) IP: #{@ip}"
    @response.writeHead(200, "Content-Type": type)
    @response.end(fs.readFileSync(file))

  renderBadRequest: ->
    @warn "400: Bad Request (#{@request.url}) IP: #{@ip}"
    @response.writeHead(400, "Content-Type": "text/plain")
    @response.end("Error 400: Bad Request")

  renderNotFound: ->
    @warn "404: Not Found (#{@request.url}) IP: #{@ip}"
    @response.writeHead(404, "Content-Type": "text/plain")
    @response.end("Error 404: Not Found")
