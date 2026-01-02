local QBCore = exports['qb-core']:GetCoreObject()

local spawned = {
    van = nil,
    npc = nil,
    guard = nil,
    meetingNpc = nil,
    crates = {},        -- drop-off crates
    pickupCrates = {},  -- art pickup crate(s)
}

local phoneBusy = false
local meetingBusy = false
local collectingBusy = false

local function Notify(msg, t)
    QBCore.Functions.Notify(msg, t or "primary")
end

RegisterNetEvent("calvin_artheist:client:notify", function(msg)
    Notify(msg)
end)

-- NUI audio
local function PlayVoice(voiceKey)
    if not voiceKey then return end
    SendNUIMessage({ action = "play", sound = voiceKey })
end

-- Freeze & disable controls 
local function FreezePlayer(ms)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)

    CreateThread(function()
        local untilTime = GetGameTimer() + (ms or 0)
        while GetGameTimer() < untilTime do
            Wait(0)
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)   
            EnableControlAction(0, 2, true)   
            EnableControlAction(0, 245, true) 
            EnableControlAction(0, 200, true) 
        end
    end)
end

local function UnfreezePlayer()
    FreezeEntityPosition(PlayerPedId(), false)
end

RegisterNetEvent("calvin_artheist:client:phoneCall", function(data)
    if phoneBusy then return end
    phoneBusy = true

    local voiceKey = data.voiceKey
    local lengthMs = tonumber(data.lengthMs or 0) or 0
    local showWaypoint = data.showWaypoint == true
    local delayMs = tonumber(data.waypointDelayMs or 0) or 0
    local waypoint = data.waypoint
    local callType = data.callType

    FreezePlayer(lengthMs)
    PlayVoice(voiceKey)

    if showWaypoint and waypoint then
        CreateThread(function()
            Wait(delayMs)
            exports['qb-menu']:openMenu({
                { header = "Call Connected", isMenuHeader = true },
                { header = "GPS", txt = "Waypoint set.", params = { event = "" } },
                { header = "Close", params = { event = "qb-menu:client:closeMenu" } },
            })
            SetNewWaypoint(waypoint.x, waypoint.y)
        end)
    end

    -- After first correct call, ensure meeting NPC exists
    if callType == "meeting" then
        CreateThread(function()
            Wait(500)
            TriggerEvent("calvin_artheist:client:spawnMeetingNpc")
        end)
    end

    CreateThread(function()
        Wait(lengthMs)
        UnfreezePlayer()
        phoneBusy = false
    end)
end)

local function CleanupEntities()
    -- pickup crate(s)
    for _, obj in ipairs(spawned.pickupCrates) do
        if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    spawned.pickupCrates = {}

    -- drop crates
    for _, obj in ipairs(spawned.crates) do
        if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    spawned.crates = {}

    -- meeting NPC
    if spawned.meetingNpc and DoesEntityExist(spawned.meetingNpc) then
        DeleteEntity(spawned.meetingNpc)
        spawned.meetingNpc = nil
    end

    -- scene NPCs
    if spawned.guard and DoesEntityExist(spawned.guard) then
        DeleteEntity(spawned.guard)
        spawned.guard = nil
    end
    if spawned.npc and DoesEntityExist(spawned.npc) then
        DeleteEntity(spawned.npc)
        spawned.npc = nil
    end
    if spawned.van and DoesEntityExist(spawned.van) then
        DeleteEntity(spawned.van)
        spawned.van = nil
    end
end

RegisterNetEvent("calvin_artheist:client:cleanup", function()
    CleanupEntities()
end)

