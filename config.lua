Config = {}

-- Database table names
Config.TableVehicles = 'auction_vehicles'
Config.TableClothes = 'auction_clothes'

-- Auction House location (del Perro parking lot)
Config.AuctionLocation = vector3(-345.0, -884.0, 31.0)
Config.AuctionRange = 5.0

-- Blip settings
Config.Blip = {
    sprite = 431,
    color = 5,
    scale = 0.9,
    label = 'Auction House'
}

-- Maximum concurrent listings per player
Config.MaxListings = 3

-- Auction duration in hours
Config.AuctionDurationHours = 24

-- Starting bid as percentage of the item's "buy now" value (min bid)
Config.MinBidPercent = 0.8 -- 80% of buy now price

-- Fees
Config.ListingFee = 500          -- Flat fee to list an item (money)
Config.CommissionPercent = 0.05  -- 5% commission on final sale

-- Currencies
Config.ListingFeeAccount = 'bank'    -- bank or money
Config.SalePayoutAccount = 'bank'    -- bank or money

-- Notification style: 'chat' or 'ox_lib' or 'esx' or 'custom'
Config.NotificationStyle = 'chat'

-- Framework: 'esx' or 'qb' or 'standalone'
Config.Framework = 'esx'

-- ESX account name used for payouts (only for ESX)
Config.ESXMoneyAccount = 'bank'
Config.ESXBankAccount = 'bank'
Config.ESXMoneyCash = 'money'

-- QBcore item for money
Config.QBMoneyItem = 'money'
Config.QBBankAccount = 'bank'

-- Vehicle categories shown in the auction house
Config.VehicleCategories = {
    { name = 'Super',     filter = 'super' },
    { name = 'Sport',     filter = 'sport' },
    { name = 'Sports Classic', filter = 'sports_classic' },
    { name = 'Muscle',    filter = 'muscle' },
    { name = 'Off-Road',  filter = 'offroad' },
    { name = 'Motorcycle',filter = 'motorcycles' },
    { name = 'Sedan',     filter = 'sedans' },
    { name = 'Coupe',     filter = 'coupes' },
    { name = 'SUV',       filter = 'suvs' },
    { name = 'Vans',      filter = 'vans' },
    { name = 'All',       filter = 'all' },
}

-- Vehicles you want to HIGHLIGHT as "premium/DLC/top-speed" (optional curated list).
-- These get a "PREMIUM" badge and sort to the top.
Config.PremiumVehicles = {
    'adder',
    'zentorno',
    't20',
    'osiris',
    'reaper',
    'fmj',
    'italigtb',
    'tempesta',
    'nero',
    'penetrator',
    'xa21',
    'pariah',
    'comet5',
    'neon',
    'cyclone',
    'rapidgt3',
    'sultanrs',
    'banshee2',
    'autarch',
    'sc1',
    'tyrant',
    'visione',
    'prototipo',
    'devil2',
    'deveste',
    'krieger',
    'emerus',
    'furia',
    'zorrusso',
    'italirsx',
    'vagner',
    's80',
    'thrax',
    'komoda',
    'jugular',
    'sugoi',
    'rebla',
    'neo',
    'jester',
}

-- Vehicles players are NOT allowed to sell (free spawns, story-only, etc.)
Config.BannedVehicles = {
    'bmx',
    'cruiser',
    'fixter',
    'scorcher',
    'tribike',
    'tribike2',
    'tribike3',
    'ambulance',
    'police',
    'police2',
    'police3',
    'police4',
    'policeb',
    'policet',
    'policeold1',
    'policeold2',
    'sheriff',
    'sheriff2',
    'firetruk',
    'rhino',
    'hydra',
    'lazer',
    'pbus',
    'bus',
    'coach',
    'taxi',
}

-- Clothing shops / masks sold by the auction. Each entry = a clothing slot
-- that the seller can select and a fixed price. Buyers get the item applied.
Config.SellableClothingSlots = {
    { slot = 'mask',   label = 'Masks / Helmets',    price = 5000 },
    { slot = 'helmet', label = 'Helmets',            price = 4000 },
    { slot = 'glasses',label = 'Glasses',            price = 3000 },
    { slot = 'ears',   label = 'Earrings',           price = 2500 },
    { slot = 'shirt',  label = 'Shirts',             price = 4000 },
    { slot = 'pants',  label = 'Pants',              price = 3500 },
    { slot = 'shoes',  label = 'Shoes',              price = 2500 },
    { slot = 'jacket', label = 'Jackets / Coats',    price = 5000 },
    { slot = 'hat',    label = 'Hats',               price = 3000 },
    { slot = 'accessory', label = 'Accessories',     price = 2000 },
}

-- Notification function used by both client and shared helpers.
-- Only relevant when Config.NotificationStyle == 'custom'
function SendCustomNotification(title, msg, type)
    -- Override this in your own script if using a custom notification system.
    -- Default falls back to chat.
    TriggerEvent('chat:addMessage', {
        color = { 0, 200, 150 },
        multiline = true,
        args = { title, msg }
    })
end
