local MySQL = MySQL

--====================================================================
-- DATABASE INITIALISATION
--====================================================================
MySQL.query([[
    CREATE TABLE IF NOT EXISTS `auction_vehicles` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `owner` VARCHAR(64) NOT NULL,
        `item_name` VARCHAR(64) NOT NULL,
        `vehicle_model` VARCHAR(64) NOT NULL,
        `price` INT NOT NULL,
        `bid` INT DEFAULT 0,
        `bidder` VARCHAR(64) DEFAULT NULL,
        `status` VARCHAR(20) DEFAULT 'active',
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `ends_at` TIMESTAMP NULL
    )
]])

MySQL.query([[
    CREATE TABLE IF NOT EXISTS `auction_clothes` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `owner` VARCHAR(64) NOT NULL,
        `slot` VARCHAR(32) NOT NULL,
        `label` VARCHAR(64) NOT NULL,
        `drawable` INT DEFAULT 0,
        `texture` INT DEFAULT 0,
        `palette` INT DEFAULT 0,
        `price` INT NOT NULL,
        `bid` INT DEFAULT 0,
        `bidder` VARCHAR(64) DEFAULT NULL,
        `status` VARCHAR(20) DEFAULT 'active',
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `ends_at` TIMESTAMP NULL
    )
]])

--====================================================================
-- FRAMEWORK HELPERS
--====================================================================
local function GetIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        if string.match(id, 'license:') then
            return id
        end
    end
    return 'unknown:' .. source
end

local function AddMoney(source, amount, account)
    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            if account == 'cash' or account == 'money' then
                xPlayer.addMoney(amount)
            else
                xPlayer.addAccountMoney(account, amount)
            end
        end
    elseif Config.Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            Player.Functions.AddMoney(account or Config.QBBankAccount, amount, 'auction-sale')
        end
    end
end

local function RemoveMoney(source, amount, account)
    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            if account == 'cash' or account == 'money' then
                xPlayer.removeMoney(amount)
            else
                xPlayer.removeAccountMoney(account, amount)
            end
        end
        return true
    elseif Config.Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            return Player.Functions.RemoveMoney(account or Config.QBBankAccount, amount, 'auction-sale')
        end
        return false
    end
    return true
end

local function HasMoney(source, amount, account)
    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        if account == 'cash' or account == 'money' then
            return xPlayer.getMoney() >= amount
        else
            return xPlayer.getAccount(account).money >= amount
        end
    elseif Config.Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.GetMoney(account or Config.QBBankAccount) >= amount
    end
    return true
end

local function GivePlayerVehicle(identifier, model)
    if Config.Framework == 'esx' then
        MySQL.insert('INSERT INTO owned_vehicles (owner, plate, vehicle, stored) VALUES (?, ?, ?, ?)',
            { identifier, GeneratePlate(), json.encode({ model = model }), 1 })
    elseif Config.Framework == 'qb' then
        local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
        if player then
            MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?)',
                { player.PlayerData.license, identifier, model, GetHashKey(model), GeneratePlate(), 'pillboxgarage', 0 })
        end
    end
end

function GeneratePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local rand = math.random(1, #chars)
        plate = plate .. string.sub(chars, rand, rand)
    end
    return plate
end

local function GetActiveListings()
    local vehicles = MySQL.query.await(string.format('SELECT * FROM %s WHERE status = ?', Config.TableVehicles), { 'active' })
    local clothes = MySQL.query.await(string.format('SELECT * FROM %s WHERE status = ?', Config.TableClothes), { 'active' })
    return vehicles or {}, clothes or {}
end

local function GetPlayerListingCount(source)
    local identifier = GetIdentifier(source)
    local vCount = MySQL.query.await(string.format('SELECT COUNT(*) as c FROM %s WHERE owner = ? AND status = ?', Config.TableVehicles),
        { identifier, 'active' })
    local cCount = MySQL.query.await(string.format('SELECT COUNT(*) as c FROM %s WHERE owner = ? AND status = ?', Config.TableClothes),
        { identifier, 'active' })
    local v = (vCount and vCount[1] and vCount[1].c) or 0
    local c = (cCount and cCount[1] and cCount[1].c) or 0
    return v + c
end

local function GetPlayerVehicles(source)
    local identifier = GetIdentifier(source)
    local result = {}

    if Config.Framework == 'esx' then
        local ownedVehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ?', { identifier })
        if ownedVehicles then
            for _, veh in ipairs(ownedVehicles) do
                local data = json.decode(veh.vehicle or '{}')
                local model = data.model
                if model then
                    table.insert(result, {
                        plate = veh.plate,
                        model = model,
                        label = GetDisplayNameFromVehicleModel(GetHashKey(model))
                    })
                end
            end
        end
    elseif Config.Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            local vehicles = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', { Player.PlayerData.citizenid })
            if vehicles then
                for _, veh in ipairs(vehicles) do
                    table.insert(result, {
                        plate = veh.plate,
                        model = veh.vehicle,
                        label = GetDisplayNameFromVehicleModel(GetHashKey(veh.vehicle))
                    })
                end
            end
        end
    end

    local filtered = {}
    for _, v in ipairs(result) do
        local isBanned = false
        for _, banned in ipairs(Config.BannedVehicles) do
            if v.model:lower() == banned then isBanned = true break end
        end
        if not isBanned then
            table.insert(filtered, {
                model = v.model,
                label = v.label or v.model,
                plate = v.plate
            })
        end
    end

    return filtered
end

local function GetPlayerClothing(source)
    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.get('skin') then
            return xPlayer.get('skin')
        end
    end
    return {}
end

local function ApplyClothingToPlayer(source, slot, drawable, texture, palette)
    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        local skin = xPlayer.get('skin') or {}
        skin[slot] = { drawable = drawable, texture = texture, palette = palette }
        xPlayer.set('skin', skin)
        TriggerClientEvent('skinchanger:loadSkin', source, skin)
        return true
    end
    return false
end

local function ClearClothingSlot(source, slot)
    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return end
        local skin = xPlayer.get('skin') or {}
        if skin[slot] then
            skin[slot] = nil
            xPlayer.set('skin', skin)
            TriggerClientEvent('skinchanger:loadSkin', source, skin)
        end
    end
end

local function RemoveVehicleFromGarage(identifier, model)
    if Config.Framework == 'esx' then
        MySQL.update('DELETE FROM owned_vehicles WHERE owner = ? AND vehicle LIKE ?',
            { identifier, '%' .. model .. '%' })
    elseif Config.Framework == 'qb' then
        MySQL.update('DELETE FROM player_vehicles WHERE license = ? AND vehicle = ?',
            { identifier, model })
    end
end

local function GetPlayerFromIdentifier(identifier)
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        if GetIdentifier(playerId) == identifier then
            return playerId
        end
    end
    return nil
end

--====================================================================
-- EXPIRY CHECK
--====================================================================
local function CheckExpired()
    local expiredV = MySQL.query.await(string.format(
        'SELECT * FROM %s WHERE status = ? AND ends_at IS NOT NULL AND ends_at < NOW()', Config.TableVehicles), { 'active' })
    if expiredV then
        for _, listing in ipairs(expiredV) do
            local winnerId = listing.bidder
            if winnerId and winnerId ~= '' then
                MySQL.update(string.format('UPDATE %s SET status = ? WHERE id = ?', Config.TableVehicles), { 'sold', listing.id })
                local winnerSrc = GetPlayerFromIdentifier(winnerId)
                GivePlayerVehicle(winnerId, listing.vehicle_model)
                if winnerSrc then
                    TriggerClientEvent('chat:addMessage', winnerSrc, {
                        args = { 'Auction', ('You won the auction for %s! Vehicle added to your garage.'):format(listing.vehicle_model) }
                    })
                end
                local payout = math.floor(listing.bid * (1 - Config.CommissionPercent))
                local sellerSrc = GetPlayerFromIdentifier(listing.owner)
                if sellerSrc then
                    AddMoney(sellerSrc, payout, Config.SalePayoutAccount)
                    TriggerClientEvent('chat:addMessage', sellerSrc, {
                        args = { 'Auction', ('Your %s auction ended. You earned $%s!'):format(listing.vehicle_model, payout) }
                    })
                end
            else
                MySQL.update(string.format('UPDATE %s SET status = ? WHERE id = ?', Config.TableVehicles), { 'returned', listing.id })
                GivePlayerVehicle(listing.owner, listing.vehicle_model)
                local sellerSrc = GetPlayerFromIdentifier(listing.owner)
                if sellerSrc then
                    TriggerClientEvent('chat:addMessage', sellerSrc, {
                        args = { 'Auction', ('Your %s auction ended without bids. Vehicle returned.'):format(listing.vehicle_model) }
                    })
                end
            end
        end
    end

    local expiredC = MySQL.query.await(string.format(
        'SELECT * FROM %s WHERE status = ? AND ends_at IS NOT NULL AND ends_at < NOW()', Config.TableClothes), { 'active' })
    if expiredC then
        for _, listing in ipairs(expiredC) do
            local winnerId = listing.bidder
            if winnerId and winnerId ~= '' then
                MySQL.update(string.format('UPDATE %s SET status = ? WHERE id = ?', Config.TableClothes), { 'sold', listing.id })
                local winnerSrc = GetPlayerFromIdentifier(winnerId)
                if winnerSrc then
                    ApplyClothingToPlayer(winnerSrc, listing.slot, listing.drawable, listing.texture, listing.palette)
                    TriggerClientEvent('chat:addMessage', winnerSrc, {
                        args = { 'Auction', ('You won the %s clothing auction! Item applied.'):format(listing.label) }
                    })
                end
                local payout = math.floor(listing.bid * (1 - Config.CommissionPercent))
                local sellerSrc = GetPlayerFromIdentifier(listing.owner)
                if sellerSrc then
                    AddMoney(sellerSrc, payout, Config.SalePayoutAccount)
                    TriggerClientEvent('chat:addMessage', sellerSrc, {
                        args = { 'Auction', ('Your %s auction ended. You earned $%s!'):format(listing.label, payout) }
                    })
                end
            else
                MySQL.update(string.format('UPDATE %s SET status = ? WHERE id = ?', Config.TableClothes), { 'returned', listing.id })
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(60000)
        CheckExpired()
    end
end)

