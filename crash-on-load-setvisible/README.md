# Game sometimes crashes when we load characters

During today's community stress test, we tried loading simultaneously while others were hitting mobs. We managed to crash the game and collect logs and dumps. I was lucky enough to crash myself. Here is what I found.

## What is going on?

There is a short window between the character-selection screen closing and your loaded hero being focused. If a unit is created during that window, your game can crash.

Things that create units include:
- Loading a hero.
- Respawning mobs or spawning raid bosses.
- Summoning or replacing pets.
- Applying bag cosmetics.
- Using abilities implemented with dummy units.
- Browsing your hero roster. Where do you think the preview hero model comes from?

The investigation points to a WC3 engine bug. I made a standalone map that reproduces it.

Now some things make sense:

- Why does hitting a dummy seem fine, but hitting mobs causes trouble? Mobs respawn afterwards!
- Why do people often crash when somebody is late for their turn to load? Everyone else is already farming at this point.
- Why does it happen right when you are about to finish loading? That is when the character-selection screen gives way to the normal UI.

This explains my particular crash, not necessarily every loading crash.

## Workaround

**Load one at a time. Avoid actions that spawn units until everyone is loaded.**

1. Do not touch anything until your turn to load. Feel free to chat though.
2. Select your hero and load.
3. Wait until everyone is loaded before doing anything else.

Selecting any unit beforehand prevents the crash in my standalone test. But I don't see a normal way to do that from CWG's selection screen.

## Credits

- `@themidlane` for encouraging us to investigate it and for CWG.
- `@getbasiled` for organizing the test session.
- `@taol`, `@nayers`, `@mateusz7167`, `@chopin`, `@hmnid`, `@retrofool`, `@numb2547` for testing.

## Want to try crashing it yourself?

Here is the standalone map: [HideAndSpawn.w3x](./HideAndSpawn.w3x).

It has a single footman already spawned and three chat commands: `-showcmd`, `-hidecmd`, and `-spawnunit`.

To reproduce the crash:

1. Start the map. **Do not select the footman.**
2. Send `-showcmd`. It should say `SetVisible(true)`.
3. Send `-spawnunit`.
4. It should crash.

If it instead prints `NO CRASH`, the crash did not reproduce. Too bad. Works for me every time.

Now restart the map and try this:

1. Select the footman first.
2. Send `-showcmd`.
3. Send `-spawnunit`.

Nothing bad happens in my tests. Same commands, but selecting a unit first makes the difference.

If you try it, please include your exact WC3 version and build when reporting the result.

---

## The test session and what to collect

The player advice ends here. This section is for anyone who wants to help investigate crashes or report one to the developer.

Our setup:

- About seven players.
- Two or three players load normally, one at a time, and go farm mobs.
- At the coordinator's signal, everybody else loads at the same time.
- Somebody is expected to crash if we are lucky enough.

We ran the test twice. Each time, at least somebody crashed.

We found no desync artifacts on any participant's PC. Instead, the affected clients generated crash reports. The report I examined contains an access violation, so we definitely have a process crash here, not just somebody getting disconnected.

Useful artifacts to collect:

- Desync announcement in chat, if there is one.
- `%USERPROFILE%\Documents\Warcraft III\CustomMapData\CWG2\DESYNCWATCH.pld`, if generated.
- `%USERPROFILE%\Documents\Warcraft III\Errors\{crash datetime} {identifier}` on a crash.
- `%USERPROFILE%\Documents\Warcraft III\Logs\*_Desync.log` and `*_replay.w3g`, if generated.
- `%USERPROFILE%\Documents\Warcraft III\Logs\War3Log.txt` in either case.

Also note your exact game build and what was happening when you crashed. Was somebody loading? Had the selection screen just closed? Were others farming?

One thing to keep in mind: dumps can contain private data from process memory. Share them with people you trust rather than posting them publicly without checking.

## Inspecting crash artifacts (technical)

From this point forward, things most likely won't make sense unless you are a software developer. Feel free to stop here.

Here is what my Errors folder contains:

```powershell
> ls "~\Documents\Warcraft III\Errors\2026-11-09 01.39.06 5a870f58"
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----        09.11.2026      1:39          49115 Crash.txt
-a----        09.11.2026      1:39          51613 TempReplay.w3g
-a----        09.11.2026      1:39         715655 War3.dmp
-a----        09.11.2026      1:39         107254 War3Log.txt
```

`War3.dmp` is a minidump of the WC3 process. Basically, a partial snapshot of the process state at the moment it crashed: thread contexts, registers, stacks, and selected memory. Not the entire heap or all process memory.

`Crash.txt` gives us a textual crash report, along with device info and process/build metadata.

Here is what mine says:

```text
<Exception.Summary:>
ACCESS_VIOLATION (Failed to read address 0x0000000000000008 at instruction 0x00007FF74EEF432D) DBG-OPTIONS<FunctionsOnly SingleLine> DBG-ADDR<00007FF74EEF432D>("Warcraft III.exe") <- DBG-ADDR<00007FF74EEC35CB>("Warcraft III.exe") <- DBG-ADDR<00007FF74EF07C2A>("Warcraft III.exe")  DBG-OPTIONS<>
<:Exception.Summary>
```

