Gear Mover v1.0.0 - Synastria / WoW 3.3.5a

PURPOSE
Transfer matching armor (Cloth, Leather, Mail, Plate) and main-hand,
off-hand, shield, and ranged-slot equipment between bags and a live
personal bank or the currently open guild bank.

SETTINGS
Open Interface > AddOns > Gear Mover or type /ggm.
Assign guild-bank tabs 1–6 (or Unassigned) to each category. Assignments
are saved per realm and guild. Individual guild deposits use an assigned
tab, or the currently selected tab if Unassigned. Deposit All processes
only assigned categories and changes tabs as needed.

Optional filters: minimum deposit quality (0–5) and Skip Mythic.
Both apply to deposits only, not withdrawals. Click Save settings.

TRANSFER WINDOW
It appears when you open a supported live bank. You can also toggle it
with /ggm window. The bottom row contains Deposit All and Stop.
Weapons withdrawn from a bank are filtered for current-character
attunability; deposits are not filtered that way. Guild-bank deposits
skip soulbound equipment. Personal-bank transfers preserve their previous
behavior. All items are processed in matching equipment categories.

PERFORMANCE / STATUS
Transfers use the configured 10-200 ms interval (80 ms default).
Source-slot observations are reconciled
about every 200 ms while a batch runs (and once at completion), avoiding
an inventory read on every rendered frame. Stack merging is conservative.
Reported observations are NOT guaranteed server-confirmed transfers.

COMMANDS
/ggm             Open Interface > AddOns > Gear Mover
/ggm window      Toggle floating transfer panel
/ggm all         Deposit All into assigned guild tabs
/ggm tabs        Display current tab assignments
/ggm debug       Display bank-detection information

INSTALL
Copy the Gear Mover folder into Interface/AddOns and reload WoW.
Keep one version installed at a time. Settings are in GearMoverDB.

RELEASE VALIDATION
Before public distribution, test bank detection, transfers, settings navigation,
and guild tab switching in the live Synastria client. Transfer counts reflect
attempts and observed source changes, not server acknowledgements.
Start with inexpensive items.

TRANSFER SPEED
Configure 10-200 ms under Interface > AddOns > Gear Mover; the default
is 80 ms. Intervals below 50 ms are experimental. This is an attempt
interval, not a guarantee of server transfer speed or successful moves.

THIRD-PARTY ATTRIBUTION
Gear Mover was developed with reference to OmniInventory/OmniInv-Syn.
See THIRD_PARTY_NOTICES.txt for the upstream MIT license notice.
This notice does not assign a license to original Gear Mover code.
