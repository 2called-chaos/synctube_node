window.SyncTubeClient_PlaylistUI = class SyncTubeClient_PlaylistUI
  constructor: (@client, @opts = {}) ->
    @playlist = $("#playlist")
    @client.CMD_ui_playlist = @CMD_ui_playlist.bind(this)
    @client.CMD_playlist_update = @CMD_playlist_update.bind(this)
    @client.CMD_playlist_single_entry = @CMD_playlist_single_entry.bind(this)
    @sortableOptions =
      disabled: !@client.control
      onSort: (ev) => @client.silentCommand("/playlist swap #{ev.oldIndex} #{ev.newIndex}")
      setData: (dataTransfer, el) ->
        if href = $(el).find("[data-attr=name]").attr("href")
          dataTransfer.setData('text/uri-list', href)
          dataTransfer.setData('text/plain', href)
    @client.requireRemoteJS "https://cdnjs.cloudflare.com/ajax/libs/Sortable/1.10.1/Sortable.min.js", => @initSortable()

  initSortable: ->
    @sortable = new Sortable @playlist.get(0), @sortableOptions

  getSortableOptions: ->
    if @sortable?
      @sortable.options
    else
      @sortableOptions

  enableSorting: ->
    @client.debug "Playlist sorting enabled"
    @getSortableOptions().disabled = false

  disableSorting: ->
    @client.debug "Playlist sorting DISABLED"
    @getSortableOptions().disabled = true

  scrollToActive: (ensure) ->
    @playlist.scrollTop(@playlist.find("div.active").prop("offsetTop") - 15)
    @client.delay(ensure, => @scrollToActive()) if ensure?
  
  getScroll: -> @playlist.scrollTop()

  setScroll: (i, ensure) ->
    @playlist.scrollTop(i)
    @client.delay(ensure, => @setScroll(i)) if ensure?
  
  clearEntries: -> @playlist.html("")
  isEmpty: -> !@playlist.find("div[data-pl-id]").length
  show: -> @playlist.show 1, -> $(window).resize()
  hide: -> @playlist.hide 1, -> $(window).resize()
  toggle: (toToggle) -> @playlist.toggle toToggle, 1, -> $(window).resize()
  toggleEmpty: -> @toggle(!@isEmpty())

  toggleCollapse: (toggleTo) ->
    if toggleTo?
      @playlist.toggleClass("collapsed", toggleTo)
    else
      @playlist.toggleClass("collapsed")
    @client.delay 200, -> $(window).resize()

  buildPlaylistElement: (data) ->
    $ """
      <div data-pl-id="#{data.id}" data-pl-index="#{data.index}">
        <span class="first">
          <img src="https://statics.bmonkeys.net/img/rpcico/unknown.png" data-attr="thumbnail" data-command="pl play #{data.index}" title="play">
        </span>
        <span class="second">
          <a data-attr="name" target="_blank"></a>
          <a data-attr="author" target="_blank"></a>
          <span class="active_indicator text-danger"><i class="fa fa-circle"></i> now playing</span>
          <span class="btn-group">
            <span class="btn btn-success btn-xs" data-command="pl play #{data.index}"><i class="fa fa-play"></i></span>
            <span class="btn btn-danger btn-xs" data-command="pl remove #{data.index}"><i class="fa fa-times"></i></span>
          </span>
        </span>
      </div>
    """

  changeHTML: (el, v) ->
    return unless el.length
    el.html(v) unless el.html() == v
    el

  changeAttr: (el, a, v) ->
    return unless el.length
    el.attr(a, v) unless el.attr(a) == v
    el

  CMD_playlist_single_entry: (data) ->
    el = @playlist.find("[data-pl-id=\"#{data.id}\"]")
    if !el.length || el.data("plIndex") != data.index
      _el = $(@buildPlaylistElement(data))
      _el.attr("data-pl-id", data.id)
      if el.length then el.replaceWith(_el) else @playlist.append(_el)
      el = _el

    @changeAttr(el.find("[data-attr=thumbnail]"), "src", data.thumbnail) if data.thumbnail
    if data.author
      if typeof data.author == "string"
        @changeAttr(el.find("[data-attr=author]"), "title", data.author)
        el.find("[data-attr=author]").removeAttr("href")
        @changeHTML(el.find("[data-attr=author]"), data.author)
      else
        @changeAttr(el.find("[data-attr=author]"), "title", data.author[0])
        @changeAttr(el.find("[data-attr=author]"), "href", data.author[1])
        @changeHTML(el.find("[data-attr=author]"), data.author[0])
    if typeof data.name == "string"
      @changeHTML(el.find("[data-attr=name]"), data.name)
      @changeAttr(el.find("[data-attr=name]"), "title", data.name)
      el.find("[data-attr=name]").removeAttr("href")
    else
      @changeAttr(el.find("[data-attr=name]"), "href", data.name[1])
      @changeAttr(el.find("[data-attr=name]"), "title", data.name[0])
      @changeHTML(el.find("[data-attr=name]"), data.name[0])
    @changeHTML(el.find("[data-attr=timestamp]"), data.timestamp)
    @toggleEmpty()
    @scrollToActive(5)
    $(window).resize()

  CMD_playlist_update: (data) ->
    # remember scroll
    cscroll = @getScroll() if data.keepScroll

    # update entries
    if data.entries
      @client.CMD_ui_clear(component: "playlist")
      @client.CMD_playlist_single_entry(ple) for ple in data.entries

    # update index
    if data.index?
      @playlist.find("div[data-pl-id]").removeClass("active")
      @playlist.find("div[data-pl-index=#{data.index}]").addClass("active")

    # post
    @toggleEmpty()
    if cscroll?
      @setScroll(cscroll, 5)
    else
      @scrollToActive(5)
      $(window).resize()

  CMD_ui_playlist: (data) ->
    switch data.action
      when "show"
        @toggleCollapse(false)
      when "hide"
        @toggleCollapse(true)
      else
        @toggleCollapse()

window.SyncTubeClient_PlaylistUI.start = ->
  @playlistUI = new SyncTubeClient_PlaylistUI(this, @opts.playlist_ui)