--====================================================================
-- EVENTS
--====================================================================
RegisterNetEvent('auction:getListings', function()
    local src = source
    local vehicles, clothes = GetActiveListings()
    TriggerClientEvent('auction:receiveListings', src, vehicles, clothes)
end)

RegisterNetEvent('auction:getMyListings', function()
    local src = source
    local identifier = GetIdentifier(src)
    local vehicles = MySQL.query.await(string.format('SELECT * FROM %s WHERE owner = ? AND status != ?', Config.TableVehicles), { identifier, 'returned' })
    local clothes = MySQL.query.await(string.format('SELECT * FROM %s WHERE owner = ? AND status != ?', Config.TableClothes), { identifier, 'returned' })
    TriggerClientEvent('auction:receiveMyListings', src, vehicles or {}, clothes or {})
end)

RegisterNetEvent('auction:getSellableInfo', function()
    local src = source
    local vehicles = GetPlayerVehicles(src)
    local clothingSlots = {}

    for _, slotData in ipairs(Config.SellableClothingSlots) do
        table.insert(clothingSlots, {
            slot = slotData.slot,
            label = slotData.label,
            price = slotData.price
        })
    end

    local skin = GetPlayerClothing(src)
    for _, slotData in ipairs(clothingSlots) do
        local cur = skin[slotData.slot]
        if cur then
            slotData.currentDrawable = cur.drawable or 0
            slotData.currentTexture = cur.texture or 0
        end
    end

    TriggerClientEvent('auction:receiveSellableInfo', src, vehicles, clothingSlots)
end)

