function InitGlobals()
end

function InitTrig_CommandButtonNullRepro()
    local trigger = CreateTrigger()
    TriggerRegisterPlayerChatEvent(trigger, Player(0), "-showcmd", true)
    TriggerRegisterPlayerChatEvent(trigger, Player(0), "-hidecmd", true)
    TriggerRegisterPlayerChatEvent(trigger, Player(0), "-spawnunit", true)
    TriggerAddAction(trigger, CommandButtonNullRepro_Chat)
    TimerStart(CreateTimer(), 1, false, ShowDocumentation)
end

function CommandButtonNullRepro_Chat()
    local command = GetEventPlayerChatString()
    local slots = {}

    for i = 0, 11 do
        slots[i] = BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, i)
        if slots[i] == nil then
            BJDebugMsg("Native command slot " .. tostring(i) .. " was not found.")
        end
    end

    if command == "-showcmd" then
        for i = 0, 11 do
            BlzFrameSetVisible(slots[i], true)
        end
        BJDebugMsg("SetVisible(true)")
    elseif command == "-hidecmd" then
        for i = 0, 11 do
            BlzFrameSetVisible(slots[i], false)
        end
        BJDebugMsg("SetVisible(false)")
    elseif command == "-spawnunit" then
        BJDebugMsg("CreateUnit('hfoo')")
        CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC("hfoo"), 0, 0, bj_UNIT_FACING)
        BJDebugMsg("NO CRASH")
    end
end

function ShowDocumentation()
    BJDebugMsg([[1. send -showcmd. It should say "SetVisible(true)"
2. send -spawnunit

WC3 is expected to crash after the second command
If it prints "NO CRASH" - crash didn't reproduce]])
    DestroyTimer(GetExpiredTimer())
end

function CreateUnitsForPlayer0()
    BlzCreateUnitWithSkin(Player(0), FourCC("hfoo"), -119.7, 124.7, 206.846, FourCC("hfoo"))
end

function CreatePlayerBuildings()
end

function CreatePlayerUnits()
    CreateUnitsForPlayer0()
end

function CreateAllUnits()
    CreatePlayerBuildings()
    CreateUnitsForPlayer0()
end

function InitCustomPlayerSlots()
    SetPlayerStartLocation(Player(0), 0)
    SetPlayerColor(Player(0), ConvertPlayerColor(0))
    SetPlayerRacePreference(Player(0), RACE_PREF_HUMAN)
    SetPlayerRaceSkin(Player(0), RACE_PREF_RANDOM)
    SetPlayerRaceSelectable(Player(0), true)
    SetPlayerController(Player(0), MAP_CONTROL_USER)
end

function InitCustomTeams()
    SetPlayerTeam(Player(0), 0)
end

function InitCustomTriggers()
    InitTrig_CommandButtonNullRepro()
end

function main()
    SetCameraBounds(
        -3328.0 + GetCameraMargin(CAMERA_MARGIN_LEFT), -3584.0 + GetCameraMargin(CAMERA_MARGIN_BOTTOM),
         3328.0 - GetCameraMargin(CAMERA_MARGIN_RIGHT), 3072.0 - GetCameraMargin(CAMERA_MARGIN_TOP),
        -3328.0 + GetCameraMargin(CAMERA_MARGIN_LEFT), 3072.0 - GetCameraMargin(CAMERA_MARGIN_TOP),
         3328.0 - GetCameraMargin(CAMERA_MARGIN_RIGHT), -3584.0 + GetCameraMargin(CAMERA_MARGIN_BOTTOM)
    )
    SetDayNightModels("Environment\\DNC\\DNCLordaeron\\DNCLordaeronTerrain\\DNCLordaeronTerrain.mdl", "Environment\\DNC\\DNCLordaeron\\DNCLordaeronUnit\\DNCLordaeronUnit.mdl")
    SetHDWaterParamsEx(0, 0, 0, false, 20, 0, 100, 10, 0, 50, 100, 100)
    NewSoundEnvironment("Default")
    SetAmbientDaySound("LordaeronSummerDay")
    SetAmbientNightSound("LordaeronSummerNight")
    SetMapMusic("Music", true, 0)
    CreateAllUnits()
    InitBlizzard()
    InitGlobals()
    InitCustomTriggers()
end

function config()
    SetMapName("HideAndSpawnLua")
    SetMapDescription("TRIGSTR_003")
    SetPlayers(1)
    SetTeams(1)
    SetGamePlacement(MAP_PLACEMENT_USE_MAP_SETTINGS)
    DefineStartLocation(0, -1216.0, 512.0)
    InitCustomPlayerSlots()
    SetPlayerSlotAvailable(Player(0), MAP_CONTROL_USER)
    InitGenericPlayerSlots()
end
