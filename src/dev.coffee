fs             = require "fs"
coffee         = require "coffeescript"
child_process  = require "child_process"
server_process = null

exec = (cmd, cb) ->
  child_process.exec cmd, {}, (e, stdout, stderr) ->
    process.stdout.write(stdout.toString())
    process.stderr.write(stderr.toString())
    cb?()

compileServer = (f) ->
  console.log ">>>> compile server file: #{f || "init"}"
  if f
    d = if f == "server.coffee" then "dist" else "dist/server"
    f = if f == "server.coffee" then "src/#{f}" else "src/server/#{f}"
    cmd = "coffee -o #{d} -c #{f}"
    console.log ">>>>>> #{cmd}"
    exec cmd, -> server_process?.kill('SIGHUP')
  else
    exec "coffee -o dist -c src/server.coffee"
    exec "coffee -o dist/server -c src/server"

compileClient = (f) ->
  console.log ">>>> compile client (#{if f then "#{f} changed" else "init"})"
  exec "cat $(find ./src/client -type f -name '*.coffee' -print0 | xargs -0 echo) src/client.coffee | coffee -c --stdio > ./dist/client.js"

# compile and watch server
compileServer()
fs.watch "./src/server.coffee", encoding: "buffer", (_, f) => compileServer(f.toString())
fs.watch "./src/server", encoding: "buffer", (_, f) => compileServer(f.toString())

# compile and watch client
compileClient()
fs.watch "./src/client.coffee", encoding: "buffer", (_, f) => compileClient(f.toString())
fs.watch "./src/client", encoding: "buffer", (_, f) => compileClient(f.toString())
fs.watch "./src/client/players", encoding: "buffer", (_, f) => compileClient(f.toString())

# run server in loop
runServer = (f) ->
  server_process = child_process.spawn("node",  ["./dist/server.js"])
  server_process.stdout.setEncoding("utf8")
  server_process.stderr.setEncoding("utf8")
  server_process.stdout.on "data", (data) -> process.stdout.write data.toString()
  server_process.stderr.on "data", (data) -> process.stderr.write data.toString()
  server_process.on "close", ->
    console.log ">>>> restarting server"
    child_process.exec "say restarting server"
    setTimeout (-> f(f)), 1000

setTimeout (-> runServer(runServer)), 1000
