# Description:
#   Play battleship
#
# Commands:
#   hubot I challenge <user> to battleship
#   hubot I accept <user> challenge
#   hubot Deploy <ship name> to <start-coord>:<end:coord> against <user>
#   hubot I'm ready to battle <user>
#   hubot Fire <coord> at <user>
#   hubot Show my board|shots|ships against <user>
#   hubot I surrender to <user>
#   hubot How do I setup my ships
#
# Author
#   curtistbone@gmail.com
#
# Notes
#   Cycle of the game is:
#     1. player1 challenges player2
#     2. player2 accepts challenge
#     3. both players setup their boards and indicate they are ready to start
#     4. player2 fires first and turns alternate
#     5. game ends when either:
#          - one of the players sinks all the other player's ships
#          - one of the players surrenders
#
#
#           SHOTS
#    A B C D E F G H I J
#  1 - - - - - - - - - -
#  2 - - - - - - - - - -
#  3 - - - - - - - - - -
#  4 - - - - - - - - - -
#  5 - - - - - - - - - -
#  6 - - - - - - - - - -
#  7 - - - - - - - - - -
#  8 - - - - - - - - - -
#  9 - - - - o - - - - -
# 10 - - - - - - x - - -
#    A B C D E F G H I J
#  1 - - - - - - - - - -
#  2 - - S S S x S - - -
#  3 - - - - - - o - - -
#  4 - - - - S o - - - -
#  5 S - - - S - - - - -
#  6 S - - - S - - - - -
#  7 S - - - - - - - - -
#  8 S - - - - - - - - -
#  9 - - - S S - - - - -
# 10 - - - - - - S S S -
#           SHIPS
#
#
# Ships
# Id Size Name       Coordinates
# 1  5    Carrier    c2:g2
# 2  4    Battleship a5:a8
# 3  3    Cruiser    g10:i10
# 4  3    Destroyer  e4:e6
# 5  2    Submarine  d9:e9
# 
# 
# Battleship  # Dictionary of competitions
#   PlayerA vs PlayerB
#     Stats # Dictionary
#       GamesPlayed: 10
#       Victories: 6
#       Defeats: 4
#       Surrenders: 0
#     Game
#       Challenger: [slack-id]
#       State {challenged|setup|battle|victory}
#       CurrentPlayer: [slack-id]
#       Boards  # Store as a dictionary <slack-id, PlayerObject>
#         Player
#           Id: [slack-id]
#           Ships
#             Idx Id Size Health Name      # Store as an array of ships
#             0   5  5    5      Carrier
#             1   4  4    4      Battleship
#             2   3  3    2      Cruiser    # Reduce Health on hit. Sunk when health = 0
#             3   2  3    3      Destroyer
#             4   1  2    2      Submarine
#           ShipsBoard
#                A B C D E F G H I J # Store board as array of arrays
#              1 - - - - - - - - - -
#              2 - - 0 0 0 0 0 - - - # Store the index of the ship to decrement
#              3 - - - - - - - - - -
#              4 - - - - 2 - - - - -
#              5 1 - - - x - - - - - # Replace ship index with 'x' on board where shot was a hit
#              6 1 - - - 2 - - - - -
#              7 1 - - - - - - - o - # Replace ship index with 'o' on board where shot was a miss
#              8 1 - - - - - - - - -
#              9 - - - 4 4 - - - - -
#             10 - - - - - - 3 3 3 -
#           Shots
#             [{'e9','o'},{'g10','x'}] # Array of {shot,result} kvp
#           ShotsBoard
#                A B C D E F G H I J
#              1 - - - - - - - - - -
#              2 - - - - - - - - - -
#              3 - - - - - - - - - -
#              4 - - - - - - - - - -
#              5 - - - - - - - - - -
#              6 - - - - - - - - - -
#              7 - - - - - - - - - -
#              8 - - - - - - - - - -
#              9 - - - - o - - - - - # replace '-' placeholder with 'o' for miss
#             10 - - - - - - x - - - # replace '-' placeholder with 'x' for hit


##
## HELPER METHODS
##
sortByValue = (a, b, r) ->
  r = if r then 1 else -1
  return -1*r if a > b
  return +1*r if a < b
  return 0

sortByKey = (key, a, b, r) ->
  return sortByValue a[key], b[key], r

roundNumber = (number, precision) ->
  precision = if precision? then Math.abs(precision) else 0
  multiplier = Math.pow(10, precision)
  result = Math.round(number * multiplier) / multiplier
  return result

