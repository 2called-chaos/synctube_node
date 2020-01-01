exports.shellQuote = (array) -> require("shell-quote").quote(array)

exports.shellSplit = (str, env, cleaned = true) ->
  r = []
  _env = env || {}
  if cleaned
    env ||= (k) -> if _env[k]? then _env[k] else "${#{k}}"
  for x in require("shell-quote").parse(str, env || _env)
    if cleaned && typeof x != "string"
      #console.log typeof x, x
      if x.pattern?
        r.push(x.pattern)
      else if x.op?
        r.push(x.op)
      else if x.comment?
        r.push(x.comment)
      else
        console.warn "unrecognized shell quote object", x
    else
      r.push(x)
  r

exports.extractArg = (args, keys, vlength = 0) ->
  spliced = null
  for k in keys
    i = args.indexOf(k)
    if i > -1
      spliced = args.splice(i, 1 + vlength)
      return if vlength then spliced.slice(1) else true
  return false

exports.htmlEntities = (str) ->
  String(str)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;')

exports.delay = (ms, func) -> setTimeout(func, ms)

exports.strbool = (v, rescue) ->
  return true if ["true", "t", "1", "y", "yes", "on"].indexOf(v) > -1
  return false if ["false", "f", "0", "n", "no", "off"].indexOf(v) > -1
  if rescue? then rescue else throw "Can't convert `#{v}' to boolean, expression invalid!"

exports.startsWith = (str, which...) ->
  return false unless typeof str == "string"
  for w in which
    return true if str.slice(0, w.length) == w
  false

exports.endsWith = (str, which...) ->
  return false unless typeof str == "string"
  for w in which
    return true if str.slice(-w.length) == w
  false

exports.argsToStr = (args) ->
  r = []
  for a in args
    r.push(if typeof a == "string" then a else a.pattern)
  r.join(" ")

exports.trim = (str) -> String(str).replace(/^\s+|\s+$/g, "")

exports.isRegExp = (input) -> input && typeof input == "object" && input.constructor == RegExp

exports.escapeRegExp = (str) -> str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

exports.bytesToHuman = (bytes) ->
  bytes = parseInt(bytes)
  i = -1;
  byteUnits = [' KB', ' MB', ' GB', ' TB', 'PB', 'EB', 'ZB', 'YB']
  loop
    bytes = bytes / 1024
    i++
    break if bytes <= 1024
  Math.max(bytes, 0.1).toFixed(1) + byteUnits[i]

exports.microToHuman = (micro) ->
  if micro > 1000000
    "#{micro / 1000000} s"
  else if micro > 1000
    "#{parseInt(micro / 1000)} ms"
  else
    "#{micro} μs"

exports.parseEasyDuration = (dur) ->
  return parseInt(dur) * (60 * 60 * 27 * 7) if exports.endsWith(dur, "w")
  return parseInt(dur) * (60 * 60 * 24) if exports.endsWith(dur, "d")
  return parseInt(dur) * (60 * 60) if exports.endsWith(dur, "h")
  return parseInt(dur) * (60) if exports.endsWith(dur, "m")
  return parseInt(dur) if exports.endsWith(dur, "s")
  dur

exports.secondsToArray = (sec) ->
  r = []
  for x in [60*60, 60]
    if sec >= x || r.length
      r.push parseInt(sec / x)
      sec %= x

  # seconds & fraction
  r.push parseInt(sec)
  sec -= parseInt(sec)
  r.push parseInt(sec * 1000)

  r

exports.secondsToTimestamp = (sec, fract = 3) ->
  sa = exports.secondsToArray(sec).reverse()
  sa.push(0) if sa.length == 2
  r = []

  for x, i in sa
    slice = if i == 0 then 3 else 2
    r.push if i < 2 || sa[i+1] then "000#{x}".slice(slice * -1) else x.toString()

  fraction = r.shift()
  if fract
    r.reverse().join(":") + ".#{fraction.slice(-fract)}"
  else
    r.reverse().join(":")

exports.videoTimestamp = (cur, max, fract = 2) ->
  [
    exports.secondsToTimestamp(cur, fract)
    exports.secondsToTimestamp(max, fract).replace(/\.[0]+$/, "")
  ].join(" / ")

exports.timestamp2Seconds = (ts) ->
  parts = ts.replace(/\.[0-9]+$/, "").split(":").reverse()
  seconds = 0

  for x, i in parts
    add = if i == 0 then parseInt(x) else parseInt(x) * Math.pow(60, i)
    seconds += if isNaN(add) then throw "invalidNaN" else add

  seconds

exports.jsonGetHttps = (url, cb) ->
  body = ""
  require("https").get url, (res) =>
    res.setEncoding("utf8")
    res.on "data", (d) => body += d
    res.on "end", () =>
      try
        cb(JSON.parse(body))
      catch e
        console.error "Failed to load meta information: #{e}"
        console.trace(e)

exports.spawnShellCommand = (cmd, args = [], opts = {}) ->
  opts.encoding ?= "utf8"

  dbuffer = ""
  lbuffer = []
  spawn = require('child_process').spawn
  prc = spawn(cmd, args)
  prc.stdout.setEncoding(opts.encoding) if opts.encoding?
  prc.on 'close', (code) -> opts.onEnd?(code, lbuffer, dbuffer)
  prc.stdout.on 'data', (data) ->
    str = data.toString()
    lines = str.split(/[\r?\n]/g)
    dbuffer += str
    Array::push.apply(lbuffer, lines)
    opts.onData?(data)
    opts.onLine?(line) for line in lines
  prc

exports.spawnShellCommandP = (cmd, args = []) ->
  new Promise (resolve, reject) ->
    exports.spawnShellCommand cmd, args, onEnd: (c, l, b) -> resolve([c, l, b])

exports.sha1 = (input) ->
  require("crypto").createHash("sha1").update(input).digest("hex")
