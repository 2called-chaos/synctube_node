window.SyncTubeClient = class SyncTubeClient
  VIEW_COMPONENTS: ["content", "view", "input", "input_nofocus", "status", "queue", "playlist", "clients"]
  included: []

  @include: (obj, into) ->
    @::[key] = value for key, value of obj when key not in ["included", "start", "init"]
    obj.included?.call(@, into)

  include: (addon) ->
    @included.push(addon)
    @constructor.include(addon, @)

  constructor: (@opts = {}) ->
    # options
    @opts.debug ?= false
    window.client = this if @opts.debug

    # synced settings (controlled by server)
    @opts.synced ?= {}
    @opts.synced.maxDrift ?= 60000 # superseded by server instructions
    @opts.synced.packetInterval ?= 10000 # superseded by server instructions

    # Client data
    @index = null
    @name = null
    @control = false
    @drift = 0

    # modules
    @include SyncTubeClient_Util
    @include SyncTubeClient_ControlCodes
    @include SyncTubeClient_Network
    @include SyncTubeClient_UI
    @include SyncTubeClient_Player_Youtube
    @include SyncTubeClient_Player_HtmlFrame
    @include SyncTubeClient_Player_HtmlImage
    @include SyncTubeClient_Player_HtmlVideo
    @include SyncTubeClient_History

    inc.init?.apply(this) for inc in @included

  start: ->
    inc.start?.apply(this) for inc in @included
    @listen()

  # ===========
  # = Logging =
  # ===========
  debug: (msg...) ->
    return unless @opts.debug
    msg.unshift "[ST #{(new Date).toISOString()}]"
    console.debug.apply(@, msg)

  info: (msg...) ->
    msg.unshift "[ST #{(new Date).toISOString()}]"
    console.log.apply(@, msg)

  warn: (msg...) ->
    msg.unshift "[ST #{(new Date).toISOString()}]"
    console.warn.apply(@, msg)

  error: (msg...) ->
    msg.unshift "[ST #{(new Date).toISOString()}]"
    console.error.apply(@, msg)
