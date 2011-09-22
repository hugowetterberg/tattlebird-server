
exports.statusDigest = (data, callback)->
  digest =
    site: data.site

  requirement_status = 0
  for status in data.status
    if status.severity > requirement_status
      requirement_status = status.severity
  digest.status_severity = requirement_status

  project_status = 5
  unknown = yes
  for project, status of data.projects
    if status.status > 0 and status.status < project_status
      project_status = status.status
      unknown = no
  if unknown then project_status = 0
  digest.project_status = project_status

  callback digest

exports.start = (session, credentials)->
  session.socket.on 'status-update', ()->
    session.collection 'statuses', (error, statuses)->
      statuses.find (error, cursor)->
        cursor.each (error, data)->
          if not error
            if data then exports.statusDigest data, (digest)->
              session.socket.emit 'status-update', digest
          else
            console.log error.message

  session.socket.on 'status-details', (site, callback)->
    session.collection 'statuses', (error, statuses)->
      if not error
        statuses.findOne site:site, (error, data)->
          callback data

  session.tattlebird.on 'status-update', (data)->
    # Compute a status digest to update the UI.
    exports.statusDigest data, (digest)->
      session.socket.emit 'status-update', digest
  null