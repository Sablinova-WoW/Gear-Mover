Gear Mover v1.1.4 Beta — Synastria / World of Warcraft 3.3.5a

INSTALL
Copy the Gear Mover folder to Interface/AddOns, replacing older versions.
Type /reload. Your existing GearMoverDB settings are retained.

SETTINGS  (/ggm)
For each category (Cloth, Leather, Mail, Plate, Weapons), check any of
six guild tabs. Categories can share tabs. Click Save settings.
Old single-tab selections are migrated automatically on load.
Tab assignments and deposit filters are saved per guild and realm.
Transfer speed (10–200 ms, default 80 ms) is shared across guilds.
Below 50 ms is experimental; the client/server may reject rapid moves.
The checkbox UI uses the bundled MaterialCraftUI Classic skin ONLY.
No separate MaterialCraftUI installation is required.

TRANSFERS  (/ggm window)
Individual Deposit: tries the selected tabs in ascending order. If none
has room for a whole stack, it also tries the tab currently open when
that tab is not already selected. With no selected tabs, it uses the
currently open tab. The first selected tab is the primary destination. Additional selected
tabs are visited only if the primary has no room for eligible stacks
(or cannot be used). When no eligible items remain, the category stops
without cycling through other selected tabs.
Deposit All: visits selected tabs only for categories that still have
transferable equipment. It skips categories with only soulbound or locked gear.
It uses the first selected tab as primary and visits subsequent selected
tabs only when eligible items cannot fit on the current tab.
It never uses an unassigned tab as an automatic fallback.
Withdraw (category): removes matching equipment from the open bank tab.
The existing weapon-withdraw attunement filter remains unchanged.
Withdraw All (guild bank only): scans the currently open tab first, then
other accessible tabs 1–6, and removes
only items currently attunable by the character, checking link-specific
attunement progress before every attempt. It stops if bags fill or a
bank/data error prevents safe continuation. No account-wide withdrawal.
Guild deposits skip soulbound items. Regular bank deposit/withdraw
behavior is preserved. Stacks merge only if the entire source stack fits.
No automatic transfer can be guaranteed by client-side UI code: bank
responses may lag; chat summaries distinguish attempted from observed.
Multi-tab jobs wait for outstanding source changes before switching tabs.
If the bank does not confirm a move within 3 seconds, the batch stops
instead of risking a second attempt on the same source stack.

COMMANDS
/ggm              Open settings (scroll-aware WoW 3.3.5 navigation)
/ggm window       Toggle floating transfer window
/ggm all          Deposit All
/ggm withdrawall  Withdraw All
/ggm tabs         Print assigned tabs
/ggm debug        Inspect live bank detection

BETA TESTING
Start at 80 ms with inexpensive items. Test two selected tabs, a full
first tab, a manual deposit to an unassigned open tab, and Withdraw All
with some eligible and ineligible items. Observe server response and
check actual item counts; attempted transfers are not confirmations.
This beta is not yet in-game verified on Synastria.
If a guild-bank response remains unconfirmed, the batch stops after a
3-second wait. Check the actual bag and bank contents before restarting.

ATTRIBUTION
MaterialCraftUI by iExpulsion (MIT); license included in
MATERIALCRAFTUI_LICENSE.txt. Only Style.lua and the Classic skin are
bundled. See THIRD_PARTY_NOTICES.txt for OmniInventory attribution.
