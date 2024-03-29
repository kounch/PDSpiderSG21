-- Copyright (c) 2022-2023, kounch
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics
gfx.setBackgroundColor(gfx.kColorWhite)

-- Global vars
local colonsSprite = nil
local digitSprites = {}
local labelSprites = {}
local playerSprite = nil
local liveSprites = {}
local rescueSprites = {}
local enemySprites = {}
local shipSprite = nil
local originSprite = nil
local playerId = 1
local lives = 0
local enemyIds = {4, 4, 4, 4, 4, 1}

print("Loading data...")

local positionsFile = playdate.file.open("positions.json")
assert(positionsFile)
local positionsTable = json.decodeFile(positionsFile)
assert(positionsTable)
local gameName = positionsTable.game
local digitPosition = positionsTable.digitPosition
local labelPositions = positionsTable.labelPositions
local playerPositions = positionsTable.playerPositions
local enemyPositions = positionsTable.enemyPositions

local enemyMoves = {}
local enemyClicks = {}
local enemyDelay = 300
local enemyPostDelay = 850
local falseMove = 0
local waitDelay = 50
local shipDelay = 10000
local killDelay = 50
local clicksPositions = {}
local score = 0
local scoreCount = 0
local spcAtkCount = 0
local speederStart = 300
local speederStepper = 150
local gameStatus = 0  -- 0-Menu, 1-Game (A or B), 2-Demo Mode, -1-Game Starting , -2-Credits
local oldGameStatus = 0
local demoSense = 0
local moveDirection = 0
local crankRadius = 0
local crankSensitivity = 65
local pauseGame = false
local endGame = false
local ki = 1
local kb = false

-- Timers
local shipTimer = nil
local atkTimers = {nil, nil, nil, nil, nil}
local clickTimer = nil
local demoTimer = nil

print ("Loading assets...")
local digitTable = gfx.imagetable.new("Images/digits")
assert(digitTable)
local labelTable = gfx.imagetable.new("Images/labels")
assert(labelTable)
local playerTable = gfx.imagetable.new("Images/player")
assert(playerTable)
local enemyTable = gfx.imagetable.new("Images/enemy")
assert(enemyTable)
local extraTable = gfx.imagetable.new("Images/extra")
assert(extraTable)
local backgroundImage = gfx.image.new("Images/fg")
assert(backgroundImage)

-- Sounds
local deadSound = playdate.sound.sampleplayer.new("dead")
local clickSound = playdate.sound.sampleplayer.new("click")
local handSound = playdate.sound.sampleplayer.new("hand")
local extraSound = playdate.sound.sampleplayer.new("extra")
local endSound = playdate.sound.sampleplayer.new("gameover")


-- Functions

--------------------
-- Initialization
--------------------

