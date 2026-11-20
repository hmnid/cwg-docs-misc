# CWG: trying a workaround for disconnects after loading

Share this guide together with **`block-wc3-https.ps1`**. No other project files are needed.

## What is this for?

When I start CWG, the map sometimes finishes loading only to send me straight to the score screen. Other times I reach character selection, then get dropped about **5–7 seconds later**. It can happen even when I'm the only player.

I've been experimenting with temporarily blocking some Warcraft III service traffic during loading, and I've had successful CWG games while using this script. **I don't know yet whether it reliably prevents the disconnects.** If you have the same problem, this guide explains how to try it and share your results.

My investigation has been on WC3 **3.0.1.24371**. Results on other builds or configurations may differ.

## Read this before trying it

- **You may disconnect, lose lobby/service access, or interrupt your game.** You can try it in solo, private, or public CWG games; just keep the possibility of an interrupted session in mind.
- You don't need to close other Warcraft III instances just because they're running. In my experience, games already underway continue normally; instances still in menus or lobbies that haven't started will lose their Battle.net connection. The rules apply to the executable, **not just one process**, so keep that in mind if you're preparing another lobby.
- Administrator rights are required because the script changes Windows Firewall rules and registers a cleanup task.
- Read the script or have someone you trust review it. Do not run an unfamiliar downloaded script merely because this guide says to.
- Automatic cleanup aims for **three minutes after script startup**, but that is not a guaranteed expiration. Sleep, shutdown, Task Scheduler problems, or errors can delay removal. Keep the manual undo command below available.
- There's no need to disable your firewall, antivirus, or other security software. Leave them enabled—the script uses Windows Firewall to apply the temporary rules.

## What the script changes

It takes one snapshot of Warcraft III's TCP connections and finds non-loopback remote addresses on **port 443**. For those addresses, it creates outbound Windows Firewall block rules restricted to the Warcraft III executable path and TCP remote port 443.

It does **not**:

- Modify game files or process memory.
- Block all Internet access or intentionally block other applications.
- Target the Battle.net launcher or Agent executable.
- Block other remote ports or UDP.
- Continuously discover new remote addresses.

The filename says “HTTPS,” but port 443 alone does not establish the application protocol. Blocking traffic also does not necessarily close a connection immediately; it may instead stall or time out.

## Requirements

- Windows with Windows Firewall, Windows PowerShell, and the built-in `NetSecurity`, `NetTCPIP`, and `ScheduledTasks` modules available.
- A running Task Scheduler service.
- Permission to run an elevated PowerShell window and change local firewall rules. Do not override an administrator's restrictions on a managed computer.
- PowerShell must permit the script to run. Depending on your execution policy, Windows may block an unsigned downloaded script. After reviewing and trusting the file, you may need to remove its download mark with `Unblock-File`; see [the preparation steps below](#1-prepare-before-starting-cwg). This does not change execution policy or override restrictions requiring signed scripts.

## How to try it

### 1. Prepare before starting CWG

1. Save `block-wc3-https.ps1` in a folder you can find.
2. Check your other Warcraft III instances, if any. Games already underway should be fine; expect instances without a started game to disconnect from Battle.net.
3. Open **Windows PowerShell → Run as administrator**.
4. Change to the script's folder, for example:

   ```powershell
   Set-Location "$env:USERPROFILE\Downloads"
   ```

5. Leave that window ready. Do **not** run the script during login or before joining/creating the lobby.

If Windows blocks the downloaded file, review it first. If you trust that exact file, you can remove its download mark with:

```powershell
Unblock-File -LiteralPath .\block-wc3-https.ps1
```

This does not override policies requiring signed scripts. If policy still prevents execution, stop rather than changing machine-wide execution policy or disabling security controls.

### 2. Run once during map loading

1. Host or join a CWG lobby as usual—solo, private, or public.
2. Start CWG normally.
3. While CWG is loading, switch to the prepared PowerShell window and run:

   ```powershell
   .\block-wc3-https.ps1
   ```

4. Return focus to Warcraft III immediately. The script can remain running in the background.
5. Check whether you reach character selection and stay in CWG beyond the point where you would usually get dropped.

Do not repeatedly launch it during the same attempt. Each invocation creates its own independent rules and cleanup task.

### 3. Let cleanup finish and verify

The script prints a cleanup deadline, then lines such as:

```text
Cleanup armed for ...: Pi-WC3-HTTPS-Cleanup-...
Blocked ...Warcraft III.exe -> ...:443
Blocking rules applied for ... target(s). Sleeping for ... seconds until cleanup at ... You can return to CWG.
```

The green “Blocking rules applied” message confirms that rule creation finished and the script is entering its sleep stage. You can leave that window alone and return to CWG while it waits for cleanup.

Normally, around three minutes after startup, its foreground cleanup removes that run's rules. A scheduled SYSTEM task is registered **before any firewall changes** as a fallback if the terminal closes; startup and missed-task handling also provide recovery opportunities. Cleanup can still be delayed or fail.

To check for remaining rules, use an elevated PowerShell window:

```powershell
Get-NetFirewallRule |
    Where-Object Group -Like 'Pi WC3 HTTPS blocks*' |
    Select-Object DisplayName, Enabled, Direction, Action
```

**No output means no matching rules remain.** This is a stronger check than assuming cleanup succeeded because the timer elapsed. The scheduled cleanup task may remain briefly until its scheduled execution removes itself.

## Stop early / manual undo

In an elevated PowerShell window, run:

```powershell
Get-NetFirewallRule |
    Where-Object Group -Like 'Pi WC3 HTTPS blocks*' |
    Remove-NetFirewallRule
```

This removes **all matching experiment rules**, including other runs and older script versions—not just the most recent run. It does not reset the rest of your firewall configuration.

Then run the verification command above. You do not need to delete the fallback task manually; leaving it in place lets it perform its cleanup and remove itself. **Do not delete cleanup tasks while matching rules may still exist.**

Removing rules permits traffic again; it cannot guarantee that an already disconnected session recovers. You may need to rejoin or restart the game afterward.

## If something goes wrong

| Symptom | What to do |
|---|---|
| Administrator/module requirement error | Stop. Check requirements; do not disable security controls. |
| `Task Scheduler is not running` or cleanup registration error | The script is designed not to create block rules without cleanup registration/verification. Check for leftover rules from earlier runs anyway. |
| `No WC3 TCP connections to remote port 443 found. No rules changed.` | This run did not block anything. Verify the game/lobby was running; do not interpret the result as a successful workaround test. |
| Login, lobby, or game stops working | Use manual undo, verify removal, then reconnect normally. |
| Red error after rules started appearing | Do not assume everything was undone. Run manual undo and verify. |
| Rules remain after three minutes, sleep, or reboot | Use manual undo and verify removal. Do not rerun the script to try to clean up. |

## Let me know how it went

If you try this with CWG, send me a short report:

```text
WC3 version:
CWG version:
Host or joining player; solo or multiplayer:
Usual symptom:
When the script was launched:
Did it print actual "Blocked ..." lines, or "No ... connections ..."?
Result: disconnected / stayed in game / other:
Any Battle.net disconnection notice:
Were all experiment rules removed afterward?
```

Mention whether the same setup sometimes succeeds without the script. One successful game is useful feedback, **not proof of a fix**. A brief result report is enough; do not send passwords, authentication tokens, personal file paths, or raw diagnostic captures.
