window.SyncTubeClient_Util =
  getHashParams: ->
    result = {}
    if window.location.hash
      parts = window.location.hash.substr(1).split("&")
      for kv in parts
        kvp = kv.split("=")
        key = kvp.shift()
        result[key] = kvp.join("=")
    result

  updateHashParams: (toMerge = {}) ->
    @setHashParams Object.assign({}, @getHashParams(), toMerge)

  setHashParams: (hparams = {}) ->
    hsh = []
    for k, v of hparams
      continue if v == undefined
      if v == null
        hsh.push("#{k}")
      else
        hsh.push("#{k}=#{v}")
    window.location.hash = "##{hsh.join("&")}"

  delay: (ms, func) -> setTimeout(func, ms)

  escapeHtml: (html) ->
    p = document.createElement('p')
    p.appendChild(document.createTextNode(html))
    p.innerHTML

  requireRemoteJS: (url, opts = {}, callback) ->
    if typeof opts == "function"
      callback = opts
      opts = {}
    jstag = $("script[src=url]")
    if jstag.length
      callback?()
    else
      jstag = document.createElement("script")
      jstag.onload = -> callback?()
      jstag[a] = v for a, v of opts
      document.head.appendChild(jstag)
      jstag.src = url

  css: (scope, css) ->
    stag = $("style[data-scope=scope]")
    if stag.length
      stag.html(stag.html() + "\n" + css)
    else
      stag = $("<style></style>")
      stag.attr("data-scope", scope)
      stag.html(css)
      stag.appendTo($("head"))
