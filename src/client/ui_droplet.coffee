window.SyncTubeClient_DropletUI = class SyncTubeClient_DropletUI
  constructor: (@client, @opts = {}) ->
    @disabled = false
    @srow = $("#second_row")
    @createCSS()
    @createDOM()
    @createEventHandlers()

  createCSS: ->
    @client.css "DropletUI", """
    #second_row {
      position: relative;
    }

    body.dragover #ui_droplet {
      opacity: 1
    }

    #ui_droplet {
      position: absolute;
      top: 10px;
      right: 15px;
      bottom: 0;
      left: 15px;
      background: rgba(33, 33, 33, 0.9);
      z-index: 999;
      pointer-events: none;
      opacity: 0;
      transition: all 100ms linear;
      
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
    }

    #ui_droplet .drophere {
      color: #6c757d;
      text-align: center;
      border: 2px dotted #6c757d;
      padding: 15px 20px 19px 20px;
      border-radius: 12px;
      transition: all 100ms linear;
    }

    #ui_droplet.dragover {
      background: rgba(33, 50, 33, 0.9);
    }

    #ui_droplet.dragover .drophere {
      border-color: #28a745;
      color: #28a745;
    }

    #ui_droplet .drophere:after {
      content: "drop URL"
    }

    #ui_droplet.dragover .drophere:after {
      content: "let it go"
    }
    """

  createDOM: ->
    @dropMask = $("""<div id="ui_droplet"></div>""").appendTo(@srow)
    @dropText = $("""<h1 class="drophere"></h1>""").appendTo(@dropMask)

  createEventHandlers: ->
    # patch sortable playlist
    if @client.playlistUI?.sortable?
      so = @client.playlistUI.sortable.options
      oldOnStart = so.onStart
      oldOnEnd = so.onEnd
      so.onStart = (ev) => @disable(); oldOnStart?.apply(so)
      so.onEnd = (ev) => @enable(); oldOnEnd?.apply(so)

    $(document).on "dragover", "#second_row", (ev) =>
      return if @disabled
      @dropMask.addClass('dragover')

    $(document).on "dragleave dragend", "#second_row", (ev) =>
      @dropMask.removeClass('dragover')

    $(document).on "dragover", (ev) =>
      ev.preventDefault()  
      return if @disabled
      $("body").addClass('dragover')

    $(document).on "dragleave dragend", (ev) =>
      ev.preventDefault()
      return if @disabled
      $("body").removeClass('dragover')

    $(document).on "drop", "#second_row", (ev) =>
      ev.preventDefault()
      return if @disabled
      ev.originalEvent.dataTransfer.items[0].getAsString (str) => @client.sendCommand("play", str)

    $(document).on "drop", (ev) =>
      $("body").removeClass('dragover')
      @dropMask.removeClass('dragover')
      ev.preventDefault()
      ev.stopPropagation()

  enable: ->
    @disabled = false

  disable: ->
    @disabled = true
    $("body").removeClass('dragover')
    @dropMask.removeClass('dragover')

window.SyncTubeClient_DropletUI.start = ->
  @DropletUI = new SyncTubeClient_DropletUI(this, @opts.droplet_ui)

