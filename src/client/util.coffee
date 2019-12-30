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
