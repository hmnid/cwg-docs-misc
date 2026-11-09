scope CommandButtonNullRepro initializer InitTrig_CommandButtonNullRepro

	function CommandButtonNullRepro_Chat takes nothing returns nothing
		local player p = GetTriggerPlayer()
		local string command = GetEventPlayerChatString()
		local framehandle array slots
		local integer slotsNo = 12
		local integer i

		set i = 0
		loop
			set slots[i] = BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, i)
			if slots[i] == null then
				call BJDebugMsg("Native command slot " + I2S(i) + " was not found.")
			endif
			set i = i + 1
			exitwhen i >= slotsNo
		endloop

		if command == "-showcmd" then
			set i = 0
			loop
				call BlzFrameSetVisible(slots[i], true)
				set i = i + 1
				exitwhen i >= slotsNo
			endloop
			call BJDebugMsg("SetVisible(true)")
		elseif command == "-hidecmd" then
			set i = 0
			loop
				call BlzFrameSetVisible(slots[i], false)
				set i = i + 1
				exitwhen i >= slotsNo
			endloop
			call BJDebugMsg("SetVisible(false)")
		elseif command == "-spawnunit" then
			call BJDebugMsg("CreateUnit('hfoo')")
			call CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'hfoo', 0, 0, bj_UNIT_FACING)
			call BJDebugMsg("NO CRASH")
		endif

		set i = 0
		loop
			set slots[i] = null
			set i = i + 1
			exitwhen i >= slotsNo
		endloop
	endfunction
	
	function ShowDocumentation takes nothing returns nothing
		local timer tmr = GetExpiredTimer()
		
		call BJDebugMsg("1. send -showcmd. It should say \"SetVisible(true)\"\n2. send -spawnunit\n\nWC3 is expected to crash after the second command\nIf it prints \"NO CRASH\" - crash didn't reproduce")
		
		call DestroyTimer(tmr)
		set tmr = null
	endfunction

	function InitTrig_CommandButtonNullRepro takes nothing returns nothing
		local trigger t = CreateTrigger()
		local timer tmr = CreateTimer()

		call TriggerRegisterPlayerChatEvent(t, Player(0), "-showcmd", true)
		call TriggerRegisterPlayerChatEvent(t, Player(0), "-hidecmd", true)
		call TriggerRegisterPlayerChatEvent(t, Player(0), "-spawnunit", true)
		call TriggerAddAction(t, function CommandButtonNullRepro_Chat)

		
        call TimerStart(tmr, 1, false, function ShowDocumentation)

		set t = null
		set tmr = null
	endfunction

endscope
