util.require_natives(1627063482)
local blipFile = require("pos_data")
local scriptPath = filesystem.stand_dir()

local blipSprite = {}
local blipData = {}
local testActions = {}

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
        file:write('  {posName = "' .. data.posName .. '", x = ' .. data.x .. ', y = ' .. data.y .. ', z = ' .. data.z .. '}')
        if i < #blipData then
            file:write(",\n")
        end
    end
    file:write("\n}\n")
    file:close()
end

function RemoveBlips()
    testActions = {}

    for i, blip in ipairs(blipSprite) do
        util.remove_blip(blip.blip)
    end

    blipSprite = {}    
    testActions = {}
end

util.on_pre_stop(function()
    RemoveBlips()
end)

menu.text_input(menu.my_root(), "Position Name ", {"set_current_position_name"}, "Name your current position", function(name)
    if name ~= nil and name ~= "" then
        local playerPed = PLAYER.PLAYER_PED_ID()
        local playerPos = ENTITY.GET_ENTITY_COORDS(playerPed, true)

        CreateBlip(playerPos.x, playerPos.y, playerPos.z, name)

        name = nil
    end
end)


local savedBlips = menu.list(menu.my_root(), "Saved positions list", {}, "")
menu.action(menu.my_root(), "Clear all blips", {}, "Clears all the blips together with positions", function()
    for i, action in pairs(testActions) do
        menu.delete(action.action)
    end   
    
    RemoveBlips()
end)

local dataManage = menu.list(menu.my_root(), "Settings", {})
menu.action(dataManage, "Import Saved", {}, "Loads all the saved positions from pos_data file", function()    
    local posCount = 0
    local blipFileCopy = copyTable(blipFile)
    local blipDataCopy = copyTable(blipData)
    local mergedBlipData = {}
    for i, v in ipairs(blipFileCopy) do
        mergedBlipData[i] = v
        posCount = posCount + 1
    end
    for i, v in ipairs(blipDataCopy) do
        mergedBlipData[#mergedBlipData + 1] = v
    end
    
    blipData = {}
    for _, blipInfo in pairs(mergedBlipData) do
        CreateBlip(blipInfo.x, blipInfo.y, blipInfo.z, blipInfo.posName)
    end

    if #mergedBlipData > 0 then
        util.toast("Successfully loaded " .. posCount .. " positions.")
    end
end)

menu.action(dataManage, "Delete All", {}, "WARNING : Deletes all your saved positions", function()
    
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

function CreateBlip(x, y, z, name)
    local existingBlip = nil
    local blip = nil

    for i, data in ipairs(blipData) do
        if data.posName == name then
            existingBlip = blipSprite[i]
            data.x = x
            data.y = y
            data.z = z
            existingBlip.x = x
            existingBlip.y = y
            existingBlip.z = z
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
        HUD.SET_BLIP_SCALE(blip, 1.0) -- Set the blip scale to normal size
        HUD.SET_BLIP_COLOUR(blip, 3) -- Set the blip color to blue
        HUD.SET_BLIP_AS_SHORT_RANGE(blip, false) -- Set the blip as a long-range blip
        HUD.SET_BLIP_DISPLAY(blip, 2) -- Set the blip to show on both the map and minimap
        
        existingBlip.blip = blip -- Assign the blip to the existingBlip table
        existingBlip.x = x
        existingBlip.y = y
        existingBlip.z = z
        table.insert(blipSprite, existingBlip) -- Insert the whole existingBlip table
        table.insert(blipData, {posName = name, x = x, y = y, z = z})

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

            menu.action(testAction, "Remove", {}, "", function()
                util.remove_blip(blip)
                menu.delete(testAction)
            
                for i, data in ipairs(blipData) do
                    if data.posName == name then
                        table.remove(blipData, i)
                        table.remove(blipSprite, i)
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