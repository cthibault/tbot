# Description:
#   Manage your giftcard collection. GiftCards get stored in the robot brain
#
# Commands:
#   hubot gc list - _Lists stored giftcards_
#   hubot gc add "`name`" with $`amt` and #:`nbr` (p:`pin`) - _Adds giftcard to your wallet (optional <pin>)_
#   hubot gc remove all - _Removes all giftcards from wallet_
#   hubot gc remove #:`nbr` - _Removes giftcard from wallet_
#   hubot gc find ("`name`" | #:`nbr`) - _Finds giftcards by name or nbr (*)_
#   hubot gc set balance on #:`nbr` to $`amt` - _Update balance for a single card (*)_
#   hubot gc $`amt` transaction on #:`nbr` - _Reduce the balance by the amt for a single card (*)_
#
# Author
#   curtistbone@gmail.com
#
# Notes
#   In order to use the methods within this module, the user must have the role of parent
#

##
## HELPER METHODS
##
auth = (robot, msg) ->
  usr = robot.brain.userForId msg.envelope.user.id
  unless robot.auth.hasRole(usr, 'parent')
    msg.reply "Sorry, but you aren't my boss... :stuck_out_tongue:"
    return false
  return true

sortBy = (key, a, b, r) ->
  r = if r then 1 else -1
  return -1*r if a[key] > b[key]
  return +1*r if a[key] < b[key]
  return 0

processResultFindings = (err, results, msg) ->
  if err?
    msg.reply "I wasn't able to find any matching cards."
  else
    msg.send({
      "attachments": [
        {
          "pretext": "Here are the cards I was able to find..."
          "text": ("#{r.formattedString()}" for r in results.sort (a,b) -> sortBy 'name', a, b).join("\r")
          "mrkdwn_in": [
            "text",
            "pretext"
          ]
        }
      ]
    })

updateBalance = (number, amount, operation, wallet, msg) ->
  unless wallet?
    msg.reply "I can't seem to find my wallet"
    return

  wallet.updateBalance number, amount*100, operation, (errorKey, result) ->
    switch errorKey
      when "NotFound" then msg.reply "I'm unable to find that one..."
      when "Empty" then msg.reply "You already don't trust me with anything"
      when "TooManyMatching" then msg.send({
          "attachments": [
            {
              "pretext": "There are too many matching results to perform the balance update.\rHere are the cards I was able to find..."
              "text": ("#{r.formattedString()}" for r in result.sort (a,b) -> sortBy 'name', a, b).join("\r")
              "mrkdwn_in": [
                "text",
                "pretext"
              ]
            }
          ]
        })
      when "Success" then msg.send({
          "attachments": [
            {
              "pretext": "Thanks. I've updated the card:"
              "text": "#{result.formattedString()}"
              "mrkdwn_in": [
                "text",
                "pretext"
              ]
            }
          ]
        })
      else msg.reply "I'm unsure what happened: #{messageKey}"

