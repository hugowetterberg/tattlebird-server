(($)->
  socket = io.connect '/'

  setState = (state, callback)->
    $ ()->
      console.log "Showing state #{state}"
      $(".current-state").hide()
      success = $(".state-#{state}").show().length
      error = if success then no else new Error("No section named #{state}")
      callback error

  socket.on 'status-update', (data)->
    console.log data

  socket.on 'challenge-failed', (data)->
    console.log data.message

  socket.on 'challenge-success', (data)->
    console.log data

  socket.on 'challenge', (data, callback)->
    console.log "Got challenge asking us to sign #{data.sign}"
    setState 'login', (error)->
      $('#login form').bind 'submit', (event)->
        values = {}
        for pair in $(this).serializeArray()
          values[pair.name] = pair.value

        signature = Crypto.HMAC(Crypto.SHA1, values.username + data.sign, values.password)
        console.log "Sending response signature #{signature} for key #{values.username}"
        callback
          key: values.username
          signature: signature
        no
)(jQuery)