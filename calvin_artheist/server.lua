local QBCore = exports['qb-core']:GetCoreObject()

-- stages:
-- 0 = not started
-- 1 = got meeting spot
-- 2 = handover complete)
-- 3 = art scene active
-- 4 = has art item
-- 5 =  dropoff
-- 6 = dropped art (crates placed)
-- 7 = got money note
-- 8 = completed 

local PlayerState = {}

local function GetState(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local cid = Player.PlayerData.citizenid
    PlayerState[cid] = PlayerState[cid] or { stage = 0, cooldownUntil = 0 }
    return PlayerState[cid], cid
end

local function InCooldown(state)
    return os.time() < (state.cooldownUntil or 0)
end

local function NormalizeNumber(s)
    s = tostring(s or "")
    s = s:gsub("%s+", "")
    s = s:gsub("%D", "")
    return s
end

local function DebugPrint(msg)
    if Config.Debug then
        print("^3[calvin_artheist]^7 " .. msg)
    end
end

RegisterNetEvent("calvin_artheist:server:dial", function(number)
    local src = source
    local state, cid = GetState(src)
    if not state then return end

    if InCooldown(state) then
        TriggerClientEvent("calvin_artheist:client:notify", src, "The line is dead. Try again later.")
        return
    end

    local input = NormalizeNumber(number)
    local secret = NormalizeNumber(Config.SecretNumber)

    DebugPrint(("dial: cid=%s raw='%s' -> '%s' | secret='%s' | stage=%d")
        :format(cid or "unknown", tostring(number), input, secret, state.stage))

    -- Wrong number boundary
    if input ~= secret then
        TriggerClientEvent("calvin_artheist:client:phoneCall", src, {
            voiceKey = Config.Voice.wrong,
            lengthMs = Config.VoiceLengthMs.wrong or 7000,
            showWaypoint = false,
            waypointDelayMs = 0,
            waypoint = nil,
            callType = "wrong",
        })
        TriggerClientEvent("calvin_artheist:client:notify", src, "Nothing but static...")
        return
    end

    -- Correct number
    if state.stage == 0 then
        state.stage = 1
        TriggerClientEvent("calvin_artheist:client:phoneCall", src, {
            voiceKey = Config.Voice.voice1,
            lengthMs = Config.VoiceLengthMs.voice1 or 21000,
            showWaypoint = true,
            waypointDelayMs = Config.WaypointDelayMs or 11000,
            waypoint = Config.MeetingSpot,
            callType = "meeting",
        })
        return
    end

    -- Correct number: second call
    if state.stage == 4 then
        state.stage = 5
        TriggerClientEvent("calvin_artheist:client:phoneCall", src, {
            voiceKey = Config.Voice.voice2,
            lengthMs = Config.VoiceLengthMs.voice2 or 25000,
            showWaypoint = true,
            waypointDelayMs = Config.WaypointDelayMs or 11000,
            waypoint = Config.DropOff,
            callType = "dropoff",
        })
        return
    end

    TriggerClientEvent("calvin_artheist:client:notify", src, "No one responds.")
end)

RegisterNetEvent("calvin_artheist:server:benchNote", function()
    local src = source
    local state, cid = GetState(src)
    if not state then return end

    DebugPrint(("benchNote (handover): cid=%s stage=%d"):format(cid or "unknown", state.stage))

    if state.stage ~= 1 then
        TriggerClientEvent("calvin_artheist:client:notify", src, "No one is expecting you right now.")
        return
    end

    state.stage = 2
    TriggerClientEvent("calvin_artheist:client:showBenchClueAndSpawnScene", src, Config.ArtScene)
end)

RegisterNetEvent("calvin_artheist:server:sceneActive", function()
    local src = source
    local state, cid = GetState(src)
    if not state then return end

    DebugPrint(("sceneActive: cid=%s stage=%d"):format(cid or "unknown", state.stage))

    if state.stage == 2 then
        state.stage = 3
    end
end)

RegisterNetEvent("calvin_artheist:server:stealArt", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local state, cid = GetState(src)
    if not state then return end

    DebugPrint(("stealArt: cid=%s stage=%d"):format(cid or "unknown", state.stage))

    if state.stage ~= 3 then
        TriggerClientEvent("calvin_artheist:client:notify", src, "You can’t do that yet.")
        return
    end

    if not QBCore.Shared.Items[Config.ArtItem] then
        DebugPrint(("ERROR: Config.ArtItem '%s' not in QBCore.Shared.Items"):format(tostring(Config.ArtItem)))
        TriggerClientEvent("calvin_artheist:client:notify", src, "Script misconfigured. Tell staff.")
        return
    end

    local added = Player.Functions.AddItem(Config.ArtItem, Config.ArtItemAmount)
    if not added then
        TriggerClientEvent("calvin_artheist:client:notify", src, "Inventory full.")
        return
    end

    TriggerClientEvent("inventory:client:ItemBox", src, QBCore.Shared.Items[Config.ArtItem], "add")

    state.stage = 4
    TriggerClientEvent("calvin_artheist:client:afterSteal", src)
end)

RegisterNetEvent("calvin_artheist:server:dropArt", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local state, cid = GetState(src)
    if not state then return end

    DebugPrint(("dropArt: cid=%s stage=%d"):format(cid or "unknown", state.stage))

    if state.stage ~= 5 then
        TriggerClientEvent("calvin_artheist:client:notify", src, "This isn’t the time.")
        return
    end

    local item = Player.Functions.GetItemByName(Config.ArtItem)
    if not item or item.amount < Config.ArtItemAmount then
        TriggerClientEvent("calvin_artheist:client:notify", src, "You don’t have the goods.")
        return
    end

    Player.Functions.RemoveItem(Config.ArtItem, Config.ArtItemAmount)
    TriggerClientEvent("inventory:client:ItemBox", src, QBCore.Shared.Items[Config.ArtItem], "remove")

    state.stage = 6
    TriggerClientEvent("calvin_artheist:client:spawnDropCratesAndNote", src, Config.DropOff, Config.CrateCount)
end)

RegisterNetEvent("calvin_artheist:server:readDropNote", function()
    local src = source
    local state, cid = GetState(src)
    if not state then return end

    DebugPrint(("readDropNote: cid=%s stage=%d"):format(cid or "unknown", state.stage))

    if state.stage ~= 6 then
        TriggerClientEvent("calvin_artheist:client:notify", src, "No note for you.")
        return
    end

    state.stage = 7
    TriggerClientEvent("calvin_artheist:client:showMoneyClue", src, Config.MoneyStash)
end)

RegisterNetEvent("calvin_artheist:server:claimMoney", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local state, cid = GetState(src)
    if not state then return end

    DebugPrint(("claimMoney: cid=%s stage=%d"):format(cid or "unknown", state.stage))

    if state.stage ~= 7 then
        TriggerClientEvent("calvin_artheist:client:notify", src, "Nothing here for you.")
        return
    end

    local cashReward = math.random(2500, 4000)
    Player.Functions.AddMoney("cash", cashReward, "art-heist-reward")

    state.stage = 8
    state.cooldownUntil = os.time() + Config.Cooldown

    TriggerClientEvent("calvin_artheist:client:notify", src, ("You found $%d. Job done."):format(cashReward))
    TriggerClientEvent("calvin_artheist:client:cleanup", src)
end)