##
## MODULE
##
module.exports = (robot) ->

##
## MODULE HELPER FUNCTIONS
##
  getBattleKey = (name1, name2) -> 
    key = ([name1,name2].sort (a,b) -> sortByValue a, b).join("||")
    console.log "BattleKey: #{key}"
    return key

  getBattle = (challenger, challenged) ->
    battleKey = getBattleKey challenger, challenged

    robot.brain.data.battleship ?= {}
    battle = robot.brain.data.battleship[battleKey]
    return battle

  startBattle = (challenger, challenged) ->
    battle = getBattle challenger, challenged
    if battle?.status is not "game-over"
      return {
        success: false
        battle: battle
      }
    
    console.log "Starting new battle..."
    battleKey = getBattleKey challenger, challenged
    battle = new Battle challenger, challenged
    robot.brain.data.battleship[battleKey] = battle
    return {
      success: true
      battle: battle
    }

  getPlayerStats = (name) ->
    robot.brain.data.battleship ?= {}
    robot.brain.data.battleship[name] ?= {
      username: name
      gamesPlayed: 0
      wins: 0
      totalShots: 0
      totalHits: 0
      hitPerc: 0
      shipsSunk: 0
    }

  computeAndRecordBattleStats = (battle) ->
    stats = {}

    for p in battle.players
      battleStats = {
        shots: p.shotsFired.length
        hits: (s for s in p.shotsFired when s.hit).length
        shipsSunk: (s for s in p.ships when s.health is 0).length
      }
      battleStats.hitPerc = roundNumber (battleStats.hits/battleStats.shots * 100), 2

      playerStats = getPlayerStats p.username
      if playerStats?
        playerStats.gamesPlayed++
        playerStats.wins = playerStats.wins + 1 if battleStats.shipsSunk is 5
        playerStats.totalShots += battleStats.shots
        playerStats.totalHits += battleStats.hits
        playerStats.hitPerc = roundNumber (playerStats.totalHits/playerStats.totalShots * 100), 2
        playerStats.shipsSunk += battleStats.shipsSunk

      stats[p.username] = {
        battle: battleStats
        overall: playerStats
      }

    console.log stats
    
    return stats

  prettyprintStats = (stats) ->
    unless stats?
      return null
    
    lines = [
      "Battle Stats"
      "```Shots : #{stats.battle.shots}"
      "Hits  : #{stats.battle.hits}"
      "Hit % : #{stats.battle.hitPerc}```"
      "Overall Stats"
      "```Games : #{stats.overall.gamesPlayed}"
      "Wins  : #{stats.overall.wins}"
      "Shots : #{stats.overall.totalShots}"
      "Hits  : #{stats.overall.totalHits}"
      "Hit % : #{stats.overall.hitPerc}"
      "Ships Sunk: #{stats.overall.shipsSunk}```"
    ]

    output = lines.join("\r")
    console.log output
    return output

  prettyprintShips = (player) ->
    unless player?.ships?
      return "No ships defined"

    colHeaders = "Size Health Deployed Name"
    data = ("#{s.size}    #{s.health}      #{if s.deployed then 'YES' else 'NO '}      #{s.name}" for s in player.ships).join("\r")
    output = "#{colHeaders}\r#{data}"
    return "```#{output}```"

  prettyprintBoard = (player, selection) ->
    console.log player.username
    unless player?.boards?
      return "No board defined"

    unless selection?
      selection = {
        shots: true
        ships: true
      }
    
    console.log selection

    colHeaders = "   A B C D E F G H I J"

    output = null
    if selection.shots? or selection.ships?
      lines = []
      if selection.shots
        rowNum = 0
        lines.push "          SHOTS"
        lines.push colHeaders
        lines.push ("#{rowNum++}| #{r.join(' ').replace /\d/g,'S'}" for r in player.boards.shots).join("\r")

      if selection.ships
        rowNum = 0
        lines.push colHeaders
        lines.push ("#{rowNum++}| #{r.join(' ').replace /\d/g,'S'}" for r in player.boards.ships).join("\r")
        lines.push "          SHIPS"
      
      output = "```#{lines.join("\r")}```"
    return output

  validateCoordinatePair = (coordinateA, coordinateB) ->
    unless coordinateA? and coordinateB?
      return false
    return coordinateA[0] is coordinateB[0] or coordinateA[1] is coordinateB[1]

  expandCoordinates = (coordinateA, coordinateB) ->
    unless coordinateA? and coordinateB?
      return null

    coordinates = []
    coordA = convertCoordinate coordinateA
    coordB = convertCoordinate coordinateB

    unless coordA? and coordB?
      return coordinates

    coordinates.push coordA

    #if the coordinates are the same, return the array with a single element
    if coordA.row is coordB.row and coordA.col is coordB.col
      return coordinates

    coordinates.push coordB

    if coordA.row is coordB.row
      #increment col
      for cValue in [(coordA.col)..coordB.col][1..-2]
        coordinates.push {
          row: coordA.row
          col: cValue
        }
    else
      #increment row
      for rValue in [(coordA.row)..coordB.row][1..-2]
        coordinates.push {
          row: rValue
          col: coordA.col
        }
    
    console.log coordinates
    return coordinates

  convertCoordinate = (coordinate) ->
    unless coordinate?
      return null
    row = coordinate[1]*1
    col = 0
    switch coordinate[0]
      when "a" then col = 0
      when "b" then col = 1
      when "c" then col = 2
      when "d" then col = 3
      when "e" then col = 4
      when "f" then col = 5
      when "g" then col = 6
      when "h" then col = 7
      when "i" then col = 8
      when "j" then col = 9
      else return null
    
    convertedCoordinate = { 
      row: row
      col: col
      }
    
    console.log "Coordinate: #{coordinate}"
    console.log convertedCoordinate
    return convertedCoordinate
