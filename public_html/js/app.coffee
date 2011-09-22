(($)->
  socket = io.connect '/'

  $ ()->
    spinner = document.getElementById 'progress-spinner'
    opts =
      lines: 16
      length: 24
      width: 20
      radius: 6
      color: '#fff'
      speed: 2.2
      trail: 100
      shadow: no
    new Spinner(opts).spin(spinner)

    # Login handler
    $('#state-login form').bind 'submit', (event)->
      setState 'progress', (error)=>
        values = {}
        for pair in $(this).serializeArray()
          values[pair.name] = pair.value

        # Saving credentials
        localStorage['tattlebird_key'] = values.username
        localStorage['tattlebird_secret'] = values.password

        signature = Crypto.HMAC(Crypto.SHA1, values.username + data.sign, values.password)
        console.log "Sending user response signature #{signature} for key #{values.username}"
        callback
          key: values.username
          signature: signature
      no

  setState = (state, callback)->
    $ ()->
      console.log "Showing state #{state}"
      $(".current-state").trigger('will-hide').removeClass('current-state')
      success = $("#state-#{state}").trigger('will-show').addClass('current-state').length
      error = if success then no else new Error("No section named #{state}")
      callback error

  statuses = {}

  
  socket.on 'status-update', (data)->
    console.log "Status update for #{data.site}"
    status_list = $('#site-statuses')
    if not statuses[data.site]?
      site = $('<li>').attr(
        site: data.site
        class: 'site'
      ).appendTo(status_list)
      .append($('<label>').text(data.site))
      .append($('<div class="site-info projects">').text('Projects').prepend('<div class="symbol symbol-unknown">'))
      .append($('<div class="site-info status">').text('Status').prepend('<div class="symbol symbol-unknown">'))
      statuses[data.site] = yes
    else
      site = $("div[site=#{site}]")

    project_status = switch data.project_status
      when 1 then 'security-update'
      when 2 then 'revoked'
      when 3 then 'unsupported'
      when 4 then 'outdated'
      when 5 then 'ok'
      else 'unknown'
    $('.projects .symbol', site).attr
      class:"symbol symbol-#{project_status}"
      title:project_status

    site_status = switch data.status_severity
      when -1 then 'info'
      when 0 then 'ok'
      when 1 then 'warning'
      when 2 then 'error'
      else 'unknown'
    $('.status .symbol', site).attr
      class:"symbol symbol-#{site_status}"
      title:site_status

  socket.on 'challenge-failed', (data)->
    console.log data.message
    setState 'login', (error)->
      null # Show error message

  socket.on 'challenge-success', (data)->
    console.log data
    setState 'main', (error)->
      console.log 'Asking for full status update'
      socket.emit 'status-update'

  socket.on 'challenge', (data, callback)->
    console.log "Got challenge asking us to sign #{data.sign}"
    if localStorage.tattlebird_key?
      key = localStorage['tattlebird_key']
      secret = localStorage['tattlebird_secret']
      signature = Crypto.HMAC(Crypto.SHA1, key + data.sign, secret)
      console.log "Sending automatic response signature #{signature} for key #{key}"
      callback
        key: key
        signature: signature
    else
      setState 'login', (error)->
        null
)(jQuery)