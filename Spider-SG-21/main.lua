-- Copyright (c) 2022, kounch
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
local boySprites = {}
local spiderSprites = {}
local boatSprite = nil
local carSprite = nil
local playerId = 1
local lives = 0
local spiderIds = {4, 4, 4, 4, 4, 1}

print("Loading data...")
local positionsFile = playdate.file.open("positions.json")
assert(positionsFile)
local positionsTable = json.decodeFile(positionsFile)
assert(positionsTable)
local playerPositions = positionsTable.playerPositions
local spiderPositions = positionsTable.spiderPositions
local spiderMoves = {}
local spiderClicks = {}
local waitDelay = 50
local spiderDelay = 300
local clicksDelay = 0
local spiderAccel = 0
local score = 0
local scoreCount = 0
local webCount = 0
local gameStatus = 0  -- 0-Menu, 1-Game (A or B), -1-Game Starting , -2-Credis
local oldGameStatus = 0
local pauseGame = false
local endGame = false
local pauseGame = false
local doTurn = false
local doBoat = false

local boatTimer = nil
local legTimers = {nil, nil, nil, nil, nil}
local clicktimer = nil

print ("Loading assets...")
local digitTable = gfx.imagetable.new("Images/digits")
assert(digitTable)
local labelTable = gfx.imagetable.new("Images/labels")
assert(labelTable)
local playerTable = gfx.imagetable.new("Images/player")
assert(playerTable)
local spiderTable = gfx.imagetable.new("Images/spider")
assert(spiderTable)
local extraTable = gfx.imagetable.new("Images/extra")
assert(extraTable)
local backgroundImage = gfx.image.new("Images/fg")
assert(backgroundImage)

local deadSound = playdate.sound.sampleplayer.new("dead")
local clickSound = playdate.sound.sampleplayer.new("click")
local handSound = playdate.sound.sampleplayer.new("hand")
local endSound = playdate.sound.sampleplayer.new("gameover")

-- Functions
function myGameSetUp()
    for i = 1,4
    do
        digitSprites[i] = gfx.sprite.new(digitTable:getImage(1))
        local digitX = 195+i*28
        if i>2 then
            digitX+=11
        end
        digitSprites[i]:moveTo(digitX,28)
        digitSprites[i]:add()
    end

    local spriteX = 210
    local spriteY = 198
    for i = 1,3
    do
        labelSprites[i] = gfx.sprite.new(labelTable:getImage(i))
        labelSprites[i]:moveTo(spriteX, spriteY + i*16)
        labelSprites[i]:add()
        labelSprites[i]:setVisible(false)
    end
    labelSprites[3]:moveTo(158, 19)

    colonsSprite = gfx.sprite.new(digitTable:getImage(11))
    colonsSprite:moveTo(271, 28)
    colonsSprite:add()

    playerSprite = gfx.sprite.new(playerTable:getImage(playerPositions[playerId].id))
    playerSprite:moveTo(playerPositions[playerId].x, playerPositions[playerId].y)
    playerSprite:add()

    deadSprite = gfx.sprite.new(playerTable:getImage(playerPositions[11].id))
    deadSprite:moveTo(playerPositions[11].x, playerPositions[11].y)
    deadSprite:add()
    deadSprite:setVisible(false)

    for i = 1,2
    do
        liveSprites[i] = gfx.sprite.new(playerTable:getImage(playerPositions[6+i].id))
        liveSprites[i]:moveTo(playerPositions[6+i].x, playerPositions[6+i].y)
        liveSprites[i]:add()
        liveSprites[i]:setVisible(false)
    end

    for i = 1,3
    do
        boySprites[i] = gfx.sprite.new(playerTable:getImage(playerPositions[15+i].id))
        boySprites[i]:moveTo(playerPositions[15+i].x, playerPositions[15+i].y)
        boySprites[i]:add()
        boySprites[i]:setVisible(false)
    end

    carSprite = gfx.sprite.new(extraTable:getImage(1))
    carSprite:moveTo(playerPositions[9].x, playerPositions[9].y)
    carSprite:add()
    carSprite:setVisible(false)

    boatSprite = gfx.sprite.new(extraTable:getImage(2))
    boatSprite:moveTo(playerPositions[10].x, playerPositions[10].y)
    boatSprite:add()
    boatSprite:setVisible(false)

    for i = 1,6
    do
        spiderSprites[i] = {}
        for j = 1,spiderIds[i]
        do
            spiderSprites[i][j] = gfx.sprite.new(spiderTable:getImage(spiderPositions[i][j].id))
            spiderSprites[i][j]:moveTo(spiderPositions[i][j].x, spiderPositions[i][j].y)
            spiderSprites[i][j]:add()
            spiderSprites[i][j]:setVisible(false)
        end
        spiderIds[i] = 0
    end
    spiderIds[6] = 1

    gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            backgroundImage:draw(0,0)
        end
    )

    setPlaydateMenu()