-- Setup all sprites and Playdate menu. This is done only once
function myGameSetUp()
    for i = 1,4  -- Score or time digits
    do
        digitSprites[i] = gfx.sprite.new(digitTable:getImage(1))
        local digitX = digitPosition.x+i*28
        if i>2 then
            digitX+=11
        end
        digitSprites[i]:moveTo(digitX,digitPosition.y)
        digitSprites[i]:add()
    end

    for i = 1,3  -- Game type and game over labels
    do
        labelPos = labelPositions[i]
        labelSprites[i] = gfx.sprite.new(labelTable:getImage(labelPos.id))
        labelSprites[i]:moveTo(labelPos.x, labelPos.y)
        labelSprites[i]:add()
        labelSprites[i]:setVisible(false)
    end

    colonsSprite = gfx.sprite.new(digitTable:getImage(11))  -- Time colons sprite
    colonsSprite:moveTo(digitPosition.x+76, digitPosition.y)
    colonsSprite:add()

    playerSprite = gfx.sprite.new(playerTable:getImage(playerPositions[playerId].id))  -- Player sprite
    playerSprite:moveTo(playerPositions[playerId].x, playerPositions[playerId].y)
    playerSprite:add()

    deadSprite = gfx.sprite.new(playerTable:getImage(playerPositions[11].id))  -- Player kill indicator sprite
    deadSprite:moveTo(playerPositions[11].x, playerPositions[11].y)
    deadSprite:add()
    deadSprite:setVisible(false)

    for i = 1,2  -- Remaining lives sprites
    do
        liveSprites[i] = gfx.sprite.new(playerTable:getImage(playerPositions[6+i].id))
        liveSprites[i]:moveTo(playerPositions[6+i].x, playerPositions[6+i].y)
        liveSprites[i]:add()
        liveSprites[i]:setVisible(false)
    end

    for i = 1,3  -- Rescue sprites
    do
        rescueSprites[i] = gfx.sprite.new(playerTable:getImage(playerPositions[15+i].id))
        rescueSprites[i]:moveTo(playerPositions[15+i].x, playerPositions[15+i].y)
        rescueSprites[i]:add()
        rescueSprites[i]:setVisible(false)
    end

    originSprite = gfx.sprite.new(extraTable:getImage(1))  -- Origin sprite
    originSprite:moveTo(playerPositions[9].x, playerPositions[9].y)
    originSprite:add()
    originSprite:setVisible(true)

    shipSprite = gfx.sprite.new(extraTable:getImage(2))  -- Rescue ship sprite
    shipSprite:moveTo(playerPositions[10].x, playerPositions[10].y)
    shipSprite:add()
    shipSprite:setVisible(false)

    for i = 1,6  -- Attacks and other enemy sprites
    do
        enemySprites[i] = {}
        for j = 1,enemyIds[i]
        do
            enemySprites[i][j] = gfx.sprite.new(enemyTable:getImage(enemyPositions[i][j].id))
            enemySprites[i][j]:moveTo(enemyPositions[i][j].x, enemyPositions[i][j].y)
            enemySprites[i][j]:add()
            enemySprites[i][j]:setVisible(false)
        end
        enemyIds[i] = 0
    end
    enemyIds[6] = 1

	-- Background image for all sprites
    gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            backgroundImage:draw(0,0)
        end
    )

    setPlaydateMenu()
end

-- Adds menu for Playdate
function setPlaydateMenu()
    local gameOptions = playdate.datastore.read()
    if gameOptions and gameOptions.crankSensitivity then
        crankSensitivity = gameOptions.crankSensitivity
    end
    local sysMenu = playdate.getSystemMenu()
    local listMenuItems = sysMenu:getMenuItems()
    sysMenu:removeAllMenuItems()
    sysMenu:addMenuItem("Credits",
        function()
            oldGameStatus = gameStatus
            ki = 1
            kb = true
            gameStatus = -2
        end
    )
    local defaultMenuItem = (90 - crankSensitivity) / 5
    local menuOptions = {}
    for i = 1,9
    do
        menuOptions[i] = tostring(i)
    end
    sysMenu:addOptionsMenuItem("Sensitivity", menuOptions, defaultMenuItem, updateSensitivity)
    sysMenu:addMenuItem("Reset game", resetGame)
end

-- Updates sensitivity menu item
function updateSensitivity(value)
    crankSensitivity = 90 - 5 * tonumber(value)
    local gameOptions = {crankSensitivity = crankSensitivity}
    playdate.datastore.write(gameOptions)
end

-- Initialize enemy attack and initialize (if needed) the recurring timers 
function startAttacks()
    for i=1,5
    do
        enemyIds[i] = 0
        for j = 1,4
        do
            enemySprites[i][j]:setVisible(false)
        end
        if atkTimers[i] ~= nil then
            atkTimers[i]:remove()
            atkTimers[i] = nil
        end
        if enemyMoves[i]>0 then
            atkTimers[i] = playdate.timer.performAfterDelay(enemyMoves[i], updateAttack, i)
        else
            falseMove = i
        end
    end
end

-- Initialize the music (clicks) recurring timer
function startClicks()
    local startDelay = clicksPositions[1]
    enemyClicks = clicksPositions[2]

    if clickTimer ~= nil then
        clickTimer:remove()
    end
    clickTimer = playdate.timer.performAfterDelay(startDelay, doClick, 1)
end

-- Initialize and run (if needed) once timer for special (middle) attack
function checkSpcAtk()
    if falseMove>0 and atkTimers[falseMove]==nil and spcAtkCount >=50 then
        spcAtkCount -= 50
        local currentDelay = enemyDelay * falseMove
        if score>speederStart then
            currentDelay -= score // speederStepper * 50 * falseMove
        end
        atkTimers[falseMove] = playdate.timer.performAfterDelay(currentDelay, updateAttack, falseMove)
    end
end

----------------------
-- Recurring timers
----------------------

