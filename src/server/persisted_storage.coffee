fs = require('fs')
path = require('path')

exports.Class = class PersistedStorage
  debug: (a...) -> @server.debug("[PStor]", a...)
  info: (a...) -> @server.info("[PStor]", a...)
  warn: (a...) -> @server.warn("[PStor]", a...)
  error: (a...) -> @server.error("[PStor]", a...)

  constructor: (@server, @key, @opts = {}) ->
    @_beforeSave = []
    @_onLoad = []
    @storage = @opts.default || {}
    @file = "#{@server.root}/data/#{@key}.json"
    @sFetch(@opts.default) unless @opts.hasOwnProperty("fetch") && !@opts.fetch
    @sAssignTo(@opts.assign_to) if @opts.assign_to

  sAssignTo: (into) ->
    for k, v of @storage
      do (k, v) => into[k] = v

  sFetch: (defVal = {}) ->
    if fs.existsSync(@file)
      @debug "Fetching #{@key} from #{@file}"
      @storage = JSON.parse(fs.readFileSync(@file))

      for func, i in @_onLoad
        @debug "Applying onLoad##{i} function for #{@key}"
        func(this, @storage)
    else
      @debug "Using default for #{@key}"
      @storage = defVal || {}

  sSave: ->
    for func, i in @_beforeSave
      @debug "Applying beforeSave##{i} function for #{@key}"
      func(this, @storage)

    dir = path.dirname(@file)
    unless fs.existsSync(dir)
      @debug "Creating directory structure for #{@key}: #{dir}"
      fs.mkdirSync(dir, recursive: true)

    @debug "Writing #{@key} to #{@file}.tmp"
    fs.writeFileSync("#{@file}.tmp", JSON.stringify(@storage))

    @debug "Atomic tmp move #{@file}"
    fs.renameSync("#{@file}.tmp", @file)


  # =============
  # = Accessors =
  # =============

  transaction: (cb) ->
    return unless typeof cb == "function"
    cb(@storage)
    @sSave()

  beforeSave: (cb) -> @_beforeSave.push(cb)
  onLoad: (cb) -> @_onLoad.push(cb)
  hasKey: (k) -> @storage.hasOwnProperty(k)
  get: (k) -> @storage[k]
  fetch: (k, d) -> if @hasKey(k) then @get(k) else d
  set: (k, v) ->
    @storage[k] = v
    @opts.assign_to?[k] = v
  rem: (k) -> delete @storage[k]
  persist: (k, v) -> @set(k, v) ; @sSave()
  purge: (k) -> @rem(k) ; @sSave()
