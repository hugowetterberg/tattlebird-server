express = require 'express'
events = require 'events'
socket_io = require 'socket.io'
mongodb = require 'mongodb'
crypto = require 'crypto'
url = require 'url'
rl = require 'readline'
signing = require './signing'

# Set up server.
app = express.createServer()
app.use(express.logger())
app.use(express.static(__dirname + '/public_html'))
io = socket_io.listen(app)
app.listen(8034)

# Connect to mongodb.
server = new mongodb.Server "127.0.0.1", 27017, {}
db = new mongodb.Db 'tattlebird', server

db.open (error, mdb)->
  if error then throw error

  # Create a central event emitter.
  events = new events.EventEmitter()

  ## Basic cli interface for adding accounts.
  # i = rl.createInterface process.stdin, process.stdout, null
  # account = (i)->
  #   i.question "Add account? (y/n): ", (answer)->
  #     if answer is 'y'
  #       i.question "Account key: ", (key)->
  #         i.question "Account secret:", (secret)->
  #           i.question "Is admin? (y/n): ", (admin)->
  #             admin = admin is 'y'
  #             mdb.collection 'credentials', (error, creds)->
  #               cred =
  #                 key: key
  #                 secret: secret
  #                 admin: admin
  #               creds.insert cred, (err, docs)->
  #                 account(i)
  #     else
  #       i.close()
  #       process.stdin.destroy()
  # account i

  parse_request = (req, callback)->
    req.setEncoding 'utf-8'
    shasum = crypto.createHash 'sha256'
    puri = url.parse req.url, yes

    requestReceived = new Date()

    data = ''
    req.on 'data', (chunk)->
      data += chunk
      shasum.update chunk
    req.on 'end', ()->
      mdb.collection 'credentials', (error, creds)->
        console.log "Loading credentials for #{puri.query.tattle_key}"
        creds.findOne key:puri.query.tattle_key, (error, cred)->
          if not cred or error
            callback new Error('Unknown API key', 1001)
          else
            # Validate get-parameter signature.
            signing.validateSignature puri, requestReceived, cred, (error, valid)->
              if error
                callback error
              else
                # Validate body hash.
                body_hash = shasum.digest('base64')
                if not (body_hash is puri.query.tattle_body_hash)
                  callback new Error('Invalid body hash', 1000)
                else
                  body = JSON.parse(data)
                  callback false, body, puri, cred

  say_no = (error, res)->
    res.writeHead 200,
      'Content-Type': 'application/json'
    res.end JSON.stringify
      status: 'error'
      message: error.message

  # Register our handler for incoming reports.
  app.post '/api/site/update-status', (req, res)->
    parse_request req, (error, data, puri, credentials)->
      if error
        say_no(error, res)
      else
        mdb.collection 'statuses', (error, statuses)->
          data.site = credentials.key
          statuses.insert data
          events.emit 'status-update', data
          res.writeHead 200,
            'Content-Type': 'application/json'
          res.end JSON.stringify(status:'ok')

  io.sockets.on 'connection', (socket)->
    signing.issueChallenge socket, mdb, (error, credentials)->
      if error
        console.log error.message
        socket.emit 'challenge-failed',
          message: error.message
      else
        socket.emit 'challenge-success',
          key: credentials.key
          admin: credentials.admin
        events.on 'status-update', (data)->
          socket.emit 'status-update', data.site