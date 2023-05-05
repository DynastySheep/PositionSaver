-- StorePosition
-- By Dynasty

local VERSION = 0.1
util.require_natives(1627063482)

-- [[Auto Updater from https://github.com/hexarobi/stand-lua-auto-updater
local status, auto_updater = pcall(require, "auto-updater")
if not status then
    local auto_update_complete = nil util.toast("Installing auto-updater...", TOAST_ALL)
    async_http.init("raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
        function(result, headers, status_code)
            local function parse_auto_update_result(result, headers, status_code)
                local error_prefix = "Error downloading auto-updater: "
                if status_code ~= 200 then util.toast(error_prefix..status_code, TOAST_ALL) return false end
                if not result or result == "" then util.toast(error_prefix.."Found empty file.", TOAST_ALL) return false end
                filesystem.mkdir(filesystem.scripts_dir() .. "lib")
                local file = io.open(filesystem.scripts_dir() .. "lib\\auto-updater.lua", "wb")
                if file == nil then util.toast(error_prefix.."Could not open file for writing.", TOAST_ALL) return false end
                file:write(result) file:close() util.toast("Successfully installed auto-updater lib", TOAST_ALL) return true
            end
            auto_update_complete = parse_auto_update_result(result, headers, status_code)
        end, function() util.toast("Error downloading auto-updater lib. Update failed to download.", TOAST_ALL) end)
    async_http.dispatch() local i = 1 while (auto_update_complete == nil and i < 40) do util.yield(250) i = i + 1 end
    if auto_update_complete == nil then error("Error downloading auto-updater lib. HTTP Request timeout") end
    auto_updater = require("auto-updater")
end
if auto_updater == true then error("Invalid auto-updater lib. Please delete your Stand/Lua Scripts/lib/auto-updater.lua and try again") end

local auto_update_config = {
    source_url="https://raw.githubusercontent.com/DynastySheep/PositionSaver/main/PositionSaver.lua",
    script_relpath=SCRIPT_RELPATH,
}

auto_updater.run_auto_update(auto_update_config)

-- Auto Updater Ends Here!

-- Read/Write position_data
local filename = "position_data.lua"
local path = filesystem.store_dir() .. filename

local file = io.open(path, "r")
local positionsData = {}
local spriteTable = {}
local listData = {}
local bookmarksData = {}

local createdBookmarks = {}
local bookmarksForBlips = {}

local defaultSprite = 1
local defaultColor = 5
local defaulScale = 7.0
local defaultBookmark = "default_library"


function table.find(t,v)
    for i, value in ipairs(t) do
        if value == v then
            return i
        end
    end
    return nil
end


-- Blip functions
local function nameExists(name)
    for _, data in ipairs(positionsData) do
        if data.name == name then
            return true
        end
    end

    for _, data in ipairs(bookmarksData) do
        if data.name == name then
            return true
        end
    end 

    return false
end

-- if name already exists, append a number to the end to make it unique
local function GetUniqueName(name)
    local newName = name
    local count = 1
    while nameExists(newName) do
        count = count + 1
        newName = name .. " " .. count
    end
    return newName
end

function TeleportToBlip(x, y, z)
    local playerPed = PLAYER.PLAYER_PED_ID()
    local playerPos = ENTITY.GET_ENTITY_COORDS(playerPed, true)
    local vehicle = PED.GET_VEHICLE_PED_IS_USING(playerPed)
    local coords = {x = x, y = y, z = z}

    if vehicle ~= 0 then
        ENTITY.SET_ENTITY_COORDS(vehicle, coords.x, coords.y, coords.z, false, false, false, true)
    else
        ENTITY.SET_ENTITY_COORDS(playerPed, coords.x, coords.y, coords.z, false, false, false, true)
    end
end

function RenameBlip(oldName, newName)
    if newName ~= nil and newName ~= "" then
        for i, data in ipairs(positionsData) do
            if data.name == oldName then
                data.name = newName
                WriteToFile()
                break
            end
        end
    end
end


function ShowExistingBookmarks(blipdataInfo, blipInstance, bookmarkMenu)
    for i, data in ipairs(createdBookmarks) do
        local newBookmark = menu.action(bookmarkMenu, menu.get_menu_name(data), {}, "", function()
            local detachedMenu = menu.detach(blipInstance)
            detachedMenu = menu.attach(data, detachedMenu)
            blipdataInfo.bookmark = menu.get_menu_name(data)
            WriteToFile()
        end)
        table.insert(bookmarksForBlips, newBookmark)
    end
end

function RefreshExistingBookmarks()
    if #bookmarksForBlips > 0 then
        for i, data in ipairs(bookmarksForBlips) do
            menu.delete(data)
            bookmarksForBlips[i] = nil
        end
    end
end

function SetSpriteValues(blip, blipColor, blipSprite, blipScale)
    HUD.SET_BLIP_SPRITE(blip, blipSprite) -- Set the blip sprite to a standard waypoint
    HUD.SET_BLIP_COLOUR(blip, blipColor) -- Set the blip color to blue
    HUD.SET_BLIP_SCALE(blip, blipScale/10) -- Set the blip scale to normal size
    HUD.SET_BLIP_AS_SHORT_RANGE(blip, false) -- Set the blip as a long-range blip
    HUD.SET_BLIP_DISPLAY(blip, 2) -- Set the blip to show on both the map and minimap
end

function RemoveBlipSprite(blip)
    util.remove_blip(blip)
end

function MoveBlipToCurrentPos(storeBlipData, blipSprite)        
    local playerPed = PLAYER.PLAYER_PED_ID()
    local playerPos = ENTITY.GET_ENTITY_COORDS(playerPed, true)

    storeBlipData.x = playerPos.x
    storeBlipData.y = playerPos.y
    storeBlipData.z = playerPos.z

    HUD.SET_BLIP_COORDS(blipSprite, storeBlipData.x, storeBlipData.y, storeBlipData.z)
end

-- Menu components
menu.divider(menu.my_root(), "Main")

-- Add blips to the list (For importing and creating)
local savedBlips = menu.list(menu.my_root(), "Blips Creator", {}, "")

menu.text_input(savedBlips, "Create new blip ", {"create_new_blip"}, "", function(blipName)   
    if blipName ~= nil and blipName ~= "" then
        local playerPed = PLAYER.PLAYER_PED_ID()
        local playerPos = ENTITY.GET_ENTITY_COORDS(playerPed, true)
        local x, y, z = playerPos.x, playerPos.y, playerPos.z

        for i, data in ipairs(positionsData) do
            if data.name == blipName then
                blipName = GetUniqueName(blipName)
                break
            end
        end

        -- Store the data
        local blipdataInfo = {
            name = blipName, 
            x = x, 
            y = y, 
            z = z,
            blip = blip,
            blipColor = defaultColor,
            blipSprite = defaultSprite,
            blipScale = defaulScale,
            bookmark = defaultBookmark
        }

        table.insert(positionsData, blipdataInfo)
        LoadBlip(blipdataInfo)        
        WriteToFile() -- Write the updated data back to the file
        util.toast("Current position saved")
    end
end, "")

local quickTeleportList = {}
local teleportList
teleportList = menu.list(savedBlips, "Quick teleport", {}, "", function()
    local children = menu.get_children(savedBlips)

    if #children > 0 then
        for i, v in ipairs(children) do 
            for j,k in ipairs(positionsData) do
                if k.name == menu.get_menu_name(v) then           
                    local tpEntry = menu.action(teleportList, menu.get_menu_name(v), {}, "", function()
                        TeleportToBlip(k.x, k.y, k.z)
                    end)
                    table.insert(quickTeleportList, tpEntry)
                end
            end   
        end 
    end
end)

menu.on_focus(teleportList, function()
    for i,v in ipairs(quickTeleportList) do
        menu.delete(v)
        quickTeleportList[i] = nil
    end
end)

menu.divider(savedBlips, "Saved Blips")

local settingsWindow = menu.list(menu.my_root(), "Settings")
local removeWindow = menu.list(settingsWindow, "Remove blips data", {}, "WARNING - Removes all data of your saved positions")
menu.action(removeWindow, "Are you sure? This will remove all positions", {}, "", function()
    RemoveSavedBlipsList()
    RefreshFile()
end)

-- Manually check for updates with a menu option
menu.action(settingsWindow, "Check for Update", {}, "The script will automatically check for updates at most daily, but you can manually check using this option anytime.", function()
    auto_update_config.check_interval = 0
    util.toast("Checking for updates")
    auto_updater.run_auto_update(auto_update_config)
end)

menu.text_input(menu.my_root(), "Create new bookmark", {"create_new_bookmark"}, "", function(bookmarkName)
    if bookmarkName ~= nil and bookmarkName ~= "" then   
        
        for i, data in ipairs(bookmarksData) do
            if data.name == bookmarkName then
                bookmarkName = GetUniqueName(bookmarkName)
                break
            end
        end

        local bookmarkInfo = {
            name = bookmarkName
        }

        LoadBookmark(bookmarkInfo)
        table.insert(bookmarksData, bookmarkInfo)
        WriteToFile() -- Write the updated data back to the file
    end
end, "")


function LoadBookmark(bookmarkInfo)
    local newBookmark = menu.list(menu.my_root(), bookmarkInfo.name)
    local settingsList = menu.list(newBookmark, "Settings")

    local quickTeleportList = {}

    menu.text_input(settingsList, "Rename", {"rename_existing_bookmark" ..bookmarkInfo.name}, "", function(newName)
        
        if newName ~= nil and newName ~= "" then
            bookmarkInfo.name = newName
            menu.set_menu_name(newBookmark, newName)

            local children = menu.get_children(newBookmark)

            for i, v in ipairs(children) do     
                for j,k in ipairs(positionsData) do
                    if k.name == menu.get_menu_name(v) then                    
                        k.bookmark = bookmarkInfo.name
                    end
                end   
            end  
            WriteToFile()
        end
    end)

    menu.action(settingsList, "Remove bookmark", {}, "", function()  

        local children = menu.get_children(newBookmark)

        for i, v in ipairs(children) do     
            for j,k in ipairs(positionsData) do
                if k.name == menu.get_menu_name(v) then                    
                    local detachedChild = menu.detach(v)
                    detachedChild = menu.attach(savedBlips, detachedChild)
                    k.bookmark = defaultBookmark
                end
            end   
        end  
        
        menu.delete(newBookmark)
        for i, data in ipairs(bookmarksData) do
            if data.name == bookmarkInfo.name then
                table.remove(bookmarksData, i)
                table.remove(createdBookmarks, i)
                WriteToFile()
                break
            end
        end
    end)


    local teleportList
    teleportList = menu.list(newBookmark, "Quick teleport", {}, "", function()
        local children = menu.get_children(newBookmark)

        if #children > 0 then
            for i, v in ipairs(children) do 
                for j,k in ipairs(positionsData) do
                    if k.name == menu.get_menu_name(v) then           
                        local tpEntry = menu.action(teleportList, menu.get_menu_name(v), {}, "", function()
                            TeleportToBlip(k.x, k.y, k.z)
                        end)
                        table.insert(quickTeleportList, tpEntry)
                    end
                end   
            end 
        end
    end)

    menu.on_focus(teleportList, function()
        for i,v in ipairs(quickTeleportList) do
            menu.delete(v)
            quickTeleportList[i] = nil
        end
    end)

    menu.divider(newBookmark, "Saved Blips")

    table.insert(createdBookmarks, newBookmark)
    
    menu.on_blur(newBookmark, function()
        WriteToFile()
    end)
end

menu.divider(menu.my_root(), "Bookmarks")

--[[
-- // Roses

local roseObj = util.joaat("prop_single_rose")
local roses = {}

-- Spawn roses at player's position
function SpawnRoses()
    local playerPed = PLAYER.PLAYER_PED_ID()
    local playerCoords = ENTITY.GET_ENTITY_COORDS(playerPed, true)
    local rose = OBJECT.CREATE_OBJECT(roseObj, playerCoords.x, playerCoords.y, playerCoords.z, true, true, false)
    if #roses <= 100 then
        table.insert(roses, rose)
    end
end

-- Remove all spawned roses
function RemoveRoses()
    for i=1, #roses do
        local ent = roses[i]
        if ENTITY.DOES_ENTITY_EXIST(ent) then
            entities.delete_by_handle(ent)
        end
    end
    roses = {}
end

-- Add menu action to spawn roses
menu.action(menu.my_root(), "Spawn Roses", {}, "Spawn roses at your location", function()
    SpawnRoses()
end)

-- Add menu action to remove all spawned roses
menu.action(menu.my_root(), "Remove Roses", {}, "Remove all spawned roses", function()
    RemoveRoses()
end)
-- // Roses
]]

function LoadBlip(blipdataInfo)
    local blipSprite = HUD.ADD_BLIP_FOR_COORD(blipdataInfo.x, blipdataInfo.y, blipdataInfo.z)

    local blipLocation

    if blipdataInfo.bookmark ~= "default_library" then
        for i, data in ipairs(createdBookmarks) do
            if blipdataInfo.bookmark == menu.get_menu_name(data) then
                blipLocation = data
            end
        end
    else
        blipLocation = savedBlips
    end

    local blipInstance = menu.list(blipLocation, blipdataInfo.name)
    local teleportAction = menu.action(blipInstance, "Teleport to " ..blipdataInfo.name, {}, "Teleports you to selected blip", function()
        TeleportToBlip(blipdataInfo.x,blipdataInfo.y,blipdataInfo.z)
    end)

    menu.divider(blipInstance, "Adjustments")
    local textAction = menu.text_input(blipInstance, "Name ", {"rename_current_blip"..blipdataInfo.name}, "Name your blip", function(newName) 
        blipdataInfo.name = newName
        menu.set_menu_name(blipInstance, newName)
        menu.set_menu_name(teleportAction, "Teleport to " ..newName)
    end, blipdataInfo.name)

    --[[ Blip Colors
        Colors: 
        White > Black = 4, 55, 40
        Red = 41, 1, 76
        Green = 11, 2, 52
        Blue = 18, 3, 78
        Yellow = 36, 5, 28
        Purple = 58, 83, 7
        Pink = 19, 8, 41
        Orange = 64, 47, 9
        Cyan = 18
        Navy Blue = 38
    ]]

    local colors = {
        value = {
            4, 55, 40, 41, 1, 76, 11, 2, 52, 18, 3, 78, 36, 5, 28, 7, 83, 58, 41, 8, 19, 9, 47, 64, 18, 38
        },
        name = {
            "White", "Grey", "Black", 
            "Light red", "Red", "Dark red", 
            "Light green", "Green", "Dark green",
            "Light blue", "Blue", "Dark blue",
            "Light yellow", "Yellow", "Dark yellow",
            "Light purple", "Purple", "Dark purple",
            "Light pink", "Pink", "Dark pink",
            "Light orange", "Orange", "Dark orange",
            "Cyan", "Navy blue"
        }   
    }

    local currentColorIndex = table.find(colors.value, blipdataInfo.blipColor)
    local chosenColor = blipdataInfo.blipColor or defaultColor
    
    menu.list_select(blipInstance, "Color ", {}, "Set color for your blip", colors.name, currentColorIndex or defaultColor, function(selectedIndex)  
        local selectedValue = colors.value[selectedIndex]
        HUD.SET_BLIP_COLOUR(blipSprite, selectedValue)
        blipdataInfo.blipColor = selectedValue
        chosenColor = selectedValue
    end)

    local sprites = {
        value = {
            1, 744, 133, 439
        },
        name = {
            "Destination", "Camera", "Snitch", "Crown"
        }            
    }
    
    local currentSpriteIndex = table.find(sprites.value, blipdataInfo.blipSprite)

    menu.list_select(blipInstance, "Sprite ", {}, "Set sprite for your blip", sprites.name, currentSpriteIndex or defaultSprite, function(selectedIndex)  
        local selectedValue = sprites.value[selectedIndex]
        HUD.SET_BLIP_SPRITE(blipSprite, selectedValue)
        HUD.SET_BLIP_COLOUR(blipSprite, chosenColor)
        blipdataInfo.blipSprite = selectedValue
    end)

    local currentSpriteScale = blipdataInfo.blipScale
    menu.slider(blipInstance, "Scale ", {}, "Set scale of your blip", 6, 14, currentSpriteScale or defaulScale, 1, function(value)  
        HUD.SET_BLIP_SCALE(blipSprite, value/10)
        blipdataInfo.blipScale = value
    end)   

    menu.toggle(blipInstance, "Is visible ", {}, "Will you see the blip?", function(isChecked)
        if isChecked then
            HUD.SET_BLIP_ALPHA(blipSprite, 255)
        else
            HUD.SET_BLIP_ALPHA(blipSprite, 0)
        end
    end, true)

    menu.divider(blipInstance, "Settings")
    menu.action(blipInstance, "Move blip to current location", {}, "", function()
        MoveBlipToCurrentPos(blipdataInfo, blipSprite)
    end)

    local bookmarkMenu
    bookmarkMenu = menu.list(blipInstance, "Move to bookmark", {}, "", function()
        ShowExistingBookmarks(blipdataInfo, blipInstance, bookmarkMenu)
    end)

    menu.on_focus(bookmarkMenu, function()
        RefreshExistingBookmarks()
    end)
    
    menu.action(bookmarkMenu, "Clear bookmark", {}, "", function()
        local currentParent = menu.get_parent(blipInstance)
        if currentParent ~= savedBlips then
            local detachedMenu = menu.detach(blipInstance)
            detachedMenu = menu.attach(savedBlips, detachedMenu)
            blipdataInfo.bookmark = defaultBookmark
            WriteToFile()
        end
    end)
    menu.divider(bookmarkMenu, "")

    menu.action(blipInstance, "Remove ", {}, "Removes current blip", function()
        RemoveBlipSprite(blipSprite)
        RemoveFromList(blipInstance, blipdataInfo.name)
        menu.delete(blipInstance)
    end)

    SetSpriteValues(blipSprite, blipdataInfo.blipColor, blipdataInfo.blipSprite, blipdataInfo.blipScale)
    table.insert(spriteTable, blipSprite)
    table.insert(listData, blipInstance)
    menu.on_blur(blipInstance, function()
        WriteToFile()
    end)

end

-- Removal Functions
function RemoveSavedBlipsList()
    if #listData > 0 then
        for i, data in ipairs(listData) do
            menu.delete(data)
        end
    end

    for i, blip in ipairs(spriteTable) do
        util.remove_blip(blip)
    end

    for i, data in ipairs(createdBookmarks) do
        menu.delete(data)
    end

    spriteTable = {}
    listData = {}
    positionsData = {}
    bookmarksData = {}
    createdBookmarks = {}
end

function RemoveFromList(blipInstance, name)
    for i, data in ipairs(positionsData) do
        if data.name == name then
            table.remove(positionsData, i)
            break
        end
    end

    for i, instance in ipairs(listData) do
        if instance == blipInstance then
            table.remove(listData, i)
            break
        end
    end
    WriteToFile()
end

-- Data handling functions

-- Write the positions data to a file

util.on_pre_stop(function()
    WriteToFile()

    for i, blip in ipairs(spriteTable) do
        util.remove_blip(blip)
    end

    spriteTable = {}
end)

function WriteToFile()
    file = io.open(path, "w")
    file:write("dataTable = {\n")
    for k, v in ipairs(positionsData) do
        file:write(string.format("{name = \"%s\", x = %f, y = %f, z = %f, blip = %s, blipColor = %d, blipSprite = %d, blipScale = %f, bookmark = \"%s\"},\n",
            v.name, v.x, v.y, v.z, v.blip, v.blipColor, v.blipSprite, v.blipScale, v.bookmark))
    end
    file:write("}\n")
    file:write("bookmarkTable = {\n")
    for k, v in ipairs(bookmarksData) do
        file:write(string.format("{name = \"%s\"},\n",
            v.name))
    end
    file:write("}")
    file:close()
end

-- Clear the file back to default
function RefreshFile()
    dataTable = {}
    file = io.open(path, "w")
    file:write("dataTable = {}\n")
    file:write("bookmarkTable = {}")
    file:close()
end

-- Read the positions data from the file
function ReadPositionsData()
    if file then
        io.close(file)
        dofile(path)
        bookmarksData = bookmarkTable
        for i, bookmark in ipairs(bookmarksData) do
            LoadBookmark(bookmark)
        end

        positionsData = dataTable    
        for i, data in ipairs(positionsData) do
            LoadBlip(data)
        end
        util.toast("Saved positions have been loaded")
    else
        RefreshFile()
        util.toast("No position_data found, creating new file")
    end
end

ReadPositionsData()