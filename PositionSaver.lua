-- Position Saver
-- Made By Dynasty

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

--Temporary
local roseObj = util.joaat("prop_single_rose")
local roses = {}
--TTT

util.require_natives(1627063482)
local blipFile = require("pos_data")
local scriptPath = filesystem.stand_dir()

local blipSprite = {}
local blipData = {}
local testActions = {}

local spriteTypes = {
    1,
    162,
    270
}

local blipColor = 5
local selectedColor = blipColor
blipData = blipFile

-- functions
function copyTable(t)
    local copy = {}
    for key, value in pairs(t or {}) do
        if type(value) == "table" then
            copy[key] = copyTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function Rewrite()
    local file, err = io.open(scriptPath .. "Lua Scripts/lib/pos_data.lua", "w+")
    if not file then
        util.toast("Error opening file: " .. err)
        return
    end
    
    file:write("return {\n")
    for i, data in ipairs(blipData) do
        if not data.colorID then
            data.colorID = 5 -- replace defaultColorID with whatever value you want to use as the default
        end

        if not data.spriteType then
            data.spriteType = 1
        end

        if not data.subMenu then
            data.subMenu = false
        end

        file:write(
        '{ posName = "'  .. data.posName ..
        '", x = ' .. data.x ..
        ', y = ' .. data.y ..
        ', z = ' .. data.z ..
        ', colorID = ' .. tostring(data.colorID) ..
        ', spriteType = ' .. tostring(data.spriteType) .. 
        ', subMenu = ' .. data.subMenu ..'}')
        if i < #blipData then
            file:write(",\n")
        end
    end
    file:write("\n}\n")
    file:close()
end


function RemoveBlips()
    for i, blip in ipairs(blipSprite) do
        util.remove_blip(blip.blip)
    end

    blipSprite = {}    
    testActions = {}
end

