COLORS = require("../colors.js")
UTIL = require("./util.js")

exports.Class = class SyncTubeServerClient
  debug: (a...) -> @server.debug("[##{@index}]", a...)
  warn: (a...) -> @server.warn("[##{@index}]", a...)
  error: (a...) -> @server.error("[##{@index}]", a...)

  constructor: (@server) ->
    @index = -1
    @name ?= null
    @control = null
    @subscribed = null

  accept: (@request) ->
    @debug "Accepting connection from origin #{@request.origin}"
    @connection = @request.accept(null, @request.origin)
    @ip = @connection.remoteAddress
    @index = @server.clients.push(this) - 1
    @connection.on("close", => @disconnect())
    @debug "Connection accepted (#{@index}): #{@ip}"
    @sendCode "session_index", index: @index
    @sendCode "server_settings", packetInterval: @server.opts.packetInterval, maxDrift: @server.opts.maxDrift
    @sendCode "require_username"
    return this

  listen: ->
    @connection.on "message", (message) =>
      msg = message.utf8Data
      if message.type != "utf8"
        @warn "Received non-utf8 data", message
        return

      @debug "Received message from #{@ip}: #{msg}"

      if @name
        @server.handleMessage(this, message, msg) || @control?.handleMessage(this, message, msg, true) || @subscribed?.handleMessage(this, message, msg)
      else
        @setUsername(msg)

    this

  disconnect: ->
    @debug "Peer #{@ip} disconnected."
    @control?.revokeControl?(this)
    @subscribed?.unsubscribe?(this)
    @server.nullSession(this)

  reindex: ->
    was_index = @index
    @index = @server.clients.indexOf(this)
    @sendCode "session_index", index: @index
    @subscribed? && @sendCode("subscriber_list", channel: @subscribed.name, subscribers: @subscribed.getSubscriberList(this))
    @debug "Reindexed client session from #{was_index} to #{@index}"
    return this

  sendCode: (type, data = {}) ->
    @connection.sendUTF JSON.stringify type: "code", data: Object.assign({}, data, { type: type })
    return this

  sendMessage: (message, color, author, author_color) ->
    @connection.sendUTF JSON.stringify
      type: "message"
      data:
        author: author
        author_color: author_color
        text: message
        text_color: color
        time: (new Date()).getTime()
    return this

  sendSystemMessage: (message, color) -> @sendMessage(message, color || COLORS.red, "system", COLORS.red)

  ack: ->
    @sendCode "ack"
    true

  setUsername: (name) ->
    @name = UTIL.htmlEntities(name)
    if @server.PROTECTED_NAMES.indexOf(@name.toLowerCase()) > -1
      @name = null
      @sendSystemMessage "This name is not allowed!", COLORS.red
      #@sendCode "require_username", autofill: false
      return @ack()
    else if UTIL.startsWith(@name, "!packet:")
      # ignore packets
      @name = null
      return @ack()
    else if @name.charAt(0) == "/" || @name.charAt(0) == "!"
      @name = null
      @sendSystemMessage "Name may not start with a / or ! character", COLORS.red
      #@sendCode "require_username", autofill: false
      return @ack()
    else
      if @old_name
        if @subscribed
          _name = @name
          @name = @old_name
          @subscribed.broadcast(this, "<i>changed his name to #{_name}</i>", COLORS.info, COLORS.muted)
          @name = _name
          @subscribed.broadcastCode(this, "update_single_subscriber", channel: @subscribed.name, data: @subscribed.getSubscriberData(this, this, @index))
        else
          @sendSystemMessage "You changed your name from #{@old_name} to #{@name}!", COLORS.info
        @old_name = null
      else
        @hello()

    @sendCode "username", username: @name
    @ack()

  hello: ->
    @sendSystemMessage "Welcome, #{@name}!", COLORS.green
    @sendSystemMessage "To create or control a channel type <strong>/control &lt;channel&gt; [password]</strong>", COLORS.info
    @sendSystemMessage "To join an existing channel type <strong>/join &lt;channel&gt;</strong>", COLORS.info
