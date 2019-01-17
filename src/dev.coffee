fs             = require "fs"
coffee         = require "coffeescript"
child_process  = require "child_process"
server_process = null

DEV =
  run: (args...) ->
    if args[args.length - 1] == "build"
      DEV.compileServer()
      DEV.compileClient()
      process.exit(0)
    else
      # compile and watch server
      DEV.compileServer()
      fs.watch(closely, DEV.compileServer) for closely in ["./src/server.coffee", "./src/server"]

      # compile and watch client
      DEV.compileClient()
      fs.watch(closely, DEV.compileClient) for closely in ["./src/client.coffee", "./src/client", "./src/client/players"]

      # run server in loop
      setTimeout (=> DEV.runServer(DEV.runServer)), 1000

  compileServer: (ev, f) ->
    console.log ">>>> compile server file: #{f || "init"}"
    if f
      d = if f == "server.coffee" then "dist" else "dist/server"
      f = if f == "server.coffee" then "src/#{f}" else "src/server/#{f}"
      cmd = "coffee -o #{d} -c #{f}"
      console.log ">>>>>> #{cmd}"
      DEV.exec cmd, -> server_process?.kill('SIGHUP')
    else
      DEV.exec "coffee -o dist -c src/server.coffee"
      DEV.exec "coffee -o dist/server -c src/server"

  compileClient: (ev, f) ->
    console.log ">>>> compile client (#{if f then "#{f} changed" else "init"})"
    DEV.exec "cat $(find ./src/client -type f -name '*.coffee' -print0 | xargs -0 echo) src/client.coffee | coffee -c --stdio > ./dist/client.js"

  runServer: (f) ->
    server_process = child_process.spawn("node",  ["./dist/server.js"])
    server_process.stdout.on "data", (data) -> process.stdout.write data.toString()
    server_process.stderr.on "data", (data) -> process.stderr.write data.toString()
    server_process.on "close", ->
      console.log ">>>> restarting server"
      child_process.exec "which say && say restarting server"
      setTimeout (-> f(f)), 1000

  exec: (cmd, cb) ->
    child_process.exec cmd, {}, (e, stdout, stderr) ->
      process.stdout.write(stdout.toString())
      process.stderr.write(stderr.toString())
      cb?()

DEV.run(process.argv...)