-- ====== MEETING NPC
RegisterNetEvent("calvin_artheist:client:spawnMeetingNpc", function()
    if spawned.meetingNpc and DoesEntityExist(spawned.meetingNpc) then return end

    local model = `ig_vincent`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local ms = Config.MeetingSpot
    local pos = vector3(ms.x, ms.y, ms.z)

    spawned.meetingNpc = CreatePed(4, model, pos.x, pos.y, pos.z - 1.0, ms.w, false, true)
    SetEntityAsMissionEntity(spawned.meetingNpc, true, true)
    SetBlockingOfNonTemporaryEvents(spawned.meetingNpc, true)
    SetPedFleeAttributes(spawned.meetingNpc, 0, 0)
    SetPedCanRagdoll(spawned.meetingNpc, false)
    FreezeEntityPosition(spawned.meetingNpc, true)

    TaskStartScenarioInPlace(spawned.meetingNpc, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
end)

local function LoadAnim(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
end

RegisterNetEvent("calvin_artheist:client:meetVincent", function()
    if meetingBusy then return end
    meetingBusy = true

    if not (spawned.meetingNpc and DoesEntityExist(spawned.meetingNpc)) then
        TriggerEvent("calvin_artheist:client:spawnMeetingNpc")
        Wait(250)
    end

    local ped = PlayerPedId()
    local npc = spawned.meetingNpc
    local ms = Config.MeetingSpot

    if npc and DoesEntityExist(npc) then
        FreezeEntityPosition(npc, false)
        ClearPedTasksImmediately(npc)

        TaskTurnPedToFaceEntity(npc, ped, 800)
        TaskTurnPedToFaceEntity(ped, npc, 800)
        Wait(650)

        local dict = "mp_common"
        local animGive = "givetake1_a"
        LoadAnim(dict)

        FreezeEntityPosition(ped, true)
        FreezeEntityPosition(npc, true)

        TaskPlayAnim(npc, dict, animGive, 8.0, -8.0, 2000, 49, 0.0, false, false, false)
        TaskPlayAnim(ped, dict, animGive, 8.0, -8.0, 2000, 49, 0.0, false, false, false)

        Wait(2100)

        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)

        TriggerServerEvent("calvin_artheist:server:benchNote")

        FreezeEntityPosition(npc, false)
        ClearPedTasksImmediately(npc)

        local away = GetOffsetFromEntityInWorldCoords(npc, 0.0, 25.0, 0.0)
        TaskGoStraightToCoord(npc, away.x, away.y, away.z, 1.2, -1, ms.w, 0.5)

        CreateThread(function()
            Wait(15000)
            if spawned.meetingNpc and DoesEntityExist(spawned.meetingNpc) then
                DeleteEntity(spawned.meetingNpc)
            end
            spawned.meetingNpc = nil
        end)
    else
        TriggerServerEvent("calvin_artheist:server:benchNote")
    end

    meetingBusy = false
end)

-- ====== ART PICKUP==
RegisterNetEvent("calvin_artheist:client:collectArtwork", function()
    if collectingBusy or phoneBusy or meetingBusy then return end
    collectingBusy = true

    local ped = PlayerPedId()

    local dict = "anim@gangops@facility@servers@bodysearch@"
    local anim = "player_search"
    LoadAnim(dict)

    local duration = 8000

    if QBCore.Functions.Progressbar then
        QBCore.Functions.Progressbar(
            "artheist_opencrate",
            "Opening crate...",
            duration,
            false,
            true,
            {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            },
            {
                animDict = dict,
                anim = anim,
                flags = 49,
            },
            {},
            {},
            function() 
                ClearPedTasks(ped)
                TriggerServerEvent("calvin_artheist:server:stealArt")
                collectingBusy = false
            end,
            function() 
                ClearPedTasks(ped)
                Notify("Cancelled.", "error")
                collectingBusy = false
            end
        )
    else
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, 49, 0.0, false, false, false)
        FreezeEntityPosition(ped, true)
        Wait(duration)
        FreezeEntityPosition(ped, false)
        ClearPedTasks(ped)
        TriggerServerEvent("calvin_artheist:server:stealArt")
        collectingBusy = false
    end
end)
-- target zones
CreateThread(function()
    exports['qb-target']:AddBoxZone("artheist_phonebox", Config.PhoneBox, Config.ZoneSize.phone[1], Config.ZoneSize.phone[2], {
        name = "artheist_phonebox",
        heading = 0,
        debugPoly = false,
        minZ = Config.PhoneBox.z - 1.0,
        maxZ = Config.PhoneBox.z + 1.0,
    }, {
        options = {
            {
                icon = "fas fa-phone",
                label = "Use Phone Box",
                action = function()
                    if phoneBusy then return end
                    local dialog = exports['qb-input']:ShowInput({
                        header = "Dial Number",
                        submitText = "Call",
                        inputs = {
                            { text = "Number", name = "number", type = "text", isRequired = true },
                        }
                    })
                    if dialog and dialog.number then
                        TriggerServerEvent("calvin_artheist:server:dial", dialog.number)
                    end
                end,
            }
        },
        distance = 2.0
    })

    exports['qb-target']:AddBoxZone("artheist_meetcontact",
        vector3(Config.MeetingSpot.x, Config.MeetingSpot.y, Config.MeetingSpot.z),
        Config.ZoneSize.note[1], Config.ZoneSize.note[2], {
            name = "artheist_meetcontact",
            heading = Config.MeetingSpot.w,
            debugPoly = false,
            minZ = Config.MeetingSpot.z - 1.0,
            maxZ = Config.MeetingSpot.z + 1.0,
        }, {
            options = {
                {
                    icon = "fas fa-user",
                    label = "Meet Contact",
                    type = "client",
                    event = "calvin_artheist:client:meetVincent",
                }
            },
            distance = 2.0
        }
    )

    exports['qb-target']:AddBoxZone("artheist_pickup",
        vector3(Config.ArtLootPoint.x, Config.ArtLootPoint.y, Config.ArtLootPoint.z),
        Config.ZoneSize.pickup[1], Config.ZoneSize.pickup[2], {
            name = "artheist_pickup",
            heading = Config.ArtLootPoint.w,
            debugPoly = false,
            minZ = Config.ArtLootPoint.z - 1.0,
            maxZ = Config.ArtLootPoint.z + 1.0,
        }, {
            options = {
                {
                    icon = "fas fa-box-open",
                    label = "Open Crate",
                    type = "client",
                    event = "calvin_artheist:client:collectArtwork",
                }
            },
            distance = 2.0
        }
    )

    exports['qb-target']:AddBoxZone("artheist_dropoff",
        vector3(Config.DropOff.x, Config.DropOff.y, Config.DropOff.z),
        Config.ZoneSize.drop[1], Config.ZoneSize.drop[2], {
            name = "artheist_dropoff",
            heading = Config.DropOff.w,
            debugPoly = false,
            minZ = Config.DropOff.z - 1.0,
            maxZ = Config.DropOff.z + 1.0,
        }, {
            options = {
                {
                    icon = "fas fa-box",
                    label = "Leave Crates",
                    type = "server",
                    event = "calvin_artheist:server:dropArt",
                },
                {
                    icon = "fas fa-note-sticky",
                    label = "Read Drop Note",
                    type = "server",
                    event = "calvin_artheist:server:readDropNote",
                },
            },
            distance = 2.0
        }
    )

    exports['qb-target']:AddBoxZone("artheist_stash", Config.MoneyStash, Config.ZoneSize.stash[1], Config.ZoneSize.stash[2], {
        name = "artheist_stash",
        heading = 0,
        debugPoly = false,
        minZ = Config.MoneyStash.z - 1.0,
        maxZ = Config.MoneyStash.z + 1.0,
    }, {
        options = {
            {
                icon = "fas fa-sack-dollar",
                label = "Search Stash",
                type = "server",
                event = "calvin_artheist:server:claimMoney",
            }
        },
        distance = 2.0
    })
end)

