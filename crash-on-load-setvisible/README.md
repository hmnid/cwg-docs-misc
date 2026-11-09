Transition from character selection to normal ui sometimes causes the game to crash

## General
Inspired by today's stress test performed by the community to nail down crashes when people are loading.

We tried to provoke a crash by loading simultaneously while others are hitting mobs. We managed to reproduce crashes and acquired logs and dumps.
I was lucky enough to crash myself. Here is what I managed to come up with.

Established facts
- Crash is triggered when any unit instance is created
	Now it makes sense why hitting a dummy doesn't cause issues, but hitting mobs does. They respawn afterwards!
	This also makes it clear why most of crashes happend when somebody is late for their turn to load (AFK). Everyone else is already farming at this point
- Crash is caused by the logic responsible for hiding character selection screen and making regular ui visible
	This explains why we often see people crash right when they are about to finish their loading

Workaround (while the fix is on the way)
- Avoid provoking any unit creation while people are loading
	This actually involves a lot of staff
	- Loading in parallel
	- Respawning mobs/spawning raid bosses
	- Summoning or replacing pets
	- Abilities that use dummy units
	- Even merely browsing your hero roaster (where do you think the rendered hero model comes from?)
	
	The most reliable algorithm to avoid crashes:
	- Do not touch anything until it is your turn to load
	- When your turn comes, select your hero and start load
	- Do not touch anything until everyone is loaded
- If you find a clever way to force game to select any unit while you are at the character selection screen, this could help
	But I doubt it is possible.

Credits: 
- @themidlane for asking us out and for our joyful cwg experience
- @GetBasiled for organizing a test session
- @taol, @nayers, @mateusz7167, @chopin, @hmnid, @retrofool, @numb2567 for performing the test

## Test session

This subarticle is relevant to any tester that wants to report a crash/desync to the developer

Test setup:
* ~7 players
* 2-3 players perform a disciplined (normal) load and go farm mobs
* On the count of the coordinator everybody else loads at the same time
* Somebody is expected to crash if we are lucky enough

Expected artifacts:
* desync announcement in the chat produced by the server (on desync)
* `%USERPROFILE%\Documents\Warcraft III\CustomMapData\CWG2\DESYNCWATCH.pld` (on desync)
* `%USERPROFILE%\Documents\Warcraft III\Errors\{crash datetime} {random string}` (on crash)
* `%USERPROFILE%\Documents\Warcraft III\Logs\*_Desync.log` and `%USERPROFILE%\Documents\Warcraft III\Logs\*_replay.w3g` (on desync)
* `%USERPROFILE%\Documents\Warcraft III\Logs\War3Log.txt` (in any case)

We performed two instances of the test. Each time at least somebody has crashed.
It was not a desync, evidenced by complete absense of any desync artifacts on any participant's pc.
The fact that new folder appeared in Errors strongly suggests that it was in fact a process crash and not a desync.

## Inspecting crash artifacts (technical)

From this point forward, things most likely won't make sense for you unless you are a software developer.

Here are crash artifacts that are present in the Errors folder:
```powershell
> ls "~\Documents\Warcraft III\Errors\2026-11-09 01.39.06 5a870f58"
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----        09.11.2026      1:39          49115 Crash.txt
-a----        09.11.2026      1:39          51613 TempReplay.w3g
-a----        09.11.2026      1:39         715655 War3.dmp
-a----        09.11.2026      1:39         107254 War3Log.txt
```

War3.dmp is a coredump of the WC3 process - basically a snapshot of the process state on the moment it crashed.
It contains a heap, all threads, their corresponding registers and stacks.
Crash.txt is a clipped textual representation of war3.dmp, along with my device info and process/build metadata

Here is what my Crash.txt says:
```
<Exception.Summary:>
ACCESS_VIOLATION (Failed to read address 0x0000000000000008 at instruction 0x00007FF74EEF432D) DBG-OPTIONS<FunctionsOnly SingleLine> DBG-ADDR<00007FF74EEF432D>("Warcraft III.exe") <- DBG-ADDR<00007FF74EEC35CB>("Warcraft III.exe") <- DBG-ADDR<00007FF74EF07C2A>("Warcraft III.exe")  DBG-OPTIONS<>
<:Exception.Summary>
```

Yeah, definetely a crash. This is a null-pointer dereference.
But this is just a singular fact. We need to acquire some context to figure out exact technical circumstances.

## So what do we do?

If you supply War3.dmp to a debugger, it will restore a process state for you, so you can inspect it:
```
> & 'C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe' -z 'C:\Users\hmnid\Documents\Warcraft III\Errors\2026-11-09 01.39.06 5a870f58\War3.dmp' -i 'C:\Program Files (x86)\Warcraft III\_retail_\x86_64\'
```

By evaluating RIP, RSP, unwinding the call stack of the crashed thread and inspecting the code section, you can, in theory, figure out, what the process was doing ending up dereferencing a null pointer.

After you thoroughly unwinding the stack, here comes the hardest part: you gotta make sense out of the code that is present along the call stack.
Try it yourself, just the funcking where crash occure: [./find-visible-button.asm](find-visible-button.asm). Pretend comments are not there.
This will take a lot of time. So **employing AI agents** is essential here.

One more pitfall lies ahead: Warcraft 3 does not supply full coredump, War3.dmp is a `minidump`. Which means it contains only a small portion of native code.


## Unleash the debugger (technical)

The call stack
```
Game timer callback                 [CTimerWar3]  // map runtime is the eventloop
 → JASS script execution           [Jass2ScriptInstance_t]
   → CreateUnit(player, 'n004', x, y, facing)
     → engine unit creation/setup  [CUnit]
       → UI handling               [CGameUI]
         → Cancel-command lookup
           → CCommandBar button search
             → null command-data dereference
```

Here is a pseudocode implementation of `CreateUnit` function: [./createunit.cpp](createunit.cpp)