function ImportSavedBlips()
    local posCount = 0
    local blipFileCopy = copyTable(blipFile)
    local blipDataCopy = copyTable(blipData)
    local mergedBlipData = {}
    blipData = {}

    for i, v in ipairs(blipFileCopy) do
        mergedBlipData[i] = v
        posCount = posCount + 1
    end

    for i, v in ipairs(blipDataCopy) do
        if not v.markedForDeletion then
            local nameExists = false
            for j, w in ipairs(mergedBlipData) do
                if v.posName == w.posName then
                    mergedBlipData[j] = v
                    nameExists = true
                    break
                end
            end
            if not nameExists then
                mergedBlipData[#mergedBlipData + 1] = v
            end
        else
            -- Remove the deleted blip from the original table
            for j, w in ipairs(blipData) do
                if v.posName == w.posName then
                    table.remove(blipData, j)
                    break
                end
            end
        end
    end

    local exists = false

    for i, list in ipairs(testActions) do
        if list.name == blipFile.posName then
            exists = true
            break
        end
    end
    
    if not exists then 
        for _, blipInfo in pairs(mergedBlipData) do
            if not blipInfo.markedForDeletion then
                CreateBlip(blipInfo.x, blipInfo.y, blipInfo.z, blipInfo.posName, blipInfo.colorID, blipInfo.spriteType)
            end
        end
    end

    if #mergedBlipData > 0 then
        util.toast("Successfully loaded " .. posCount .. " positions.")
    end
end

menu.divider(menu.my_root(), "Main")
local blipMenu = menu.list(menu.my_root(), "Create Blip", {}, "")
menu.text_input(blipMenu, "Position Name ", {"set_current_position_name"}, "Name your current position", function(name)
    if name ~= nil and name ~= "" then
        local playerPed = PLAYER.PLAYER_PED_ID()
        local playerPos = ENTITY.GET_ENTITY_COORDS(playerPed, true)

        CreateBlip(playerPos.x, playerPos.y, playerPos.z, name, selectedColor)
    end
end, "")

menu.divider(blipMenu, "To be completed")
menu.slider(blipMenu, "Blip color", {}, "",  1, 85, blipColor, 1, function()
    selectedColor = blipColor
end)

menu.slider(blipMenu, "Blip Sprite", {}, "", 1, #spriteTypes, spriteTypes[1], 1, function()

end)

local savedBlips = menu.list(menu.my_root(), "Saved positions list", {}, "")
menu.slider(menu.my_root(), "Blip color", {}, "", 1, 85, 5, 1, function(value)
    for i, blipTable in pairs(blipSprite) do
        local blip = blipTable.blip -- Get the actual blip from the table
        HUD.SET_BLIP_COLOUR(blip, value)
    end
end)

menu.slider(menu.my_root(), "Blip scale", {}, "", 6, 10, 6, 1, function(value)
    for i, blipTable in pairs(blipSprite) do
        local blip = blipTable.blip -- Get the actual blip from the table
        HUD.SET_BLIP_SCALE(blip, value/10)
    end
end)

--[[menu.textslider(menu.my_root(), "Blip Sprite", {}, "", spriteTypes, function(value)
    for i, blipTable in pairs(blipSprite) do
        local blip = blipTable.blip
        HUD.SET_BLIP_SPRITE(blip, value)
    end
end)]]

menu.divider(menu.my_root(), "Settings")
local blipSettings = menu.list(menu.my_root(), "Blip Settings", {})
menu.action(blipSettings, "Import Saved", {}, "Loads all the saved positions from pos_data file", function()    
    ImportSavedBlips()
end)


menu.action(blipSettings, "Delete All", {}, "WARNING : Deletes all your saved positions", function()    
    if #blipData > 0 then   
        
        for i, action in pairs(testActions) do
            menu.delete(action.action)
        end   

        RemoveBlips()
        blipData = {}
        Rewrite()

        util.toast("Removed all positions")
    end
end)

menu.action(menu.my_root(), "Check for Update", {}, "The script will automatically check for updates at most daily, but you can manually check using this option anytime.", function()
    auto_update_config.check_interval = 0
    util.toast("Checking for updates")
    auto_updater.run_auto_update(auto_update_config)
end)

function CreateBlip(x, y, z, name, colorID, spriteType)
    local existingBlip = nil
    local blip = nil

    for i, data in ipairs(blipData) do
        if data.posName == name then
            data.x = x
            data.y = y
            data.z = z
            data.colorID = colorID
            data.spriteType = spriteType
            local existingBlip = blipSprite[i]
            if existingBlip then -- check if existingBlip is not nil
                existingBlip.x = x
                existingBlip.y = y
                existingBlip.z = z
                existingBlip.colorID = colorID
                existingBlip.spriteType = spriteType
            end
            Rewrite()
            break
        end
    end    

    if existingBlip == nil then
        existingBlip = {} -- Initialize as empty table
    end

    if existingBlip.blip ~= nil then -- Check if blip field exists before indexing
        blip = existingBlip.blip
        HUD.SET_BLIP_COORDS(blip, x, y, z)
    else
        blip = HUD.ADD_BLIP_FOR_COORD(x, y, z)
        HUD.SET_BLIP_SPRITE(blip, 1) -- Set the blip sprite to a standard waypoint
        HUD.SET_BLIP_SCALE(blip, 0.6) -- Set the blip scale to normal size
        HUD.SET_BLIP_COLOUR(blip, 5) -- Set the blip color to blue
        HUD.SET_BLIP_AS_SHORT_RANGE(blip, false) -- Set the blip as a long-range blip
        HUD.SET_BLIP_DISPLAY(blip, 2) -- Set the blip to show on both the map and minimap

        existingBlip.blip = blip -- Assign the blip to the existingBlip table
        existingBlip.x = x
        existingBlip.y = y
        existingBlip.z = z

        table.insert(blipSprite, existingBlip) -- Insert the whole existingBlip table
        table.insert(blipData, {posName = name, x = x, y = y, z = z, colorID = colorID, spriteType = spriteType})

        local exists = false -- Add a flag to check if the name already exists in the savedBlips list

        for i, list in ipairs(testActions) do
            if list.name == name then
                exists = true
                break
            end
        end

        if not exists then -- Only create menu options if the name does not exist in the savedBlips list
            local testAction = menu.list(savedBlips, name, {})
            
            menu.action(testAction, "Teleport to", {}, "", function()
                local playerPed = PLAYER.PLAYER_PED_ID()
                local vehicle = PED.GET_VEHICLE_PED_IS_USING(playerPed)
                local coords = {x = existingBlip.x, y = existingBlip.y, z = existingBlip.z}
            
                if vehicle ~= 0 then
                    ENTITY.SET_ENTITY_COORDS(vehicle, coords.x, coords.y, coords.z, false, false, false, true)
                else
                    ENTITY.SET_ENTITY_COORDS(playerPed, coords.x, coords.y, coords.z, false, false, false, true)
                end
            end)

            menu.action(testAction, "Update position to current location", {}, "", function()
                local playerPed = PLAYER.PLAYER_PED_ID()
                local vehicle = PED.GET_VEHICLE_PED_IS_USING(playerPed)
                local coords = ENTITY.GET_ENTITY_COORDS(playerPed, true)
            
                existingBlip.x = coords.x
                existingBlip.y = coords.y
                existingBlip.z = coords.z
            
                -- Find the corresponding entry in the blipData table and update it with the new coordinates
                for i, data in ipairs(blipData) do
                    if data.posName == name then
                        data.x = coords.x
                        data.y = coords.y
                        data.z = coords.z
                        break
                    end
                end
            
                HUD.SET_BLIP_COORDS(blip, coords.x, coords.y, coords.z)
            
                Rewrite()
            end)        

            menu.text_input(testAction, "Rename", {"insert_new_blip_name"}, "Insert a new name", function(newName)
                for i, data in ipairs(blipData) do
                    if data.posName == name then
                        data.posName = newName
                        blipFile = blipData
                        Rewrite()
                        break
                    end
                end
                menu.set_menu_name(testAction, newName)
            end)

            local deleteDivider = menu.divider(testAction, "")
            menu.action(testAction, "Delete", {}, "", function()
                util.remove_blip(blip)
                menu.delete(testAction)
            
                for i, data in ipairs(blipData) do
                    if data.posName == name then
                        table.remove(blipData, i)
                        --table.remove(blipSprite, i)
                        --table.remove(testActions, i)
                        Rewrite()
                        return
                    end
                end
            end)
        
            table.insert(testActions, {name = name, action = testAction}) -- Save the name and corresponding menu options in the testActions table
        end
    end

    Rewrite()
end

ImportSavedBlips() -- Start script with blips automatically imported

util.on_pre_stop(function()
    RemoveRoses()
    RemoveBlips()
end)

-- Temporary
function SpawnRoses()
    local playerPed = PLAYER.PLAYER_PED_ID()
    local playerCoords = ENTITY.GET_ENTITY_COORDS(playerPed, true)
    local rose = OBJECT.CREATE_OBJECT(roseObj, playerCoords.x, playerCoords.y, playerCoords.z, true, true, false)
    table.insert(roses, rose)
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

menu.divider(menu.my_root(), "Misc")
local roses = menu.list(menu.my_root(), "Rose Manager")

-- Add menu action to spawn roses
menu.action(roses, "Spawn Roses", {}, "Spawn roses at your location", function()
    SpawnRoses()
end)

-- Add menu action to remove all spawned roses
menu.action(roses, "Remove Roses", {}, "Remove all spawned roses", function()
    RemoveRoses()
end)