Gear Mover
Gear Mover is a World of Warcraft 3.3.5a addon made for Synastria. It lets you quickly deposit and withdraw equipment between your bags, guild bank, and regular bank without dragging items one by one.

Features
- Deposit and Withdraw by category: Move Cloth, Leather, Mail, Plate, and Weapons (including shields and off-hands).
- Multiple guild-bank tabs: Assign any combination of tabs 1–6 to each category. Gear Mover tries the lowest selected tab first and uses the others for overflow when needed.
- Deposit All: Sort eligible gear into its assigned tabs. Unassigned categories are skipped.
- Withdraw All: Scan accessible guild-bank tabs and withdraw gear that the current character can still attune.
- Attunement-aware weapons: Individual guild-bank weapon withdrawals only take weapons the current character can still attune.
- Deposit filters: Set a minimum item quality, skip Mythic gear, skip fully attuned BoEs, or skip BoEs with an already-attuned variant.
- Three transfer-window layouts: Full, compact, and icon-only, with custom equipment icons and green/amber direction highlights.
- Resizable window: Drag the corner to scale the transfer UI.
- Account-wide UI preferences: Window position, size, layout, and selected Deposit/Withdraw direction carry across characters.
- Bank support: Guild banks, normal banks, and Jeeves. Built primarily around Bagnon but designed to work with Blizzard's default bank and bag frames.
Guild-bank tab assignments and deposit rules are saved per guild and realm. The transfer interval (10–200 ms, 80 ms default) is an account-wide preference.
Installation
1. Download the ZIP from the latest release. Use the release attachment rather than GitHub's automatically generated source-code ZIP.
2. Extract the Gear Mover folder to your WoW installation's Interface/AddOns/ directory.
3. Confirm the path looks like Interface/AddOns/Gear Mover/Gear Mover.toc and that the UI and Textures subfolders are inside Gear Mover.
4. Fully restart WoW after installing or updating so the custom textures load.
The required MaterialCraftUI Classic files are included. You do not need to install MaterialCraftUI separately.
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
- Withdraw All is for guild banks and only withdraws equipment eligible for attunement on the current character.
- Individual Deposit can fall back to the currently open guild tab when the assigned tabs cannot accept an item. Deposit All uses assigned tabs only.
- BoE deposit protections are optional and off by default. If enabled and Synastria cannot confirm the relevant item information, Gear Mover skips the item rather than risking a deposit.
- Transfers depend on server responses and may be throttled. Speeds below 50 ms are experimental and may result in failed moves or instability.
- Test new versions with inexpensive items first and back up your SavedVariables before major upgrades.
Credits
Special thanks to @iExpulsion for troubleshooting help and MaterialCraftUI, and to @Qt for making her OmniInventory source public, which helped form the basis of this addon.

The bundled MaterialCraftUI files are distributed under the MIT license; see MATERIALCRAFTUI_LICENSE.txt. See THIRD_PARTY_NOTICES.txt for additional attribution.

AI Disclaimer: This addon was made with the help of AI. I am not a coder. It's been tested and refined for performance issues, but could still be sloppy.

If you find any bugs or have suggestions, feel free to open an issue.