end

function setPlaydateMenu()
    local sysMenu = playdate.getSystemMenu()
    local listMenuItems = sysMenu:getMenuItems()
    sysMenu:removeAllMenuItems()
    local menuItem, error = sysMenu:addMenuItem("Reset", resetGame)
    local menuItem, error = sysMenu:addMenuItem("Credits",
        function()
            oldGameStatus = gameStatus
            gameStatus = -2
        end
    )
end

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
    spiderSprites[6][1]:setVisible(isVisible)
end

function displayScore()
    local scoreDigits = {}
    scoreDigits[1] = score//1000
    scoreDigits[2] = (score%1000)//100
    scoreDigits[3] = (score%100)//10
    scoreDigits[4] = score%10

    colonsSprite:setVisible(false)
    spiderSprites[6][1]:setVisible(true)  -- Show spider eyes
    for i = 1,4
    do
        digitSprites[i]:setVisible(false)
        if score >= 10^(4-i) or i==4 then
            digitSprites[i]:setImage(digitTable:getImage(scoreDigits[i] + 1))
            digitSprites[i]:setVisible(true)
        end
    end
end

function startLegs()
    for i=1,5
    do
        spiderIds[i] = 0
        for j = 1,4
        do
            spiderSprites[i][j]:setVisible(false)
        end
        if legTimers[i] ~= nil then
            legTimers[i]:remove()
        end
        if spiderMoves[i]>0 then
            legTimers[i] = playdate.timer.performAfterDelay(spiderMoves[i], updateLeg, i)
        end
    end
end

function checkWeb()
    if legTimers[3]==nil and webCount >=50 then
        webCount -= 50
        local newDelay = spiderDelay * 3
        legTimers[3] = playdate.timer.performAfterDelay(newDelay, updateLeg, 3)
    end
end

function startClicks()
    local startDelay = positionsTable.clicks[1]
    spiderClicks = positionsTable.clicks[2]

    if clicktimer ~= nil then
        clicktimer:remove()
    end
    clicktimer = playdate.timer.performAfterDelay(startDelay, doClick, 1)
end

