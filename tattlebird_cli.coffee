mongodb = require 'mongodb'
rl = require 'readline'

# Connect to mongodb.
server = new mongodb.Server "127.0.0.1", 27017, {}
db = new mongodb.Db 'tattlebird', server

db.open (error, mdb)->
  if error then throw error

  # Basic cli interface for adding accounts.
  i = rl.createInterface process.stdin, process.stdout, null
  account = (i)->
    i.question "Add account? (y/n): ", (answer)->
      if answer is 'y'
        i.question "Account key: ", (key)->
          i.question "Account secret:", (secret)->
            i.question "Is admin? (y/n): ", (admin)->
              admin = admin is 'y'
              mdb.collection 'credentials', (error, creds)->
                cred =
                  key: key
                  secret: secret
                  admin: admin
                creds.insert cred, (err, docs)->
                  account(i)
      else
        i.close()
        process.stdin.destroy()
  account i