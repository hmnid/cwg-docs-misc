# Reported symptoms and observations

## Symptoms

- A custom map finishes loading, but the player is sent to the score screen immediately or several seconds later.
- Sometimes character selection appears first; animations then freeze before the score screen.
- The original reporter usually encounters it while hosting. It can also happen with no other players.
- Occasional later-game disconnects have been reported, but may have another cause.

## What remains uncertain

Reports about hardware differences or closing the Battle.net launcher are anecdotal. A Battle.net disconnection notice has sometimes appeared while the game continued normally. None of these observations establishes the cause of this problem.

The original reporter has had successful games while temporarily blocking selected Warcraft III traffic during loading. Because games can also succeed without the intervention, this is a lead to test—not proof of a fix or of a particular server-side behavior.

## Trying the experiment

Use the [standalone player guide](blocking-script-guide.md) with `block-wc3-https.ps1`. Start with a solo/private test, close other WC3 instances, and verify that the temporary rules are removed afterward.

When reporting results, include the WC3/map version, whether you hosted or joined, whether blocking rules were actually created, and whether the usual disconnect occurred. No low-level diagnostic material is needed.