function doClick(clickId)
    clickSound:play()

    local currentDelay = spiderClicks[clickId] * clicksDelay

    clickId += 1
    if (clickId > #spiderClicks) then
        clickId = 1
    end
    clicktimer = playdate.timer.performAfterDelay(currentDelay, doClick, clickId)
end

function pauseSpider()
    if clicktimer ~= nil then
        clicktimer:pause()
    end
    for i=1,5
    do
        if legTimers[i] ~= nil then
            legTimers[i]:pause()
        end
    end
end

function startSpider()
    if clicktimer ~= nil then
        clicktimer:start()
    end
    for i=1,5
    do
        if legTimers[i] ~= nil then
            legTimers[i]:start()
        end
    end
end

function updateLeg(legId)
    if gameStatus>0 then
        spiderIds[legId] += 1
        local newDelay = spiderDelay
        if spiderIds[legId]>4 then
            spiderIds[legId] = 0
            newDelay *= 2
        end

        for j = 1,4
        do
            if j>spiderIds[legId] then
                spiderSprites[legId][j]:setVisible(false)
            else
                spiderSprites[legId][j]:setVisible(true)
            end
        end

        if legId~=3 or spiderIds[legId]~=0 then
            legTimers[legId] = playdate.timer.performAfterDelay(newDelay, updateLeg, legId)
        else
            legTimers[legId] = nil
        end
    end
end

function startGame(gameMode)
    print("Starting new game:" .. gameMode)
    lives = 2

    backgroundImage:load( "Images/bg" )
    assert(backgroundImage)
    gfx.sprite.redrawBackground()

    clearSprites()
    for i = 1,2
    do
        liveSprites[i]:setVisible(true)
    end
    carSprite:setVisible(true)
    boatSprite:setVisible(false)
    playerSprite:setVisible(true)
    waitAndPush(waitDelay)

    gameStatus = -1
    score = 0
    scoreCount = 0
    webCount = 0
    pauseGame = true
    endGame = false
    doTurn = true
    doBoat = true
    local r = math.random(1,2)
    spiderMoves = positionsTable.GameA[r]
    spiderDelay = positionsTable.GameA[3]
    clicksDelay = positionsTable.clicks[3]
    if gameMode>1 then
        spiderMoves = positionsTable.GameB[r]
        spiderDelay = positionsTable.GameB[3]
        clicksDelay = positionsTable.clicks[3]//2
    end
    for i = 1,3
    do
        labelSprites[i]:setVisible(false)
    end
    labelSprites[gameMode]:setVisible(true)
end

function resetGame()
    score = 0
    pauseGame = true
    endGame = false
    gameStatus = 0

    if clicktimer ~= nil then
        clicktimer:remove()
    end
    if boatTimer ~= nil then
        boatTimer:remove()
    end

    playdate.timer.performAfterDelay(260,
        function()
            clearSprites()
            backgroundImage:load( "Images/fg" )
            assert(backgroundImage)
            gfx.sprite.redrawBackground()
        end
    )
end

function gameOver()
    endSound:play()
    pauseGame = true
    endGame = true
    gameStatus = 0
    labelSprites[3]:setVisible(true)
    playdate.timer.performAfterDelay(4000,
        function()
            deadSprite:setVisible(false)
            playerSprite:setVisible(false)
            labelSprites[3]:setVisible(true)
        end
    )
end

function clearSprites()
    playerId = 1
    drawPlayer()

    for i = 1,2
    do
        liveSprites[i]:setVisible(false)
        labelSprites[i]:setVisible(false)
    end
    labelSprites[3]:setVisible(false)
    deadSprite:setVisible(false)
    carSprite:setVisible(false)
    boatSprite:setVisible(false)

    for i = 1,5
    do
        spiderIds[i] = 0
    end
    drawSpider()
end

function drawPlayer()
    playerSprite:setImage(playerTable:getImage(playerPositions[playerId].id))
    playerSprite:moveTo(playerPositions[playerId].x, playerPositions[playerId].y)
end

function killPlayer()
    lives -= 1
    if lives<0 then
        gameOver()
    else
        startSpider()
        deadSprite:setVisible(false)
        playerId = 1
        drawPlayer()
        waitAndPush(waitDelay)
        pauseGame = false
    end
end

function drawSpider()
    for i = 1,5
    do
        for j = 1,4
        do
            if j>spiderIds[i] then
                spiderSprites[i][j]:setVisible(false)
            else
                spiderSprites[i][j]:setVisible(true)
            end
        end
    end
end

function drawBoy(spriteId)
    if spriteId>1 then
        boySprites[spriteId-1]:setVisible(false)
    end
    if spriteId<4 then
        boySprites[spriteId]:setVisible(true)
        playdate.timer.performAfterDelay(100, drawBoy, spriteId+1)
    end
end

function drawMachete()
    if playerId == 6 then
        if playerSprite:getImage() == playerTable:getImage(playerPositions[playerId].id) then
            playerSprite:setImage(playerTable:getImage(playerPositions[playerId].anim))
            playdate.timer.performAfterDelay(100, drawMachete)
        elseif playerSprite:getImage() == playerTable:getImage(playerPositions[playerId].anim) then
            playerSprite:setImage(playerTable:getImage(playerPositions[playerId].id))
        end
    end
end

function drawHello(spriteId)
    if playerId==1 then
        playerSprite:setImage(playerTable:getImage(spriteId))
        local newId = playerPositions[playerId].anim
        if playerSprite:getImage() == playerTable:getImage(newId) then
            newId = playerPositions[playerId].id
        end
        handSound:play()
        playdate.timer.performAfterDelay(220, drawHello, newId)
    end
end

function drawKill(counter)
    deadSprite:setVisible(not deadSprite:isVisible())
    if counter>0 then
        playdate.timer.performAfterDelay(50, drawKill, counter-1)
    end
end

function waitAndPush(counter)
    if playerId==1 then
        if counter>0 then
            playdate.timer.performAfterDelay(100, waitAndPush, counter-1)
        else
            gameStatus = 1
            playerId=2
            drawPlayer()
        end
    end
end

function showCredits()
    gameStatus = -2

    local bgImage = gfx.image.new("Images/fg")
    bgImage:draw(0,0)

    gfx.setLineWidth(3)
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    gfx.fillRoundRect(20, 20, 360, 200, 5)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    gfx.drawRoundRect(20, 20, 360, 200, 5)

    bgImage = gfx.image.new("Images/qr")
    bgImage:draw(220,62)

    gfx.drawTextAligned("*Spider SG-21 for Playdate*", 200, 38, kTextAlignment.center)
    gfx.drawTextInRect("Scan this QR code to access the official web page at", 40, 75, 170, 100, nil, nil, kTextAlignment.left)
    gfx.drawTextAligned("_kounch.itch.io_", 150, 140, kTextAlignment.center)
    gfx.drawTextAligned("(C) Kounch 2022", 125, 182, kTextAlignment.center)
end

print("Game Init...")
myGameSetUp()
resetGame()

print("Main loop...")
function playdate.update()
    if doBoat then
        doBoat = false
        if boatTimer ~= nil then
            boatTimer:remove()
        end
        boatTimer = playdate.timer.performAfterDelay(10000,
            function()
                if gameStatus>-2 then
                    doBoat = true
                    local showBoat = not boatSprite:isVisible()
                    boatSprite:setVisible(showBoat)
                end
            end
        )
    end

    if gameStatus==0 then
        if playdate.buttonIsPressed(playdate.kButtonUp) then
            backgroundImage:load( "Images/bg" )
            assert(backgroundImage)
            gfx.sprite.redrawBackground()
            endGame = false
        elseif playdate.buttonJustPressed(playdate.kButtonA) then
            startGame(1)
        elseif playdate.buttonJustPressed(playdate.kButtonB) then
            startGame(2)
        else
            displayScore()
        end

        if endGame then
            displayScore()
        else
            displayTime()
        end
    elseif gameStatus>0 then
        if not pauseGame then
            if doTurn then
                doTurn = false
                local scoreDelay = spiderDelay//(1+score/130)
                playdate.timer.performAfterDelay(scoreDelay,
                    function()
                        displayScore()
                        doTurn = true
                    end
                )
            else
                doTurn = false
            end

            local moved = false
            if playdate.buttonJustPressed(playdate.kButtonRight) or playdate.buttonJustPressed(playdate.kButtonA) then
                if playerId < 6 then
                    playerId += 1
                    moved = true
                    if playerId==2 then
                        checkWeb()
                    end
                else
                    drawMachete()
                    if boatSprite:isVisible() and scoreCount<15 then
                        handSound:play()
                        score += 3
                        scoreCount += 1
                        webCount += 3
                        checkWeb()
                        drawBoy(1)
                    end
                end
            end

            if playdate.buttonJustPressed(playdate.kButtonLeft) then
                if playerId>2 or (playerId==2 and scoreCount>0) then
                    playerId -= 1
                    moved = true
                    if playerId == 1 then
                        score += 2
                        webCount += 2
                        scoreCount = 0
                        if score>50 and webCount>8 then
                            webCount += 50
                        end
                        drawHello(playerPositions[playerId].id)
                        waitAndPush(waitDelay-20)
                    end
                end
            end

            if (moved) then
                drawPlayer()
            end

            if playerId>1 and spiderSprites[playerId-1][4]:isVisible() then  -- Is it a kill?
                pauseGame = true
                scoreCount = 0
                deadSound:play()
                deadSprite:setImage(playerTable:getImage(playerPositions[playerId+9].id))
                deadSprite:moveTo(playerPositions[playerId+9].x, playerPositions[playerId+9].y)
                pauseSpider()
                drawKill(14)
                if lives>0 and lives<3 then
                    liveSprites[3-lives]:setVisible(false)
                end
                playdate.timer.performAfterDelay(1500, killPlayer)
            end
        end
    end

    if gameStatus<-1 then
        showCredits()
        if playdate.buttonJustPressed(playdate.kButtonA) then
            gameStatus = oldGameStatus
        end
    else
        if gameStatus<0 then
            displayScore()
            if playdate.buttonJustPressed(playdate.kButtonRight) or playdate.buttonJustPressed(playdate.kButtonA) then
                if not pauseGame then
                    doTurn = true
                    gameStatus = 1
                    playerId += 1
                    drawPlayer()
                    startLegs()
                    playdate.timer.performAfterDelay(30,
                        function ()
                            clickSound:play()
                            startClicks()
                        end
                    )
                end
            else
                pauseGame = false
            end
        end
        
        playdate.timer.updateTimers()
        gfx.sprite.update()
    end

end