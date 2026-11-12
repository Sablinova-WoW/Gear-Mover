Gear Mover
Gear Mover is a World of Warcraft 3.3.5a addon made for Synastria. It lets you quickly deposit and withdraw equipment between your bags, guild bank, and regular bank without dragging items one by one.

Features
- Deposit and Withdraw by category: Move Cloth, Leather, Mail, Plate, and Weapons (including shields and off-hands).
- Multiple guild-bank tabs: Assign any combination of tabs 1–6 to each category. Gear Mover tries the lowest selected tab first and uses the others for overflow when needed.
- Deposit All: Guild banks sort eligible gear into its assigned tabs (unassigned categories are skipped). Regular banks and Jeeves put eligible gear into free bank slots.
- Withdraw All: Works with guild banks, regular banks, and Jeeves. Withdraws only gear that the current character can still attune.
- Attunement-aware weapons: Individual weapon withdrawals only take weapons the current character can still attune.
- Deposit filters: Set a minimum item quality, skip Mythic gear, skip fully attuned BoEs, skip BoEs with an already-attuned variant, or keep gear the current character can still attune.
- Item counts: Hover any button to see how many items it would move right now, e.g. "Deposit Cloth (7)".
- Three transfer-window layouts: Full, compact, and icon-only, with custom equipment icons and green/amber direction highlights. Buttons visibly press in when clicked.
- Resizable window: Drag the corner to scale the transfer UI.
- Account-wide settings: Window position, size, layout, selected Deposit/Withdraw direction, deposit filters, and transfer interval carry across all characters.
- Bank support: Guild banks, normal banks, and Jeeves. Built primarily around Bagnon but designed to work with Blizzard's default bank and bag frames, and with ElvUI.
- Lightweight: Gear Mover does no background work while you're away from a bank.
Guild-bank tab assignments are saved per guild and realm. Deposit filters and the transfer interval (10–200 ms, 80 ms default) are shared by every character on your account.
Installation
1. Download the ZIP from the latest release. Use the release attachment rather than GitHub's automatically generated source-code ZIP.
2. Extract the Gear Mover folder to your WoW installation's Interface/AddOns/ directory.
3. Confirm the path looks like Interface/AddOns/Gear Mover/Gear Mover.toc and that the UI and Textures subfolders are inside Gear Mover.
4. Fully restart WoW after installing or updating so the custom textures load.
The required MaterialCraftUI Classic files are included. You do not need to install MaterialCraftUI separately.
Upgrading from an older version keeps your settings. Deposit filters you set before 1.4.0 (which were saved per guild) are carried over to the new account-wide settings automatically.
Commands
Command	Action
/ggm	Open the addon settings under Interface → AddOns
/ggm window	Toggle the floating transfer window
/ggm all	Deposit All
/ggm withdrawall	Withdraw All eligible equipment
/ggm tabs	Show assigned guild-bank tabs
/ggm debug	Show bank-detection diagnostics


The floating window also appears when you open a supported bank. Use its top-right control to cycle layouts.
Notes
- Withdraw All only withdraws equipment eligible for attunement on the current character. Individual Cloth, Leather, Mail, and Plate withdrawals take every item of that type on the open tab or bank.
- Individual Deposit can fall back to the currently open guild tab when the assigned tabs cannot accept an item. Deposit All uses assigned tabs only.
- BoE deposit protections and "Keep gear I can still attune" are optional and off by default. If enabled and Synastria cannot confirm the relevant item information, Gear Mover keeps the item rather than risking a deposit.
- Transfers are not blocked just because you're in combat (handy with Jeeves). If the game refuses an action in combat, the batch stops safely with a message.
- Transfers depend on server responses and may be throttled. Speeds below 50 ms are experimental and may result in failed moves or instability.
- Test new versions with inexpensive items first and back up your SavedVariables before major upgrades.
Credits
Special thanks to @iExpulsion for troubleshooting help and MaterialCraftUI, and to @Qt for making her OmniInventory source public, which helped form the basis of this addon.

The bundled MaterialCraftUI files are distributed under the MIT license; see MATERIALCRAFTUI_LICENSE.txt. See THIRD_PARTY_NOTICES.txt for additional attribution.

AI Disclaimer: This addon was made with the help of AI. I am not a coder. It's been tested and refined for performance issues, but could still be sloppy.

If you find any bugs or have suggestions, feel free to open an issue.
