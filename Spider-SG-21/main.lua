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
local timeSprites = {}
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
local spiderMoves = positionsTable.spiderMoves
local spiderTurn = 1
local spiderDelay = 300

print ("Loading assets...")
local digitTable = gfx.imagetable.new("Images/digits")
assert(digitTable)
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
        timeSprites[i] = gfx.sprite.new(digitTable:getImage(1))
        local digitX = 195+i*28
        if i>2 then
            digitX+=11
        end
        timeSprites[i]:moveTo(digitX,28)
        timeSprites[i]:add()
    end

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
    spiderSprites[6][1]:setVisible(true)

    gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            backgroundImage:draw(0,0)
        end
    )
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
        timeSprites[i]:setImage(digitTable:getImage(timeDigits[i]))
    end

    if timeTable.second%2== 0 then
        colonsSprite:setVisible(false)
    else
        colonsSprite:setVisible(true)
    end
end

function updateSpider()
    spiderIds[spiderMoves[spiderTurn]] += 1
    if spiderIds[spiderMoves[spiderTurn]] > 4 then
        spiderIds[spiderMoves[spiderTurn]] = 0
    end

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
end

print("Game Init...")
myGameSetUp()

print("Main loop...")
local doTurn = true
function playdate.update()
    if doTurn then
        doTurn = false
        playdate.timer.performAfterDelay(spiderDelay, 
            function()
                updateSpider()
                spiderTurn += 1
                local testSize = table.getsize(spiderMoves) - 3
                if spiderTurn>testSize then
                    spiderTurn = 1
                end
                doTurn = true
            end
        )
    end
        

    if playdate.buttonIsPressed(playdate.kButtonB) then
        if not bg then
            backgroundImage:load( "Images/fg" )
            assert(backgroundImage)
            gfx.sprite.redrawBackground()
            bg = true
        end
    elseif bg then
        backgroundImage:load( "Images/bg" )
        assert(backgroundImage)
        gfx.sprite.redrawBackground()
        bg = false
    else
        displayTime()
    end

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

    gfx.sprite.update()
    playdate.timer.updateTimers()
end