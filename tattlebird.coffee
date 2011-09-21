express = require 'express'
events = require 'events'
socket_io = require 'socket.io'
mongodb = require 'mongodb'
crypto = require 'crypto'
url = require 'url'
rl = require 'readline'
signing = require './signing'
status_updates = require './status_updates'
drupal_api = require './drupal_api'

# Set up server.
app = express.createServer()
app.use(express.logger())
app.use(express.static(__dirname + '/public_html'))
io = socket_io.listen(app)
app.listen(8034)

# Connect to mongodb.
server = new mongodb.Server "127.0.0.1", 27017, {}
db = new mongodb.Db 'tattlebird', server

class Tattlebird extends events.EventEmitter
  constructor: (@db)->

  collection: (name, callback)->
    @db.collection name, callback

class TattlebirdSession
  constructor: (@tattlebird, @socket, @credentials = null)->

  collection: (name, callback)->
    @tattlebird.db.collection name, callback

db.open (error, mdb)->
  if error then throw error

  tattlebird = new Tattlebird(mdb)
  drupal_api.registerAPI tattlebird, app

  io.sockets.on 'connection', (socket)->
    session = new TattlebirdSession(tattlebird, socket)
    signing.issueChallenge session, (error, credentials)->
      # Only let admin account get status updates.
      if not error and credentials.admin
        status_updates.start session
