# Description:
#   Manage your giftcard collection. GiftCards get stored in the robot brain
#   Also keeps a history of all transactions and automatically updates giftcard
#   balance 
#
# Commands:
#   hubot giftcard list - Lists stored giftcards
#   hubot giftcard add '<name>' with $<balance> and #:<number> (p:<pin>) - Adds a new giftcard to your wallet. <pin> is optional
#   hubot giftcard remove all - Removes all giftcards from wallet
#   hubot giftcard remove #:<number> - Removes giftcard from wallet (exact number required)
#   hubot giftcard find ('<name>' | #:<number>) - Finds giftcard(s) by name or number (allow wildcards)
# TODO
#   hubot giftcard set balance on #:<number> to $<balance> - Updates the balance for a specific card (allow wildcard for number)
#   hubot giftcard set name on <number> to '<name>' - Updates the name for a specific card (allow wildcard for number)
#   hubot giftcard $<amount> transaction on <number> - Reduces the balance by the transacted amount for a specific card (allow wildcard for number)
#
# Author
#   curtistbone@gmail.com

module.exports = (robot) ->
  #robot.respond /giftcard(s?) curtis/i, (msg) ->
  #  wallet = new Wallet robot
  #  

  robot.respond /(gc|giftcard(s?)) list/i, (msg) ->
    wallet = new Wallet robot
    wallet.list (err, results) -> 
      if err?
        msg.reply "I'm not aware of any giftcards..."
      else
        msg.send({
          "attachments": [
            {
              "pretext": "Here are the cards I'm aware of..."
              "text": ("#{r.formattedString()}" for r in results).join("\r")
              "mrkdwn_in": [
                "text",
                "pretext"
              ]
            }
          ]
        })

  robot.respond /(gc|giftcard(s?)) add .+/i, (msg) ->
    nameMatch = msg.match[0].match /['"](.+)['"]/i
    balanceMatch = msg.match[0].match /\$(\S+)/i
    numberMatch = msg.match[0].match /#:(\d+)/i

    unless nameMatch? and balanceMatch? and numberMatch?
      msg.reply "You need to provide the card's Name, Balance, and Number for me to add the card to your wallet [#{nameMatch?}, #{balanceMatch?}, #{numberMatch?}]"
    
    pinMatch = msg.match[0].match /p:(\d+)/i
    
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
    wallet = new Wallet robot
    wallet.clear (messageKey) ->
      switch messageKey
        when "NoRobot" then msg.reply "I'm having an internal crisis..."
        when "Empty" then msg.reply "You already don't trust me with anything"
        when "Success" then msg.reply "All trace evidence has been removed.  Your wallet is empty."
        else msg.reply "I'm unsure what happened: #{messageKey}"

  robot.respond /(gc|giftcard(s?)) remove #:(\d+)/i, (msg) ->
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
    nameMatch = msg.match[0].match /['"](.+)['"]/i
    numberMatch = msg.match[0].match /#:([\*\d]+)/i
    
    unless nameMatch? or numberMatch? 
      msg.reply "Without a Name or Number I don't know what I'm looking for..."

    wallet = new Wallet robot

    if nameMatch?
      wallet.findByName nameMatch[1], (err, results) ->
        if err?
          msg.reply "I wasn't able to find any matching cards."
        else
          msg.send({
            "attachments": [
              {
                "pretext": "Here are the cards I was able to find..."
                "text": ("#{r.formattedString()}" for r in results).join("\r")
                "mrkdwn_in": [
                  "text",
                  "pretext"
                ]
              }
            ]
          })

    if numberMatch?
      wallet.findByNumber numberMatch[1], (err, results) ->
        if err?
          msg.reply "I wasn't able to find any matching cards."
        else
          msg.send({
            "attachments": [
              {
                "pretext": "Here are the cards I was able to find..."
                "text": ("#{r.formattedString()}" for r in results).join("\r")
                "mrkdwn_in": [
                  "text",
                  "pretext"
                ]
              }
            ]
          })

  robot.respond /(gc|giftcard(s?)) set balance .+/i, (msg) ->
    numberMatch = msg.match[0].match /#:([\*\d]+)/i
    balanceMatch = msg.match[0].match /\$(\S+)/i
    
    unless numberMatch? and balanceMatch?
      msg.reply "You need to provide the card's Number and the new Balance. [#{numberMatch?}, #{balanceMatch?}]"
    
    wallet = new Wallet robot
    wallet.updateBalance numberMatch[1], balanceMatch[1]*100, (errorKey, result) ->
      switch errorKey
        when "NotFound" then msg.reply "I'm unable to find that one..."
        when "Empty" then msg.reply "You already don't trust me with anything"
        when "TooManyMatching" then msg.send({ #"There are too many matching results to perform the balance update"
            "attachments": [
              {
                "pretext": "There are too many matching results to perform the balance update.\rHere are the cards I was able to find..."
                "text": ("#{r.formattedString()}" for r in result).join("\r")
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
                "pretext": "Thanks. I'll start tracking this card:"
                "text": "#{result.formattedString()}"
                "mrkdwn_in": [
                  "text",
                  "pretext"
                ]
              }
            ]
          })
        else msg.reply "I'm unsure what happened: #{messageKey}"

# Classes

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

  updateBalance: (number, balance, callback) ->
    if @all().length > 0
      results = @_findByNumber number
      if results.length == 1
        gc = new Giftcard results[0].name, balance, results[0].number, results[0].pin
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