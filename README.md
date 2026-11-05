# Elite Auctions - FiveM Auction House Resource

Elite Auctions is a comprehensive FiveM auction house resource that allows players to buy and sell vehicles and clothing items through a user-friendly interface. This resource supports both ESX and QBCore frameworks and includes features such as auctions, buy-now pricing, vehicle previews, premium DLC vehicle highlighting, and a complete listing management system. Players can browse vehicles across multiple categories, place bids, purchase items instantly, and list their own vehicles or clothing for auction, with full support for DLC and non-DLC content.

## Install

1. Download the `elite-auctions` folder and place it in your server's `resources` directory.
2. Ensure the following dependencies are installed and started:
   - `oxmysql` (server-side database)
   - Your framework resource (ESX or QBCore)
   - Optional: `ox_lib` for enhanced notifications
3. Add the following to your server configuration file (usually `server.cfg`):
   ```
   ensure oxmysql
   ensure es_extended  # or qb-core
   ensure elite-auctions
   ```
4. By default, the resource is configured for ESX. If you use QBCore, edit `config.lua` and change `Config.Framework` to `'qb'`.
5. Adjust the database table names in `config.lua` if needed (default: `auction_vehicles` and `auction_clothes`). Tables will be created automatically on first start.
6. Customize notification style in `config.lua` by setting `Config.NotificationStyle` to `'chat'`, `'ox_lib'`, `'esx'`, or `'custom'`.

## Use

1. Start your server and ensure the resource loads without errors.
2. Players can navigate to the auction house location (default: Del Perro parking lot at coordinates -345.0, -884.0, 31.0).
3. A blip will appear on the map showing the auction house location.
4. When near the auction house, players will see a marker and help text.
5. Press **E** to open the auction house UI and browse available vehicles and clothing.
6. Press **L** to open the listing menu to sell items.
7. In the auction tab, players can:
   - Filter vehicles by category (Super, Sport, Classic, Muscle, Off-Road, etc.)
   - Browse premium vehicles highlighted with a special badge
   - Place bids on vehicles or clothing
   - Buy items instantly using the "Buy Now" button
   - Preview vehicles by spawning a temporary version nearby
8. In the Sell Item tab, players can:
   - Select from their garage vehicles to auction
   - Choose from available clothing slots (masks, shirts, pants, etc.)
   - Set a buy-now price and list the item for auction
9. The "My Listings" tab shows all active listings, allowing players to cancel them if needed.
10. Auctions automatically expire after the configured duration (default: 24 hours).

---

More FiveM resource projects by EnderDevelopment: https://github.com/EnderDevelopment

Project page: https://dash.enderdevelopment.com/community/7b4d205f-c5d4-4c16-a5b7-0d848dc322c9?utm_source=github&utm_medium=readme&utm_campaign=auto_publish&utm_content=7b4d205f-c5d4-4c16-a5b7-0d848dc322c9