Yeah, definitely a crash. Reading address `0x8` is a strong hint that we are dereferencing a null pointer and accessing a field eight bytes into the object.

But this is just one fact. We need some context to figure out what exactly the game was doing.

## Unleash the debugger

Here is the reconstructed call stack:

```text
Game timer callback                 [CTimerWar3]
 → JASS script execution           [Jass2ScriptInstance_t]
   → CreateUnit(player, 'n004', x, y, facing)
     → engine unit creation/setup  [CUnit]
       → UI handling               [CGameUI]
         → Cancel-command lookup
           → CCommandBar button search
             → null command-data dereference
```

`n004` is the Corrupted field enemy, by the way.

Here is the reconstructed [CreateUnit pseudocode](./createunit.cpp), and here is the [visible-button search disassembly](./find-visible-button.asm).

These are reverse-engineered interpretations, not Blizzard source code. Some names come from runtime metadata; descriptive function and field names are otherwise inferred.

What appears to happen:

1. `CreateUnit` reaches UI code that tries to update the Cancel button's tooltip, for whatever reason. So it asks the command bar for a visible Cancel button.
2. The command bar iterates over all 12 buttons.
3. It checks whether each button is visible.
4. For a visible button, it reads the underlying command data to check the command type.

The command type lives in an object I called `button->commandData`. In this crash, that pointer is null.

Then why don't we crash in every map that spawns units at the beginning?

Could something be marking an uninitialized button as visible?

## The perpetrator

```jass
call BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, index), true)
```

The evidence points to this call making the button visible without initializing its command data. The engine's button search then assumes that a visible button has valid command data. Apparently not always.

Here is how that fits CWG's loading sequence:

1. Native UI is hidden. The character-selection screen is displayed.
2. You load your character.
3. Your character is successfully instantiated.
4. The character-selection screen closes and the native UI is shown. Among other things, this explicitly shows the command buttons.
5. Wait approximately 0.4 seconds.
6. Your character is selected. At this point, the command bar gets valid command data.

Create another unit between steps 4 and 6, and we can hit the null pointer.

That is the explanation supported by the dump and the standalone reproduction. It also explains why unrelated things like mob respawns or somebody browsing the hero roster can bring down a player who is finishing loading.

### The reproduction in code

```jass
function Crash takes nothing returns nothing
    // Assumes you have not selected any unit yet.
    local integer i = 0
    local framehandle frm = null
    local unit spawned = null

    loop
        exitwhen i >= 12
        set frm = BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, i)
        call BlzFrameSetVisible(frm, true)
        set i = i + 1
    endloop

    // Crashes under the reproduction conditions.
    set spawned = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'hfoo', 0, 0, bj_UNIT_FACING)

    set spawned = null
    set frm = null
endfunction
```

There is no CWG save data involved here. Just showing native buttons and creating a footman. That is why I consider this an engine bug rather than a broken character save.

You see, this code doesn't seem to do anything wrong. Both `ORIGIN_FRAME_COMMAND_BUTTON` and `BlzFrameSetVisible` are exposed as native API. How in the world could you figure out that this particular sequence causes the game executable to crash? The game code should check is `button->commandData` initialized before accessing it's fields.

## How I got to the bottom of it

The boring part, for anyone who wants to follow the investigation or check my work.

The key idea: `War3.dmp` lets us work backwards from the crash and figure out what the native code was doing.

### Open the dump

Supply it to a debugger. For example, CDB:

```powershell
& 'C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe' `
    -z 'C:\Users\hmnid\Documents\Warcraft III\Errors\2026-11-09 01.39.06 5a870f58\War3.dmp' `
    -i 'C:\Program Files (x86)\Warcraft III\_retail_\x86_64\'
```

The executable images need to match the build that crashed.

You need some familiarity with a native debugger and a general understanding of x86-64: registers, memory, and the stack.

### Unwind the stack

Inspect the exception context, RIP, and RSP. Work backwards through the callers. Take note of code addresses, arguments, and the objects being passed around.

You need to know the Windows x64 calling convention. Missing symbols and memory can make stack interpretation tricky, so don't blindly trust every apparent frame.

### Make sense of the code

Here comes the hard part.

Try it yourself: [just the function where the crash occurs](./find-visible-button.asm). Pretend the comments are not there.

1. Turn the instructions into pseudocode: branches, loops, assignments, calls.
2. Give that pseudocode meaning by figuring out what the objects and fields represent.
   - Get the most out of runtime metadata. In our case, C++ RTTI helps.
   - Look at what values are assigned and how callers use them.
   - Compare your interpretation against the register values and memory in the dump.

This sure takes a lot of time. Knowledge of the C++ runtime and the Portable Executable format helps too.

AI agents were a big help here, especially with assembly and pseudocode. But you still have to check what they tell you against the actual instructions and process state.

### Fill in what the dump is missing

WC3 gives us a minidump, not a full process dump. Some memory and code simply are not there.

Matching executable images can supply missing code. Inspecting a running WC3 process of the same build can also help with code and object layouts. It won't magically recover the crashed process's missing state, but it can give you enough context to keep going.