-- Music (click) sound and keep recurring timer working
function doClick(clickId)
    clickSound:play()

    local currentDelay = clicksPositions[3]
    if score>speederStart then
        currentDelay -= score // speederStepper * 3
    end
    currentDelay *= enemyClicks[clickId]

    clickId += 1
    if (clickId > #enemyClicks) then
        clickId = 1
    end
    clickTimer = playdate.timer.performAfterDelay(currentDelay, doClick, clickId)
end

-- Update enemy attack sprite and keep recurring timer if needed
function updateAttack(atkId)
    if gameStatus>0 then
        enemyIds[atkId] += 1
        local currentDelay = enemyDelay
        if enemyIds[atkId]>4 then
            enemyIds[atkId] = 0
            currentDelay = enemyPostDelay
        end
        if score>speederStart then
            currentDelay -= score // speederStepper * 50
        end

        for j = 1,4
        do
            if j>enemyIds[atkId] then
                enemySprites[atkId][j]:setVisible(false)
            else
                enemySprites[atkId][j]:setVisible(true)
            end
        end

        if atkId~=falseMove or enemyIds[atkId]~=0 then
            atkTimers[atkId] = playdate.timer.performAfterDelay(currentDelay, updateAttack, atkId)
        else
            atkTimers[atkId] = nil
        end
    end
end

-- Update ship sprite and keep recurring timer
function updateShip()
    if shipTimer ~= nil then
        shipTimer:remove()
        shipTimer = nil
    end
    currentDelay = shipDelay
    local showShip = not shipSprite:isVisible()
    if showShip and shipDelay<10000 then
        currentDelay = 10000 - shipDelay
    end
    shipSprite:setVisible(showShip)
    shipTimer = playdate.timer.performAfterDelay(currentDelay, updateShip)
end

-- Pause enemy and demo timers
function pauseEnemy()
    if clickTimer ~= nil then
        clickTimer:pause()
    end
    for i=1,5
    do
        if atkTimers[i] ~= nil then
            atkTimers[i]:pause()
        end
    end
    if demoTimer ~= nil then
        demoTimer:pause()
    end
end

-- Resume enemy and demo timers
function startEnemy()
    if clickTimer ~= nil then
        clickTimer:start()
    end
    for i=1,5
    do
        if atkTimers[i] ~= nil then
            atkTimers[i]:start()
        end
    end
    if demoTimer ~= nil then
        demoTimer:start()
    end
end

-- Timer to force player moving after inactivity next to origin
function waitAndPush(counter)
    if playerId==1 then
        if counter>0 then
            playdate.timer.performAfterDelay(100, waitAndPush, counter-1)
        else
            if gameStatus>0 then
                playerId=2
                drawPlayer()
            else
                doStart()
            end
        end
    end
end

-- Timer to move demo player
function waitAndMove()
    if not pauseGame then
        demoSense -= 1
        moveDirection=-1
        if demoSense>0 then
            moveDirection = 1
        elseif demoSense==0 then
            demoSense = -1
        end
        demoTimer = playdate.timer.performAfterDelay(killDelay*4, waitAndMove)
    end
end

---------------------------------------
-- Principal sprite drawing routines
---------------------------------------

-- Shows the current time using the digit sprites
function displayTime()
    local timeTable = playdate.getTime()
    local timeDigits = {}
    timeDigits[1] = timeTable.hour//10 + 1
    timeDigits[2] = timeTable.hour%10 + 1
    timeDigits[3] = timeTable.minute//10 + 1
    timeDigits[4] = timeTable.minute%10 + 1

    for i = 1,4
    do
        digitSprites[i]:setImage(digitTable:getImage(timeDigits[i]))
        digitSprites[i]:setVisible(true)
    end

    local isVisible = true
    if timeTable.second%2== 0 then
        isVisible = false
    end
    colonsSprite:setVisible(isVisible)
    enemySprites[6][1]:setVisible(isVisible)
end

-- Shows the current score using the digit sprites
function displayScore()
    local scoreDigits = {}
    scoreDigits[1] = score//1000
    scoreDigits[2] = (score%1000)//100
    scoreDigits[3] = (score%100)//10
    scoreDigits[4] = score%10

    colonsSprite:setVisible(false)
    enemySprites[6][1]:setVisible(true)  -- Show enemy "eyes"
    for i = 1,4
    do
        digitSprites[i]:setVisible(false)
        if score >= 10^(4-i) or i==4 then
            digitSprites[i]:setImage(digitTable:getImage(scoreDigits[i] + 1))
            digitSprites[i]:setVisible(true)
        end
    end
end

-- Reset almost all sprites and timers to the starting state before a new game
function clearSprites()
    playerId = 1
    drawPlayer()

    lives = 0
    drawLives()
    deadSprite:setVisible(false)
    originSprite:setVisible(false)
    shipSprite:setVisible(false)
    for i = 1,3
    do
        rescueSprites[i]:setVisible(false)
    end

    for i = 1,5
    do
        enemyIds[i] = 0
        if atkTimers[i] ~= nil then
            atkTimers[i]:remove()
            atkTimers[i] = nil
        end
    end
    if demoTimer~= nil then
        demoTimer:remove()
        demoTimer = nil
    end
    drawEnemy()
end

-- Select image and move player sprite
function drawPlayer()
    playerSprite:setImage(playerTable:getImage(playerPositions[playerId].id))
    playerSprite:moveTo(playerPositions[playerId].x, playerPositions[playerId].y)
end

-- Show or hide the lives sprites in the origin
function drawLives()
    for i = 1,2
    do
        liveSprites[3-i]:setVisible(lives>=i)
    end
end

-- Draw all enemy attack sprites at once
function drawEnemy()
    for i = 1,5
    do
        for j = 1,4
        do
            if j>enemyIds[i] then
                enemySprites[i][j]:setVisible(false)
            else
                enemySprites[i][j]:setVisible(true)
            end
        end
    end
end

-- Animate the rescue sprites
function drawRescue(spriteId)
    if gameStatus>0 then
        if spriteId>1 then
            rescueSprites[spriteId-1]:setVisible(false)
        end
        if spriteId<4 then
            rescueSprites[spriteId]:setVisible(true)
            playdate.timer.performAfterDelay(100, drawRescue, spriteId+1)
        end
    end
end

-- Animate the player rescue action
function drawArm()
    if gameStatus>0 then
        if playerId == 6 then
            if playerSprite:getImage() == playerTable:getImage(playerPositions[playerId].id) then
                playerSprite:setImage(playerTable:getImage(playerPositions[playerId].anim))
                playdate.timer.performAfterDelay(100, drawArm)
            elseif playerSprite:getImage() == playerTable:getImage(playerPositions[playerId].anim) then
                playerSprite:setImage(playerTable:getImage(playerPositions[playerId].id))
            end
        end
    end
end

-- Animate the player hello action next to the origin
function drawHello(spriteId)
    if gameStatus>0 then
        if playerId==1 then
            playerSprite:setImage(playerTable:getImage(spriteId))
            local newId = playerPositions[playerId].anim
            if playerSprite:getImage() == playerTable:getImage(newId) then
                newId = playerPositions[playerId].id
            end
            if gameStatus<2 then
                handSound:play()
            end
            playdate.timer.performAfterDelay(220, drawHello, newId)
        end
    end
end

-- Animate (flash) when the player is killed
function drawKill(counter, tmpSprite)
    deadSprite:setVisible(not deadSprite:isVisible())
    if counter == 9 then
        tmpSprite = gfx.sprite.new(playerTable:getImage(playerPositions[1].id))
        tmpSprite:moveTo(playerPositions[1].x, playerPositions[1].y)
        tmpSprite:add()
        if lives<3 then
            liveSprites[2]:setVisible(false)
        end
    end
    if counter == 5 then
        drawLives()
    end
    if counter>0 and gameStatus>0 then
        playdate.timer.performAfterDelay(killDelay, drawKill, counter-1, tmpSprite)
    elseif tmpSprite ~= nil then
        tmpSprite:remove()
        tmpSprite = nil
        if lives>=0 then
            deadSprite:setVisible(false)
            playerId = 1
            drawPlayer()
        end
    end
end

-- Pause everything and show the credits window
function showCredits()
    local bgImage = gfx.image.new("Images/fg")
    bgImage:draw(0,0)

    gfx.setLineWidth(3)
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    gfx.fillRoundRect(20, 20, 360, 200, 5)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    gfx.drawRoundRect(20, 20, 360, 200, 5)

    bgImage = gfx.image.new("Images/qr")
    bgImage:draw(225,70)

    gfx.drawTextAligned(gameName, 200, 38, kTextAlignment.center)
    gfx.drawTextInRect("Scan this QR code to access the official web page at", 40, 75, 170, 100, nil, nil, kTextAlignment.left)
    gfx.drawTextAligned("_kounch.itch.io_", 150, 140, kTextAlignment.center)
    gfx.drawTextAligned("© Kounch 2022-2023", 120, 182, kTextAlignment.center)
end


---------------------
-- Other functions
---------------------

-- Start game moving player and starting enemy and sound
function doStart()
    if not pauseGame then
        gameStatus = 1
        playerId += 1
        drawPlayer()
        startAttacks()
        playdate.timer.performAfterDelay(30,
            function ()
                clickSound:play()
                startClicks()
            end
        )
    end
end

-- Increase the score and, if needed, add extra life
function checkScore(scoreIncrease)
    if gameStatus<2 then
        score += scoreIncrease
    end
    spcAtkCount += scoreIncrease

    local scoreLimit = 300
    if scoreLimit>0 and score>scoreLimit-1 and score<scoreLimit+scoreIncrease then
        if gameStatus<2 then
            extraSound:play()
            lives += 1
            drawLives()
        end
    end
end

-- Finish player kill action
function killPlayer()
    if lives<0 then
        gameOver()
    else
        if gameStatus==2 then
            demoSense = -6
        else
            waitAndPush(waitDelay)
        end
        startEnemy()
        pauseGame = false
    end
end

-- Finish when there are no lives remaining
function gameOver()
    endSound:play()
    pauseGame = true
    endGame = true
    labelSprites[3]:setVisible(true)
    if clickTimer ~= nil then
        clickTimer:remove()
    end
    playdate.timer.performAfterDelay(4000,
        function()
            deadSprite:setVisible(false)
            if gameStatus>0 then
                playerSprite:setVisible(false)
                labelSprites[3]:setVisible(true)
                gameStatus = 0
            end
        end
    )
end

-- Stop everything and show the image with all sprites active
function resetGame()
    score = 0
    pauseGame = true
    endGame = false
    gameStatus = 0
    kb = false

    if clickTimer ~= nil then
        clickTimer:remove()
        clickTimer = nil
    end
    if shipTimer ~= nil then
        shipTimer:remove()
        shipTimer = nil
    end

    clearSprites()
    backgroundImage:load( "Images/fg" )
    assert(backgroundImage)
    gfx.sprite.redrawBackground()
end

-- Begin a new game (A or B) or start demo game mode
function startGame(gameMode)
    print("Starting new game:" .. gameMode)
    backgroundImage:load( "Images/bg" )
    assert(backgroundImage)
    gfx.sprite.redrawBackground()

    clearSprites()
    lives = 2
    drawLives()
    originSprite:setVisible(true)
    shipSprite:setVisible(false)
    playerSprite:setVisible(true)

    score = 0
    scoreCount = 0
    spcAtkCount = 0
    pauseGame = true
    endGame = false
    moveDirection = 0
    crankRadius = 0
    local r = math.random(1,2)

    falseMove = 0
    local newPositions = positionsTable.GameA
    clicksPositions = positionsTable.clicksA
    if gameMode==2 then
        newPositions = positionsTable.GameB
        clicksPositions = positionsTable.clicksB
    end

    if gameMode<3 then
        for i = 1,3
        do
            labelSprites[i]:setVisible(false)
        end
        gameStatus = -1
        waitAndPush(waitDelay)
        labelSprites[gameMode]:setVisible(true)
    else
        gameStatus = 2
        newPositions = positionsTable.Demo
        clicksPositions = {}
    end

    enemyMoves = newPositions[r]
    enemyDelay = newPositions[3]
    enemyPostDelay = newPositions[4]
    shipDelay = newPositions[5]
    killDelay = newPositions[6]

    if shipTimer ~= nil then
        shipTimer:remove()
        shipTimer = nil
    end
    shipTimer = playdate.timer.performAfterDelay(shipDelay, updateShip)

    if gameMode==3 then
        pauseGame = false
        demoSense = -8
        demoTimer = playdate.timer.performAfterDelay(800, waitAndMove)
        startAttacks()
    end
end


------------------
-- Main program
------------------

print("Game Init...")
myGameSetUp()
resetGame()

print("Main loop...")
function playdate.update()
    local kr = {playdate.kButtonUp, playdate.kButtonDown, playdate.kButtonLeft, playdate.kButtonRight, playdate.kButtonB, playdate.kButtonA}
    if gameStatus==0 or gameStatus==2 then
        if gameStatus==0 and playdate.buttonIsPressed(kr[1]) then
            backgroundImage:load( "Images/bg" )
            assert(backgroundImage)
            gfx.sprite.redrawBackground()
            endGame = false
            startGame(3)
        elseif playdate.buttonJustPressed(kr[6]) then
            startGame(1)
        elseif playdate.buttonJustPressed(kr[5]) then
            startGame(2)
        else
            displayScore()
        end

        if endGame then
            displayScore()
        else
            displayTime()
        end
    end

    if gameStatus>0 then
        if not pauseGame then
            if gameStatus<2 then
                displayScore()
            else
                displayTime()
            end

            local moved = false
            if gameStatus<2 then
                moveDirection = 0
                if playdate.buttonJustPressed(kr[4]) or playdate.buttonJustPressed(kr[6]) then
                    moveDirection = 1
                elseif playdate.buttonJustPressed(kr[3]) then
                    moveDirection = -1
                end
                if not playdate.isCrankDocked() then
                    crankRadius += playdate.getCrankChange()
                    if crankRadius>crankSensitivity then
                        moveDirection = 1
                        crankRadius = 0
                    elseif crankRadius<-crankSensitivity then
                        moveDirection = -1
                        crankRadius = 0
                    end
                end
            end
            
            if moveDirection == 1 then
                moveDirection = 0
                if playerId < 6 then
                    playerId += 1
                    moved = true
                    if playerId==2 then
                        checkSpcAtk()
                    end
                else
                    drawArm()
                    local newScore = 3
                    if scoreCount == 9 then
                        newScore = 18
                    end
                    if shipSprite:isVisible() and scoreCount<10 then
                        if gameStatus<2 then
                            handSound:play()
                        end
                        checkScore(newScore)
                        scoreCount += 1
                        checkSpcAtk()
                        drawRescue(1)
                    end
                end
            elseif moveDirection == -1 then
                moveDirection = 0
                if demoSense<-10 then
                    demoSense = 12
                end
                if playerId>2 or (playerId==2 and scoreCount>0) then
                    playerId -= 1
                    moved = true
                    if playerId == 1 then
                        checkScore(2)
                        scoreCount = 0
                        if score>50 and spcAtkCount>8 then
                            spcAtkCount += 50
                        end
                        drawHello(playerPositions[playerId].id)
                        if gameStatus<2 then
                            waitAndPush(waitDelay-20)
                        end
                    end
                end
            end

            if (moved) then
                drawPlayer()
            end

            if playerId>1 and enemySprites[playerId-1][4]:isVisible() then  -- Is it a kill?
                scoreCount = 0
                pauseGame = true
                if gameStatus<2 then
                    deadSound:play()
                    lives -= 1
                end
                deadSprite:setImage(playerTable:getImage(playerPositions[playerId+9].id))
                deadSprite:moveTo(playerPositions[playerId+9].x, playerPositions[playerId+9].y)
                pauseEnemy()
                drawKill(14)
                playdate.timer.performAfterDelay(30 * killDelay, killPlayer)
            end
        end
    end

    if gameStatus<-1 then
        local kc = {1, 1, 2, 2, 3, 4, 3, 4, 5, 6}
        showCredits()
        if kb and playdate.buttonJustPressed(kr[kc[ki]]) then
            ki+=1
            if ki==11 then
                if oldGameStatus==1 then
                    extraSound:play()
                    lives += kc[1]
                    drawLives()
                end
            end
        end
        if playdate.buttonJustPressed(kr[6]) then
            gameStatus = oldGameStatus
            kb = false
        end
    else
        if gameStatus<0 then
            displayScore()

            local startMoving = false
            if playdate.buttonJustPressed(kr[4]) or playdate.buttonJustPressed(kr[6]) then
                startMoving = true
            end
            if not playdate.isCrankDocked() then
                crankRadius += playdate.getCrankChange()
                if crankRadius>crankSensitivity then
                    startMoving = true
                end
            end

            if startMoving then
                doStart()
            else
                pauseGame = false
            end
        end
        
        playdate.timer.updateTimers()
        gfx.sprite.update()
    end
end
