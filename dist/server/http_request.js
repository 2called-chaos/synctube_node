// Generated by CoffeeScript 2.3.2
(function() {
  var HttpRequest, fs;

  fs = require('fs');

  exports.Class = HttpRequest = class HttpRequest {
    debug(...a) {
      return this.server.debug("[HTTP]", ...a);
    }

    info(...a) {
      return this.server.info("[HTTP]", ...a);
    }

    warn(...a) {
      return this.server.warn("[HTTP]", ...a);
    }

    error(...a) {
      return this.server.error("[HTTP]", ...a);
    }

    constructor(server) {
      this.server = server;
    }

    accept(request, response) {
      var file;
      this.request = request;
      this.response = response;
      this.ip = this.request.connection.remoteAddress;
      if (this.server.opts.allowedAssets.indexOf(this.request.url) > -1) {
        file = "./www" + (this.request.url === "/" ? "/index.html" : this.request.url);
        return this.renderSuccess(file);
      } else {
        return this.renderBadRequest();
      }
    }

    reject(request, response) {
      this.request = request;
      this.response = response;
      return this.renderBadRequest();
    }

    getMimeFromExtension(file) {
      var type;
      if (file.slice(-3) === ".js") {
        return type = "application/javascript";
      } else if (file.slice(-5) === ".html") {
        return "text/html";
      } else if (file.slice(-4) === ".css") {
        return "text/css";
      } else if (file.slice(-4) === ".jpg" || file.slice(-5) === ".jpeg") {
        return "image/jpeg";
      } else if (file.slice(-4) === ".gif") {
        return "image/gif";
      } else if (file.slice(-4) === ".png") {
        return "image/png";
      } else {
        return "text/plain";
      }
    }

    renderSuccess(file, headers = {}) {
      var type;
      if (!fs.existsSync(file)) {
        return this.renderNotFound();
      }
      type = this.getMimeFromExtension(file);
      this.debug(`200: served ${file} (${type}) IP: ${this.ip}`);
      this.response.writeHead(200, {
        "Content-Type": type
      });
      return this.response.end(fs.readFileSync(file));
    }

    renderBadRequest() {
      this.warn(`400: Bad Request (${this.request.url}) IP: ${this.ip}`);
      this.response.writeHead(400, {
        "Content-Type": "text/plain"
      });
      return this.response.end("Error 400: Bad Request");
    }

    renderNotFound() {
      this.warn(`404: Not Found (${this.request.url}) IP: ${this.ip}`);
      this.response.writeHead(404, {
        "Content-Type": "text/plain"
      });
      return this.response.end("Error 404: Not Found");
    }

  };

}).call(this);
