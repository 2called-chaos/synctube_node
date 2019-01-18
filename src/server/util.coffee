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
  for w in which
    return true if str.slice(0, w.length) == w
  false

exports.endsWith = (str, which...) ->
  return false unless str?
  for w in which
    return true if str.slice(-w.length) == w
  false

exports.trim = (str) -> String(str).replace(/^\s+|\s+$/g, "")

exports.isRegExp = (input) -> input && typeof input == "object" && input.constructor == RegExp

exports.secondsToArray = (sec) ->
  r = []
  for x in [60*60, 60]
    if sec >= x
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
  r.reverse().join(":") + ".#{fraction.slice(-fract)}"

exports.videoTimestamp = (cur, max, fract = 2) ->
  [
    exports.secondsToTimestamp(cur, fract)
    exports.secondsToTimestamp(max, fract).replace(/\.[0]+$/, "")
  ].join(" / ")

exports.timestamp2Seconds = (ts) ->
  parts = ts.replace(/\.[0-9]+$/, "").split(":").reverse()
  seconds = 0

  for x, i in parts
    seconds += if i == 0 then parseInt(x) else parseInt(x) * Math.pow(60, i)

  seconds