RegisterNetEvent("calvin_artheist:client:showBenchClueAndSpawnScene", function(artScene)
    exports['qb-menu']:openMenu({
        { header = "Handwritten Note", isMenuHeader = true },
        { header = "Address", txt = "He’s unloading a van. Be there on time.", params = { event = "" } },
        { header = "GPS", txt = "Waypoint set to the handover.", params = { event = "" } },
        { header = "Close", params = { event = "qb-menu:client:closeMenu" } },
    })

    SetNewWaypoint(artScene.x, artScene.y)
    SpawnArtScene(artScene)
end)

RegisterNetEvent("calvin_artheist:client:afterSteal", function()
    Notify("You collected the artwork. Call the phone box again.", "success")
end)

RegisterNetEvent("calvin_artheist:client:showMoneyClue", function(moneyStash)
    exports['qb-menu']:openMenu({
        { header = "Drop Note", isMenuHeader = true },
        { header = "Message", txt = "Your payment is stashed nearby. Look carefully.", params = { event = "" } },
        { header = "GPS", txt = "Waypoint set to stash.", params = { event = "" } },
        { header = "Close", params = { event = "qb-menu:client:closeMenu" } },
    })
    SetNewWaypoint(moneyStash.x, moneyStash.y)
end)

-- ====== SCENE SPAWNING ===
local function SpawnPickupCrateOnly()
    for _, obj in ipairs(spawned.pickupCrates) do
        if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    spawned.pickupCrates = {}

    local lp = Config.ArtLootPoint
    local prop = Config.ArtPickupCrateProp or `prop_box_wood01a`

    RequestModel(prop); while not HasModelLoaded(prop) do Wait(0) end

    local crate = CreateObject(prop, lp.x, lp.y, lp.z - 1.0, true, true, false)
    PlaceObjectOnGroundProperly(crate)
    SetEntityHeading(crate, lp.w)
    FreezeEntityPosition(crate, true)
    table.insert(spawned.pickupCrates, crate)
