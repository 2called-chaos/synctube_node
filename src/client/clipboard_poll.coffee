window.SyncTubeClient_ClipboardPoll = class SyncTubeClient_ClipboardPoll
  constructor: (@client, @opts = {}) ->
    @opts.pollrate ?= 1000
    @opts.autostartIfGranted ?= true
    @running = false
    @lastValue = null
    @detectAutostart()

  detectAutostart: ->
    navigator.permissions.query(name: 'clipboard-read').then (status) =>
      @start() if @opts.autostartIfGranted && status.state == "granted"
      status.onchange = =>
        if status.state == "granted"
          @start()
        else
          @stop()

  start: ->
    @run = true
    @client.debug "Started clipboard polling"
    @tick()

  stop: (wait = true) ->
    @run = false
    @client.debug "Stopping clipboard polling..."
    promise = new Promise (resolve, reject) => @stopped = resolve
    @stopped() unless @running
    if wait
      await promise
      @client.debug "Stopped clipboard polling"
    promise

  tick: ->
    if !@run
      @running = false
      @stopped?()
      return

    @running = true

    try
      text = await navigator.clipboard.readText()
      if text != @lastValue
        @process(text)
        @lastValue = text
    catch err
      # nothing we can do about it :D
    finally
      setTimeout((=> @tick()), @opts.pollrate)

  process: (val) ->
    @client.debug "Processing", val

window.SyncTubeClient_ClipboardPoll.start = ->
  @clipboardPoll = new SyncTubeClient_ClipboardPoll(this, @opts.clipboardPoll)

