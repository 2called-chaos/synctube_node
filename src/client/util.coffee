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