--====================================================================
-- LIST VEHICLE
--====================================================================
RegisterNetEvent('auction:listVehicle', function(data)
    local src = source
    if not data or not data.model or not data.price then return end

    local identifier = GetIdentifier(src)
    local model = tostring(data.model):lower()
    local price = math.floor(tonumber(data.price) or 0)

    if price < 1 then
        TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'Invalid price.' } })
        return
    end

    for _, banned in ipairs(Config.BannedVehicles) do
        if model == banned then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'That vehicle cannot be sold.' } })
            return
        end
    end

    local count = GetPlayerListingCount(src)
    if count >= Config.MaxListings then
        TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'You have reached the maximum number of listings.' } })
        return
    end

    -- Charge listing fee
    if not HasMoney(src, Config.ListingFee, Config.ListingFeeAccount) then
        TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', ('You need $%s to list a vehicle.'):format(Config.ListingFee) } })
        return
    end
    RemoveMoney(src, Config.ListingFee, Config.ListingFeeAccount)

    -- Remove vehicle from garage
    RemoveVehicleFromGarage(identifier, model)

    local displayName = GetDisplayNameFromVehicleModel(GetHashKey(model))
    local endsAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.AuctionDurationHours * 3600))

    MySQL.insert(string.format(
        'INSERT INTO %s (owner, item_name, vehicle_model, price, status, ends_at) VALUES (?, ?, ?, ?, ?, ?)',
        Config.TableVehicles),
        { identifier, displayName, model, price, 'active', endsAt })

    TriggerClientEvent('chat:addMessage', src, {
        args = { 'Auction', ('Your %s has been listed for auction at $%s.'):format(displayName, price) }
    })
end)

--====================================================================
-- LIST CLOTHING
--====================================================================
RegisterNetEvent('auction:listClothing', function(data)
    local src = source
    if not data or not data.slot or not data.price then return end

    local identifier = GetIdentifier(src)
    local slot = tostring(data.slot)
    local price = math.floor(tonumber(data.price) or 0)
    local drawable = math.floor(tonumber(data.drawable) or 0)
    local texture = math.floor(tonumber(data.texture) or 0)
    local palette = math.floor(tonumber(data.palette) or 0)

    if price < 1 then
        TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'Invalid price.' } })
        return
    end

    -- Check listing limit
    local count = GetPlayerListingCount(src)
    if count >= Config.MaxListings then
        TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'You have reached the maximum number of listings.' } })
        return
    end

    -- Charge listing fee
    if not HasMoney(src, Config.ListingFee, Config.ListingFeeAccount) then
        TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', ('You need $%s to list clothing.'):format(Config.ListingFee) } })
        return
    end
    RemoveMoney(src, Config.ListingFee, Config.ListingFeeAccount)

    -- Find slot label
    local slotLabel = slot
    for _, slotData in ipairs(Config.SellableClothingSlots) do
        if slotData.slot == slot then
            slotLabel = slotData.label
            break
        end
    end

    -- Clear the clothing slot from seller
    ClearClothingSlot(src, slot)

    local endsAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.AuctionDurationHours * 3600))

    MySQL.insert(string.format(
        'INSERT INTO %s (owner, slot, label, drawable, texture, palette, price, status, ends_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        Config.TableClothes),
        { identifier, slot, slotLabel, drawable, texture, palette, price, 'active', endsAt })

    TriggerClientEvent('chat:addMessage', src, {
        args = { 'Auction', ('Your %s has been listed for auction at $%s.'):format(slotLabel, price) }
    })
end)

