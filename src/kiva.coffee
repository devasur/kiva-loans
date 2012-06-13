# kiva donation organizer
express = require 'express'
http = require 'http'
fs = require 'fs'
path = require 'path'

app = express.createServer()
app.configure ->
  app.use express.static "#{__dirname}/../pub"
  app.set 'views', "#{__dirname}/../pub/views"
  app.set 'view options', { layout: false }
  app.set 'view engine', 'coffee'
  app.register '.coffee', require('coffeekup').adapters.express


app.get '/', (req,res)->
  res.render 'index'

app.get '/flag/:countryCode', (req,res)->
  # where the image should be if already downloaded
  localPath = "#{__dirname}/../pub/img/flags/#{req.params.countryCode}.png"
  servePath = "/img/flags/#{req.params.countryCode}.png"
  
  # if we have it local, just send it
  if path.exists localPath
    res.redirect servePath
  
  # else, get it from the geognos api, then send it
  else
    options =
      host: "www.geognos.com"
      path: "/api/en/countries/flag/#{req.params.countryCode}.png"
      port: 80

    http.get options, (resp)->
      fileStream = fs.createWriteStream(localPath)
      resp.on 'data', (data)->
        fileStream.write data
      resp.on 'end', ->
        fileStream.end()
        fileStream.destroySoon()
        fs.chmod localPath, '775', ->
          res.redirect servePath 
    
    


app.listen 5555
