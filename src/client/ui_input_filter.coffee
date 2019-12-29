window.SyncTubeClient_InputFilterUI = class SyncTubeClient_InputFilterUI
  constructor: (@client, @opts = {}) ->
    @opts.secrets ?= []
    @opts.filters ?= []
    @opts.secrets.push /^\/system auth (.*)/
    @opts.filters.push /^\/system auth (.*)/
    @opts.filters.push /^\/control [^\s]+ (.*)/
    @opts.filters.push /^\/password ([^\s]+).*/
    @hook()

  getSecret: (str) ->
    for secret in @opts.secrets
      return [match, str, secret] if match = str.match(secret)
    null

  getFilter: (str) ->
    for filter in @opts.filters
      return [match, str, filter] if match = str.match(filter)
    null

  filterCommand: (str) ->
    m = @getFilter(str)
    return str unless m
    fstr = m[0][0]
    for x, i in m[0] when i isnt 0
      fstr = fstr.replace(x, "".padEnd(x.length, "*"))
    fstr

  hook: ->
    @client.input.on "keyup keydown change blur focus", (event) =>
      if m = @getSecret(@client.input.val())
        @client.input.attr("type", "password")
      else
        @client.input.attr("type", "input")

    oldAddSendCommand = @client.addSendCommand
    @client.addSendCommand = (cmd, a...) =>
      oldAddSendCommand.call(@client, @filterCommand(cmd), a...)
 
    @client.debug "client input filtering enabled"

window.SyncTubeClient_InputFilterUI.start = ->
  @inputFilterUI = new SyncTubeClient_InputFilterUI(this, @opts.input_filter_ui)