--====================================================================
-- BUY NOW
--====================================================================
RegisterNetEvent('auction:buyNow', function(listingId)
    local src = source
    if not listingId then return end

    local identifier = GetIdentifier(src)
    listingId = tonumber(listingId)

    -- Try vehicles first
    local vResult = MySQL.query.await(string.format('SELECT * FROM %s WHERE id = ? AND status = ?', Config.TableVehicles),
        { listingId, 'active' })

    if vResult and vResult[1] then
        local listing = vResult[1]

        -- Can't buy your own listing
        if listing.owner == identifier then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'You cannot buy your own listing.' } })
            return
        end

        local price = listing.price

        -- Check funds
        if not HasMoney(src, price, Config.SalePayoutAccount) then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'You do not have enough money.' } })
            return
        end

        -- Transaction
        if not RemoveMoney(src, price, Config.SalePayoutAccount) then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'Transaction failed.' } })
            return
        end

        -- Mark as sold
        MySQL.update(string.format('UPDATE %s SET status = ?, bidder = ?, bid = ? WHERE id = ?', Config.TableVehicles),
            { 'sold', identifier, price, listingId })

        -- Give vehicle to buyer
        GivePlayerVehicle(identifier, listing.vehicle_model)

        -- Pay seller
        local sellerSrc = GetPlayerFromIdentifier(listing.owner)
        local payout = math.floor(price * (1 - Config.CommissionPercent))
        if sellerSrc then
            AddMoney(sellerSrc, payout, Config.SalePayoutAccount)
            TriggerClientEvent('chat:addMessage', sellerSrc, {
                args = { 'Auction', ('Your %s was bought for $%s (after %s%% commission, you received $%s).'):format(
                    listing.vehicle_model, price, Config.CommissionPercent * 100, payout) }
            })
        end

        TriggerClientEvent('chat:addMessage', src, {
            args = { 'Auction', ('You bought %s for $%s! Vehicle added to your garage.'):format(listing.vehicle_model, price) }
        })
        return
    end

    -- Try clothes
    local cResult = MySQL.query.await(string.format('SELECT * FROM %s WHERE id = ? AND status = ?', Config.TableClothes),
        { listingId, 'active' })

    if cResult and cResult[1] then
        local listing = cResult[1]

        if listing.owner == identifier then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'You cannot buy your own listing.' } })
            return
        end

        local price = listing.price

        if not HasMoney(src, price, Config.SalePayoutAccount) then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'You do not have enough money.' } })
            return
        end

        if not RemoveMoney(src, price, Config.SalePayoutAccount) then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'Transaction failed.' } })
            return
        end

        MySQL.update(string.format('UPDATE %s SET status = ?, bidder = ?, bid = ? WHERE id = ?', Config.TableClothes),
            { 'sold', identifier, price, listingId })

        -- Apply clothing to buyer
        ApplyClothingToPlayer(src, listing.slot, listing.drawable, listing.texture, listing.palette)

        -- Pay seller
        local sellerSrc = GetPlayerFromIdentifier(listing.owner)
        local payout = math.floor(price * (1 - Config.CommissionPercent))
        if sellerSrc then
            AddMoney(sellerSrc, payout, Config.SalePayoutAccount)
            TriggerClientEvent('chat:addMessage', sellerSrc, {
                args = { 'Auction', ('Your %s was bought for $%s (after %s%% commission, you received $%s).'):format(
                    listing.label, price, Config.CommissionPercent * 100, payout) }
            })
        end

        TriggerClientEvent('chat:addMessage', src, {
            args = { 'Auction', ('You bought %s for $%s! Item applied to your character.'):format(listing.label, price) }
        })
    end
end)

