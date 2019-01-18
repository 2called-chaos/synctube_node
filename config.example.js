module.exports = config = {};

// server control password, if falsy will autogenerate one on every start
config.systemPassword = false;

// If enabled, will print loads and loads of debug output to console
config.debug = false;

// Port on which to bind the HTTP/WS server to.
// Client will autodiscover from document.location, otherwise edit index.html
config.port = 1337;

// Amount of nulled sessions before a reindexing occurs (there should be no need to change this value)
config.sessionReindex = 250;

// clients can't use these names
config.protectedNames = [
  "admin",
  "system",
];

// ====================
// = Channel defaults =
// ====================

// Default video to cue in new channels
config.defaultCtype = "Youtube"; // youtube, frame, image, video (mp4/webp)
config.defaultUrl = "6Dh-RL__uN4"; // id suffices when YouTube
config.defaultAutoplay = false; // only when youtube or video

// Interval in ms (1000ms = 1s) for CLIENTS to send update packets to the server.
// Triggered actions will automatically send instant updates.
config.packetInterval = 2000;

// Maximum drift (difference to host) in ms (1000ms = 1s) for CLIENTS before force seeking to correct drift
config.maxDrift = 5000;


// ========================
// = Static asset serving =
// ========================

// If enabled, will server static assets, otherwise will answer requests with "400: Bad Request"
// Disable this if you serve static assets via nginx, etc.
config.answerHttp = true;

// The HTTP server will only ever serve assets listed here and when answerHttp is enabled
config.allowedAssets = [
  "/", // will serve index.html
  "/index.html",
  "/favicon.ico",
  "/dist/client.js",
];

