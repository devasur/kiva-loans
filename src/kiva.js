(function() {
  var app, express, fs, http, path;

  express = require('express');

  http = require('http');

  fs = require('fs');

  path = require('path');

  app = express.createServer();

  app.configure(function() {
    app.use(express.static("" + __dirname + "/../pub"));
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

  app.listen(5555);

}).call(this);
