window.SyncTubeClient_History = class SyncTubeClient_History
  constructor: (@client, @opts = {}) ->
    @opts.limit ?= 100
    @opts.save ?= true # @todo set to false

    @log = if @opts.save then @loadLog() else []
    @index = -1
    @buffer = null
    @captureInput()

  captureInput: ->
    @client.input.keydown (event) =>
      if event.keyCode == 27 # ESC
        if @index != -1
          @index = -1
          @client.input.val(@buffer) if @buffer?
          @buffer = null
        return true

      if event.keyCode == 38 # ArrowUp
        return false unless @log[@index + 1]?
        @buffer = @client.input.val() if @index == -1
        @index++
        @client.input.val(@log[@index])
        return false

      if event.keyCode == 40 # ArrowDown
        if @index == 0
          @index = -1
          @restoreBuffer()
          return false

        return false unless @log[@index - 1]?
        @index--
        @client.input.val(@log[@index])
        return false

      return true

  restoreBuffer: ->
    @client.input.val(@buffer) if @buffer?
    @buffer = null

  append: (cmd) ->
    @log.unshift(cmd) if cmd && (@log.length && @log[0] != cmd)
    @log.pop() while @log.length > @opts.limit
    @saveLog() if @opts.save
    @index = -1
    @buffer = null

  saveLog: -> localStorage.setItem("synctube_client_history", JSON.stringify(@log))
  loadLog: -> try JSON.parse(localStorage.getItem("synctube_client_history")) || [] catch e then []

window.SyncTubeClient_History.start = ->
  @history = new SyncTubeClient_History(this, @opts.history)

