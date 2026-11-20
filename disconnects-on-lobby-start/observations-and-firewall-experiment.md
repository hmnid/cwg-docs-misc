# My CWG disconnect symptoms and observations

## Symptoms

- CWG finishes loading, but I'm sent to the score screen immediately or several seconds later.
- Sometimes I reach character selection first; animations then freeze before the score screen appears.
- I usually encounter this while hosting. It can happen even when I'm the only player.
- I've also had occasional disconnects later in a game, but those may have another cause.

## What remains uncertain

I've heard suggestions about hardware differences and closing the Battle.net launcher, but I haven't verified them. I've sometimes seen a Battle.net disconnection notice while CWG continued normally. None of this tells me for certain what's causing the drops.

I've had successful CWG games while temporarily blocking selected Warcraft III traffic during loading. Because games can also succeed without the script, I see this as something worth testing—not a confirmed fix or proof of what the server is doing.

## Trying the experiment

Use the [standalone player guide](blocking-script-guide.md) with `block-wc3-https.ps1`. Start with a solo/private test, close other WC3 instances, and verify that the temporary rules are removed afterward.

If you try it, let me know your WC3 and CWG versions, whether you hosted or joined, whether blocking rules were actually created, and whether you got dropped as usual. A brief description is enough; no low-level diagnostic material is needed.
