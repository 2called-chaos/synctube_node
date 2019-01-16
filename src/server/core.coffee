# requires
http = require('http');
webSocketServer = require('websocket').server;

# colors
COLORS = require("./colors.js")
UTIL = require("./util.js")
Channel = require("./channel.js").Class
Client = require("./client.js").Class
HttpRequest = require("./http_request.js").Class

exports.Class = class SyncTubeServer
  # Clients can't use these names
  PROTECTED_NAMES: [
    "admin"
    "system"
  ]

  # Default video to cue in new channels
  DEFAULT_CTYPE: "Youtube" # youtube, frame, image, video (mp4/webp)
  DEFAULT_URL: "6Dh-RL__uN4" # id suffices when YouTube
  DEFAULT_AUTOPLAY: false # only when youtube or video

  constructor: (@opts = {}) ->
    # set process title
    process.title = 'synctube-server';

    # options
    @opts.debug          ?= false
    @opts.port           ?= 1337 # Don't forget to change in client as well
    @opts.packetInterval ?= 2000 # (CL) interval in ms for CLIENTS to send packet updates to the server
    @opts.maxDrift       ?= 5000 # (CL) max ms (1000ms = 1s) for CLIENTS before force seeking to correct drift to host
    @opts.answerHttp     ?= true # If set to false no static assets will be served, all requests result in a 400: Bad request
    @opts.sessionReindex ?= 250  # amount of nulled sessions before a reindexing occurs

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

  eachClient: (method, args...) -> c[method]?(args...) for c in @clients

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

  handleHTTPRequest: (request, response) ->
    req = new HttpRequest(this)
    if @opts.answerHttp
      req.accept(request, response)
    else
      req.reject(request, response)

  handleWSRequest: (request) ->
    client = new Client(this)
    client.accept(request).listen()

  # ===========
  # = Logging =
  # ===========
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

  # ===================
  # = Server commands =
  # ===================
  handleMessage: (client, message, msg) ->
    return @SCMD_packet(client, m[1]) if m = msg.match(/^!packet:(.+)$/i)
    return @SCMD_join(client, m[1]) if m = msg.match(/^\/join\s([^\s]+)$/i)
    return @SCMD_control(client, m[1], m[2]) if m = msg.match(/^\/control(?:\s([^\s]+)(?:\s(.+))?)?$/i)
    return @SCMD_rename(client) if msg.match(/^\/rename$/i)
    return @SCMD_restart(client) if msg.match(/^\/restart$/i)
    return @SCMD_invoke(client, m[1], m[2]) if m = msg.match(/^\/invoke\s([^\s]+)(?:\s(.+))?$/i)
    return @SCMD_dump(client, m[1], m[2]) if m = msg.match(/^\/dump\s([^\s]+)(?:\s(.+))?$/i)
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
      json.timestamp = UTIL.videoTimestamp(json.seek, json.playtime) if json.seek? && json.playtime?

      client.state = json
      ch.broadcastCode(client, "update_single_subscriber", channel: ch.name, data: ch.getSubscriberData(client, client, client.index))
      if client == ch.control[ch.host] && ch.desired.url == json.url
        seek_was = ch.desired.seek
        ch.desired.seek = json.seek
        ch.desired.seek_update = new Date()
        ch.broadcastCode(false, "desired", Object.assign({}, ch.desired, { force: Math.abs(ch.desired.seek - seek_was) > (@opts.packetInterval + 0.75) }))
    else
      client.sendCode("desired", ch.desired) if ch
    return true

  SCMD_join: (client, chname) ->
    if channel = @channels[chname]
      channel.subscribe(client)
    else
      client.sendSystemMessage("I don't know about this channel, sorry!")
      client.sendSystemMessage("<small>You can create it with <strong>/control #{UTIL.htmlEntities(chname)} [password]</strong></small>", COLORS.info)

    return client.ack()

  SCMD_control: (client, name, password) ->
    chname = UTIL.htmlEntities(name || client.subscribed?.name || "")
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

  SCMD_rename: (client) ->
    client.sendCode "require_username", autofill: false
    client.old_name = client.name
    client.name = null
    client.sendSystemMessage "Tell me your new username!"
    return client.ack()

  SCMD_restart: (client) ->
    client.sendSystemMessage "See ya!"
    throw "bye"
    #UTIL.delay 1000, => client.sendCode "navigate", reload: true
    return true

  SCMD_invoke: (client, which, args) ->
    args ||= "{}"
    client.sendCode(which, JSON.parse(args))
    return client.ack()

  SCMD_dump: (client, what, detail) ->
    if what == "client"
      console.log if detail then @clients[parseInt(detail)] else client
    else if what == "channel"
      console.log if detail then @channels[detail] else if client.subscribed then client.subscribed else @channels

    return client.ack()
