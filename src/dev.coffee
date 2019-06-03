fs             = require "fs"
coffee         = require "coffeescript"
child_process  = require "child_process"
server_process = null
useDebugger    = false
stopLoop       = false

DEV =
  run: (args...) ->
    if "debugger" in args
      useDebugger = true
      args.splice(args.indexOf("debugger"), 1)

    if args[args.length - 1] == "build"
      DEV.compileServer()
      DEV.compileClient()
      process.exit(0)
    else
      _proc = process
      process.on 'SIGINT', =>
        if server_process?
          stopLoop = true
          server_process.on 'close', =>
            console.log "seya"
            _proc.exit(130)
          server_process.kill('SIGINT')
        else
          _proc.exit(130)
      process.on 'SIGTERM', =>
        if server_process?
          stopLoop = true
          server_process.on 'close', => _proc.exit(2)
          server_process.kill('SIGTERM')
        else
          _proc.exit(2)

      # compile and watch server
      DEV.compileServer()
      @watchRecursive(closely, DEV.compileServer) for closely in ["./src/server.coffee", "./src/server"]

      # compile and watch client
      DEV.compileClient()
      @watchRecursive(closely, DEV.compileClient) for closely in ["./src/client.coffee", "./src/client"]

      # run server in loop
      setTimeout (=> DEV.runServer(DEV.runServer)), 1000

  watchRecursive: (dirOrFile, callback) ->
    if fs.lstatSync(dirOrFile).isDirectory()
      fs.watch(dirOrFile, (ev, f) -> callback(ev, dirOrFile, f))
      for _x in fs.readdirSync(dirOrFile)
        ((x) =>
          xx = "#{dirOrFile}/#{x}"
          @watchRecursive(xx, callback) if fs.lstatSync(xx).isDirectory()
        )(_x)
    else
      fs.watch(dirOrFile, (ev, f) -> callback(ev, dirOrFile.split("/").slice(0, -1).join("/"), f))

  compileServer: (ev, d, f) ->
    return if d && f && !fs.existsSync("#{d}/#{f}")
    console.log ">>>> compile server file: #{f || "init"}"
    if f
      sf = "#{d}/#{f}"
      dd = d.replace("./src", "./dist")
      console.log ">>>>>> #{sf}  >>  #{dd}"
      cmd = "coffee -o #{dd} -c #{sf}"
      console.log ">>>>>> #{cmd}"
      DEV.exec cmd, -> server_process?.kill('SIGTERM')
    else
      DEV.exec "coffee -o dist -c src/server.coffee"
      DEV.exec "coffee -o dist/server -c src/server"

  compileClient: (ev, f) ->
    console.log ">>>> compile client (#{if f then "#{f} changed" else "init"})"
    DEV.exec "cat $(find ./src/client -type f -name '*.coffee' -not -path '*/example.coffee' -print0 | xargs -0 echo) src/client.coffee | coffee -c --stdio > ./dist/client.js"

  runServer: (f) ->
    pargs = ["./dist/server.js"]
    pargs.unshift("inspect") if useDebugger
    server_process = child_process.spawn("node",  pargs)
    server_process.stdout.on "data", (data) -> process.stdout.write data.toString()
    server_process.stderr.on "data", (data) -> process.stderr.write data.toString()
    server_process.on "close", ->
      return if stopLoop
      console.log ">>>> restarting server"
      child_process.exec "which say && say restarting server"
      setTimeout (-> f(f)), 1000

  exec: (cmd, cb) ->
    child_process.exec cmd, {}, (e, stdout, stderr) ->
      process.stdout.write(stdout.toString())
      process.stderr.write(stderr.toString())
      cb?()

DEV.run(process.argv...)
