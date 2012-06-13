// Generated by CoffeeScript 1.3.3
(function() {
  var app, express, fs, http, path;

  express = require('express');

  http = require('http');

  fs = require('fs');

  path = require('path');

  app = express.createServer();

  app.configure(function() {
    app.use(express["static"]("" + __dirname + "/../pub"));
    app.use(express.bodyParser());
    app.set('views', "" + __dirname + "/../pub/views");
    app.set('view options', {
      layout: false
    });
    app.set('view engine', 'coffee');
    return app.register('.coffee', require('coffeekup').adapters.express);
  });

  app.get('/', function(req, res) {
    return res.render('index');
  });

  app.post('/reqBin/:id', function(req, res) {
    var options, postBin, postData;
    postData = JSON.stringify(req.body);
    options = {
      host: 'requestb.in',
      path: "/" + req.params.id,
      method: 'POST',
      port: 80,
      headers: {
        'Content-length': postData.length
      }
    };
    postBin = http.request(options, function(resp) {
      resp.setEncoding('utf8');
      console.log('status: ', resp.statusCode);
      return resp.on('data', function(data) {
        console.log('resp: ', data);
        return res.json(data);
      });
    });
    postBin.on('error', function(err) {
      return res.json(err);
    });
    return postBin.end(postData);
  });

  app.get('/flag/:countryCode', function(req, res) {
    var localPath, options, servePath;
    localPath = "" + __dirname + "/../pub/img/flags/" + req.params.countryCode + ".png";
    servePath = "/img/flags/" + req.params.countryCode + ".png";
    if (path.exists(localPath)) {
      return res.redirect(servePath);
    } else {
      options = {
        host: "www.geognos.com",
        path: "/api/en/countries/flag/" + req.params.countryCode + ".png",
        port: 80
      };
      return http.get(options, function(resp) {
        var fileStream;
        fileStream = fs.createWriteStream(localPath);
        resp.on('data', function(data) {
          return fileStream.write(data);
        });
        return resp.on('end', function() {
          fileStream.end();
          fileStream.destroySoon();
          return fs.chmod(localPath, '775', function() {
            return res.redirect(servePath);
          });
        });
      });
    }
  });

  app.listen(5555);

}).call(this);
