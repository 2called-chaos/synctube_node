UTIL = require("./util.js")

exports.Class = class PlaylistManager
  debug: (a...) -> @channel.debug("[PL]", a...)
  info: (a...) -> @channel.info("[PL]", a...)
  warn: (a...) -> @channel.warn("[PL]", a...)
  error: (a...) -> @channel.error("[PL]", a...)

  constructor: (@channel, @data = {}, @opts = {}) ->
    @server = @channel.server
    @set = null

  sdata: (sub = @set) -> @data[sub]

  onListChange: (cb) -> @_onListChange = cb

  load: (name, opts = {}) ->
    old = @set
    @set = name
    unless @data[@set]
      @debug "Creating new playlist #{name}"
      @data[@set] = Object.assign({}, {
        index: -1
        entries: []
        map: {}
        maxListSize: 100 #
        autoPlayNext: true
        autoRemove: true
        shuffle: false #
        loop: false #
        loadImageThumbs: true #
        persisted: true #
      }, opts)
    @cUpdateList()
    @delete(old) if @data[old] && !@data[old].persisted
    @_onListChange?(@set)
    @data[@set]

  rebuildMaps: (only...) ->
    for name, data of @data
      continue if only.length && only.indexOf(name) < 0
      delete data["map"]
      data.map = {}
      data.map[entry[1]] = entry for entry in data.entries

  delete: (name = @set) ->
    return if @opts.history
    throw "cannot delete default playlist" if name == "default"
    if name == @set
      @load("default")
      delete @data[name]
    else
      delete @data[name]
      @cUpdateList()

  clear: (name = @set) ->
    return unless sdata = @data[name]
    sdata.index = -1
    sdata.entries = []
    sdata.map = {}
    @cUpdateList()
    return true

  cUpdateList: (client, opts = {}) ->
    return if @opts.history
    entries = []
    for qel, i in @data[@set].entries
      qel[2].index = i
      entries.push(qel[2])
    if client
      client.sendCode("playlist_update", entries: entries, index: @data[@set].index, keepScroll: opts.keepScroll)
    else
      @channel.broadcastCode(false, "playlist_update", entries: entries, index: @data[@set].index, keepScroll: opts.keepScroll)

  cUpdateIndex: (client) ->
    return if @opts.history
    if client
      client.sendCode("playlist_update", index: @data[@set].index)
    else
      @channel.broadcastCode(false, "playlist_update", index: @data[@set].index)

  cAtStart: -> @data[@set].index == 0 && !@cEmpty()
  cAtEnd: -> @data[@set].index == (@data[@set].entries.length - 1)
  cEmpty: -> @data[@set].entries.length == 0

  cPlayI: (index) ->
    return if @opts.history
    index = parseInt(index)
    if @data[@set].entries[index]
      @data[@set].index = index
      @cUpdateIndex()
      @channel.live(@data[@set].entries[@data[@set].index]...)
    else
      throw "no such index"

  cSwap: (srcIndex, dstIndex) ->
    return if @opts.history
    srcIndex = parseInt(srcIndex)
    dstIndex = parseInt(dstIndex)
    if srcItem = @data[@set].entries[srcIndex]
      if dstItem = @data[@set].entries[dstIndex]
        activeElement = @data[@set].entries[@data[@set].index]

        # swap entries
        @data[@set].entries[srcIndex] = dstItem
        @data[@set].entries[dstIndex] = srcItem
        
        # index bounds
        _qel[2].index = i for _qel, i in @data[@set].entries
        if activeElement
          @data[@set].index = activeElement[2].index
        else
          @data[@set].index = Math.min(@data[@set].index, @data[@set].entries.length - 1)
        
        @cUpdateList(null, keepScroll: true)
      else
        throw "no such dstIndex"
    else
      throw "no such srcIndex"

  cNext: ->
    return if @opts.history
    return false if @cEmpty()
    return false if @cAtEnd()
    if @data[@set].autoRemove && @data[@set].entries[@data[@set].index]
      @removeItemAtIndex(@data[@set].index)
    else
      @data[@set].index++
      @cUpdateIndex()
    @channel.live(@data[@set].entries[@data[@set].index]...)

  cPrev: ->
    return if @opts.history

  removeItemAtIndex: (index) ->
    return if @opts.history
    index = parseInt(index)
    wasAtEnd = @cAtEnd()
    wasActive = index == @data[@set].index
    activeElement = @data[@set].entries[@data[@set].index]
    url = @data[@set].entries[index][1]
    dmap = @data[@set].map
    delete dmap[url]
    @data[@set].entries.splice(index, 1)

    # index bounds
    _qel[2].index = i for _qel, i in @data[@set].entries
    if activeElement
      @data[@set].index = activeElement[2].index
    else
      @data[@set].index = Math.min(@data[@set].index, @data[@set].entries.length - 1)
    @data[@set].index = -1 if @data[@set].entries.length == 0
    if wasAtEnd && wasActive
      @data[@set].index = -1
      @channel.setDefaultDesired()

    @cPlayI(@data[@set].index) if !wasAtEnd && @data[@set].index != -1 && wasActive
    @cUpdateList(null, keepScroll: !wasActive)

  handlePlay: ->
    return if @opts.history
    #return if @channel.desired?.state == "play"
    return if !(@channel.desired?.state == "ended" || (@data[@set].entries.length == 1 && @data[@set].index == -1))
    @cNext() if @data[@set].autoPlayNext

  handleEnded: ->
    return if @opts.history
    @cNext() if @data[@set].autoPlayNext

  add: (ctype, url) ->
    #@data[@set].entries.push([ctype, url, player.getMeta(url)])

  ensurePlaylistQuota: (client) ->
    if @data[@set].entries.length >= @data[@set].maxListSize
      if @opts.history
        url = @data[@set].entries.shift()[1]
        dmap = @data[@set].map
        delete dmap[url]
        return false
      else
        client?.sendRPCResponse(error: "Playlist entry limit of #{@data[@set].maxListSize} exceeded!")
        client?.sendSystemMessage("Playlist entry limit of #{@data[@set].maxListSize} exceeded!")
        return true
    return false

  intermission: (method, args...) ->
    return if @opts.history
    # @getMeta: (url) ->

  playNext: (ctype, url) ->
    return if @opts.history
    return false if @ensurePlaylistQuota()
    return @append(ctype, url) if @cEmpty()
    activeElement = @data[@set].entries[@data[@set].index]
    if qel = @buildQueueElement(ctype, url)
      qel[2].index = @data[@set].index + 1
    else
      qel = @data[@set].map[url]
      return if qel[2].index == @data[@set].index
      @data[@set].entries.splice(qel[2].index, 1)
      _qel[2].index = i for _qel, i in @data[@set].entries

    @data[@set].entries.splice((if activeElement then activeElement[2].index else @data[@set].index) + 1, 0, qel)

    # reset index
    _qel[2].index = i for _qel, i in @data[@set].entries
    @data[@set].index = if activeElement then activeElement[2].index else qel[2].index
    @cUpdateList()
    @handlePlay()

  append: (ctype, url) ->
    return false if @ensurePlaylistQuota()
    activeElement = @data[@set].entries[@data[@set].index]
    if qel = @buildQueueElement(ctype, url)
      @data[@set].entries.push(qel)
      qel[2].index = @data[@set].entries.length - 1
      @channel.broadcastCode(false, "playlist_single_entry", qel[2]) unless @opts.history
    else
      qel = @data[@set].map[url]
      @data[@set].entries.splice(qel[2].index, 1)
      @data[@set].entries.push(qel)

      # reset index
      _qel[2].index = i for _qel, i in @data[@set].entries
      @data[@set].index = if @data[@set].index == -1 then -1 else if activeElement then activeElement[2].index else qel[2].index
      @cUpdateList()
    @handlePlay()

  buildQueueElement: (ctype, url) ->
    return false if @data[@set].map[url]
    data = [ctype, url]
    data.push
      ctype: ctype
      name: "loading #{url}"
      author: null
      id: url
      seconds: 0
      timestamp: "0:00"
      thumbnail: false
    @data[@set].map[url] = data
    @fetchMeta(data...)
    data

  fetchMeta: (ctype, url, data) ->
    try
      return if data.thumbnail != false
      switch ctype
        when "Youtube"
          data.name = [url, "https://youtube.com/watch?v=#{url}"]
          UTIL.jsonGetHttps "https://www.youtube.com/oembed?url=http://www.youtube.com/watch?v=#{url}&format=json", (d) =>
            data.name = [d.title, "https://youtube.com/watch?v=#{url}"]
            data.author = [d.author_name, d.author_url]
            data.thumbnail = d.thumbnail_url.replace("hqdefault", "default")
            @channel.broadcastCode(false, "playlist_single_entry", data)
        when "HtmlImage"
          data.name = [(if m = url.match(/\/([^\/]+)$/) then m[1] else url), url]
          data.thumbnail = url
          data.author = "image"
          @channel.broadcastCode(false, "playlist_single_entry", data)
        when "HtmlVideo"
          data.name = [(if m = url.match(/\/([^\/]+)$/) then m[1] else url), url]
          data.thumbnail = null
          data.author = "video"
          @channel.broadcastCode(false, "playlist_single_entry", data)
        when "HtmlFrame"
          data.name = [url, url]
          data.thumbnail = null
          data.author = "URL"
          @channel.broadcastCode(false, "playlist_single_entry", data)
    catch e
      @error "Failed to load meta information: #{e}"
      console.trace(e)

