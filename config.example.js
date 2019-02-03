module.exports = config = {};

// Server control password, if falsy will autogenerate one on every start
config.systemPassword = false;

// If enabled, will print loads and loads of debug output to console
config.debug = false;
config.debug_packets = false; // log all incoming packets
config.debug_codes = false;   // log all outgoing control codes (MUCH DATA!)

// Port on which to bind the HTTP/WS server to.
// Client will autodiscover from document.location, otherwise edit index.html
config.port = 1337;

// IP/Host to bind to, set to 0.0.0.0 (v4) or ::0 (v6) to bind to all devices
config.host = "localhost";

// Amount of nulled sessions before a reindexing occurs (there should be no need to change this value)
config.sessionReindex = 250;

// Maximum client name length
config.nameMaxLength = 25;

// Clients can't use these names
// when comparing to string: input name will be lowercased and have all characters not a-z0-9 removed before checking
// when comparing to regexp: raw input, match = reject
config.protectedNames = [
  "admin", // will match ".-admin-.", "a-dmin", "Ad-Min", etc.
  "system",
  /^[a]+$/, // will match "aaaaaaaaAAAAAAA"
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
// which is recommended due to crude implementation to avoid express dependency
config.answerHttp = true;

// The HTTP server (if answerHttp is true) will only ever serve assets listed here for security reasons (basedir evasion)
config.allowedAssets = [
  "/", // will serve index.html
  "/index.html",
  "/favicon.ico",
  "/client.js",
  "/client.css",
];

