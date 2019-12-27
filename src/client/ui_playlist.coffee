window.SyncTubeClient_PlaylistUI = class SyncTubeClient_PlaylistUI
  constructor: (@client, @opts = {}) ->
    @playlist = $("#playlist")
    @initSortable()

  initSortable: ->
    @sortable = new Sortable @playlist.get(0),
      disabled: true
      onEnd: (ev) => @client.connection.send("/playlist swap #{ev.oldIndex} #{ev.newIndex}")

  enableSorting: ->
    @client.debug "Playlist sorting enabled"
    @sortable.options.disabled = false

  disableSorting: ->
    @client.debug "Playlist sorting DISABLED"
    @sortable.options.disabled = true
    
  show: -> @playlist.show 1, -> $(window).resize()

  hide: -> @playlist.hide 1, -> $(window).resize()

window.SyncTubeClient_PlaylistUI.start = ->
  @playlistUI = new SyncTubeClient_PlaylistUI(this, @opts.playlist_ui)