##
## MODULE CLASSES
##
  class Battle
    constructor: (challenger, challenged) ->
      @challenger = challenger
      @challenged = challenged
      @state = 'challenge'
      @currentPlayer = challenged

      @players = [
        {
          username: challenger
          isReady: false
          ships: [
            {
              id: 1
              size: 2
              health: 2
              deployed: false
              name: "Submarine"
              coordinates: []
            },
            {
              id: 2
              size: 3
              health: 3
              deployed: false
              name: "Destroyer"
              coordinates: []
            },
            {
              id: 3
              size: 3
              health: 3
              deployed: false
              name: "Cruiser"
              coordinates: []
            },
            {
              id: 4
              size: 4
              health: 4
              deployed: false
              name: "Battleship"
              coordinates: []
            },
            {
              id: 5
              size: 5
              health: 5
              deployed: false
              name: "Carrier"
              coordinates: []
            }
          ]
          boards: {
            shots: [
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-']
            ]
            ships: [
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-']
            ]
          }
          shotsFired: []
        },
        {
          username: challenged
          isReady: false
          ships: [
            {
              id: 1
              size: 2
              health: 2
              deployed: false
              name: "Submarine"
              coordinates: []
            },
            {
              id: 2
              size: 3
              health: 3
              deployed: false
              name: "Destroyer"
              coordinates: []
            },
            {
              id: 3
              size: 3
              health: 3
              deployed: false
              name: "Cruiser"
              coordinates: []
            },
            {
              id: 4
              size: 4
              health: 4
              deployed: false
              name: "Battleship"
              coordinates: []
            },
            {
              id: 5
              size: 5
              health: 5
              deployed: false
              name: "Carrier"
              coordinates: []
            }
          ]
          boards: {
            "shots": [
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-']
            ]
            "ships": [
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-'],
              ['-','-','-','-','-','-','-','-','-','-']
            ]
          }
          shotsFired: []
        }
      ]

  class BattleStats
    constructor: () ->
      @gamesPlayed = 0
      @victories = 0
      @defeats = 0
      @surrenders = 0

##
## ROBOT LISTENERS
##
# hubot I challenge <user> to battleship
  robot.respond /I challenges? @?(.+) to battleship/i, (msg) ->
    challenger = msg.message.user.name.toLowerCase()
    challenged = msg.match[1].trim().toLowerCase()

    console.log "Challenger: #{challenger}"
    console.log "Challenged: #{challenged}"
    
    unless (robot.brain.userForName challenged)?
      msg.reply "Sorry, but I don't know who #{challenged} is..."
      return

    startBattleResult = startBattle challenger, challenged
    if startBattleResult.success
      msg.reply "I'll notify @#{startBattleResult.battle.challenged}"

      challengedUser = robot.brain.userForName challenged
      robot.send challengedUser, "@#{challenger} has challenged you to a friendly game of battleship.  Are you up to the challenge?\r\r_Send me the following command if you'd like to accept:_\r```I accept @#{challenger} challenge```"
    else
      if startBattleResult.battle.challenger is challenger
        msg.reply "You already challenged @#{challenged} to battleship"
      else
        msg.reply "You've already been challenged by @#{challenged}"

