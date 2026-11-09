Transition from character selection screen to native ui sometimes causes the game to crash

## General
Inspired by today's stress test performed by the community to nail down crashes when people are loading.

We tried to provoke a crash by loading simultaneously while others are hitting mobs. We managed to reproduce crashes and acquired logs and dumps.
I was lucky enough to crash myself. Here is what I managed to come up with.

Established facts
- Crash is triggered when any unit instance is created

	Now it makes sense why hitting a dummy doesn't cause issues, but hitting mobs does. They respawn afterwards!

	This also makes it clear why most of crashes happend when somebody is late for their turn to load (AFK). Everyone else is already farming at this point
- Crash is caused by a WC3 bug happening on transition between character selection screen to native ui

	This explains why we often see people crash right when they are about to finish loading

Workaround (while the fix is on the way)
- Avoid provoking any unit creation while people are loading

	This actually involves a lot of staff
	- Loading in parallel
	- Respawning mobs/spawning raid bosses
	- Summoning or replacing pets
	- Abilities that use dummy units
	- Even merely browsing your hero roaster (where do you think the rendered hero model comes from?)
	
	So how to avoid crashes during character loading? The only reliable way:
	- Do not touch anything until it is your turn to load
        Feel free to chat though
	- When your turn comes, select your hero and start load
	- Do not touch anything until everyone is loaded
- If you find a clever way to force game to focus any unit while you are at the character selection screen, this could help
	But I doubt it is possible.

Credits: 
- `@themidlane` for asking us out to go investigate it and for our great CWG experience overall
- `@getbasiled` for organizing a test session
- `@taol`, `@nayers`, `@mateusz7167`, `@chopin`, `@hmnid`, `@retrofool`, `@numb2547` for performing the test

## Test session

This paragraph is relevant to any tester that wants to report a crash/desync to the developer

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
The fact that new folder appeared in Errors strongly suggests that it was in fact a process crash.

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
Crash.txt is a cut textual representation of war3.dmp, along with my device info and process/build metadata

Here is what my Crash.txt says:
```
<Exception.Summary:>
ACCESS_VIOLATION (Failed to read address 0x0000000000000008 at instruction 0x00007FF74EEF432D) DBG-OPTIONS<FunctionsOnly SingleLine> DBG-ADDR<00007FF74EEF432D>("Warcraft III.exe") <- DBG-ADDR<00007FF74EEC35CB>("Warcraft III.exe") <- DBG-ADDR<00007FF74EF07C2A>("Warcraft III.exe")  DBG-OPTIONS<>
<:Exception.Summary>
```

Yeah, definetely a crash. This is a null-pointer dereference.

But this is just a singular fact. We need to acquire some context to figure out exact technical circumstances.

## The methodology

Boring part. This paragraph describes how to get to the down of it. Pointing out what tools and knowledge we need along the way.

To cut the long story short, **employing AI agents** is essential here.

Key idea: War3.dmp is our key to understand what exactly the wc3 code was doing when it crashed and what led to it

* Supply war3.dmp to a debugger
    ```
    > & 'C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe' -z 'C:\Users\hmnid\Documents\Warcraft III\Errors\2026-11-09 01.39.06 5a870f58\War3.dmp' -i 'C:\Program Files (x86)\Warcraft III\_retail_\x86_64\'
    ```

    You better be familiar with cdb or any native code debugger.

    You need a general understanding of x86\_64 (registers, memory, stack)
* Unwind the call stack to get the carcass for the upcoming native code inference
    Evaluate RIP, RSP. Unwind the stack back to the top (or to some point). Take note what code addresses were mentioned, what objects were passed as arguments

    You need to be familiar with x86\_64 assembler.

    You need to know x64 calling convention
* Gather the code and figure out what it does
    Here comes the hardest part: you gotta make sense out of the code that is present along the call stack.

    Try it yourself, just the funcking where crash occure: [find-visible-button.asm](./find-visible-button.asm). Pretend comments are not there.
    1. Make a pseudocode that reflects general code structure: branching, loops, assignments, calls
    2. Imbue this pseudocode with meaning by assigning correct names to objects and fields
        * Get the most out of runtime reflection available. In our instance it is RTTI (c++)
        * Infer names based on what value is assigned there/in what context it is used

    This sure will take a lot of time.

    You need to know how c++ runtime works on a low level.

    You need to know to get data from Portable Executable (aka PE aka .exe).
* Get missing process state by dumping actual running warcraft 3
    Warcraft 3 does not supply full coredump, War3.dmp is a `minidump`. For example, it means the dump contains just a small portion of native code. This can be overcome by dumping code section of a running process, preferrable with some lobby launched.

To sum up, **employing AI agents** is essential here.


## Unleash the debugger (technical)

Finally, the lecture is over. Time to have some fun.

The call stack
```
Game timer callback                 [CTimerWar3]  // map logic operates under the eventloop, hence "callback"
 → JASS script execution           [Jass2ScriptInstance_t]
   → CreateUnit(player, 'n004', x, y, facing)
     → engine unit creation/setup  [CUnit]
       → UI handling               [CGameUI]
         → Cancel-command lookup
           → CCommandBar button search
             → null command-data dereference
```

Here is a pseudocode implementation of `CreateUnit` function: [createunit.cpp](./createunit.cpp)

At this point it is clear what causes the crash.
1. `CreateUnit` tries to update `"Cancel"` button's tooltip for whatever reason. So it queries `CommandBar::FindVisibleButton` for an instance of the `"Cancel"` button.
2. `CommandBar::FindVisibleButton` tries to find button with requested command type
    1. Iterates over all 12 command panel buttons
    2. Checks whether the button is visible
    3. Checks does button's command belong the requested command type.

Type of a button lies in the underlying object `button->commandData`, which appears to be not initialized at the start of the game (it contains `nullptr`).

Then why don't we experience crashes in any map that spawn units in the beginning?
Could it be that something is messing up with IsVisible flag, marking unilitialized button as visible?

## The perpetrator

```
call BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, index), true)
```

How it works
1. Native ui is hidden. Character selection screen is displayed
2. You load your character
3. Your character is successfully instantiated
4. Character selection screen is hidden, native ui is displayed
    This logic, among other things, calls `BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, index), true)`
    It is evident that this blizzard native makes `button->IsVisible()` to return `true`, but it does not initialize `button->commandData`
5. Wait 0.4s
6. Your character is focused.
    At this point, `button->commandData` is finally initialized

### The reproducible example in a nutshell

```jass
function Crash takes nothing returns nothing
    // Assumes you did not focus any unit yet
    local integer i = 0
    local framehandle frm = null

    loop
      set frm = BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, i)
      call BlzFrameSetVisible(frm, true)
      set i = i + 1
      exitwhen i >= slotsNo
    endloop

    call CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'hfoo', 0, 0, bj_UNIT_FACING) // crash!

    set frm = null
endfunction
```

This code does nothing wrong. But it crashes. It's the engine bug.

## Minimal reproducible example

Here it is: [HideAndSpawn.w3x](./HideAndSpawn.w3x)
This map has a single footman already spawned and supports three chat commands: -showcmd, -hidecmd, -spawnunit

To reproduce the crash
1. Do not focus the footman
2. Send -showcmd.
    It should say "SetVisible(true)"
3. Send -spawnunit.
    It should crash.
    If it instead prints "NO CRASH" - then crash didn't reproduce. Too bad. Works for me every time.

If you instead
1. Focus the footman
2. Send -showcmd.
3. Send -spawnunit.

Nothing bad will happend.
