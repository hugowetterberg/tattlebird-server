crypto = require 'crypto'
url = require 'url'

percentEncode = (s)->
  if s is null
    return ""
  if s instanceof Array
    e = ""
    for v in s
      if e isnt "" then e += '&'
      e += percentEncode v
    return e
  s = encodeURIComponent s
  extraEscapeCharacters = "!*'()"
  for c in extraEscapeCharacters
    s = s.replace c, "%" + c.charCodeAt(0).toString(16)
  return s

formEncode = (parameters)->
  form = ""
  for [key, value] in parameters
    if value is null then value = ""
    if form isnt "" then form += '&'
    form += percentEncode(key) + '=' + percentEncode(value)
  form

normalizeParameters = (parameters)->
    if not parameters
      return ""
    else
      console.log "Parameters"
      console.dir parameters
      sortable = []
      for key, value of parameters
        if key isnt "tattle_signature"
          sortKey = percentEncode(key) + " " + percentEncode(value)
          sortable.push [sortKey, [key, value]]
      sortable.sort (a, b)->
        if a[0] < b[0] then -1
        else if (a[0] > b[0]) then 1
        else 0

      sorted = for pair in sortable then pair[1]
      console.dir sorted
      formEncode sorted

nonceChars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXTZabcdefghiklmnopqrstuvwxyz"
nonce = (length)->
  nlen = nonceChars.length
  result = ""
  for i in [1..length]
    rnum = Math.floor(Math.random() * nlen)
    result += nonceChars.substring(rnum, rnum+1)
  result

exports.validateSignature = (puri, requestReceived, credentials, callback)->
  # Check that we have all required fields.
  required = ['tattle_key', 'tattle_nonce', 'tattle_body_hash', 'tattle_signature', 'tattle_timestamp']
  for key in required
    if not puri.query[key]?
      callback new Error("Missing required parameter #{key}")
      return

  # Allow for 
  request_max_time_diff = 120
  timestamp = parseInt(puri.query.tattle_timestamp, 10)
  now = requestReceived.getTime() / 1000
  if timestamp < (now - 60)
    callback new Error("Request timestamp too old, must not be older than #{request_max_time_diff} seconds")
    return
  else if timestamp > (now + 60)
    callback new Error("Request timestamp from the future, that doesn't work you know.")
    return

  # Build signature
  hmac = crypto.createHmac 'sha256', credentials.secret
  base = normalizeParameters puri.query
  hmac.update base
  signature = hmac.digest 'base64'

  # Verify signature
  if signature is puri.query.tattle_signature
    callback no, yes
  else
    callback new Error('Invalid signature')
  null

exports.parseRequest = (req, mdb, callback)->
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
          exports.validateSignature puri, requestReceived, cred, (error, valid)->
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

exports.issueChallenge = (session, callback)->
  challenge = nonce(64)
  session.socket.emit 'challenge', sign:challenge, (data)->
    key = data.key

    session.collection 'credentials', (error, creds)->
      console.log "Loading credentials for #{key}"
      creds.findOne key:key, (error, credentials)->
        if error
          callback new Error("Could not load credentials for #{key}")
        else if not credentials
          callback new Error("Could not find the account #{key}")
        else
          # Calculate the expected signature.
          hmac = crypto.createHmac 'sha1', credentials.secret
          hmac.update key
          hmac.update challenge
          signature = hmac.digest 'hex'
    
          if signature isnt data.signature
            session.socket.emit 'challenge-failed',
              message: "Signature mismatch"
            callback new Error("Signature mismatch")
          else
            session.socket.emit 'challenge-success',
              key: credentials.key
              admin: credentials.admin
            callback no, credentials
