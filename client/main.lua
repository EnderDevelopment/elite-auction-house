local isUIOpen = false
local isInRange = false

-- Helper to send notifications
function SendNotification(title, msg, type)
    if Config.NotificationStyle == 'chat' then
        TriggerEvent('chat:addMessage', {
            color = { 0, 200, 150 },
            multiline = true,
            args = { title, msg }
        })
    elseif Config.NotificationStyle == 'ox_lib' then
        lib.notify({ title = title, description = msg, type = type or 'info' })
    elseif Config.NotificationStyle == 'esx' then
        if ESX then
            ESX.ShowNotification(title .. ': ' .. msg)
        else
            TriggerEvent('chat:addMessage', { args = { title, msg } })
        end
    elseif Config.NotificationStyle == 'custom' then
        SendCustomNotification(title, msg, type)
    end
end

-- Check framework availability
function HasFramework()
    if Config.Framework == 'esx' then
        return ESX ~= nil
    elseif Config.Framework == 'qb' then
        return QBCore ~= nil
    end
    return true -- standalone
end

-- Create the auction house blip
CreateThread(function()
    local blip = AddBlipForCoord(Config.AuctionLocation.x, Config.AuctionLocation.y, Config.AuctionLocation.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blip.label)
    EndTextCommandSetBlipName(blip)
end)

-- Draw marker / check proximity
CreateThread(function()
    while true do
        local sleep = 800
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        local dist = #(playerCoords - Config.AuctionLocation)
        if dist < Config.AuctionRange then
            isInRange = true
            sleep = 100

            DrawMarker(
                22, Config.AuctionLocation.x, Config.AuctionLocation.y, Config.AuctionLocation.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                1.5, 1.5, 0.5,
                0, 200, 150, 180,
                false, true, 2, nil, nil, nil, false
            )

            -- Help text
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(('~g~[E]~s~ Auction House - ~g~[L]~s~ List an item'):format())
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustReleased(0, 38) then -- E
                OpenAuctionUI()
            end

            if IsControlJustReleased(0, 201) then -- L
                OpenListingUI()
            end
        else
            isInRange = false
        end
        Wait(sleep)
    end
end)

-- Open the main auction UI (browse)
function OpenAuctionUI()
    if not HasFramework() then
        TriggerEvent('chat:addMessage', { args = { 'Auction House', 'Framework not loaded. Check config.' } })
        return
    end
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        panel = 'auction',
        premiumVehicles = Config.PremiumVehicles or {}
    })

    -- Request data
    TriggerServerEvent('auction:getListings')
end

-- Open the listing UI (sell an item)
function OpenListingUI()
    if not HasFramework() then
        TriggerEvent('chat:addMessage', { args = { 'Auction House', 'Framework not loaded. Check config.' } })
        return
    end
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        panel = 'list'
    })

    -- Request sellable items info
    TriggerServerEvent('auction:getSellableInfo')
end

-- Close the UI
function CloseAuctionUI()
    isUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
end

-- NUI callbacks
RegisterNUICallback('close', function(_, cb)
    CloseAuctionUI()
    cb('ok')
end)

RegisterNUICallback('buyNow', function(data, cb)
    TriggerServerEvent('auction:buyNow', data.id)
    cb('ok')
end)

RegisterNUICallback('placeBid', function(data, cb)
    TriggerServerEvent('auction:placeBid', data.id, data.amount)
    cb('ok')
end)

RegisterNUICallback('listVehicle', function(data, cb)
    TriggerServerEvent('auction:listVehicle', data)
    cb('ok')
end)

RegisterNUICallback('listClothing', function(data, cb)
    TriggerServerEvent('auction:listClothing', data)
    cb('ok')
end)

RegisterNUICallback('cancelListing', function(data, cb)
    TriggerServerEvent('auction:cancelListing', data.id, data.isClothing)
    cb('ok')
end)

RegisterNUICallback('getMyListings', function(_, cb)
    TriggerServerEvent('auction:getMyListings')
    cb('ok')
end)

RegisterNUICallback('getListings', function(_, cb)
    TriggerServerEvent('auction:getListings')
    cb('ok')
end)

RegisterNUICallback('getSellableInfo', function(_, cb)
    TriggerServerEvent('auction:getSellableInfo')
    cb('ok')
end)

RegisterNUICallback('spawnPreview', function(data, cb)
    TriggerServerEvent('auction:spawnPreviewReq', data.model)
    cb('ok')
end)

-- Server -> client events
RegisterNetEvent('auction:receiveListings', function(vehicles, clothes)
    SendNUIMessage({
        action = 'setListings',
        vehicles = vehicles,
        clothes = clothes
    })
end)

RegisterNetEvent('auction:receiveSellableInfo', function(vehicles, clothingSlots)
    SendNUIMessage({
        action = 'setSellable',
        vehicles = vehicles,
        clothingSlots = clothingSlots
    })
end)

RegisterNetEvent('auction:receiveMyListings', function(vehicles, clothes)
    SendNUIMessage({
        action = 'setMyListings',
        vehicles = vehicles,
        clothes = clothes
    })
end)

RegisterNetEvent('auction:previewSpawned', function(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local attempts = 0
    while not HasModelLoaded(hash) and attempts < 200 do
        Wait(10)
        attempts = attempts + 1
    end
    if not HasModelLoaded(hash) then return end

    -- Spawn preview near the player, offset to the side
    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 4.0, 3.0, 0.0)
    local heading = GetEntityHeading(ped)

    local previewVan = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetVehicleOnGroundProperly(previewVan)
    SetVehicleNeedsToBeHotwired(previewVan, false)
    FreezeEntityPosition(previewVan, true)
    SetEntityAsMissionEntity(previewVan, true, false)
    SetEntityNoCollisionEntity(previewVan, ped, true)
end)

-- Clean up previews when leaving the area
CreateThread(function()
    while true do
        Wait(2000)
        if not isInRange then
            -- Find and delete nearby preview vehicles (freeze set marks them as previews)
            local vehicles = GetGamePool('CVehicle')
            for _, veh in ipairs(vehicles) do
                if IsEntityAMissionEntity(veh) and IsEntityFrozen(veh) then
                    local distance = #(GetEntityCoords(veh) - GetEntityCoords(PlayerPedId()))
                    if distance < 15.0 then
                        DeleteEntity(veh)
                    end
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(0)
        if isUIOpen and IsControlJustPressed(0, 200) then -- ESC
            CloseAuctionUI()
        end
    end
end)