# hubot I accept <user> challenge
  robot.respond /I accept @?(.+) challenge/i, (msg) ->
    actor = msg.message.user.name.toLowerCase()
    opponent = msg.match[1].trim().toLowerCase()

    console.log "Actor: #{actor}"
    console.log "Opponent: #{opponent}"
    
    battle = getBattle opponent, actor
    
    if battle?
      if battle.challenged is actor
        if battle.state is "challenge"
          battle.state = "setup"

          nextStepMessage = "The next step is to deploy your ships."
          tutorialCommandMessage = "_Send me the following command if you'd like to review the tutorial to deploy your ships:_\r```How do I deploy my ships```"
          boardMessage = prettyprintBoard battle.players[0], { ships:true }
          shipsMessage = prettyprintShips battle.players[0] 

          msg.reply "Excellent!  #{nextStepMessage}\r\r#{tutorialCommandMessage}\r\r#{boardMessage}\r#{shipsMessage}"

          opponentUser = robot.brain.userForName opponent
          robot.send opponentUser, "@#{actor} has accepted your battleship challenge!  #{nextStepMessage}\r\r#{tutorialCommandMessage}\r\r#{boardMessage}\r#{shipsMessage}"
        else
          console.log battle.state
          msg.reply "Sorry, but your acceptance doesn't matter at this point in time..."
      else
        msg.reply "Nice try... but you are not the one who has been challenged..."
    else
      msg.reply "Umm...you might be losing your edge. @#{opponent} has not challenged you to battle. Perhaps you ought to challenge them.  ;)"

# hubot Deploy <ship name> to <start-coord>:<end:coord> against <user>
  robot.respond /Deploy (.+) to ([a-jA-J]\d):([a-jA-J]\d) against @?(.+)/i, (msg) ->
    actor = msg.message.user.name.toLowerCase()
    opponent = msg.match[4].trim().toLowerCase()
    shipName = msg.match[1].trim().toLowerCase()
    coordA = msg.match[2].trim().toLowerCase()
    coordB = msg.match[3].trim().toLowerCase()

    console.log "Actor: #{actor}"
    console.log "Opponent: #{opponent}"
    console.log "Ship Name: #{shipName}"
    console.log "Coordinate A: #{coordA}"
    console.log "Coordinate B: #{coordB}"

    battle = getBattle actor, opponent
    
    if battle?
      if battle.state is "setup"
        isValidCoordinatePair = validateCoordinatePair coordA, coordB
        coordinates = if isValidCoordinatePair then expandCoordinates coordA, coordB else null
        if coordinates? and coordinates.length > 0
          player = (p for p in battle.players when p.username is actor)[0]
          board = player.boards.ships
          ship = (s for s in player.ships when s.name.toLowerCase() is shipName)[0]
          if ship?
            # validate that cells match ship size
            if coordinates.length is ship.size
              # check the cells
              for c in coordinates
                cellValue = board[c.row][c.col]
                unless cellValue is '-' or cellValue is ship.id
                  msg.reply "I'm sorry but I cannot, in good conscience, let you crash your ships.  Try again!"
                  return
              # remove the ship from its current place
              if ship.deployed
                for c in ship.coordinates
                  board[c.row][c.col] = '-'
                ship.coordinates = []
              # deploy ship
              for c in coordinates
                board[c.row][c.col] = ship.id
                ship.coordinates.push c
              ship.deployed = true

              boardMessage = prettyprintBoard player, { ships:true }
              shipsMessage = prettyprintShips player
              fullyDeployedMessage = if (s for s in player.ships when not s.deployed).length > 0 then "" else "\r\rExcellent!  All your ships have been deployed.  Are ready to start the game?!  _Send me the following command when you're ready:_\r```I'm ready to battle @#{opponent}```"
              msg.reply "Anchors away!\r\r#{boardMessage}\r#{shipsMessage}#{fullyDeployedMessage}"
              msg.reply message
            else
              shipsMessage = prettyprintShips player 
              msg.reply "Those coordinates do not match the size of ship you are deploying.  Do the math and try again..."
          else
            shipsMessage = prettyprintShips player 
            msg.reply "I don't believe you have a ship by the name of _#{shipName}_.  Your ships are:\r#{shipsMessage}"
        else
          msg.reply "Those coordinates don't make sense to me.  Try again!"
      else
        msg.reply "Sorry, but you are not allowed to setup ships at this time..."
    else
      msg.reply "Umm...you might be losing your edge. @#{opponent} has not challenged you to battle. Perhaps you ought to challenge them.  ;)"

