# libraries
fs = require('fs')
http = require('http')
webSocketServer = require('websocket').server

# internal
COLORS = require("./colors.js")
UTIL = require("./util.js")
Client = require("./client.js").Class
HttpRequest = require("./http_request.js").Class

exports.Class = class SyncTubeServer
  constructor: (@opts = {}) ->
    @root = process.env.ST_ROOT || process.cwd()
    @loadConfig()
    @banned = {}
    @clients = []
    @channels = {}
    @pendingRestart = null

    # set process title
    process.title = "synctube-server"

  loadConfig: () ->
    unless fs.existsSync("#{@root}/config.js")
      fs.copyFileSync("#{@root}/config.example.js", "#{@root}/config.js")
      @warn "No config file found! Copied config.example.js to config.js"

    @opts = require("#{@root}/config.js")

    unless @opts.systemPassword
      @opts.systemPassword = require("crypto").randomBytes(10).toString("hex")
      @warn "==========================================="
      @warn "== No system password defined in config, =="
      @warn "== a random password will be generated!  =="
      @warn "== This will happen every boot, to avoid =="
      @warn "== this set a password in your config.js =="
      @warn "== SystemPassword: #{@opts.systemPassword}  =="
      @warn "==========================================="

  listen: ->
    throw "HTTP server is already bound!" if @http
    @info "Creating HTTP server..."
    @http = http.createServer((a...) => @handleHTTPRequest(a...))

    @debug "Binding HTTP/WS server on port #{@opts.port}..."
    @http.listen @opts.port, @opts.host
    @http.on "listening", => @info "HTTP/WS server is listening on IPv#{@http._connectionKey}"

    # create WS socket server
    @ws = new webSocketServer httpServer: @http
    @ws.on "request", (request) => @handleWSRequest(request)

  eachClient: (method, args...) -> c?[method]?(args...) for c in @clients

  nullSession: (client, forceReindex) ->
    @clients[client.index] = null
    @cleanupSessions(forceReindex)

  cleanupSessions: (force = false) ->
    unless force
      nulled = 0
      nulled += 1 for c in @clients when c is  null
      if nulled >= @opts.sessionReindex
        @debug "reindexing sessions (#{nulled} nulled sessions)"
      else
        return

    newClients = []
    newClients.push(c) for c in @clients when c isnt null
    @clients = newClients
    @eachClient("reindex")

  handlePendingRestart: (force = false, client) ->
    unless @pendingRestart?
      clearTimeout(@pendingRestartTimeout)
      return
    msg = @pendingRestartReason
    diff = (@pendingRestart - (new Date).getTime()) / 1000
    fdiff = UTIL.secondsToTimestamp(diff, false)

    if diff <= 0
      if client
        client.sendSystemMessage "Server will restart NOW#{if msg then " (#{msg})" else ""}"
      else
        @eachClient "sendSystemMessage", "Server will restart NOW#{if msg then " (#{msg})" else ""}"
      throw "bye"
    else
      if force \
      || parseInt(diff % 15*60) == 0 \
      || parseInt(diff % 5*60) == 0 \
      || parseInt(diff % 60) == 0 \
      || parseInt(diff) == 60 \
      || parseInt(diff) == 30 \
      || parseInt(diff) == 15 \
      || parseInt(diff) <= 5
        if client
          client.sendSystemMessage "Server will restart in #{fdiff}#{if msg then " (#{msg})" else ""}"
        else
          @eachClient "sendSystemMessage", "Server will restart in #{fdiff}#{if msg then " (#{msg})" else ""}"
      return if client
      @pendingRestartTimeout = UTIL.delay 1000, => @handlePendingRestart()

  handleHTTPRequest: (request, response) ->
    req = new HttpRequest(this)
    if @opts.answerHttp
      req.accept(request, response)
    else
      req.reject(request, response)

  handleWSRequest: (request) ->
    client = new Client(this)
    client.accept(request).listen()

  banIp: (ip, duration, reason) ->
    end = if duration == -1 then null else new Date((new Date).getTime() + duration * 1000)
    @banned[ip] = end
    @guardBanned(client, reason) for client in @clients when client?

  guardBanned: (client, reason) ->
    return false if !client
    return false unless @banned.hasOwnProperty(client.ip)
    match = @banned[client.ip]

    # check expired
    if match && (new Date) > match
      @debug "Purge expired ban for #{client.ip} which expired #{match}"
      delete @banned[client.ip]
      return false

    client.info "closing connection for #{client.ip}, banned until #{match}"
    client.sendCode("banned", banned_until: match, reason: reason)
    client.sendSystemMessage "You got banned from the server #{if match then "until #{match}" else "permanently"}!"
    client.sendSystemMessage "Reason: #{reason}" if reason
    client.connection.close()
    return true

  # ===========
  # = Logging =
  # ===========
  debug: (msg...) ->
    return unless @opts.debug
    msg.unshift new Date
    msg.unshift "[ST-DEBUG]"
    console.debug.apply(@, msg)

  info: (msg...) ->
    msg.unshift new Date
    msg.unshift "[ST-INFO] "
    console.log.apply(@, msg)

  warn: (msg...) ->
    msg.unshift new Date
    msg.unshift "[ST-WARN] "
    console.warn.apply(@, msg)

  error: (msg...) ->
    msg.unshift new Date
    msg.unshift "[ST-ERROR]"
    console.error.apply(@, msg)
