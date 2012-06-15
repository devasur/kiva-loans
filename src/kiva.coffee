# kiva donation organizer
express = require 'express'
http = require 'http'
fs = require 'fs'
path = require 'path'

app = express.createServer()
app.configure ->
  app.use express.static "#{__dirname}/../pub"
  app.use express.bodyParser()
  app.set 'views', "#{__dirname}/../pub/views"
  app.set 'view options', { layout: false }
  app.set 'view engine', 'coffee'
  app.register '.coffee', require('coffeekup').adapters.express


app.get '/', (req,res)->
  res.render 'index'


# passes along ajax-post data to requestb.in
# (to avoid access-origin)
app.post '/reqBin/:id', (req,res)->
  
  postData = JSON.stringify req.body
  
  options =
    host: 'requestb.in'
    path: "/#{req.params.id}"
    method: 'POST'
    port: 80
    headers:
      'Content-length': postData.length
  
  
  postBin = http.request options, (resp)->
    resp.setEncoding 'utf8'
    console.log 'status: ',resp.statusCode
    resp.on 'data', (data)->
      console.log 'resp: ',data
      res.json data
  
  postBin.on 'error', (err)->
    res.json err
  
  postBin.end postData


app.listen 5555
