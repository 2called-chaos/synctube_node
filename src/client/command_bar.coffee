window.SyncTubeClient_CommandBar = class SyncTubeClient_CommandBar
  constructor: (@client, @opts = {}) ->
    @buildDom()
    @captureInput()

  captureInput: ->
    $(document).on "keydown keypress keyup", (ev) ->
      $("[data-alt-class]").each (i, el) ->
        if ev.altKey && !$(el).data("isAlted")
          $(el).attr("data-was-class", $(el).attr("class"))
          $(el).attr("class", $(el).data("altClass"))
          $(el).data("isAlted", true)
        else if !ev.altKey && $(el).data("isAlted")
          $(el).attr("class", $(el).attr("data-was-class"))
          $(el).removeAttr("data-was-class")
          $(el).data("isAlted", false)

  updateDesired: (data) ->
    if data.state == "play"
      $("#command_bar [data-command=toggle]").removeClass("btn-success").addClass("btn-warning")
      $("#command_bar [data-command=toggle] i").removeClass("fa-play").addClass("fa-pause")
    else
      $("#command_bar [data-command=toggle]").removeClass("btn-warning").addClass("btn-success")
      $("#command_bar [data-command=toggle] i").removeClass("fa-pause").addClass("fa-play")

    if data.loop
      $("#command_bar [data-command='loop toggle']").addClass("btn-warning")
      $("#command_bar [data-command='loop toggle'] i + i").removeClass("fa-toggle-off").addClass("fa-toggle-on")
    else
      $("#command_bar [data-command='loop toggle']").removeClass("btn-warning")
      $("#command_bar [data-command='loop toggle'] i + i").removeClass("fa-toggle-on").addClass("fa-toggle-off")

  buildDom: ->
    $("#second_row").prepend """
    <div class="col col-12" id="command_bar" style="margin-top: 10px; margin-bottom: -5px; opacity: 0.8; display: none">
      <div class="btn-group btn-group-sm">
        <button type="button" data-command="seek 0" title="start from 0" class="btn btn-secondary"><i class="fa fa-step-backward"></i></button>
        <button type="button" data-command="seek -60" data-alt-command="seek --slowmo -60" title="go back(+alt=slowmo) 60 seconds" class="btn btn-secondary"><i class="fa fa-fw fa-backward" data-alt-class="fa fa-fw fa-history"></i> <small>60</small></button>
        <button type="button" data-command="seek -30" data-alt-command="seek --slowmo -30" title="go back(+alt=slowmo) 30 seconds" class="btn btn-secondary"><i class="fa fa-fw fa-backward" data-alt-class="fa fa-fw fa-history"></i> <small>30</small></button>
        <button type="button" data-command="seek -10" data-alt-command="seek --slowmo -10" title="go back(+alt=slowmo) 10 seconds" class="btn btn-secondary"><i class="fa fa-fw fa-backward" data-alt-class="fa fa-fw fa-history"></i> <small>10</small></button>
      </div>

      <button type="button" data-command="toggle" class="btn btn-sm btn-success" style="padding-left: 15px; padding-right: 15px"><i class="fa fa-fw fa-play"></i></button>

      <div class="btn-group btn-group-sm">
        <button type="button" data-command="seek +10" title="go forward 60 seconds" class="btn btn-secondary"><i class="fa fa-forward"></i> <small>10</small></button>
        <button type="button" data-command="next" title="next in playlist" class="btn btn-info" style="display: none"><i class="fa fa-step-forward"></i></button>
        <button type="button" data-command="seek +30" title="go forward 30 seconds" class="btn btn-secondary"><i class="fa fa-forward"></i> <small>30</small></button>
        <button type="button" data-command="seek +60" title="go forward 10 seconds" class="btn btn-secondary"><i class="fa fa-forward"></i> <small>60</small></button>
      </div>

      <button title="toggle loop" type="button" data-command="loop toggle" class="btn btn-secondary btn-sm"><i class="fa fa-refresh"></i> <i class="fa fa-toggle-on"></i></button>
    </div>
    """

  show: -> $("#command_bar").show 200, -> $(window).resize()

  hide: -> $("#command_bar").hide 200, -> $(window).resize()

window.SyncTubeClient_CommandBar.start = ->
  @commandBar = new SyncTubeClient_CommandBar(this, @opts.command_bar)