##
## ROBOT LISTENERS
##
module.exports = (robot) ->
  robot.respond /(gc|giftcard(s?)) list/i, (msg) ->
    unless auth robot, msg
      return

    wallet = new Wallet robot
    wallet.list (err, results) -> 
      if err?
        msg.reply "I'm not aware of any giftcards..."
      else
        msg.send({
          "attachments": [
            {
              "pretext": "Here are the cards I'm aware of..."
              "text": ("#{r.formattedString()}" for r in results.sort (a,b) -> sortBy 'name', a, b).join("\r")
              "mrkdwn_in": [
                "text",
                "pretext"
              ]
            }
          ]
        })

  robot.respond /(gc|giftcard(s?)) add .+/i, (msg) ->
    unless auth robot, msg
      return
    
    nameMatch = msg.match[0].match /['"](.+)['"]/i
    balanceMatch = msg.match[0].match /\$(\S+)/i
    numberMatch = msg.match[0].match /#:(\d+)/i
    pinMatch = msg.match[0].match /p:(\d+)/i

    unless nameMatch? and balanceMatch? and numberMatch?
      msg.reply "You need to provide the card's Name, Balance, and Number for me to add the card to your wallet [#{nameMatch?}, #{balanceMatch?}, #{numberMatch?}]"

    gc = new Giftcard nameMatch[1], balanceMatch[1]*100, numberMatch[1], pinMatch?[1]
    wallet = new Wallet robot

    wallet.add gc, (err, message) ->
      if err?
        msg.reply "I am already aware of that card."
      else
        msg.send({
          "attachments": [
            {
              "pretext": "Thanks. I'll start tracking this card:"
              "text": "#{gc.formattedString()}"
              "mrkdwn_in": [
                "text",
                "pretext"
              ]
            }
          ]
        })

  robot.respond /(gc|giftcard(s?)) remove all/i, (msg) ->
    unless auth robot, msg
      return
    
    wallet = new Wallet robot
    wallet.clear (messageKey) ->
      switch messageKey
        when "NoRobot" then msg.reply "I'm having an internal crisis..."
        when "Empty" then msg.reply "You already don't trust me with anything"
        when "Success" then msg.reply "All trace evidence has been removed.  Your wallet is empty."
        else msg.reply "I'm unsure what happened: #{messageKey}"

  robot.respond /(gc|giftcard(s?)) remove #:(\d+)/i, (msg) ->
    unless auth robot, msg
      return
    
    number = msg.match[3]
    if number?
      wallet = new Wallet robot
      wallet.remove number, (messageKey) ->
        switch messageKey
          when "NotFound" then msg.reply "I'm unable to find that one..."
          when "Empty" then msg.reply "You already don't trust me with anything"
          when "Success" then msg.reply "All trace evidence has been removed for #:#{number}"
          else msg.reply "I'm unsure what happened: #{messageKey}"

  robot.respond /(gc|giftcard(s?)) find .+/i, (msg) ->
    unless auth robot, msg
      return
    
    nameMatch = msg.match[0].match /['"](.+)['"]/i
    numberMatch = msg.match[0].match /#:([\*\d]+)/i
    
    unless nameMatch? or numberMatch? 
      msg.reply "Without a Name or Number I don't know what I'm looking for..."

    wallet = new Wallet robot

    if nameMatch?
      wallet.findByName nameMatch[1], (err, results) ->
        processResultFindings err, results, msg
    else if numberMatch?
      wallet.findByNumber numberMatch[1], (err, results) ->
        processResultFindings err, results, msg

  robot.respond /(gc|giftcard(s?)) set balance .+/i, (msg) ->
    unless auth robot, msg
      return
    
    numberMatch = msg.match[0].match /#:([\*\d]+)/i
    balanceMatch = msg.match[0].match /\$(\S+)/i
    
    unless numberMatch? and balanceMatch?
      msg.reply "You need to provide the card's Number and the new Balance."
    
    wallet = new Wallet robot
    updateBalance numberMatch[1], balanceMatch[1], "SET", wallet, msg

  robot.respond /(gc|giftcard(s?)) .+ transaction .+/i, (msg) ->
    unless auth robot, msg
      return
    
    numberMatch = msg.match[0].match /#:([\*\d]+)/i
    transAmountMatch = msg.match[0].match /\$(\S+)/i
    
    unless numberMatch? and transAmountMatch?
      msg.reply "You need to provide the card's Number and the transaction amount."
    
    wallet = new Wallet robot
    updateBalance numberMatch[1], transAmountMatch[1], "DEBIT", wallet, msg

##
## WALLET CLASS
##
class Wallet
  constructor: (robot) ->
    @robot = robot
    @initialize()

  initialize: ->
    @robot.brain.data.gcwallet ?= []
    @giftcards = @robot.brain.data.gcwallet

  all: (gc) ->
    if gc
      @giftcards.push gc
    else
      @giftcards

  clear: (callback) ->
    if @all().length > 0
      if @robot?
        @robot.brain.data.gcwallet = []
        @initialize()
        callback "Success"
      else
        callback "NoRobot"
    else
      callback "Empty"
  
  remove: (number, callback) ->
    if @all().length > 0
      results = @_findByNumber number
      if results.length > 0
        @giftcards[t..t] = [] if (t = @giftcards.indexOf(results[0])) > -1
        callback "Success"
      else
        callback "NotFound"
    else
      callback "Empty"

  list: (callback) ->
    if @all().length > 0
      results = []
      for entry in @all()
        if entry?
          results.push new Giftcard entry.name, entry.balance, entry.number, entry.pin
      callback null, results
    else
      callback "No Giftcards exist"

  add: (gc, callback) ->
    if gc?
      results = if @all().length > 0 then @_findByNumber gc.number else []
      if results.length > 0
        callback "Giftcard already exists"
      else
        @all gc
        callback null, "Giftcard added"
    else
      callback "Not a valid giftcard"

  updateBalance: (number, amount, operation, callback) ->
    if @all().length > 0
      results = @_findByNumber number
      if results.length == 1
        updatedBalance = amount
        switch operation
          when "SET" then updatedBalance = amount
          when "DEBIT" then updatedBalance = results[0].balance - amount
          when "CREDIT" then updatedBalance = results[0].balance + amount
          else updatedBalance = results[0].balance
        gc = new Giftcard results[0].name, updatedBalance, results[0].number, results[0].pin
        @giftcards[t..t] = gc if (t = @giftcards.indexOf(results[0])) > -1
        callback "Success", gc
      else if results.length > 1
        convertedResults = (new Giftcard r.name, r.balance, r.number, r.pin for r in results)
        callback "TooManyMatching", convertedResults
      else
        callback "NotFound"
    else
      callback "Empty"

  findByNumber: (numberExp, callback) ->
    if @all().length > 0
      results = @_findByNumber numberExp
      if results.length > 0
        convertedResults = (new Giftcard r.name, r.balance, r.number, r.pin for r in results)
        callback null, convertedResults
      else
        callback "No results found"
    else
      callback "Empty list"

  _findByNumber: (numberExp) ->
    exp = "^#{numberExp.replace /\*/g,".*"}$"
    results = []
    @all().forEach (gc) ->
      if gc and gc.number
        if RegExp(exp, "i").test gc.number
          results.push gc
    return results

  findByName: (nameExp, callback) ->
    if @all().length > 0
      exp = "^#{nameExp.replace /\*/g,".*"}$"
      results = []
      @all().forEach (gc) ->
        if gc and gc.name
          if RegExp(exp, "i").test gc.name
            results.push new Giftcard gc.name, gc.balance, gc.number, gc.pin
      if results.length > 0
        callback null, results
      else
        callback "No results found"
    else
      callback "Empty list"

##
## GIFTCARD CLASS
##
class Giftcard
  constructor: (name, balance, number, pin) ->
    @name = name
    @balance = balance
    @number = number
    @pin = pin

  formattedString: ->
    balanceInDollars = (@balance / 100).toFixed(2)    
    text = "*#{@name}*  $#{balanceInDollars}  #:#{@number}"
    text += "  _p:#{@pin}_" if @pin?
    return text