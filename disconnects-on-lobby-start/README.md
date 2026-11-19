## What happends

1. I host a lobby
2. I start this lobby
3. The map loads successfully

Then
1. Either I'm being sent to the score screen right away
2. Or
    1. Character selection screen loads normally
    2. Several seconds passes (5-7)
    3. Animations freeze (model of the hero I chose on the selection screen)
    4. I'm sent to the score screen

Bummer

## Circumstances

The circumstances are not clear so far

* Usually this happends when I am the host
* Reproducible even when I'm the only player
* Sometimes drops happend late in the game, although rare and not necessary related to the same issue
* Allegedly players with better hardware never experience the issue
* Some players recommend to close battle net launcher to avoid this issue
* Sometimes, when the game starts, I see "You have beed disconnected from the Battle.net. The current game will proceed normally". And it does. Could be a coincidence though.

## Current hypothesis

Supplementary battle.net connection deliberately instructs the game to tear down the current game session.

Here is how it breaks down

When warcraft 3 starts, it makes several HTTPS connections to it's servers (probably websockets). What does it do is unknown for certain, but it should include:
* Getting lobby list
* Just checking that you are "online", preventing you from playing offline (reforged 3.1+)

Lobby on the other hand is handled by a separate server - the host server, listening on a high port.
When the game started, the latter connection is vital. The game proceeds normally if you lose connection to :443 endpoints.

So, the hypothesis is that the back end of one of these two :443 connections decides for some reason that my current gaming session is stale and should be teared down.
This could be a thing because loading and map initialization takes a lot of time, potentinally hanging websocket instance's lifecycle, including keepalives.

## Diagnostic

### Possible mitigation: blocking battle.net traffic

It __feels__ like it has something to do with the supplementary battle.net connection, but closing battle.net launcher should not help.
What should do is dropping active connections to :443 endpoints with firewall rules.

The proposed recipe:
1. Launch your lobby
2. While you are still on the load screen, invoke [this powershell script](./block-wc3-https.ps1)
    **DISCLAIMER**: do not run the script unless you understand it. Scripts could be malicious.
3. Don't forget to focus your wc3 window again
4. The game should proceed normally

So far I haven't experienced any weird disconnections since i started to drop :443 connections once the game starts. Unfortunately, this is circumstantional, maybe I'm just lucky.

### Logs and dumps

There are none. Nothing is produced.
This is neither a crash, nor a desync. Nothing interesting in War3Log.txt either.

### Network traffic

My typical netstat footprint of launched WC3 looks like this:

```
PS C:\Users\hmnid> Get-Process -Name 'Warcraft III'

Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
   2939    2811  4824212    1705692   8 739,52  14012   1 Warcraft III


PS C:\Users\hmnid> Get-NetTCPConnection |Where-Object { $_.OwningProcess -eq 14012}

LocalAddress                        LocalPort RemoteAddress                       RemotePort State       AppliedSetting OwningProcess
------------                        --------- -------------                       ---------- -----       -------------- -------------
192.168.1.79                        65102     66.40.186.140                       12583      Established Internet       14012
192.168.1.79                        60901     136.110.153.89                      443        Established Internet       14012
192.168.1.79                        60805     34.90.35.110                        443        Established Internet       14012
```

The connection to 66.40.186.140:12583 is vital while I'm in a started gaming session - this is the host server.
Connections to :443 can be dropped without any consequences.

### Score screen unwinding
