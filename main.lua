Equinox = LibStub("AceAddon-3.0"):NewAddon("Equinox", "AceConsole-3.0", "AceEvent-3.0")

local LH = LibStub("LibHash-1.0")
local InstanceInfo = { }
local lootHistory = {}

function Equinox:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("EquinoxDb", defaults)
    Equinox:RegisterEvent('LOOT_OPENED', 'HandleLootingHistory')
    Equinox:RegisterEvent('UPDATE_INSTANCE_INFO', 'HandleRaidInfo')
    Equinox:RegisterEvent("PLAYER_ENTERING_WORLD", "HandBackValue")

    Equinox:RegisterChatCommand('eqtest', 'HandleTest')
    Equinox:RegisterChatCommand('eqraid', 'HandleRaidExportCommand')
    Equinox:RegisterChatCommand('eqrst', 'HandleResetLootCommand')
    Equinox:RegisterChatCommand('eqloot', 'HandleExportLootCommand')
    Equinox:RegisterChatCommand('eqrand', 'HandleRandCommand')
end

-- region handler

function Equinox:HandBackValue()
    lootHistory = G_LootHistory
end

function Equinox:HandleTest()
    MainFrame:Show();
end

function Equinox:HandleRaidInfo()
    G_InstanceInfo = GetInstanceInfo()
end

function Equinox:HandleRandCommand(input)
    local baseSplit = Equinox:SplitString(input, "#");
    local itemId = baseSplit[1];
    local characterCanRand = baseSplit[2];
    local characterCantRand = baseSplit[3];

    local it = select(2, GetItemInfo(itemId));
    SendChatMessage("Roll for : ", "RAID_WARNING");
    SendChatMessage(it, "RAID_WARNING");

    SendChatMessage("-----------------------------", "RAID");
    local charactersCanRand = Equinox:SplitString(characterCanRand, "*");
    for _, v in ipairs(charactersCanRand) do
        local splitRatio = Equinox:SplitString(v, "_");
        SendChatMessage(splitRatio[1] .. " => " .. splitRatio[2], "RAID");
    end

    SendChatMessage("-----------------------------", "RAID");
    local charactersCantRand = Equinox:SplitString(characterCantRand, "*");
    local baseCanRandContent = "No roll : ";

    for _, v in ipairs(charactersCantRand) do
        local splitRatio = Equinox:SplitString(v, "_");
        baseCanRandContent = baseCanRandContent .. splitRatio[1] .. "(" .. splitRatio[2] ..") /";
    end

    SendChatMessage(baseCanRandContent, "RAID");
    SendChatMessage("-----------------------------", "RAID");
end

function Equinox:HandleResetLootCommand()
    RequestRaidInfo()
    lootHistory = {}
    G_LootHistory = {}
    G_RaidId = Equinox:CreateGuid()
    print('Loot history reset.')
end
-- end region handler

-- region raid
function Equinox:HandleRaidExportCommand()
    local exportString = ''
    local raidMembers = ''
    local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID = G_InstanceInfo
    
    for i = 1, GetNumGroupMembers(), 1 do
        local name, _, subgroup, level, class, _, _, _, _, role = GetRaidRosterInfo(i)
        raidMembers = raidMembers .. '#' .. name .. ',' .. level .. ',' .. class .. ',' .. subgroup
    end

    exportString = '[' .. raidMembers .. ']'
    Equinox:DisplayExportStringWithoutCrypting(exportString)
end

function Equinox:HandleExportLootCommand()
    local exportString = 'RaidId=' .. G_RaidId .. ';'
    for key, value in pairs(G_LootHistory) do
        exportString = exportString .. key .. '@' .. value .. '_'
    end
    Equinox:DisplayExportStringWithoutCrypting(exportString)
end
-- end region

