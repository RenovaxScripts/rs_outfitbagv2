# README for `rs_outfitbagv2` Script

## Overview

The `rs_outfitbagv2` script adds functionality to interact with "outfit bags" in a FiveM server, allowing players to place, pick up, and open them for outfit management. This script is highly customizable and integrates with different notification systems and appearance systems.

---

## Features
- **Place Outfit Bags**: Players can place outfit bags into the game world.
- **Pick Up Bags**: Retrieve previously placed outfit bags.
- **Open Bags**: Access outfit management directly from the bag.
- **Progress Animation**: Smooth progress circle and animations for interactions.
- **Debugging**: Enable detailed debug outputs for monitoring script behavior.
- **Customization**: Support for different notification and appearance systems.

---

## Installation

1. **Download and Add the Script**  
   Place the `rs_outfitbagv2` folder in your FiveM server's `resources` directory.

2. **Configure `server.cfg`**  
   Add the following line to your `server.cfg` to ensure the resource starts:
   ```bash
   ensure rs_outfitbagv2
   ```

3. **Dependencies**  
   - **ox_target**: Used for interaction targets.
   - **ox_inventory**: Required for item checks.
   - **lib.progressCircle**: For progress animations.
   - **illenium-appearance** (Optional): For the outfit menu.

---

## Configuration

### Debugging
Set `Config.Debug = true` to enable detailed logs for troubleshooting.

### Appearance System
- `Config.Appearance = 'illenium'`: Use Illenium Appearance system.
- Change to `'custom'` or `'fivem'` to use a different system or customize.

### Notification System
- `Config.Notify = 'ox'`: Use `ox_notify` for alerts.
- Set to `'rsscripts'` or `'custom'` for other notification systems.

### Command
- Command to place bags: `/outfitbag`  
- Enable or disable the command in `Config.Command`.

### Interaction Range
Set `Config.Distance` to control how close players need to be to interact with the bag.

### Bag Item
The item required to place bags can be configured:
```lua
Config.Item = {
    enabled = true,
    item = 'outfitbag' -- Name of the item
}
```

### Bag Prop
The 3D model used for the outfit bag:
```lua
Config.Prop = 'bkr_prop_duffel_bag_01a'
```

---

## Usage

### Place a Bag
1. Ensure the player has the required item (`outfitbag` by default).
2. Use the `/outfitbag` command or trigger the `rs_outfitbagv2:place` event.

### Open a Bag
Approach the placed bag and interact with it using the target system (`ox_target`).

### Pick Up a Bag
Approach the placed bag and interact with it to pick it up.

---

## Events

### Client Events
- `rs_outfitbagv2:open`: Opens the outfit bag interface.
- `rs_outfitbagv2:placed`: Triggered when a bag is placed.
- `rs_outfitbagv2:pickedup`: Triggered when a bag is picked up.

### Server Events
- `rs_outfitbagv2:placedBag`: Handles server-side logic when a bag is placed.
- `rs_outfitbagv2:pickedupBag`: Handles server-side logic when a bag is picked up.

---

## Debugging

Set `Config.Debug = true` to enable console prints. Look for messages prefixed with `[RS Outfit Bag | DEBUG]` to track actions and troubleshoot issues.

---

## Customization

### Notifications
Customize notifications in the `notify` function:
```lua
function notify(title, desc)
    -- Add your own notification logic here
end
```

### Appearance System
Support for custom appearance systems can be added in the `openAppearance` function:
```lua
function openAppearance()
    if Config.Appearance == 'custom' then
        -- Add your custom appearance logic here
    end
end
```

---

## Known Issues
- Ensure dependencies are correctly installed and configured.
- Interaction range (`Config.Distance`) might need tuning for your use case.

---

## Recommended FiveM Hosting — RocketNode

Looking for reliable hosting for your FiveM server?

I personally recommend RocketNode for hosting FiveM servers running my or other scripts and resources.

Get 25% OFF your FiveM server using my discount code:

Code: RENOVAX

Get your server here:
https://rocketnode.us/RENOVAX

The 25% discount code is valid for FiveM server hosting only.


## Credits
Developed for FiveM by **Renovax Scripts**.


