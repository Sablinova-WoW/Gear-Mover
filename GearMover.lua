-- Gear Mover for WoW 3.3.5a (Synastria)
-- Independent of OmniInventory. Works with an open guild bank or personal bank.
-- Transfer timing is configurable in Interface > AddOns (10-200 ms).
local addonName, GearMoverNS = ...
if GearMoverNS and GearMoverNS.Style then GearMoverNS.Style.UseSkin("classic") end
local addon = CreateFrame("Frame", "GearMoverEventFrame")
local panel
local createPanel
local refreshPanel
local layoutMode = 1 -- 1=full, 2=compact text, 3=icons
local transferDirection = "deposit"
local skipCompletedBoE = false
local skipAccountAttunedBoE = false
local configPanel -- Blizzard Interface > AddOns settings page
local configRegistered = false
local configuredTabs = {}
local minDepositQuality = 0
local skipMythic = false
local observations = {}
local pendingObservations = {}
local tabKeys = {"Cloth", "Leather", "Mail", "Plate", "Weapon"}
local tabLabels = {Cloth="Cloth", Leather="Leather", Mail="Mail", Plate="Plate", Weapon="Weapons"}
local function configuredTabList(key)
    return configuredTabs[key] or {}
end
local function selectedTabs(key)
    local out = {}
    for _, tab in ipairs(configuredTabList(key)) do
        if tab >= 1 and tab <= (GetNumGuildBankTabs() or 0) then
            out[#out+1] = tab
        end
    end
    return out
end
local guildActive = false
local personalActive = false
local job
local transferMs = 80 -- User-configured delay between attempts; 10-200 ms.
local interval = transferMs / 1000
local tick = 0
local observationTick = 0
local detectionTick = 0
local wasBankAvailable = false
local synastriaReady = type(_G.SynastriaSafeInvoke) ~= "function"
-- The safe-invoke helper only accepts a global function name (not a Lua closure).
_G.GearMoverSynastriaReady = function()
    synastriaReady = true
end
if type(_G.SynastriaSafeInvoke) == "function" then
    -- Defer API-dependent checks until Synastria has finished loading its Lua extensions.
    pcall(_G.SynastriaSafeInvoke, "GearMoverSynastriaReady")
end
-- Tooltip inspection is needed on the 3.3.5 client: GetContainerItemInfo
-- does not provide a reliable isSoulbound return value.
local bindTip = CreateFrame("GameTooltip", "GearMoverBindTooltip", UIParent, "GameTooltipTemplate")
bindTip:SetOwner(UIParent, "ANCHOR_NONE")
local function isSoulbound(bag, slot)
    -- Synastria exposes a direct, language-independent bag-slot check.
    -- Fall back to the tooltip if that optional API is absent or fails.
    if synastriaReady and type(_G.Custom_IsContainerItemSoulbound) == "function" then
        local ok, bound = pcall(_G.Custom_IsContainerItemSoulbound, bag, slot)
        if ok and (bound == true or bound == 1) then return true end
        if ok and (bound == false or bound == 0) then return false end
    end
    bindTip:SetOwner(UIParent, "ANCHOR_NONE")
    bindTip:ClearLines()
    bindTip:SetBagItem(bag, slot)
    local soulboundText = ITEM_SOULBOUND or "Soulbound"
    for i = 1, bindTip:NumLines() do
        local line = _G["GearMoverBindTooltipTextLeft" .. i]
        local value = line and line:GetText()
        if value and (value == soulboundText or value:find("Soulbound", 1, true)) then
            bindTip:Hide()
            return true
        end
    end
    bindTip:Hide()
    return false
end
-- Original binding must be read from the Synastria item template, not
-- today's soulbound state. Mirror AttuneSight's documented tag semantics.
local boeTemplateCache, boeTemplateEntries = {}, 0
local boeTip = CreateFrame("GameTooltip", "GearMoverOriginalBoETooltip", UIParent, "GameTooltipTemplate")
boeTip:SetOwner(UIParent,"ANCHOR_NONE")
local function originalBoE(link, bag, slot)
    local id = link and tonumber(link:match("item:(%d+)"))
    if not id then return nil end
    if boeTemplateCache[id]~=nil then return boeTemplateCache[id] end
    if synastriaReady and type(_G.GetItemTagsCustom)=="function" and bit and bit.band then
        local ok, _, tags2, tags3 = pcall(_G.GetItemTagsCustom,id)
        if ok and type(tags3)=="number" then
            local known
            if bit.band(tags3,1)~=0 then known=true
            elseif type(tags2)=="number" and bit.band(tags2,128)~=0 then known=false end
            if known~=nil then
                if boeTemplateEntries>=256 then boeTemplateCache={};boeTemplateEntries=0 end
                boeTemplateCache[id]=known
                boeTemplateEntries=boeTemplateEntries+1
                return known
            end
        end
    end
    -- Current unsoulbound BoEs still show their original binding in tooltips.
    -- Once soulbound, original BoE can only be established by custom tags.
    if bag ~= nil and slot ~= nil then
        boeTip:SetOwner(UIParent,"ANCHOR_NONE")
        boeTip:ClearLines()
        boeTip:SetBagItem(bag,slot)
        for i=2,boeTip:NumLines() do
            local text=_G["GearMoverOriginalBoETooltipTextLeft"..i]
            if text and text:GetText()==ITEM_BIND_ON_EQUIP then
                boeTip:Hide()
                return true
            end
        end
        boeTip:Hide()
    end
    -- A missing BoE tooltip line does not reliably classify the original
    -- binding: tooltip/item data may not have loaded yet. With protection
    -- enabled, fail closed rather than risking an unwanted deposit.
    return nil -- No reliable template classification available.
end
local function completedLinkAttunement(link)
    if not synastriaReady then return nil end
    if type(_G.GetItemLinkAttuneProgress)=="function" then
        local ok, n=pcall(_G.GetItemLinkAttuneProgress,link)
        if ok and type(n)=="number" then return n>=100 end
    end
    if type(_G.GetItemAttuneProgress)=="function" and
       type(_G.CustomExtractItemAffix)=="function" and
       type(_G.CustomExtractItemBonus)=="function" and
       bit and type(bit.rshift)=="function" then
        local id=tonumber(link:match("item:(%d+)"))
        local okA,affix=pcall(_G.CustomExtractItemAffix,link)
        local okB,bonus=pcall(_G.CustomExtractItemBonus,link)
        if id and okA and okB and type(affix)=="number" and type(bonus)=="number" then
            local ok,n=pcall(_G.GetItemAttuneProgress,id,affix,bit.rshift(bonus,12))
            if ok and type(n)=="number" then return n>=100 end
        end
    end
    -- Unknown affix data must not be mistaken for an unattuned variant.
    return nil
end
local function accountVariantAttuned(link)
    local id=link and tonumber(link:match("item:(%d+)"))
    if not id or not synastriaReady or type(_G.HasAttunedAnyVariantOfItem)~="function" then return nil end
    local ok, result=pcall(_G.HasAttunedAnyVariantOfItem,id)
    if not ok then return nil end
    if result==true or result==1 then return true end
    if result==false or result==0 or result==nil then return false end
    return nil
end
local function msg(s) DEFAULT_CHAT_FRAME:AddMessage("|cff55ddaaGear Mover:|r " .. s) end

local categories = {
    { key="Cloth", label="Cloth" },
    { key="Leather", label="Leather" },
    { key="Mail", label="Mail" },
    { key="Plate", label="Plate" },
    { key="Weapon", label="Weapons" },
}
-- Equipment locations supported by the main-hand, off-hand and ranged slots.
-- Includes shields, off-hand frills, relics, wands, bows and thrown weapons.
-- GetItemInfo's ninth return value is equipLoc on the 3.3.5 client.
local weaponEquipLocations = {
    ["INVTYPE_WEAPON"] = true,
    ["INVTYPE_WEAPONMAINHAND"] = true,
    ["INVTYPE_WEAPONOFFHAND"] = true,
    ["INVTYPE_2HWEAPON"] = true,
    ["INVTYPE_SHIELD"] = true,
    ["INVTYPE_HOLDABLE"] = true,
    ["INVTYPE_RANGED"] = true,
    ["INVTYPE_RANGEDRIGHT"] = true,
    ["INVTYPE_THROWN"] = true,
    ["INVTYPE_RELIC"] = true,
}
local function itemCategory(link)
    if not link then return end
    local _, _, _, _, _, kind, subType, _, equipLoc = GetItemInfo(link)
    -- Synastria can resolve item IDs that the standard client cache does not yet know.
    if (not kind or not equipLoc) and synastriaReady and type(_G.GetItemInfoCustom) == "function" then
        local itemID = tonumber(string.match(link, "item:(%d+)"))
        if itemID then
            local ok, _, _, _, _, _, customKind, customSubtype, _, customEquipLoc =
                pcall(_G.GetItemInfoCustom, itemID)
            if ok then
                kind = kind or customKind
                subType = subType or customSubtype
                equipLoc = equipLoc or customEquipLoc
            end
        end
    end
    if weaponEquipLocations[equipLoc] then return "Weapon" end
    if kind == "Armor" and (subType == "Cloth" or subType == "Leather" or subType == "Mail" or subType == "Plate") then
        return subType
    end
end

-- Optional deposit restrictions. Defaults preserve all previous matching equipment.
local function allowedDeposit(link, bag, slot)
    if not link then return false end
    local _, _, quality = GetItemInfo(link)
    if minDepositQuality > 0 and (not quality or quality < minDepositQuality) then return false end
    if skipCompletedBoE or skipAccountAttunedBoE then
        local boe=originalBoE(link,bag,slot)
        if boe==true then
            if skipCompletedBoE and completedLinkAttunement(link)~=false then return false end
            if skipAccountAttunedBoE and accountVariantAttuned(link)~=false then return false end
        elseif boe==nil then
            -- The user explicitly asked us to protect potentially saleable BoEs.
            -- Unknown binding is skipped rather than risking an accidental deposit.
            return false
        end
    end
    if skipMythic then
        local itemID=tonumber(string.match(link, "item:(%d+)"))
        if itemID and type(_G.GetItemTagsCustom)=="function" and _G.bit then
            local ok,tags1=pcall(_G.GetItemTagsCustom,itemID)
            if not ok or type(tags1)~="number" then return false end
            if bit.band(tags1,128)~=0 then return false end
        else
            -- If the API cannot tell us whether an item is Mythic, don't risk moving it.
            return false
        end
    end
    return true
end

-- Replicates the strict CURRENT-character Attunable category from
-- OmniInv-Syn's Omni/Categorizer.lua (not account-wide attunability).
-- Use link-based progress first so affix/forge variants resolve correctly.
local function isAttunableForCurrentCharacter(link)
    if not link or not synastriaReady or type(_G.CanAttuneItemHelper) ~= "function" then return false end
    local itemID = tonumber(string.match(link, "item:(%d+)"))
    if not itemID then return false end
    local ok, canAttune = pcall(CanAttuneItemHelper, itemID)
    if not ok or type(canAttune) ~= "number" or canAttune < 1 then return false end

    -- Current-character eligibility is authoritative here. Account-wide eligibility
    -- is not an additional requirement and may report differently on custom variants.

    local progress
    if type(_G.GetItemLinkAttuneProgress) == "function" then
        local worked, result = pcall(GetItemLinkAttuneProgress, link)
        if worked and type(result) == "number" then progress = result end
    end
    if type(progress) ~= "number" and type(_G.GetItemAttuneProgress) == "function" then
        -- Compatibility fallback for installations without the link-based helper.
        -- If we cannot resolve variant-specific forge/affix data, fail closed instead
        -- of misidentifying an already-attuned variant as fresh.
        if type(_G.CustomExtractItemAffix) == "function" and
           type(_G.CustomExtractItemBonus) == "function" and
           type(_G.bit) == "table" and type(_G.bit.rshift) == "function" then
            local affixOk, affix = pcall(_G.CustomExtractItemAffix, link)
            local bonusOk, bonus = pcall(_G.CustomExtractItemBonus, link)
            if affixOk and bonusOk and type(affix) == "number" and type(bonus) == "number" then
                local tier = bit.rshift(bonus, 12)
                local worked, result = pcall(_G.GetItemAttuneProgress, itemID, affix, tier)
                if worked and type(result) == "number" then progress = result end
            end
        end
    end
    -- Unknown progress is NOT safe to treat as attunable.
    return type(progress) == "number" and progress < 100
end
local function currentTab()
    local n = GetCurrentGuildBankTab and GetCurrentGuildBankTab()
    if n and n > 0 and n <= (GetNumGuildBankTabs() or 0) then return n end
end
local bankOpen
local function freeGuildSlot(tab, reserved)
    for slot=1,98 do
        if not reserved[slot] then
            local texture = GetGuildBankItemInfo(tab,slot)
            if not texture then return slot end
        end
    end
end
-- Bank main container is -1; purchased bank-bag containers are 5 through 11.
-- Query GetContainerNumSlots so unopened/unpurchased bank bags are excluded.
local function bankContainers()
    local out = {-1}
    for bag=5,11 do
        if (GetContainerNumSlots(bag) or 0)>0 then table.insert(out,bag) end
    end
    return out
end
local function emptySlot(containers, reserved)
    for _,bag in ipairs(containers) do
        for slot=1,(bag==-1 and 28 or (GetContainerNumSlots(bag) or 0)) do
            local id=tostring(bag)..":"..slot
            if not reserved[id] and not GetContainerItemLink(bag,slot) then return bag,slot,id end
        end
    end
end
-- Move to an existing identical stack only if the ENTIRE source fits.
-- A partial merge can leave a remainder on the cursor and is not safe for batch transfers.
local function sourceStackCount(bag,slot)
    local _, count = GetContainerItemInfo(bag,slot)
    return count or 1
end
local function stackCapacity(link)
    local max = select(8,GetItemInfo(link))
    return type(max)=="number" and max or 1
end
local function matchingPersonalStack(containers,link,count,sourceBag,sourceSlot)
    local cap=stackCapacity(link)
    if cap<=1 or count>cap then return end
    for _,bag in ipairs(containers) do
        for slot=1,(bag==-1 and 28 or (GetContainerNumSlots(bag) or 0)) do
            if (bag~=sourceBag or slot~=sourceSlot) and GetContainerItemLink(bag,slot)==link then
                local n=sourceStackCount(bag,slot)
                if n>0 and n+count<=cap then return bag,slot end
            end
        end
    end
end
local function matchingGuildStack(tab,link,count,planned)
    local cap=stackCapacity(link)
    if cap<=1 or count>cap then return end
    for slot=1,98 do
        if GetGuildBankItemLink(tab,slot)==link then
            local _,n,locked=GetGuildBankItemInfo(tab,slot)
            if not locked and n and n>0 and n+count+(planned[slot] or 0)<=cap then return slot end
        end
    end
end

local function guildCount(tab,slot)
    local _,count=GetGuildBankItemInfo(tab,slot)
    return count or 0
end
local function observeLater(entry)
    pendingObservations[#pendingObservations+1]=entry
end
local function reconcileObservations()
    for i=#pendingObservations,1,-1 do
        local e=pendingObservations[i]
        local link,count
        if e.sourceType=="guild" then
            link=GetGuildBankItemLink(e.tab,e.slot)
            count=link and guildCount(e.tab,e.slot) or 0
        else
            link=GetContainerItemLink(e.bag,e.slot)
            count=link and sourceStackCount(e.bag,e.slot) or 0
        end
        if link~=e.link or count<e.count then
            observations.confirmed=observations.confirmed+1
            -- Observation order is irrelevant; swap removal avoids shifting the list.
            pendingObservations[i] = pendingObservations[#pendingObservations]
            pendingObservations[#pendingObservations] = nil
        end
    end
end
local function freeBagSlot()
    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            if not GetContainerItemLink(bag, slot) then return true end
        end
    end
    return false
end
-- Bagnon overrides the default Blizzard bank display. Its BANK_OPENED /
-- BANK_CLOSED are Ace messages, not game events. Query the actual live
-- bank state Bagnon maintains from BANKFRAME_OPENED/CLOSED instead.
-- Never infer an active bank session just from a visible Bagnon bank frame:
-- Bagnon supports opening a cached, offline bank view anywhere.
local function bagnonBankState()
    local b = _G.Bagnon
    if not b or not b.BagEvents or type(b.BagEvents.AtBank) ~= "function" then return nil end
    local ok, atBank = pcall(b.BagEvents.AtBank, b.BagEvents)
    if ok then return atBank and true or false end
    return nil
end
local function bagnonFrameShown(frameID)
    local b = _G.Bagnon
    if not b or type(b.GetFrame) ~= "function" then return false end
    local ok, frame = pcall(b.GetFrame, b, frameID)
    return ok and frame and frame.IsShown and frame:IsShown() or false
end
local function personalBankOpen()
    local bagnonState = bagnonBankState()
    -- A real BANKFRAME_OPENED event is definitive, even if Bagnon reports
    -- false temporarily (e.g. before its state refresh finishes).
    if personalActive then return true end
    if bagnonState ~= nil then return bagnonState end
    return (BankFrame and BankFrame:IsShown()) or false
end
local function guildBankOpen()
    -- Blizzard and Bagnon share guild bank APIs; Bagnon_GuildBank renders
    -- a separate 'guildbank' frame and hides Blizzard's original frame.
    if not currentTab() then return false end
    if guildActive then return true end
    if GuildBankFrame and GuildBankFrame:IsShown() then return true end
    return bagnonFrameShown("guildbank")
end
bankOpen = guildBankOpen
-- Move a full stack only to an empty slot, avoiding accidental item swaps.
-- If the destination rejects the stack, attempt to restore its source.
local function movePersonal(srcBag,srcSlot,dstBag,dstSlot)
    if CursorHasItem() then return false,"cursor occupied" end
    local sourceLink=GetContainerItemLink(srcBag,srcSlot)
    local destLink=GetContainerItemLink(dstBag,dstSlot)
    if not sourceLink or (destLink and destLink~=sourceLink) then return false,"slot changed" end
    if destLink and sourceStackCount(dstBag,dstSlot)+sourceStackCount(srcBag,srcSlot)>stackCapacity(sourceLink) then
        return false,"stack cannot fit"
    end
    PickupContainerItem(srcBag,srcSlot)
    if not CursorHasItem() then return false,"source locked" end
    PickupContainerItem(dstBag,dstSlot)
    if CursorHasItem() then
        PickupContainerItem(srcBag,srcSlot)
        if CursorHasItem() then return false,"item stuck on cursor" end
        return false,"destination rejected"
    end
    return true
end
local function stop(reason)
    if job then
        local finished = job.moved
        local skipped = job.skipped or 0
        reconcileObservations()
        local confirmed=observations.confirmed or 0
        local outstanding=#pendingObservations
        job = nil
        tick = 0
        observationTick = 0
        pendingObservations = {}
        observations = {}
        if refreshPanel then refreshPanel() end
        if reason then msg(reason .. " (attempted: " .. finished .. ", source changes observed: " .. confirmed .. ", awaiting/uncertain: " .. outstanding .. ", skipped: " .. skipped .. ")") end
    end
end
local function buildQueue(direction, key, mode, tab)
    local q={}
    if direction=="deposit" then
        for bag=0,4 do
            for slot=1,(GetContainerNumSlots(bag) or 0) do
                local link=GetContainerItemLink(bag,slot)
                if itemCategory(link)==key and allowedDeposit(link,bag,slot) then table.insert(q,{bag=bag,slot=slot,link=link}) end
            end
        end
    elseif mode=="guild" then
        for slot=1,98 do
            local link=GetGuildBankItemLink(tab,slot)
            if (key=="All" and isAttunableForCurrentCharacter(link)) or
               (itemCategory(link)==key and (key~="Weapon" or isAttunableForCurrentCharacter(link))) then
                table.insert(q,{slot=slot,link=link})
            end
        end
    else
        for _,bag in ipairs(bankContainers()) do
            for slot=1,(bag==-1 and 28 or (GetContainerNumSlots(bag) or 0)) do
                local link=GetContainerItemLink(bag,slot)
                if itemCategory(link)==key and (key~="Weapon" or isAttunableForCurrentCharacter(link)) then
                    table.insert(q,{bag=bag,slot=slot,link=link})
                end
            end
        end
    end
    return q
end
-- Multi-tab guild deposits are a sequence of tab visits. A full tab advances
-- to the next selected destination; individual Deposit adds the OPEN tab as
-- a last-resort destination if it was not selected. Deposit All never does.
local function newJob(direction, mode, stages)
    observations={confirmed=0}
    pendingObservations={}
    job={direction=direction,mode=mode,stages=stages,stage=1,
         index=1,moved=0,skipped=0,reserved={},guildPlanned={},
         phase="select",tabWait=0}
    if refreshPanel then refreshPanel() end
end
local function addDepositStages(stages,key,includeOpenTab)
    local tabs=selectedTabs(key)
    if includeOpenTab then
        local open=currentTab()
        local exists=false
        for _, tab in ipairs(tabs) do if tab==open then exists=true end end
        if open and not exists then tabs[#tabs+1]=open end
    end
    for _, tab in ipairs(tabs) do
        stages[#stages+1]={category=key,tab=tab}
    end
end
local function attunementReady()
    return synastriaReady and type(_G.CanAttuneItemHelper)=="function" and
           (type(_G.GetItemLinkAttuneProgress)=="function" or
            type(_G.GetItemAttuneProgress)=="function")
end
local function hasDepositableItems(key)
    for bag=0,4 do
        for slot=1,(GetContainerNumSlots(bag) or 0) do
            local link=GetContainerItemLink(bag,slot)
            if link and itemCategory(link)==key and allowedDeposit(link,bag,slot) then
                local _,_,locked=GetContainerItemInfo(bag,slot)
                if not locked and not isSoulbound(bag,slot) then return true end
            end
        end
    end
    return false
end

local function start(direction,key)
    if job then msg("A transfer is running. Click Stop before starting another.") return end
    local mode=bankOpen() and "guild" or (personalBankOpen() and "personal" or nil)
    if not mode then msg("No live bank session detected. Use /ggm debug if needed.") return end
    if InCombatLockdown and InCombatLockdown() then msg("Cannot transfer in combat.") return end
    if CursorHasItem and CursorHasItem() then msg("Clear your cursor first.") return end
    if direction=="withdraw" and key=="Weapon" and not attunementReady() then
        msg("Attunement APIs unavailable; no weapons withdrawn.") return
    end
    if mode=="guild" and direction=="deposit" then
        if not hasDepositableItems(key) then msg("No transferable items to deposit.") return end
        local stages={}
        addDepositStages(stages,key,true)
        if #stages==0 then msg("No available guild bank tab.") return end
        newJob(direction,mode,stages)
        msg("Depositing "..tabLabels[key].." through up to "..#stages.." tabs.")
        return
    end
    local tab=mode=="guild" and currentTab() or nil
    if mode=="guild" then
        if not tab then msg("Select an available guild bank tab.") return end
        local _,_,viewable,_,_,remaining=GetGuildBankTabInfo(tab)
        if not viewable or (direction=="withdraw" and remaining==0) then
            msg("No access or withdrawal allowance on this tab.") return
        end
    end
    local queue=buildQueue(direction,key,mode,tab)
    if #queue==0 then msg("No matching items found.") return end
    observations={confirmed=0};pendingObservations={}
    job={direction=direction,category=key,mode=mode,tab=tab,queue=queue,
         index=1,moved=0,skipped=0,reserved={},guildPlanned={},phase="transfer",tabWait=0}
    if refreshPanel then refreshPanel() end
    msg(string.format("Starting %s: %d %s stacks.",direction,#queue,tabLabels[key]))
end


local function startAll()
    if job then msg("Stop the active transfer first.") return end
    if not guildBankOpen() then msg("Open your live guild bank first.") return end
    if InCombatLockdown and InCombatLockdown() then msg("Cannot transfer in combat.") return end
    if CursorHasItem and CursorHasItem() then msg("Clear your cursor first.") return end
    local stages={}
    for _,key in ipairs(tabKeys) do
        if hasDepositableItems(key) then
            addDepositStages(stages,key,false)
        end
    end
    if #stages==0 then msg("No matching items with assigned guild tabs.") return end
    newJob("deposit","guild",stages)
    msg("Deposit All: "..#stages.." tab visits queued.")
end

local function startWithdrawAll()
    if job then msg("Stop the active transfer first.") return end
    if not guildBankOpen() then msg("Open your live guild bank first.") return end
    if InCombatLockdown and InCombatLockdown() then msg("Cannot transfer in combat.") return end
    if CursorHasItem and CursorHasItem() then msg("Clear your cursor first.") return end
    if not attunementReady() then msg("Attunement APIs unavailable; nothing withdrawn.") return end
    -- Withdraw All cannot use partial-stack capacity safely without relying
    -- on AutoStore's undocumented merge behavior. Avoid touring six tabs when
    -- every carried bag slot is already occupied.
    if not freeBagSlot() then msg("No empty bag slots; Withdraw All not started.") return end
    local stages={}
    local first=currentTab()
    if first and first<=6 then stages[#stages+1]={category="All",tab=first} end
    for tab=1,math.min(6,GetNumGuildBankTabs() or 0) do
        if tab~=first then stages[#stages+1]={category="All",tab=tab} end
    end
    if #stages==0 then msg("No guild tabs available.") return end
    newJob("withdraw","guild",stages)
    msg("Withdraw All: scanning "..#stages.." guild tabs for current-character attunables.")
end

local function loadStage(j)
    local stage=j.stages and j.stages[j.stage]
    if not stage then return false end
    j.category=stage.category
    j.tab=stage.tab
    j.queue=nil -- Build only once this tab's live data is ready.
    j.index=1
    j.reserved={}
    j.guildPlanned={}
    j.tabWait=0
    j.overflowBlocked=false
    j.phase="select"
    return true
end
-- A completed tab queue is not evidence that the tab is full. Only an
-- actual lack of destination space (or inaccessible tab) permits overflow
-- to another tab of the same category. This keeps the first selected tab
-- as the primary destination and avoids unnecessary guild-bank queries.

local function finishStage(j,overflow)
    if not j.stages then stop("Transfer complete") return end
    local previousCategory=j.category
    j.stage=j.stage+1
    if j.direction=="deposit" then
        -- Once a category's items have all been attempted, do not visit its
        -- other assigned tabs. Even on overflow, skip them if no eligible
        -- items remain after outstanding moves have been confirmed.
        if not overflow or not hasDepositableItems(previousCategory) then
            while j.stages[j.stage] and j.stages[j.stage].category==previousCategory do
                j.stage=j.stage+1
            end
        end
        -- A category might have no transferable items by the time we reach it
        -- (e.g. only soulbound or locked gear). Skip its tabs entirely.
        while j.stages[j.stage] and not hasDepositableItems(j.stages[j.stage].category) do
            local emptyCategory=j.stages[j.stage].category
            repeat
                j.stage=j.stage+1
            until not j.stages[j.stage] or j.stages[j.stage].category~=emptyCategory
        end
    end
    j.advanceOverflow=nil
    if not loadStage(j) then
        stop(j.direction=="withdraw" and "Withdraw All complete" or "Deposit complete")
    end
end
local function advanceStage(j,overflow)
    -- Source slots can update asynchronously after a guild bank operation.
    -- Never make an overflow decision based on stale bag contents.
    reconcileObservations()
    if #pendingObservations > 0 then
        j.phase="settling"
        j.settleElapsed=0
        j.advanceOverflow=overflow==true
    else
        finishStage(j,overflow==true)
    end
end

addon:SetScript("OnUpdate",function(self,elapsed)
    -- Detect transitions even if a bank addon handles UI through its own messages.
    detectionTick = detectionTick + elapsed
    if detectionTick >= 0.3 then
        detectionTick = 0
        local available = (bankOpen() or personalBankOpen()) and true or false
        if available and not wasBankAvailable then
            createPanel()
            panel:Show()
        elseif not available and wasBankAvailable then
            if job then stop("Bank session closed") end
            if panel then panel:Hide() end
        end
        wasBankAvailable = available
    end
    if not job then return end
    -- Guild responses can lag; inspect pending source slots at a modest cadence
    -- instead of on every rendered frame. The final stop() performs one last check.
    if #pendingObservations > 0 then
        observationTick = observationTick + elapsed
        if observationTick >= 0.20 then
            observationTick = 0
            reconcileObservations()
        end
    end
    tick=tick+elapsed
    if tick<interval then return end
    tick=0
    if job.mode=="guild" then
        if not bankOpen() then stop("Guild bank closed") return end
        if job.stages and not job.category then loadStage(job) end
        if job.phase=="settling" then
            reconcileObservations()
            if #pendingObservations==0 then
                finishStage(job,job.advanceOverflow)
            else
                job.settleElapsed=(job.settleElapsed or 0)+interval
                if job.settleElapsed>=3 then
                    stop("Guild bank response unconfirmed; stopped to avoid retrying an unchanged item")
                end
            end
            return
        end
        if job.phase=="select" then
            local _,_,viewable,canDeposit,_,remaining=GetGuildBankTabInfo(job.tab)
            if not viewable or (job.direction=="deposit" and not canDeposit) or
               (job.direction=="withdraw" and remaining==0) then
                msg("Skipping tab "..job.tab.." (no permission or withdrawals remaining).")
                advanceStage(job,true)
                return
            end
            local switching=currentTab()~=job.tab
            if switching and type(SetCurrentGuildBankTab)~="function" then
                stop("Guild tab switch API unavailable") return
            end
            job.tabWasChanged=switching
            job.tabUpdated=not switching
            -- Register the wait state BEFORE requesting a tab. A fast/synchronous
            -- GUILDBANKBAGSLOTS_CHANGED must not be lost between the request
            -- and changing phase (which previously caused spurious timeouts).
            job.phase="waiting";job.tabWait=0
            if switching then SetCurrentGuildBankTab(job.tab) end
            if type(QueryGuildBankTab)=="function" then QueryGuildBankTab(job.tab) end
            return
        elseif job.phase=="waiting" then
            job.tabWait=job.tabWait+interval
            if currentTab()~=job.tab then
                if job.tabWait>3 then stop("Guild tab switch timed out") end
                return
            end
            if job.tabWait<0.45 then return end
            if job.tabWasChanged and not job.tabUpdated then
                if job.tabWait>4 then stop("Guild tab data timed out; no further items moved") end
                return
            end
            if job.stages then
                job.queue=buildQueue(job.direction,job.category,"guild",job.tab)
                job.index=1
                if #job.queue==0 then advanceStage(job,false) return end
            end
            job.phase="transfer"
        elseif currentTab()~=job.tab then stop("Guild tab changed during transfer") return end
    elseif not personalBankOpen() then stop("Regular bank closed") return end
    if InCombatLockdown and InCombatLockdown() then stop("Transfer stopped: combat") return end
    if CursorHasItem and CursorHasItem() then stop("Transfer stopped: item on cursor") return end
    local entry=job.queue[job.index]
    if not entry then advanceStage(job,job.overflowBlocked==true) return end
    job.index=job.index+1
    if job.mode=="personal" then
        local sourceBag,sourceSlot=entry.bag,entry.slot
        local link=GetContainerItemLink(sourceBag,sourceSlot)
        if link and link==entry.link and itemCategory(link)==job.category and
           (job.direction~="deposit" or allowedDeposit(link,sourceBag,sourceSlot)) and
           (job.direction~="withdraw" or job.category~="Weapon" or isAttunableForCurrentCharacter(link)) then
            local _,_,locked=GetContainerItemInfo(sourceBag,sourceSlot)
            if locked then job.skipped=job.skipped+1
            else
                local containers=job.direction=="deposit" and bankContainers() or {0,1,2,3,4}
                local count=sourceStackCount(sourceBag,sourceSlot)
                local destBag,destSlot=matchingPersonalStack(containers,link,count,sourceBag,sourceSlot)
                local merging=destBag~=nil
                local id
                if not merging then destBag,destSlot,id=emptySlot(containers,job.reserved) end
                if not destBag then stop("No empty destination slots") return end
                local ok,err=movePersonal(sourceBag,sourceSlot,destBag,destSlot)
                if ok then
                    if id then job.reserved[id]=true end
                    job.moved=job.moved+1
                    -- Personal bank APIs update locally; still verify actual source reduction.
                    if GetContainerItemLink(sourceBag,sourceSlot)~=link or sourceStackCount(sourceBag,sourceSlot)<count then
                        observations.confirmed=observations.confirmed+1
                    else
                        observeLater({sourceType="container",bag=sourceBag,slot=sourceSlot,link=link,count=count})
                    end
                elseif err=="item stuck on cursor" then stop("Could not restore item; clear cursor") return
                else job.skipped=job.skipped+1 end
            end
        else job.skipped=job.skipped+1 end
    elseif job.direction=="deposit" then
        local tab=job.tab
        local link=GetContainerItemLink(entry.bag,entry.slot)
        if link and itemCategory(link)==job.category and link==entry.link and allowedDeposit(link,entry.bag,entry.slot) then
            local _,_,locked=GetContainerItemInfo(entry.bag,entry.slot)
            if locked or isSoulbound(entry.bag,entry.slot) then job.skipped=job.skipped+1
            else
                local _,_,_,canDeposit=GetGuildBankTabInfo(tab)
                if not canDeposit then stop("No guild-tab deposit permission") return end
                local count=sourceStackCount(entry.bag,entry.slot)
                local dest=matchingGuildStack(tab,link,count,job.guildPlanned)
                local merging=dest~=nil
                if not dest then dest=freeGuildSlot(tab,job.reserved) end
                if not dest then
                    if job.stages then
                        -- One oversized stack does not mean the tab is full:
                        -- later smaller stacks may still fit. Inspect the
                        -- remaining queue before considering overflow.
                        job.overflowBlocked=true
                    else
                        stop("No empty guild-bank slots")
                        return
                    end
                else
                    PickupContainerItem(entry.bag,entry.slot)
                    if CursorHasItem and CursorHasItem() then
                        PickupGuildBankItem(tab,dest)
                        if CursorHasItem and CursorHasItem() then
                            PickupContainerItem(entry.bag,entry.slot)
                            if CursorHasItem and CursorHasItem() then
                                stop("Could not restore item; clear cursor")
                                return
                            end
                            job.skipped=job.skipped+1
                        else
                            if not merging then
                                job.reserved[dest]=true
                            else
                                job.guildPlanned[dest]=(job.guildPlanned[dest] or 0)+count
                            end
                            job.moved=job.moved+1
                            observeLater({sourceType="container",bag=entry.bag,slot=entry.slot,link=link,count=count})
                        end
                    else
                        job.skipped=job.skipped+1
                    end
                end
            end
        else job.skipped=job.skipped+1 end
    else
        local tab=job.tab
        local link=GetGuildBankItemLink(tab,entry.slot)
        if link and (job.category=="All" or itemCategory(link)==job.category) and link==entry.link then
            if (job.category=="All" or job.category=="Weapon") and
               not isAttunableForCurrentCharacter(link) then job.skipped=job.skipped+1
            else
                if not freeBagSlot() then stop("No completely empty bag slot") return end
                local _,_,_,_,_,remaining=GetGuildBankTabInfo(tab)
                if remaining and remaining==0 then
                    if job.stages then advanceStage(job,true) else stop("Guild-tab withdrawal limit reached") end
                    return
                end
                local before=guildCount(tab,entry.slot)
                AutoStoreGuildBankItem(tab,entry.slot)
                job.moved=job.moved+1
                observeLater({sourceType="guild",tab=tab,slot=entry.slot,link=link,count=before})
            end
        else job.skipped=job.skipped+1 end
    end
    if job.index>#job.queue then advanceStage(job,job.overflowBlocked==true) end
end)

local function guildConfigKey()
    local guild=GetGuildInfo("player") or "NoGuild"
    local realm=GetRealmName() or "UnknownRealm"
    return realm.."/"..guild
end
local function saveTabs()
    if not GearMoverDB then GearMoverDB={guilds={}} end
    if not GearMoverDB.guilds then GearMoverDB.guilds={} end
    local stored={}
    for _,key in ipairs(tabKeys) do
        local copy={}
        for _,tab in ipairs(configuredTabList(key)) do copy[#copy+1]=tab end
        stored[key]=copy
    end
    stored.minDepositQuality=minDepositQuality
    stored.skipMythic=skipMythic
    stored.skipCompletedBoE=skipCompletedBoE
    stored.skipAccountAttunedBoE=skipAccountAttunedBoE
    -- Speed is a global player preference; all guilds and personal banks use it.
    GearMoverDB.transferMs=transferMs
    GearMoverDB.guilds[guildConfigKey()]=stored
end
-- UI preferences are shared by all characters on this WoW account.
-- Migrate the previous character-scoped data once, preferring the current
-- character so upgrading does not unexpectedly change the visible layout.
local function uiSettings()
    GearMoverDB=GearMoverDB or {}
    if type(GearMoverDB.uiGlobal) ~= "table" then
        local old=GearMoverDB.ui
        local previous
        if type(old)=="table" then
            local key=(GetRealmName() or "UnknownRealm").."/"..(UnitName("player") or "Unknown")
            if type(old[key])=="table" then
                previous=old[key]
            else
                -- If this character has no legacy preferences, use an existing
                -- character's saved layout rather than dropping all prior settings.
                local keys={}
                for candidate,settings in pairs(old) do
                    if type(candidate)=="string" and type(settings)=="table" then
                        keys[#keys+1]=candidate
                    end
                end
                table.sort(keys)
                if keys[1] then previous=old[keys[1]] end
            end
        end
        GearMoverDB.uiGlobal={}
        if previous then
            for _,field in ipairs({"layout","direction","x","y","scale"}) do
                GearMoverDB.uiGlobal[field]=previous[field]
            end
        end
    end
    -- Per-character UI settings are obsolete. Discard them after migration
    -- rather than retaining stale SavedVariables and Lua tables forever.
    GearMoverDB.ui=nil
    return GearMoverDB.uiGlobal
end
local function savePanelPosition()
    if not panel or not panel.GetCenter or not UIParent.GetCenter then return end
    local x,y=panel:GetCenter()
    local cx,cy=UIParent:GetCenter()
    if not x or not cx then return end
    local prefs=uiSettings()
    prefs.x=x-cx
    prefs.y=y-cy
end
local function restorePanelPosition()
    if not panel then return end
    local prefs=uiSettings()
    panel:ClearAllPoints()
    local x=type(prefs.x)=="number" and prefs.x or 285
    local y=type(prefs.y)=="number" and prefs.y or 0
    -- Avoid a window that is completely offscreen after a resolution change.
    local scale=panel:GetScale() or 1
    local limitX=math.max(0,(UIParent:GetWidth() or 1024)/2-80*scale)
    local limitY=math.max(0,(UIParent:GetHeight() or 768)/2-35*scale)
    x=math.max(-limitX,math.min(limitX,x))
    y=math.max(-limitY,math.min(limitY,y))
    panel:SetPoint("CENTER",UIParent,"CENTER",x,y)
end
local function loadUiPreference()
    local prefs=uiSettings()
    local mode=tonumber(prefs.layout)
    layoutMode=(mode and mode>=1 and mode<=3) and math.floor(mode) or 1
    transferDirection=prefs.direction=="withdraw" and "withdraw" or "deposit"
    -- SetScale affects the entire window, preserving the proportions of each
    -- layout and avoiding different button hitboxes after a user resize.
    local scale=tonumber(prefs.scale) or 1
    if scale~=scale then scale=1 end -- Reject invalid NaN persisted by another addon.
    panel:SetScale(math.max(0.65,math.min(1.65,scale)))
    restorePanelPosition()
    if refreshPanel then refreshPanel() end
end
local function loadTabs()
    if not GearMoverDB then GearMoverDB={guilds={}} end
    if not GearMoverDB.guilds then GearMoverDB.guilds={} end
    configuredTabs={}
    local savedMs=tonumber(GearMoverDB.transferMs)
    transferMs=savedMs and math.max(10,math.min(200,math.floor(savedMs+0.5))) or 80
    interval=transferMs/1000
    local stored=GearMoverDB.guilds[guildConfigKey()] or {}
    minDepositQuality=tonumber(stored.minDepositQuality) or 0
    if minDepositQuality<0 or minDepositQuality>5 then minDepositQuality=0 end
    skipMythic=stored.skipMythic==true
    skipCompletedBoE=stored.skipCompletedBoE==true
    skipAccountAttunedBoE=stored.skipAccountAttunedBoE==true
    for _,key in ipairs(tabKeys) do
        local value=stored[key]
        local list={}
        if type(value)=="table" then
            for tab=1,6 do
                if value[tab]==true then list[#list+1]=tab end
            end
            -- Also accept the new compact ordered-list format.
            if #list==0 then
                for _,v in ipairs(value) do
                    v=tonumber(v)
                    if v and v>=1 and v<=6 then
                        local exists=false
                        for _,old in ipairs(list) do if old==v then exists=true end end
                        if not exists then list[#list+1]=math.floor(v) end
                    end
                end
                table.sort(list)
            end
        else
            local v=tonumber(value)
            if v and v>=1 and v<=6 then list[1]=math.floor(v) end
        end
        configuredTabs[key]=list
    end
end
-- Native WotLK Interface > AddOns settings. Values are edited locally and
-- committed together; closing the interface without Save leaves them alone.
local registerConfigPanel
-- The 3.3.5 InterfaceOptionsFrame_OpenToCategory helper only clicks buttons
-- currently rendered in the scrollable AddOns list. Scroll to our registered
-- panel before selecting it; otherwise it can leave the previous panel open.
local function openOptionsCategory(panel)
    if not panel or type(InterfaceOptionsFrame_OpenToCategory) ~= "function" then return false end
    local categories = _G.INTERFACEOPTIONS_ADDONCATEGORIES
    local found, visibleIndex = false, 0
    if type(categories) == "table" then
        for _, category in ipairs(categories) do
            if not category.hidden then
                if category == panel then found = true; break end
                visibleIndex = visibleIndex + 1
            end
        end
    end
    if not found then return false end

    -- Opening the window refreshes its categories and may restore its former
    -- page, so perform our selection only after the window is visible.
    if _G.InterfaceOptionsFrame and not InterfaceOptionsFrame:IsShown()
        and type(_G.InterfaceOptionsFrame_Show) == "function" then
        InterfaceOptionsFrame_Show()
    end
    if _G.InterfaceOptionsFrameTab2 then InterfaceOptionsFrameTab2:Click() end
    if type(_G.InterfaceAddOnsList_Update) == "function" then
        InterfaceAddOnsList_Update()
    end
    if type(_G.FauxScrollFrame_SetOffset) == "function"
        and _G.InterfaceOptionsFrameAddOnsList then
        -- The row position is zero-based; leave the target near the top.
        FauxScrollFrame_SetOffset(InterfaceOptionsFrameAddOnsList, math.max(0, visibleIndex - 1))
        if type(_G.InterfaceAddOnsList_Update) == "function" then InterfaceAddOnsList_Update() end
    end
    local ok, err = pcall(InterfaceOptionsFrame_OpenToCategory, panel)
    if not ok then msg("Settings navigation failed: " .. tostring(err)); return false end
    -- Fallback for modified 3.3.5 interfaces: use Blizzard's own display
    -- helper if its category selection still points at the previous page.
    if _G.InterfaceOptionsFramePanelContainer
        and InterfaceOptionsFramePanelContainer.displayedPanel ~= panel
        and type(_G.InterfaceOptionsList_DisplayPanel) == "function" then
        InterfaceOptionsList_DisplayPanel(panel)
    end
    return not _G.InterfaceOptionsFramePanelContainer
        or InterfaceOptionsFramePanelContainer.displayedPanel == panel
end

local function openConfigPanel()
    if registerConfigPanel and not registerConfigPanel() then
        msg("Gear Mover settings are not registered yet.")
        return
    end
    if not openOptionsCategory(configPanel) then
        msg("Unable to select Gear Mover settings; open Interface > AddOns > Gear Mover manually.")
    end
end

local function createConfigPanel()
    if configPanel then return end
    local S=GearMoverNS and GearMoverNS.Style
    assert(S and S.Button and S.Check and S.Dropdown and S.Slider and S.Frame,
        "MaterialCraftUI Classic failed to load")
    -- Register only a fully constructed settings page.
    local page=CreateFrame("Frame", nil, UIParent)
    page.name="Gear Mover"

    local function label(text,x,y,font)
        local f=page:CreateFontString(nil,"ARTWORK",font or "GameFontHighlight")
        f:SetPoint("TOPLEFT",page,"TOPLEFT",x,y)
        f:SetText(text)
        return f
    end
    local function help(control,title,lines)
        control:HookScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(title,1,0.82,0)
            for _,t in ipairs(lines) do GameTooltip:AddLine(t,1,1,1,true) end
            GameTooltip:Show()
        end)
        control:HookScript("OnLeave",function()GameTooltip:Hide()end)
    end
    label("Gear Mover",20,-18,"GameFontNormalLarge")
    label("Guild-bank tab assignments",24,-56,"GameFontNormal")
    local tabInputs,pendingTabs,selectors={},{},{}
    local function summary(key)
        local parts={}
        for n=1,6 do if pendingTabs[key][n] then parts[#parts+1]=tostring(n) end end
        return #parts>0 and ("Tabs "..table.concat(parts,", ")) or "Unassigned"
    end
    for i,key in ipairs(tabKeys) do
        local categoryKey=key
        local y=-84-(i-1)*29
        label(tabLabels[key],36,y-4)
        pendingTabs[key]={}
        tabInputs[key]={}
        local selector=S.Button(page,"Unassigned","secondary",188)
        selector:SetPoint("TOPLEFT",page,"TOPLEFT",160,y)
        selectors[key]=selector
        local popup=CreateFrame("Frame",nil,page)
        popup:SetSize(232,92)
        popup:SetPoint("TOPLEFT",selector,"BOTTOMLEFT",0,-2)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetFrameLevel(page:GetFrameLevel()+15)
        popup:EnableMouse(true)
        S.Frame(popup,"menu")
        popup.owner=selector
        S.TrackPopup(popup)
        popup:Hide()
        for tab=1,6 do
            local tabNumber=tab
            local col=(tab-1)%3
            local row=math.floor((tab-1)/3)
            local box=S.Check(popup,18,function(self)
                local value=not self.on
                self:SetChecked(value)
                pendingTabs[categoryKey][tabNumber]=value
                selector:SetText(summary(categoryKey))
            end)
            box:SetPoint("TOPLEFT",popup,"TOPLEFT",16+col*74,-15-row*34)
            box.tooltipText="Tab "..tabNumber.." for "..tabLabels[categoryKey]
            local t=popup:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            t:SetPoint("LEFT",box,"RIGHT",5,0)
            t:SetText(tostring(tabNumber))
            tabInputs[categoryKey][tabNumber]=box
        end
        selector:SetScript("OnClick",function()
            local open=popup:IsShown()
            S.CloseMenus()
            if not open then popup:Show() end
        end)
        selector:HookScript("OnHide",function()popup:Hide()end)
        help(selector,tabLabels[key].." destinations",{
            "Select any number of guild-bank tabs.",
            "Lowest selected number is tried first; others are overflow."
        })
    end

    label("Deposit rules",24,-236,"GameFontNormal")
    label("Minimum quality",36,-261)
    local qualityNames={[0]="Any quality (0)",[1]="Common (1)",[2]="Uncommon (2)",
        [3]="Rare (3)",[4]="Epic (4)",[5]="Legendary (5)"}
    local pendingQuality=0
    local quality
    quality=S.Dropdown(page,158,function(value)
        pendingQuality=value
        quality:SetText(qualityNames[value])
    end)
    quality:SetPoint("TOPLEFT",page,"TOPLEFT",162,-254)
    local qOptions={}
    for n=0,5 do qOptions[#qOptions+1]={value=n,text=qualityNames[n]} end
    quality:SetOptions(qOptions)
    help(quality,"Minimum deposit quality",{
        "Only deposit items at or above the chosen quality.",
        "0 = Any quality (including Poor)", "1 = Common", "2 = Uncommon",
        "3 = Rare", "4 = Epic", "5 = Legendary",
        "Applies only to deposits."
    })

    -- Keep all three deposit protections on one vertical axis. These are
    -- independently saved; moving them must not change their semantics.
    local function checkSetting(y,name,details)
        local cb=S.Check(page,18,function(self) self:SetChecked(not self.on) end)
        cb:SetPoint("TOPLEFT",page,"TOPLEFT",42,y)
        local text=page:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        text:SetPoint("LEFT",cb,"RIGHT",10,0)
        text:SetText(name)
        help(cb,name,details)
        -- Make the label itself discoverable without making it clickable.
        return cb
    end
    local mythicBox=checkSetting(-279,"Skip Mythics",{
        "Skips depositing Mythic Gear. Doesn't affect withdrawals."
    })
    local completedBox=checkSetting(-303,"Skip attuned BoEs",{
        "Skips attuned BoEs to sell/move manually"
    })
    local accountBox=checkSetting(-327,"Skip attuned variant BoEs",{
        "Skips BoE gear you've attuned a variant affix of to sell/manually move"
    })

    label("Transfer interval",36,-358,"GameFontNormal")
    local pendingMs=80
    local slider=S.Slider(page,248,10,200,1,function(v)
        pendingMs=math.floor(v+0.5)
    end,function(v)return tostring(math.floor(v+0.5)).." ms" end)
    slider:SetPoint("TOPLEFT",page,"TOPLEFT",46,-378)
    help(slider,"Transfer interval",{
        "Delay between item transfer attempts (10-200 ms).",
        "80 ms is the default. Lower values may cause failed moves or throttling.",
        "Below 50 ms is experimental."
    })
    local warning=label("WARNING: Below 50 ms may cause instability.",38,-412,"GameFontNormalSmall")
    warning:SetTextColor(1,0.25,0.25)

    local revert=S.Button(page,"Revert changes","secondary",126,function()
        S.CloseMenus()
        page:Hide()
        page:Show()
    end)
    revert:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-18,15)
    local save=S.Button(page,"Save settings","primary",126,function()
        if job then msg("Stop the active transfer before saving settings.") return end
        configuredTabs={}
        for _,key in ipairs(tabKeys) do
            local chosen={}
            for t=1,6 do if pendingTabs[key][t] then chosen[#chosen+1]=t end end
            configuredTabs[key]=chosen
        end
        minDepositQuality=pendingQuality
        skipMythic=mythicBox.on==true
        skipCompletedBoE=completedBox.on==true
        skipAccountAttunedBoE=accountBox.on==true
        transferMs=pendingMs
        interval=transferMs/1000
        saveTabs()
        S.CloseMenus()
        msg("Guild tab assignments and deposit rules saved.")
    end)
    save:SetPoint("RIGHT",revert,"LEFT",-8,0)
    page:SetScript("OnShow",function()
        for _,key in ipairs(tabKeys) do
            local chosen={}
            for _,t in ipairs(configuredTabList(key)) do chosen[t]=true end
            for n=1,6 do
                local on=chosen[n] or false
                pendingTabs[key][n]=on
                tabInputs[key][n]:SetChecked(on)
            end
            selectors[key]:SetText(summary(key))
        end
        pendingQuality=minDepositQuality
        quality:SetText(qualityNames[pendingQuality] or qualityNames[0])
        mythicBox:SetChecked(skipMythic)
        completedBox:SetChecked(skipCompletedBoE)
        accountBox:SetChecked(skipAccountAttunedBoE)
        pendingMs=transferMs
        slider:SetValue(transferMs)
    end)
    page:HookScript("OnHide",function()S.CloseMenus()end)
    configPanel=page
end

-- Create the panel independently of PLAYER_LOGIN, and register only once.
-- On some 3.3.5 client setups the Interface Options API loads after addons.
registerConfigPanel = function()
    if configRegistered then return true end
    if type(InterfaceOptions_AddCategory) ~= "function" then
        if type(UIParentLoadAddOn) == "function" then
            pcall(UIParentLoadAddOn, "Blizzard_InterfaceOptions")
        end
    end
    if type(InterfaceOptions_AddCategory) ~= "function" then return false end
    if not configPanel then
        local ok, err = pcall(createConfigPanel)
        if not ok then
            msg("Settings setup failed: " .. tostring(err))
            return false
        end
    end
    local ok, err = pcall(InterfaceOptions_AddCategory, configPanel)
    if not ok then
        msg("Settings registration failed: " .. tostring(err))
        return false
    end
    configRegistered = true
    return true
end

-- All layouts are thin, Classic-skinned views over the existing transfer engine.
-- A layout/direction change never calls a bank or transfer API.
local ART="Interface\\AddOns\\Gear Mover\\Textures\\"
local ICONS={Cloth=ART.."Cloth",Leather=ART.."Leather",Mail=ART.."Mail",
    Plate=ART.."Plate",Weapon=ART.."Weapons",Deposit=ART.."Bank",
    Withdraw=ART.."Inventory",All=ART.."All"}
local GREEN={0.16,0.93,0.25}
local AMBER={1,0.67,0.10}
local function tooltipButton(b,textFn)
    local enter=function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText(type(textFn)=="function" and textFn() or textFn)
        GameTooltip:Show()
    end
    -- MaterialCraftUI buttons already have mouse enter/leave scripts for
    -- their Classic hover/pressed states. Hook them instead of overriding.
    if b.kind then
        b:HookScript("OnEnter",enter)
    else
        b:SetScript("OnEnter",enter)
        b:SetScript("OnLeave",function()GameTooltip:Hide()end)
    end
end
local function actionAll()
    if job then stop("Stopped by user")
    elseif transferDirection=="deposit" then startAll()
    else startWithdrawAll() end
end
local function categoryAction(key)start(transferDirection,key)end

createPanel=function()
    if panel then return end
    local S=GearMoverNS and GearMoverNS.Style
    assert(S and S.Frame and S.Button,"MaterialCraftUI Classic UI missing")
    panel=CreateFrame("Frame","GearMoverPanel",UIParent)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)
    panel:SetScript("OnDragStart",function(self)self:StartMoving()end)
    panel:SetScript("OnDragStop",function(self)self:StopMovingOrSizing();savePanelPosition()end)
    S.Frame(panel,"window")

    -- Bottom-right drag handle scales the entire panel, so every layout keeps
    -- its pixel alignment and click targets. Unlike Resize/Sizing, this does
    -- not reflow or stretch MaterialCraftUI's fixed-size Classic controls.
    local resizeGrip=CreateFrame("Button",nil,panel)
    resizeGrip:SetSize(17,17)
    resizeGrip:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-5,5)
    resizeGrip:SetFrameLevel(panel:GetFrameLevel()+12)
    local resizeArt=resizeGrip:CreateTexture(nil,"ARTWORK")
    resizeArt:SetAllPoints(resizeGrip)
    resizeArt:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetNormalTexture(resizeArt)
    resizeGrip:RegisterForClicks("LeftButtonDown","LeftButtonUp")
    local resizing=false
    local startX,startY,startScale
    local function stopResize(self)
        if not resizing then return end
        resizing=false
        self:SetScript("OnUpdate",nil)
        local scale=panel:GetScale() or 1
        uiSettings().scale=scale
        savePanelPosition()
    end
    -- Keep one reusable update callback instead of allocating a new closure
    -- every time the resize handle is pressed. It is inactive when not dragging.
    local function updateResize()
        if not resizing then return end
        local x,y=GetCursorPosition()
        local parentScale=UIParent:GetEffectiveScale()
        if not parentScale or parentScale<=0 then return end
        local dx=(x-startX)/parentScale
        local dy=(startY-y)/parentScale
        -- Dragging outward grows the window; inward shrinks it.
        local factor=math.max(dx/math.max(1,panel:GetWidth()),dy/math.max(1,panel:GetHeight()))
        local inward=math.min(dx/math.max(1,panel:GetWidth()),dy/math.max(1,panel:GetHeight()))
        if dx<0 and dy<0 then factor=inward end
        local scale=math.max(0.65,math.min(1.65,startScale+factor))
        if scale~=panel:GetScale() then panel:SetScale(scale) end
    end
    resizeGrip:SetScript("OnMouseDown",function(self,button)
        if button~="LeftButton" then return end
        resizing=true
        startX,startY=GetCursorPosition()
        startScale=panel:GetScale() or 1
        self:SetScript("OnUpdate",updateResize)
    end)
    resizeGrip:SetScript("OnMouseUp",stopResize)
    resizeGrip:SetScript("OnHide",stopResize)
    tooltipButton(resizeGrip,"Drag to resize Gear Mover")

    local views={}
    for n=1,3 do
        local f=CreateFrame("Frame",nil,panel)
        f:SetAllPoints(panel)
        views[n]=f
    end
    local function textButton(parent,text,width,x,y,handler)
        local b=S.Button(parent,text,"secondary",width,handler)
        b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
        return b
    end
    -- Bagnon/oGlow-style additive OVERLAY, but shaped for the control.
    -- The shared 9-slice texture keeps its corners at a fixed size for both
    -- rectangular Classic buttons and square artwork; its middle is transparent.
    -- Unlike UI-ActionButton-Border stretched over a rectangle, it does not
    -- color the button label or the center of the user's icon.
    local glowTexture=ART.."SoftEdgeGlow"
    local function edgeGlow(button,opacity)
        local parts={}
        local cuts={0,0.25,0.75,1}
        local cap=12
        local pad=4
        local fragments={
            {"TOPLEFT",1,1},{"TOP",2,1},{"TOPRIGHT",3,1},
            {"LEFT",1,2},{"RIGHT",3,2},
            {"BOTTOMLEFT",1,3},{"BOTTOM",2,3},{"BOTTOMRIGHT",3,3}
        }
        for _,part in ipairs(fragments) do
            local tex=button:CreateTexture(nil,"OVERLAY")
            tex:SetTexture(glowTexture)
            tex:SetBlendMode("ADD")
            local col,row=part[2],part[3]
            tex:SetTexCoord(cuts[col],cuts[col+1],cuts[row],cuts[row+1])
            if col==1 then
                tex:SetPoint("LEFT",button,"LEFT",-pad,0)
                tex:SetWidth(cap)
            elseif col==3 then
                tex:SetPoint("RIGHT",button,"RIGHT",pad,0)
                tex:SetWidth(cap)
            else
                tex:SetPoint("LEFT",button,"LEFT",cap-pad,0)
                tex:SetPoint("RIGHT",button,"RIGHT",pad-cap,0)
            end
            if row==1 then
                tex:SetPoint("TOP",button,"TOP",0,pad)
                tex:SetHeight(cap)
            elseif row==3 then
                tex:SetPoint("BOTTOM",button,"BOTTOM",0,-pad)
                tex:SetHeight(cap)
            else
                tex:SetPoint("TOP",button,"TOP",0,pad-cap)
                tex:SetPoint("BOTTOM",button,"BOTTOM",0,cap-pad)
            end
            tex:SetAlpha(0)
            parts[#parts+1]=tex
        end
        button.edgeGlow=parts
        button.edgeOpacity=opacity or 0.85
        return button
    end
    local function paintDirection(button,active,color)
        button:SetKind(active and "selected" or "secondary")
        for _,tex in ipairs(button.edgeGlow) do
            tex:SetVertexColor(color[1],color[2],color[3])
            tex:SetAlpha(active and button.edgeOpacity or 0)
        end
    end
    local function separator(parent,x,y,height)
        local t=parent:CreateTexture(nil,"ARTWORK")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetVertexColor(0.72,0.60,0.35,0.65)
        t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
        t:SetSize(1,height)
    end
    local title=views[1]:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOP",panel,"TOP",0,-15)
    title:SetText("Gear Mover")
    for i,c in ipairs(categories) do
        local y=-39-(i-1)*26
        local key=c.key
        local lab=views[1]:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        lab:SetPoint("TOPLEFT",views[1],"TOPLEFT",20,y-4)
        lab:SetText(c.label)
        textButton(views[1],"Deposit",105,84,y,function()start("deposit",key)end)
        textButton(views[1],"Withdraw",105,198,y,function()start("withdraw",key)end)
    end
    textButton(views[1],"Deposit All",93,18,-173,startAll)
    textButton(views[1],"Withdraw All",98,118,-173,startWithdrawAll)
    local fullStop=textButton(views[1],"Stop",87,224,-173,function()stop("Stopped by user")end)

    local function setDirection(direction)
        if transferDirection~=direction then
            transferDirection=direction
            uiSettings().direction=direction
            refreshPanel()
        end
    end
    -- Compact mode is two short, precisely aligned rows, no redundant heading.
    local compactDeposit=edgeGlow(textButton(views[2],"Deposit",98,12,-16,function()setDirection("deposit")end))
    local compactWithdraw=edgeGlow(textButton(views[2],"Withdraw",98,116,-16,function()setDirection("withdraw")end))
    local compactCategories={}
    for i,c in ipairs(categories) do
        local key=c.key
        local b=edgeGlow(textButton(views[2],({"Cl","Le","Ma","Pl","Wp"})[i],35,12+(i-1)*44,-48,
            function()categoryAction(key)end))
        tooltipButton(b,function()return (transferDirection=="deposit" and "Deposit " or "Withdraw ")..tabLabels[key]end)
        compactCategories[#compactCategories+1]=b
    end
    local compactAll=edgeGlow(textButton(views[2],"All",42,234,-48,actionAll))
    tooltipButton(compactAll,function()return job and "Stop transfer" or (transferDirection=="deposit" and "Deposit All" or "Withdraw All")end)

    -- Original user-supplied artwork, converted to TGA only for client texture compatibility.
    local function imageButton(parent,x,texture,fn,textFn)
        local b=CreateFrame("Button",nil,parent)
        b:SetSize(34,34)
        b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-15)
        local art=b:CreateTexture(nil,"ARTWORK")
        art:SetAllPoints()
        art:SetTexture(texture)
        b.art=art
        -- Square buttons do not need eight separate 9-slice regions.
        -- The source glow has a transparent middle; a single centered overlay
        -- preserves the artwork and reduces retained UI textures per icon.
        local border=b:CreateTexture(nil,"OVERLAY")
        border:SetTexture(glowTexture)
        border:SetBlendMode("ADD")
        border:SetPoint("TOPLEFT",b,"TOPLEFT",-4,4)
        border:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",4,-4)
        border:SetAlpha(0)
        b.edgeGlow={border}
        b.edgeOpacity=0.95
        b:SetScript("OnClick",fn)
        tooltipButton(b,textFn)
        return b
    end
    local iconDirection=imageButton(views[3],12,ICONS.Deposit,function()
        setDirection(transferDirection=="deposit" and "withdraw" or "deposit")
    end,function()return (transferDirection=="deposit" and "Deposit" or "Withdraw").." is selected. Click to switch to "..(transferDirection=="deposit" and "Withdraw" or "Deposit")end)
    separator(views[3],52,-18,28)
    local iconCategories={}
    for i,c in ipairs(categories) do
        local key=c.key
        iconCategories[#iconCategories+1]=imageButton(views[3],60+(i-1)*42,ICONS[key],
            function()categoryAction(key)end,
            function()return (transferDirection=="deposit" and "Deposit " or "Withdraw ")..tabLabels[key]end)
    end
    separator(views[3],270,-18,28)
    local iconAll=imageButton(views[3],280,ICONS.All,actionAll,
        function()return job and "Stop transfer" or (transferDirection=="deposit" and "Deposit All" or "Withdraw All")end)

    local viewButton=S.Button(panel,">","secondary",23,function()
        layoutMode=layoutMode%3+1
        uiSettings().layout=layoutMode
        refreshPanel()
        savePanelPosition()
    end)
    viewButton:SetSize(23,21)
    viewButton:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-10,-10)
    viewButton:SetFrameLevel(panel:GetFrameLevel()+10)
    viewButton.tooltipText="Switch layout: Full / Compact / Icons"

    -- Cached dimensions: direction toggles and transfers repaint without
    -- allocating two throwaway tables on every refresh.
    local widths={334,294,360}
    local heights={217,89,65}
    refreshPanel=function()
        panel:SetSize(widths[layoutMode],heights[layoutMode])
        for i,v in ipairs(views) do if i==layoutMode then v:Show() else v:Hide()end end
        if job then fullStop:Enable() else fullStop:Disable() end
        compactAll:SetText(job and "Stop" or "All")
        local current=transferDirection=="deposit" and GREEN or AMBER
        paintDirection(compactDeposit,transferDirection=="deposit",GREEN)
        paintDirection(compactWithdraw,transferDirection=="withdraw",AMBER)
        for _,b in ipairs(compactCategories) do paintDirection(b,true,current)end
        paintDirection(compactAll,true,current)
        iconDirection.art:SetTexture(ICONS[transferDirection=="deposit" and "Deposit" or "Withdraw"])
        for _,b in ipairs(iconCategories) do
            for _,tex in ipairs(b.edgeGlow) do
                tex:SetVertexColor(current[1],current[2],current[3])
                tex:SetAlpha(b.edgeOpacity)
            end
        end
        -- Avoid creating a temporary table on every panel refresh.
        for _,tex in ipairs(iconDirection.edgeGlow) do
            tex:SetVertexColor(current[1],current[2],current[3])
            tex:SetAlpha(iconDirection.edgeOpacity)
        end
        for _,tex in ipairs(iconAll.edgeGlow) do
            tex:SetVertexColor(current[1],current[2],current[3])
            tex:SetAlpha(iconAll.edgeOpacity)
        end
    end
    refreshPanel()
    panel:Hide()
end
-- Register slash commands before attempting the optional settings UI.
-- Even if panel creation fails on a custom client, the main addon stays usable.
addon:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
addon:RegisterEvent("GUILDBANKFRAME_OPENED")
addon:RegisterEvent("GUILDBANKFRAME_CLOSED")
addon:RegisterEvent("BANKFRAME_OPENED")
addon:RegisterEvent("BANKFRAME_CLOSED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("ADDON_LOADED")
addon:SetScript("OnEvent",function(self,event)
    if event=="ADDON_LOADED" then
        -- API registration may become available after another addon finishes loading.
        registerConfigPanel()
    elseif event=="PLAYER_LOGIN" then
        loadTabs();createPanel();loadUiPreference();registerConfigPanel()
    elseif event=="GUILDBANKBAGSLOTS_CHANGED" then
        if job and job.mode=="guild" and job.phase=="waiting" and currentTab()==job.tab then
            job.tabUpdated=true
        end
    elseif event=="GUILDBANKFRAME_OPENED" then
        guildActive=true; if not job then loadTabs() end; createPanel();panel:Show()
    elseif event=="GUILDBANKFRAME_CLOSED" then
        guildActive=false
        if job and job.mode=="guild" then stop("Guild bank closed") end
        if panel and not bankOpen() and not personalBankOpen() then panel:Hide() end
    elseif event=="BANKFRAME_OPENED" then
        personalActive=true; createPanel();panel:Show()
    elseif event=="BANKFRAME_CLOSED" then
        personalActive=false
        if job and job.mode=="personal" then stop("Regular bank closed") end
        if panel and not bankOpen() and not personalBankOpen() then panel:Hide() end
    end
end)
SLASH_GEARMOVER1="/ggm"
SLASH_GEARMOVER2="/gearmover"
SlashCmdList.GEARMOVER=function(input)
    input = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if input=="tabs" then
        for _,key in ipairs(tabKeys) do msg(tabLabels[key].." -> "..(#configuredTabList(key)>0 and table.concat(configuredTabList(key),",") or "unassigned")) end
        return
    end
    if input=="all" then startAll() return end
    if input=="withdrawall" then startWithdrawAll() return end
    if input=="" or input=="setup" or input=="options" then openConfigPanel() return end
    if input=="debug" then
        local shown = BankFrame and BankFrame:IsShown()
        local bagnonState = bagnonBankState()
        local bagnonBankShown = bagnonFrameShown("bank")
        local bagnonGuildShown = bagnonFrameShown("guildbank")
        local n = 0
        for slot=1,28 do
            if GetContainerItemLink(-1,slot) then n=n+1 end
        end
        msg("Bank: event active="..tostring(personalActive)..
            " Blizzard shown="..tostring(shown)..
            " Bagnon AtBank="..tostring(bagnonState)..
            " Bagnon frame shown="..tostring(bagnonBankShown)..
            " Synastria ready="..tostring(synastriaReady))
        msg("Guild: event active="..tostring(guildActive)..
            " Bagnon frame shown="..tostring(bagnonGuildShown)..
            " active tab="..tostring(currentTab())..
            " | personal bank slots readable="..tostring(n).."/28")
        msg("Detected mode="..tostring(bankOpen() and "guild" or (personalBankOpen() and "personal" or "none")))
        return
    end
    if input=="window" or input=="show" or input=="toggle" then
        createPanel()
        if panel:IsShown() then panel:Hide() else panel:Show() end
        return
    end
    msg("Commands: /ggm (settings), /ggm window, /ggm all, /ggm withdrawall, /ggm tabs, /ggm debug")
end

-- Safe to attempt now that all slash commands have been registered.
registerConfigPanel()
