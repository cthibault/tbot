# Description:
#   Manage your giftcard collection. GiftCards get stored in the robot brain
#   Also keeps a history of all transactions and automatically updates giftcard
#   balance 
#
# Commands:
#   hubot giftcard list - Lists stored giftcards
#   hubot giftcard add '<name>' with $<balance> and #:<number> (p:<pin>, c:<categories>) - Adds a new giftcard <pin> and <categories> are optional
#   hubot giftcard remove all - Removes all giftcards from storage
#   hubot giftcard find <number> - Finds specific giftcard (exact number required)
# TODO
#   hubot giftcard set balance on <number> to $<balance> - Updates the balance for a specific card (allow wildcard for number)
#   hubot giftcard set category on <number> to c:<categories> - Updates the balance for a specific card (allow wildcard for number)
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

  robot.respond /(gc|giftcard(s?)) remove all/i, (msg) ->
    wallet = new Wallet robot
    wallet.clear (messageKey) ->
      switch messageKey
        when "NoRobot" then msg.reply "I'm having an internal crisis..."
        when "Empty" then msg.reply "You already don't trust me with anything"
        when "Success" then msg.reply "All trace evidence has been removed"
        else msg.reply "I'm unsure what happened: #{messageKey}"
  
  robot.respond /(gc|giftcard(s?)) add.+/i, (msg) ->
    nameMatch = msg.match[0].match /'(.+)'/i
    balanceMatch = msg.match[0].match /\$(\S+)/i
    numberMatch = msg.match[0].match /#:(\d+)/i

    unless nameMatch? and balanceMatch? and numberMatch?
      msg.reply "You need to provide the card's Name, Balance, and Number for me to add the card to your wallet [#{nameMatch?}, #{balanceMatch?}, #{numberMatch?}]"
    
    pinMatch = msg.match[0].match /p:(\d+)/i
    categoryMatch = msg.match[0].match /c:(\S+)/i
    
    gc = new Giftcard nameMatch[1], balanceMatch[1]*100, numberMatch[1], pinMatch?[1], categoryMatch?[1]
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
  robot.respond /(gc|giftcard(s?)) find.+/i, (msg) ->
    numberMatch = msg.match[0].match /#:([\*\d]+)/i

    unless numberMatch?
      msg.reply "You need to provide the Number for me to search to your wallet"

    wallet = new Wallet robot

    wallet.find numberMatch[1], (err, results) ->
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

  list: (callback) ->
    if @all().length > 0
      results = []
      for entry in @all()
        if entry?
          results.push new Giftcard entry.name, entry.balance, entry.number, entry.pin, entry.categories
      callback null, results
    else
      callback "No Giftcards exist"

  add: (gc, callback) ->
    if gc?
      results = if @all().length > 0 then @_find gc.number else []
      if results.length > 0
        callback "Giftcard already exists"
      else
        @all gc
        callback null, "Giftcard added"
    else
      callback "Not a valid giftcard"

  find: (numberExp, callback) ->
    if @all().length > 0
      results = @_find numberExp
      if results.length > 0
        callback null, results
      else
        callback "No results found"
    else
      callback "Empty list"

  _find: (numberExp) ->
    exp = "^#{numberExp.replace /\*/g,".*"}$"
    results = []
    @all().forEach (gc) ->
      if gc and gc.number
        if RegExp(exp, "i").test gc.number
          results.push new Giftcard gc.name, gc.balance, gc.number, gc.pin, gc.categories
    return results

class Giftcard
  constructor: (name, balance, number, pin, categories) ->
    @name = name
    @balance = balance
    @number = number
    @pin = pin
    @categories = categories

  formattedString: ->
    balanceInDollars = (@balance / 100).toFixed(2)
    text = "*#{@name}*  $#{balanceInDollars}  #:#{@number}"
    if @pin?
      text += "  _p:#{@pin}_"
    if @pin?
      text += "  _c:#{@categories}_"
    return text