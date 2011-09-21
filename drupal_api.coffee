signing = require './signing'

say_no = (error, res)->
  res.writeHead 200,
    'Content-Type': 'application/json'
  res.end JSON.stringify
    status: 'error'
    message: error.message

exports.registerAPI = (tattlebird, app)->
  # Register our handler for incoming reports.
  app.post '/api/site/update-status', (req, res)->
    signing.parseRequest req, tattlebird, (error, data, puri, credentials)->
      if error
        say_no(error, res)
      else
        tattlebird.collection 'statuses', (error, statuses)->
          data.site = credentials.key
          statuses.insert data
          tattlebird.emit 'status-update', data
          res.writeHead 200,
            'Content-Type': 'application/json'
          res.end JSON.stringify(status:'ok')
  console.log 'Drupal API handler registered'