end

function SpawnArtScene(artScene)
    CleanupEntities()

    local vanModel = Config.VanModel
    local npcModel = Config.NpcModel
    local guardModel = Config.GuardModel or `s_m_m_security_01`

    RequestModel(vanModel); while not HasModelLoaded(vanModel) do Wait(0) end
    RequestModel(npcModel); while not HasModelLoaded(npcModel) do Wait(0) end
    RequestModel(guardModel); while not HasModelLoaded(guardModel) do Wait(0) end

    spawned.van = CreateVehicle(vanModel, artScene.x, artScene.y, artScene.z, artScene.w, true, false)
    SetVehicleDoorsLocked(spawned.van, 1)
    SetEntityAsMissionEntity(spawned.van, true, true)

    local rearPos = GetOffsetFromEntityInWorldCoords(spawned.van, 0.0, -2.2, 0.0)
    spawned.npc = CreatePed(4, npcModel, rearPos.x, rearPos.y, rearPos.z, artScene.w, true, true)
    SetEntityAsMissionEntity(spawned.npc, true, true)
    SetBlockingOfNonTemporaryEvents(spawned.npc, true)
    SetPedFleeAttributes(spawned.npc, 0, 0)
    TaskStartScenarioInPlace(spawned.npc, "WORLD_HUMAN_CLIPBOARD", 0, true)

    local guardPos = GetOffsetFromEntityInWorldCoords(spawned.van, 2.0, -0.5, 0.0)
    spawned.guard = CreatePed(4, guardModel, guardPos.x, guardPos.y, guardPos.z, artScene.w, true, true)
    SetEntityAsMissionEntity(spawned.guard, true, true)
    SetBlockingOfNonTemporaryEvents(spawned.guard, true)
    SetPedFleeAttributes(spawned.guard, 0, 0)

    local guardWeapon = Config.GuardWeapon or `WEAPON_PISTOL`
    GiveWeaponToPed(spawned.guard, guardWeapon, 250, false, true)
    SetPedArmour(spawned.guard, 50)
    SetPedAccuracy(spawned.guard, 30)
    SetPedAlertness(spawned.guard, 3)
    SetPedSeeingRange(spawned.guard, 60.0)
    SetPedHearingRange(spawned.guard, 40.0)
    SetPedCombatRange(spawned.guard, 1)
    SetPedCombatMovement(spawned.guard, 2)

    CreateThread(function()
        local aggroed = false
        local aggroDist = Config.GuardAggroDistance or 8.0
        while spawned.guard and DoesEntityExist(spawned.guard) do
            Wait(300)
            if IsEntityDead(spawned.guard) then break end
            local ped = PlayerPedId()
            local dist = #(GetEntityCoords(ped) - GetEntityCoords(spawned.guard))
            if (not aggroed) and dist <= aggroDist then
                aggroed = true
                Notify("Guard: Hey! Back off!", "error")
                Wait(600)
                TaskCombatPed(spawned.guard, ped, 0, 16)
            end
        end
    end)

    SpawnPickupCrateOnly()

    TriggerServerEvent("calvin_artheist:server:sceneActive")
    Notify("Handover spotted. Open the crate.", "primary")
end

RegisterNetEvent("calvin_artheist:client:spawnDropCratesAndNote", function(dropOff, crateCount)
    local prop = Config.DropCrateProp or `prop_box_wood01a`
    RequestModel(prop); while not HasModelLoaded(prop) do Wait(0) end

    local count = crateCount or 3
    for i = 1, count do
        local offsetX = (i - ((count + 1) / 2)) * 0.55
        local obj = CreateObject(prop, dropOff.x + offsetX, dropOff.y + 0.4, dropOff.z - 1.0, true, true, false)
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        table.insert(spawned.crates, obj)
    end

    Notify("Crates left. Read the note for the payment location.", "success")
end)