--====================================================================
-- PLACE BID
--====================================================================
RegisterNetEvent('auction:placeBid', function(listingId, bidAmount)
    local src = source
    if not listingId or not bidAmount then return end

    local identifier = GetIdentifier(src)
    listingId = tonumber(listingId)
    bidAmount = math.floor(tonumber(bidAmount) or 0)

    if bidAmount < 1 then
        TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'Invalid bid amount.' } })
        return
    end

    -- Try vehicles
    local vResult = MySQL.query.await(string.format('SELECT * FROM %s WHERE id = ? AND status = ?', Config.TableVehicles),
        { listingId, 'active' })

    if vResult and vResult[1] then
        local listing = vResult[1]

        if listing.owner == identifier then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'You cannot bid on your own listing.' } })
            return
        end

        -- Minimum bid: buy-now price * MinBidPercent, or current bid + 1
        local minBid = listing.price
        if listing.bid > 0 then
            minBid = listing.bid + 1
        else
            minBid = math.floor(listing.price * Config.MinBidPercent)
        end

        if bidAmount < minBid then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', ('Your bid must be at least $%s.'):format(minBid) } })
            return
        end

        if not HasMoney(src, bidAmount, Config.SalePayoutAccount) then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'You do not have enough money for this bid.' } })
            return
        end

        -- Refund previous bidder if any
        if listing.bidder and listing.bidder ~= '' and listing.bidder ~= identifier then
            local prevBidderSrc = GetPlayerFromIdentifier(listing.bidder)
            if prevBidderSrc then
                AddMoney(prevBidderSrc, listing.bid, Config.SalePayoutAccount)
                TriggerClientEvent('chat:addMessage', prevBidderSrc, {
                    args = { 'Auction', ('You were outbid on %s for $%s. Your bid was refunded.'):format(listing.vehicle_model, listing.bid) }
                })
            end
        end

        -- Take new bid from bidder
        if not RemoveMoney(src, bidAmount, Config.SalePayoutAccount) then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'Failed to place bid.' } })
            return
        end

        MySQL.update(string.format('UPDATE %s SET bid = ?, bidder = ? WHERE id = ?', Config.TableVehicles),
            { bidAmount, identifier, listingId })

        -- Refresh UI for everyone who has it open
        local vehicles, clothes = GetActiveListings()
        for _, playerId in ipairs(GetPlayers()) do
            TriggerClientEvent('auction:receiveListings', tonumber(playerId), vehicles, clothes)
        end

        return
    end

    -- Try clothes
    local cResult = MySQL.query.await(string.format('SELECT * FROM %s WHERE id = ? AND status = ?', Config.TableClothes),
        { listingId, 'active' })

    if cResult and cResult[1] then
        local listing = cResult[1]

        if listing.owner == identifier then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'You cannot bid on your own listing.' } })
            return
        end

        local minBid = listing.price
        if listing.bid > 0 then
            minBid = listing.bid + 1
        else
            minBid = math.floor(listing.price * Config.MinBidPercent)
        end

        if bidAmount < minBid then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', ('Your bid must be at least $%s.'):format(minBid) } })
            return
        end

        if not HasMoney(src, bidAmount, Config.SalePayoutAccount) then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'You do not have enough money for this bid.' } })
            return
        end

        if listing.bidder and listing.bidder ~= '' and listing.bidder ~= identifier then
            local prevBidderSrc = GetPlayerFromIdentifier(listing.bidder)
            if prevBidderSrc then
                AddMoney(prevBidderSrc, listing.bid, Config.SalePayoutAccount)
                TriggerClientEvent('chat:addMessage', prevBidderSrc, {
                    args = { 'Auction', ('You were outbid on %s for $%s. Your bid was refunded.'):format(listing.label, listing.bid) }
                })
            end
        end

        if not RemoveMoney(src, bidAmount, Config.SalePayoutAccount) then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'Failed to place bid.' } })
            return
        end

        MySQL.update(string.format('UPDATE %s SET bid = ?, bidder = ? WHERE id = ?', Config.TableClothes),
            { bidAmount, identifier, listingId })

        local vehicles, clothes = GetActiveListings()
        for _, playerId in ipairs(GetPlayers()) do
            TriggerClientEvent('auction:receiveListings', tonumber(playerId), vehicles, clothes)
        end
    end
end)

--====================================================================
-- CANCEL LISTING
--====================================================================
RegisterNetEvent('auction:cancelListing', function(listingId, isClothing)
    local src = source
    if not listingId then return end

    local identifier = GetIdentifier(src)
    listingId = tonumber(listingId)

    if isClothing then
        local result = MySQL.query.await(string.format('SELECT * FROM %s WHERE id = ? AND owner = ? AND status = ?', Config.TableClothes),
            { listingId, identifier, 'active' })
        if result and result[1] then
            MySQL.update(string.format('UPDATE %s SET status = ? WHERE id = ?', Config.TableClothes), { 'cancelled', listingId })
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'Listing cancelled.' } })
        end
    else
        local result = MySQL.query.await(string.format('SELECT * FROM %s WHERE id = ? AND owner = ? AND status = ?', Config.TableVehicles),
            { listingId, identifier, 'active' })
        if result and result[1] then
            MySQL.update(string.format('UPDATE %s SET status = ? WHERE id = ?', Config.TableVehicles), { 'cancelled', listingId })
            -- Return vehicle
            GivePlayerVehicle(identifier, result[1].vehicle_model)
            TriggerClientEvent('chat:addMessage', src, { args = { 'Auction', 'Listing cancelled. Vehicle returned to your garage.' } })
        end
    end
end)

--====================================================================
-- PREVIEW VEHICLE
--====================================================================
RegisterNetEvent('auction:spawnPreviewReq', function(modelName)
    local src = source
    if not modelName then return end

    local model = tostring(modelName)
    local hash = GetHashKey(model)
    if IsModelInCdimage(hash) then
        TriggerClientEvent('auction:previewSpawned', src, model)
    end
end)