# hubot How do I setup my ships
  robot.respond /How do I deploy my ships/i, (msg) ->
    msg.reply "TBD"

# hubot Show my board|shots|ships against <user>
  robot.respond /Show (me )?my (boards?|shots?|ships?) against @?(.+)/i, (msg) ->
    actor = msg.message.user.name.toLowerCase()
    opponent = msg.match[3].trim().toLowerCase()
    boardType = msg.match[2].trim().toLowerCase()

    console.log "Actor: #{actor}"
    console.log "Opponent: #{opponent}"
    console.log "Board Type: #{boardType}"

    battle = getBattle actor, opponent
    if battle?
      type = { }
      switch boardType
        when "ship", "ships" then type = { ships:true, shots:false }
        when "shot", "shots" then type = { ships:false, shots:true }
        else type = { ships:true, shots:true }

      player = (p for p in battle.players when p.username is actor)[0]
      boardMessage = prettyprintBoard player, type
      msg.reply boardMessage
    else
      msg.reply "Umm...you might be losing your edge. @#{opponent} has not challenged you to battle. Perhaps you ought to challenge them.  ;)"

# hubot I'm ready to battle <user>
  robot.respond /I('m)? ready to battle @?(.+)/i, (msg) ->
    actor = msg.message.user.name.toLowerCase()
    opponent = msg.match[2].trim().toLowerCase()

    console.log "Actor: #{actor}"
    console.log "Opponent: #{opponent}"
    
    battle = getBattle opponent, actor

    if battle?
      if battle.state is "setup"
        player = (p for p in battle.players when p.username is actor)[0]
        arePlayersShipsDeployed = (s for s in player.ships when not s.deployed).length == 0
        if arePlayersShipsDeployed
          if not player.isReady
            player.isReady = true
            if (p for p in battle.players when p.isReady).length is 2
              #everyone is ready
              battle.state = "battle"
              commonMessage = "It's time!  All ships have been deployed and everyone is ready."
              
              challengerUser = robot.brain.userForName battle.challenger
              robot.send challengerUser, "#{commonMessage}  @#{battle.challenged} is first.  I'll let you know once it is your turn to play."

              challengedUser = robot.brain.userForName battle.challenged
              robot.send challengedUser, "#{commonMessage}  Fire when ready!!"
            else
              #only actor is ready
              msg.reply "Thanks for your declaration.  I'll let you know once the battle is about to begin."

              opponentUser = robot.brain.userForName opponent
              robot.send opponentUser, "@#{actor} has declared ready for battle.  Make sure to let me know you are ready once all your ships have been deployed."
          else
            msg.reply "You must be eager to battle. Once @#{opponent} is ready, I'll let you know..."
        else
          boardMessage = prettyprintBoard player, { ships:true }
          shipsMessage = prettyprintShips player
          msg.reply "You haven't even deployed all your ships?\r\r#{boardMessage}\r#{shipsMessage}!"
      else
        #TODO: different message based on battle.state
        msg.reply "Sorry, but you are not allowed to declare battle at this time..."
    else
      msg.reply "Umm...you might be losing your edge. @#{opponent} has not challenged you to battle. Perhaps you ought to challenge them.  ;)"

#  hubot Fire <coord> against <user>
  robot.respond /Fire ([a-jA-J]\d) (against|at)?\s?@?(.+)/i, (msg) ->
    actor = msg.message.user.name.toLowerCase()
    opponent = msg.match[3].trim().toLowerCase()
    targetCoord = msg.match[1].trim().toLowerCase()

    console.log "Actor: #{actor}"
    console.log "Opponent: #{opponent}"
    console.log "Coordinate: #{targetCoord}"

    battle = getBattle actor, opponent
    
    if battle?
      console.log "State: #{battle.state}"
      if battle.state is "battle"
        if battle.currentPlayer is actor
          targetCoordinate = convertCoordinate targetCoord
          if targetCoordinate?
            actorPlayer = (p for p in battle.players when p.username is actor)[0]
            opponentPlayer = (p for p in battle.players when p.username is opponent)[0]
            
            cellValue = opponentPlayer.boards.ships[targetCoordinate.row][targetCoordinate.col]
            if cellValue is "x" or cellValue is "o"
              # previously targeted coordinate
              msg.reply "You've already targeted that coordinate.  Please review your board and fire again."
            else 
              # valid targetCoord
              result =
              {
                hit: false
                text: ""
                oldCellValue: cellValue
                newCellValue: ""
                hitShipName: null
                sunk: false
                isGameover: false
              }

              if cellValue is "-"
                # empty
                result.hit = false
                result.text = "MISS"
                result.newCellValue = "o"
              else
                # ship
                shipId = cellValue*1
                hitShip = (s for s in opponentPlayer.ships when s.id is shipId)[0]
                hitShip.health--
                
                result.hit = true
                result.text = "HIT"
                result.newCellValue = "x"
                result.hitShipName = hitShip.name
                result.sunk = hitShip.health is 0
                result.isGameover = (s for s in opponentPlayer.ships when s.health > 0).length is 0
              
              console.log result
              
              # Update game objects
              actorPlayer.shotsFired.push {
                coord: targetCoord
                hit: result.hit
              }
              actorPlayer.boards.shots[targetCoordinate.row][targetCoordinate.col] = result.newCellValue
              opponentPlayer.boards.ships[targetCoordinate.row][targetCoordinate.col] = result.newCellValue

              if result.isGameover
                battle.state = "game-over"
                stats = computeAndRecordBattleStats battle
                statsOutput = {}
                statsOutput[actor] = prettyprintStats stats[actor]
                statsOutput[opponent] = prettyprintStats stats[opponent]
              else
                battle.currentPlayer = opponent

              # build message for ACTOR
              actorMessage = "#{result.text}!"
              actorMessage += "  You sunk their #{result.hitShipName}!" if result.sunk
              actorMessage += "\rYou sunk all @#{opponent} ships!  You are *VICTORIOUS!*" if result.isGameover
              
              actorBoard = if result.isGameover then prettyprintBoard actorPlayer else prettyprintBoard actorPlayer, { shots:true }
              actorStats = if result.isGameover then "\r\rHere are your stats:\r#{statsOutput?[actor]}\r\rHere are @#{opponent} stats:\r#{statsOutput?[opponent]}" else ""
              msg.reply "#{actorMessage}\r#{actorBoard}#{actorStats}"

              # build message for OPPONENT
              opponentUser = robot.brain.userForName opponent
              opponentMessage = "@#{actor} fired at #{targetCoord.toUpperCase()} and it was a #{result.text}!"
              opponentMessage += "  They #{if result.sunk then "sunk" else "hit"} your #{result.hitShipName}!" if result.hit              
              opponentMessage += if result.isGameover then "\rUnfortunately that was your last ship.  You've been *DEFEATED*" else "\rNow it is your turn.  Fire when ready..."
              
              opponentBoard = prettyprintBoard opponentPlayer
              opponentStats = if result.isGameover then "\r\rHere are your stats:\r#{statsOutput?[opponent]}\r\rHere are @#{actor} stats:\r#{statsOutput?[actor]}" else ""
              robot.send opponentUser, "#{opponentMessage}\r#{opponentBoard}#{opponentStats}"
          else
            msg.reply "Those coordinates don't make any sense.  Try again!"
        else
          msg.reply "Cheater cheater!  You need to wait your turn..."
      else
        msg.reply "What are you doing?!  Now is not the time to be firing missiles!"
    else
      msg.reply "Umm...you might be losing your edge. @#{opponent} has not challenged you to battle. Perhaps you ought to challenge them.  ;)"


# hubot reset bs
  robot.respond /reset bs/i, (msg) ->
    robot.brain.data.battleship = {}
    msg.reply "Battleship Brain reset..."

  robot.respond /fix bs @?(.+)/i, (msg) ->
    actor = msg.message.user.name.toLowerCase()
    opponent = msg.match[1].trim().toLowerCase()

    console.log "Actor: #{actor}"
    console.log "Opponent: #{opponent}"

    battle = getBattle actor, opponent
    if battle?
      battle.state = "battle"
      msg.reply "Battle.State = battle"

  robot.respond /get my stats/i, (msg) ->
    actor = msg.message.user.name.toLowerCase()

    console.log "Actor: #{actor}"

    stats = getPlayerStats actor
    console.log stats

  robot.respond /clear stats/i, (msg) ->
    actor = msg.message.user.name.toLowerCase()

    console.log "Actor: #{actor}"

    robot.brain.data.battleship[actor] = null
    msg.reply "Cleared stats for @#{actor}"
