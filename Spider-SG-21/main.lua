-- Copyright (c) 2022, kounch
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics
gfx.setBackgroundColor(playdate.graphics.kColorWhite)

-- Global vars
local colonsSprite = nil
local digitSprites = {}
local labelSprites = {}
local playerSprite = nil
local spiderSprites = {}
local bg = false
local playerId = 1
local spiderIds = {4, 4, 4, 4, 4, 1}

print("Loading data...")
local positionsFile = playdate.file.open("positions.json")
assert(positionsFile)
local positionsTable = json.decodeFile(positionsFile)
assert(positionsTable)
local playerPositions = positionsTable.playerPositions
local spiderPositions = positionsTable.spiderPositions
local spiderMoves = positionsTable.spiderMovesA
local spiderTurn = 1
local spiderDelay = 300
local score = 0

print ("Loading assets...")
local digitTable = gfx.imagetable.new("Images/digits")
assert(digitTable)
local labelTable = gfx.imagetable.new("Images/labels")
assert(labelTable)
local playerTable = gfx.imagetable.new("Images/player")
assert(playerTable)
local spiderTable = gfx.imagetable.new("Images/spider")
assert(spiderTable)
local backgroundImage = gfx.image.new("Images/bg")
assert(backgroundImage)

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
end

function displayTime()
    local timeTable = playdate.getTime()
    -- print(timeTable.hour .. ":" .. timeTable.minute)
    local timeDigits = {}
    timeDigits[1] = timeTable.hour//10 + 1
    timeDigits[2] = timeTable.hour%10 + 1
    timeDigits[3] = timeTable.minute//10 + 1
    timeDigits[4] = timeTable.minute%10 + 1

    for i = 1,4
    do
        digitSprites[i]:setImage(digitTable:getImage(timeDigits[i]))
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
        if score > 10^(4-i)-2 then
            digitSprites[i]:setImage(digitTable:getImage(scoreDigits[i] + 1))
            digitSprites[i]:setVisible(true)
        end
    end
end

function updateSpider()
    for i = 1,5
    do
        for j = 1,4
        do
            if j > spiderIds[i] then
                spiderSprites[i][j]:setVisible(false)
            else
                spiderSprites[i][j]:setVisible(true)
            end
        end
    end

    if spiderMoves[spiderTurn] > 0 then
        spiderIds[spiderMoves[spiderTurn]] += 1
        if spiderIds[spiderMoves[spiderTurn]] > 4 then
            spiderIds[spiderMoves[spiderTurn]] = 0
        end
    end
end

local gameStatus = 0  -- 0-Menu, 1-Game A, 2-Game B
local endGame = true
local doTurn = false
function startGame(gameMode)
    print("Starting new game:" .. gameMode)
    gameStatus = gameMode
    score = 0
    endGame = false
    doTurn = true
    spiderTurn = 1
    spiderDelay = 30 + (2 - gameMode) * 220
    spiderMoves = positionsTable.spiderMovesA
    if gameMode>1 then
        spiderMoves = positionsTable.spiderMovesB
    end
    labelSprites[gameMode]:setVisible(true)
end

function resetGame()
    print("Reset!")
    for i = 1,5
    do
        spiderIds[i] = 0
    end
    spiderTurn = 1
    updateSpider()

    for i = 1,3
    do
        labelSprites[i]:setVisible(false)
        digitSprites[i]:setVisible(true)
    end
    gameStatus = 0
    endGame = true
end

print("Game Init...")
myGameSetUp()

print("Main loop...")
function playdate.update()
    if doTurn and not endGame then
        doTurn = false
        playdate.timer.performAfterDelay(spiderDelay, 
            function()
                displayScore()
                updateSpider()
                spiderTurn += 1
                if spiderTurn>#spiderMoves then
                    spiderTurn = 1
                end
                doTurn = true
            end
        )
    else
        doTurn = false
    end
        
    if gameStatus==0 then
        if playdate.buttonIsPressed(playdate.kButtonUp) then
            if not bg then
                backgroundImage:load( "Images/fg" )
                assert(backgroundImage)
                gfx.sprite.redrawBackground()
                bg = true
            end
        elseif playdate.buttonJustPressed(playdate.kButtonA) then
            startGame(1)
        elseif playdate.buttonJustPressed(playdate.kButtonB) then
            startGame(2)
        elseif bg then
            backgroundImage:load( "Images/bg" )
            assert(backgroundImage)
            gfx.sprite.redrawBackground()
            bg = false
        else
            displayTime()
        end
    else
        local moved = false
        if playdate.buttonJustPressed(playdate.kButtonRight) or playdate.buttonJustPressed(playdate.kButtonA) then
            if playerId < 6 then
                playerId += 1
                moved = true
            end
        end

        if playdate.buttonJustPressed(playdate.kButtonLeft) then
            if playerId > 1 then
                playerId -= 1
                moved = true
            end
        end

        if (moved) then
            playerSprite:setImage(playerTable:getImage(playerPositions[playerId].id))
            playerSprite:moveTo(playerPositions[playerId].x, playerPositions[playerId].y)
        end
    end

    gfx.sprite.update()
    playdate.timer.updateTimers()
end