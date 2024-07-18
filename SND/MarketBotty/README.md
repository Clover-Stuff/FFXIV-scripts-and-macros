https://github.com/plottingCreeper/FFXIV-scripts-and-macros/blob/main/SND/MarketBotty/MarketBotty.lua  
# WORKING!  
<br>  

I tried to write some documentation at some point, but it was never finished. Here it is I guess, maybe it'll help someone.  
PRs welcome.  
<br>  

Look, this is dodgy as hell. A lot of FFXIV plugin communities will have opinions on shit like this. I don't agree with those opinions, but regardless, I want to respect them, and especially respect the rules in those communities. DO NOT discuss this in places that ban discussion of market automation. Check the damn rules before saying anything.  

<br>  

Known bug: Items with no sale history cause MarketBotty to stop. Should be fixed Soon™️.  

<br>  

# MarketBotty!
Automatic sale undercutting script. Requires `Something Need Doing (Expanded Edition)`. Multimode currently requires `AutoRetainer`.
Requires Pandora for /pcall, but that's being moved to SND at some point(?) so good luck I guess.
<br>  

## Starting conditions
If script is started while not at a summoning bell, it will try to find a summoning bell and interact with it. Don't expect too much of this. It's only intended for multimode, for characters that are logged out near a summoning bell or house.  
If started while on the retainer list, MarketBotty will run in normal mode. Retainers that have items for sale and aren't on the blacklist will be opened. All items on opened retainers will be repriced according to configured pricing logic.  
If started while a retainer is open, MarketBotty will run in single retainer mode. All items on that retainer will be repriced, then the script will stop.  
If started while an item price window is open, MarketBotty will run in single item mode. That item will be repriced, then the script will stop.  
If started while at a summoning bell, and the `Recommendations` window is open, MarketBotty will start in helper mode. It will wait for an item sale window to appear, then it will reprice the item and go back to waiting. Helper mode will end when the summoning bell is closed.  

## Repricing logic
MarketBotty will read the first 10 prices from search, and up to 20 prices from history.  
A trimmed mean is taken from history prices by culling the highest and lowest `5` (configurable) then averaging what's left.  
The lowest search result is found which:
- is higher than 1 gil
- is higher than half the trimmed mean from history

If none of the first 9 search results qualify, then the 10th search result is chosen.  
If the 10th search result is lower than the item `minimum` set in `item_overrides` then item minimum is used instead.  
Unless `minimum` is used, the target listings retainer name will be checked. If it's on the `my_retainers` list, the price will be matched rather than undercut.  
If after all this the price is somehow only 1, it will be set to 69 instead. That's an old bit of code, but it seemed nice enough, so it's staying in.  

If there are no search results, the price is set to history trimmed mean multiplied by `10` (configurable).

<br>

## Arrays

### `'`
If your characters or retainers have a `'` in their name, it needs to be escaped with `\`.  
For example, `R'etainer` would be entered into the array as `R\'etainer`.  
This does not apply to the files, only the arrays in the script.  


### `my_characters`  
Used for multimode. First in the list should be main character, which will be switched back to before running `multimode_ending_command`  
Will probably cause an infinite wait loop if your character isn't known to AutoRetainer. Rework planned eventually to remove dependency, but it's still going to require you to spell your own characters name correctly.  
```
my_characters = { --Characters to switch to in multimode
  'Character Name@Server',
  'Character Name@Server',
}
```

<br>
<br>

### `my_retainers`  
Exact string match. Price sanity checking takes priority, but if the target price is of a retainer on this list, it will be matched rather than undercut.
```
my_retainers = { --Retainers to avoid undercutting
  'Dont-undercut-this-retainer',
  'Or-this-one',
}
```

<br>
<br>

### `blacklist_retainers`  
Exact string match. Retainers on this list will be skipped when opening the next retainer. MarketBotty will still run in single retainer mode if started when a blacklisted retainer is already open.
```
blacklist_retainers = { --Do not run script on these retainers
  'Dont-run-this-retainer',
  'Or-this-one',
}
```

<br>


`my_characters`, `my_retainers`, and `blacklist_retainers` arrays are **replaced** be the contents of `file_characters`, `file_retainers`, and `file_blacklist`, if found.  
Files should be one entry per line, with no additional quotes, escape characters, or formatting of any kind.  
Default file location is `%appdata%\XIVLauncher\pluginConfigs\SomethingNeedDoing\` 
Default file names are:  
`characters_file` = "my_characters.txt"  
`retainers_file` = "my_retainers.txt"  
`blacklist_file` = "blacklist_retainers.txt"  

<br>


### `item_overrides`  
Item names have all non-word characters stripped out of them. Currently only supports `minimum` and `maximum` for setting prices. Hope to add some kind of `autolist` if I can figure out how to click on specific items from inventory.  


<br>

## Script Options  

### `is_blind`  
Undercut the lowest price with no additional logic. Overrides most other options.  

### `is_dont_undercut_my_retainers`  

  
### `is_price_sanity_checking`  
Ignores market results below half the trimmed mean of historical prices.  

### `is_using_blacklist`  
Whether or not to use the blacklist_retainers list.  

### `undercut`  
There's no reason to change this. 1 gil undercut is life.  

### `history_multiplier`  
if no active sales then get average historical price and multiply  

### `is_using_overrides`  
item_overrides table. Currently just minimum price, but expansion are coming soon:tm:!  

### `is_postrun_one_gil_report`  
Requires is_verbose  

### `is_postrun_sanity_report`  
Requires is_verbose  

### `history_trim_amount`  
Trims this many from highest and lowest in history list  

### `is_verbose`  
Basic info in chat about what's going on.  

### `is_debug`  
Absolutely flood your chat with all sorts of shit you don't need to know.  

### `name_rechecks`  
Latency sensitive tunable. Probably sets wrong price if below 5  


### `after_multi`  
Intent of this is to stop and wait for AutoRetainer to run. It mostly works, but this isn't the super graceful end result I had in mind.  
`"logout"` to logout  
`"wait 10"` to wait `10` minutes (configurable)  
`1` to relog to first character in `my_characters` list.  
`wait logout` logs out and waits for a character to be logged in, then waits to be sitting back at the title screen for a while. Crappy AutoRetainer compatibility attempt.  
