coffee --compile --output dist --watch src&
while true; do say "node"; node dist/server.js; done
