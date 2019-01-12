# requires
http = require('http');
fs = require('fs');
webSocketServer = require('websocket').server;
{spawn} = require( 'child_process' )

# colors
COLORS = require("../colors.js")
Channel = require("./channel.js").Class
Client = require("./client.js").Class

exports.Class = class SyncTubeServer
  SERVE_STATIC: [
    "/"
    "/favicon.ico"
    "/dist/client.js"
  ]

  PROTECTED_NAMES: [
    "admin"
    "system"
  ]

  DEFAULT_VIDEO: "6Dh-RL__uN4"
  DEFAULT_AUTOPLAY: false

  debug: (msg...) ->
    return unless @opts.debug
    msg.unshift new Date
    msg.unshift "[ST]"
    console.debug.apply(@, msg)

  warn: (msg...) ->
    msg.unshift new Date
    msg.unshift "[ST]"
    console.warn.apply(@, msg)

  error: (msg...) ->
    msg.unshift new Date
    msg.unshift "[ST]"
    console.error.apply(@, msg)

  constructor: (@opts = {}) ->
    # set process title
    process.title = 'synctube-server';

    # options
    @opts.debug          ?= false
    @opts.port           ?= 1337 # Don't forget to change in client as well
    @opts.packetInterval ?= 2000 # (CL) interval in ms for CLIENTS to send packet updates to the server
    @opts.maxDrift       ?= 5000 # (CL) max ms (1000ms = 1s) for CLIENTS before force seeking to correct drift to host

    @clients = []
    @channels = {}

  listen: ->
    throw "HTTP server is already bound!" if @http
    @debug "Creating HTTP server..."
    @http = http.createServer((a...) => @handleHTTPRequest(a...))

    @debug "Binding HTTP/WS server on port #{@opts.port}..."
    @http.listen @opts.port, => @debug "HTTP/WS server is listening on port #{@opts.port}!"

    # create WS socket server
    @ws = new webSocketServer httpServer: @http
    @ws.on "request", (request) => @handleWSRequest(request)

  htmlEntities: (str) ->
    String(str)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;')

  delay: (ms, func) -> setTimeout(func, ms)

  eachClient: (method, args...) -> c[method]?(args...) for c in @clients

  handleHTTPRequest: (request, response) ->
    if @SERVE_STATIC.indexOf(request.url) > -1
      file = request.url
      file = "/index.html" if file == "/"
      file = ".#{file}"
      type = "text/html"
      type = "application/javascript" if file.slice(-3) == ".js"
      if fs.existsSync(file)
        @debug "200: served #{file} (#{type}) IP: #{request.connection.remoteAddress}"
        response.writeHead(200, 'Content-Type': 'text/html')
        response.end(fs.readFileSync(file))
      else
        @warn "404: Not Found (#{request.url}) IP: #{request.connection.remoteAddress}"
        response.writeHead(404, 'Content-Type': 'text/plain')
        response.end("Error 404: Not Found")
    else
      @warn "400: Bad Request (#{request.url}) IP: #{request.connection.remoteAddress}"
      response.writeHead(400, 'Content-Type': 'text/plain')
      response.end("Error 400: Bad Request")

  handleWSRequest: (request) ->
    client = new Client(this)
    client.accept(request).listen()

  handleMessage: (client, message, msg) ->
    return @SCMD_packet(client, m[1]) if m = msg.match(/^!packet:(.+)$/i)
    return @SCMD_invoke(client, m[1], m[2]) if m = msg.match(/^\/invoke\s([^\s]+)(?:\s(.+))?$/i)
    return @SCMD_rename(client) if msg.match(/^\/rename$/i)
    return @SCMD_restart(client) if m = msg.match(/^\/restart$/i)
    return @SCMD_retry(client) if m = msg.match(/^\/retry$/i)
    return @SCMD_control(client, m[1], m[2]) if m = msg.match(/^\/control(?:\s([^\s]+)(?:\s(.+))?)?$/i)
    return @SCMD_join(client, m[1]) if m = msg.match(/^\/join\s([^\s]+)$/i)
    return @SCMD_leave(client) if m = msg.match(/^\/leave$/i)
    return false

  SCMD_packet: (client, jdata) ->
    try
      json = JSON.parse(jdata)
    catch error
      @error "Invalid JSON", jdata, error
      return

    client.lastPacket = new Date
    ch = client.subscribed
    if ch && (!client.state || (JSON.stringify(client.state) != jdata))
      json.time = new Date
      client.state = json
      ch.broadcastCode(client, "update_single_subscriber", channel: ch.name, data: ch.getSubscriberData(client, client, client.index))
      if client == ch.control[ch.host] && ch.desired.url == json.url
        seek_was = ch.desired.seek
        ch.desired.seek = json.seek
        ch.desired.seek_update = new Date()
        ch.broadcastCode(false, "desired", Object.assign({}, ch.desired, { force: Math.abs(ch.desired.seek - seek_was) > 2.75 }))
    else
      client.sendCode("desired", ch.desired) if ch
    return true

  SCMD_invoke: (client, which, args) ->
    args ||= "{}"
    client.sendCode(which, JSON.parse(args))
    client.ack()
    return true

  SCMD_rename: (client) ->
    client.sendCode "require_username", autofill: false
    client.old_name = client.name
    client.name = null
    client.sendSystemMessage "Tell me your new username!"
    client.ack()
    return true

  SCMD_restart: (client) ->
    client.sendSystemMessage   "See ya!"
    throw "bye"
    #@delay 1000, => client.sendCode "navigate", reload: true
    return true

  SCMD_retry: (client) ->
    return unless ch = client.subscribed
    ch.revokeControl(client)
    ch.unsubscribe(client)
    ch.subscribe(client)
    return client.ack()

  SCMD_control: (client, name, password) ->
    chname = @htmlEntities(name || client.subscribed?.name || "")
    unless chname
      client.sendSystemMessage("Channel name required", COLORS.red)
      return client.ack()

    if channel = @channels[chname]
      if channel.control.indexOf(client) > -1 && password == "delete"
        channel.destroy(client)
        return client.ack()
      else
        if channel.password == password
          channel.subscribe(client)
          channel.grantControl(client)
        else
          client.sendSystemMessage("Password incorrect", COLORS.red)
    else
      @channels[chname] = new Channel(this, chname, password)
      client.sendSystemMessage("Channel created!", COLORS.green)
      @channels[chname].subscribe(client)
      @channels[chname].grantControl(client)

    return client.ack()

  SCMD_join: (client, chname) ->
    if channel = @channels[chname]
      channel.subscribe(client)
    else
      client.sendSystemMessage("I don't know about this channel, sorry!")
      client.sendSystemMessage("<small>You can create it with <strong>/control #{@htmlEntities(chname)} [password]</strong></small>", COLORS.info)

    return client.ack()

  SCMD_leave: (client) ->
    if ch = client.subscribed
      ch.unsubscribe(client)
      client.sendCode("video_action", action: "destroy")
    else
      client.sendSystemMessage("You are not in any channel!")

    return client.ack()