-- RaidId=012315651;6384181@02/02/02 21:31:31+TestEnnemy+[40400*6116-AF784C-541411#40264*6116-AF784C-541411]

-- region raid history
function Equinox:HandleLootingHistory()
    local inInstance, instanceType = IsInInstance()
    local lootAdded = false
    if (inInstance == true and instanceType == 'raid') then
        local numOfLoots = GetNumLootItems()
        if numOfLoots > 0 then
            local ennemyName = UnitName("target")
            local uniqueId = UnitGUID("target") 
            local lootTableKey = uniqueId

            if G_LootHistory[lootTableKey] == nil == true then 
                local lootChain = date("%m/%d/%Y %H:%M:%S") .. '+' .. ennemyName .. '+['
                for i = 0, numOfLoots do
                    local itemLoot = GetLootSlotLink(i)
                    if itemLoot == nil == false then
                        local itemName, itemLink, itemRarity = GetItemInfo(itemLoot)
                        if (itemRarity >= 3 and itemRarity <= 4) == true then
                            lootChain = lootChain .. itemLoot .. '*' .. Equinox:CreateGuid() .. '#'
                            lootAdded = true
                        end
                    end
                end

                lootChain = lootChain .. ']'

                if lootAdded == true then
                    G_LootHistory[lootTableKey] = lootChain
                    -- G_LootHistory = lootHistory
                end
            end
        end
    end    
end
-- end region

-- region utils
function Equinox:DisplayExportString(exportString)

    local encoded = Equinox:Encode(exportString);
    local guid = Equinox:CreateGuid()
    local sign = LH.hmac(LH.sha256, guid, encoded)
    local cryptedData = Equinox:Encode(encoded .. guid .. sign)

    EquinoxFrame:Show();
    EquinoxFrameScroll:Show()
    EquinoxFrameScrollText:Show()
    EquinoxFrameScrollText:SetText(cryptedData)
    EquinoxFrameScrollText:HighlightText()

    EquinoxFrameButton:SetScript("OnClick", function(self) EquinoxFrame:Hide(); end);
end

function Equinox:DisplayExportStringWithoutCrypting(exportString)

    local encoded = Equinox:Encode(exportString);

    EquinoxFrame:Show();
    EquinoxFrameScroll:Show()
    EquinoxFrameScrollText:Show()
    EquinoxFrameScrollText:SetText(encoded)
    EquinoxFrameScrollText:HighlightText()

    EquinoxFrameButton:SetScript("OnClick", function(self) EquinoxFrame:Hide(); end);
end

function Equinox:SplitString (inputstr, sep)
    if sep == nil then
       sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do 
       table.insert(t, str)
    end
    return t
 end


local extract = _G.bit32 and _G.bit32.extract
if not extract then
    if _G.bit then
        local shl, shr, band = _G.bit.lshift, _G.bit.rshift, _G.bit.band
        extract = function(v, from, width)
            return band(shr(v, from), shl(1, width) - 1)
        end
    elseif _G._VERSION >= "Lua 5.3" then
        extract = load [[return function( v, from, width )
			return ( v >> from ) & ((1 << width) - 1)
		end]]()
    else
        extract = function(v, from, width)
            local w = 0
            local flag = 2 ^ from
            for i = 0, width - 1 do
                local flag2 = flag + flag
                if v % flag2 >= flag then w = w + 2 ^ i end
                flag = flag2
            end
            return w
        end
    end
end

local char, concat = string.char, table.concat

function Equinox:MakeEncoder(s62, s63, spad)
    local encoder = {}
    for b64code, char in pairs {
        [0] = 'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
        'N',
        'O',
        'P',
        'Q',
        'R',
        'S',
        'T',
        'U',
        'V',
        'W',
        'X',
        'Y',
        'Z',
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
        'g',
        'h',
        'i',
        'j',
        'k',
        'l',
        'm',
        'n',
        'o',
        'p',
        'q',
        'r',
        's',
        't',
        'u',
        'v',
        'w',
        'x',
        'y',
        'z',
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        s62 or '+',
        s63 or '/',
        spad or '='
    } do encoder[b64code] = char:byte() end
    return encoder
end

function Equinox:Encode(str)
    encoder = Equinox:MakeEncoder()
    local t, k, n = {}, 1, #str
    local lastn = n % 3
    for i = 1, n - lastn, 3 do
        local a, b, c = str:byte(i, i + 2)
        local v = a * 0x10000 + b * 0x100 + c

        t[k] = char(encoder[extract(v, 18, 6)], encoder[extract(v, 12, 6)],
                    encoder[extract(v, 6, 6)], encoder[extract(v, 0, 6)])
        k = k + 1
    end
    if lastn == 2 then
        local a, b = str:byte(n - 1, n)
        local v = a * 0x10000 + b * 0x100
        t[k] = char(encoder[extract(v, 18, 6)], encoder[extract(v, 12, 6)],
                    encoder[extract(v, 6, 6)], encoder[64])
    elseif lastn == 1 then
        local v = str:byte(n) * 0x10000
        t[k] = char(encoder[extract(v, 18, 6)], encoder[extract(v, 12, 6)],
                    encoder[64], encoder[64])
    end
    return concat(t)
end

function Equinox:CreateGuid()
    local random = math.random;
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';

    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb);
        return string.format('%x', v);
    end);
end
-- end region utils
