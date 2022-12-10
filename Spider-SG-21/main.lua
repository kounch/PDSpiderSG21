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
local bg = false
local playerId = 1

print("Loading data...")
local positionsFile = playdate.file.open("positions.json")
assert(positionsFile)
local positionsTable = json.decodeFile(positionsFile)
assert(positionsTable)
local playerPositions = positionsTable.playerPositions

print ("Loading assets...")
local digitTable = gfx.imagetable.new("Images/digits")
assert(digitTable)
local playerTable = gfx.imagetable.new("Images/player")
assert(playerTable)
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

print("Game Init...")
myGameSetUp()

print("Main loop...")
function playdate.update()
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
        if playerId > 2 then
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