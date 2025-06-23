import("System.Numerics")

--[[
    MarketBotty! Fuck it, I'm going there. Don't @ me.
    Original Creator: https://github.com/plottingCreeper/FFXIV-scripts-and-macros/tree/main/SND/MarketBotty
    Clover's Fork: https://github.com/Clover-Stuff/FFXIV-scripts-and-macros/tree/main/SND/MarketBotty
]]

my_characters = { --Characters to switch to in multimode
  'Character Name@Server',
  'Character Name@Server',
}
my_retainers = { --Retainers to avoid undercutting
  'Dont-undercut-this-retainer',
  'Or-this-one',
}
blacklist_retainers = { --Do not run script on these retainers
  'Dont-run-this-retainer',
  'Or-this-one',
}
item_overrides = { --Item names with no spaces or symbols
  StuffedAlpha = { maximum = 450 },
  StuffedBomBoko = { minimum = 450 },
  Coke = { minimum = 450, maximum = 5000 },
  RamieTabard = { default = 25000 },
}

undercut = 1 --There's no reason to change this. 1 gil undercut is life.
is_dont_undercut_my_retainers = true --Working!
is_price_sanity_checking = true --Ignores market results below half the trimmed mean of historical prices.
price_sanity_check_depth = 10 --How many top listings (0-13) to scan for sanity check before giving up and accepting a lower price.
is_using_blacklist = true --Whether or not to use the blacklist_retainers list.
history_trim_amount = 5 --Trims this many from highest and lowest in history list
history_multiplier = "round" --if no active sales then get average historical price and multiply
is_using_overrides = true --item_overrides table.
is_check_for_hq = true --Working!
nq_price_drop_multiplier = 0.6

is_override_report = true
is_postrun_one_gil_report = true  --Requires is_verbose
is_postrun_sanity_report = true  --Requires is_verbose

is_verbose = true --Basic info in chat about what's going on.
is_debug = true --Absolutely flood your chat with all sorts of shit you don't need to know.
name_rechecks = 10 --Latency sensitive tunable. Probably sets wrong price if below 5

is_read_from_files = true --Override arrays with lists in files. Missing files are ignored.
is_write_to_files = true --Adds characters and retainers to characters_file and retainers_file
is_echo_during_read = false --Echo each character and retainer name as they're read, to see how you screwed up.
config_folder = os.getenv("appdata").."\\XIVLauncher\\pluginConfigs\\SomethingNeedDoing\\"
marketbotty_settings = "marketbotty_settings.lua" --loaded first
characters_file = "my_characters.txt"
retainers_file = "my_retainers.txt"
blacklist_file = "blacklist_retainers.txt"
overrides_file = "item_overrides.lua"

is_multimode = false --It worked once, which means it's perfect now. Please send any complaints to /dev/null
start_wait = false --For when starting script during AR operation.
after_multi = false  --"logout", "wait 10", "wait logout", number. See readme.
is_autoretainer_while_waiting = false
multimode_ending_command = "/ays multi e"
is_use_ar_to_enter_house = true --Breaks if you have subs ready.
is_autoretainer_compatibility = false --Not implemented. Last on the to-do list.

------------------------------------------------------------------------------------------------------

function Echo(text)
	yield("/echo " .. tostring(text))
end

function echo(text)
	Echo(text)
end

function IsAddonReady(name)
    return Addons.GetAddon(name).Ready
end

function IsAddonVisible(name)
    return Addons.GetAddon(name).Exists
end

function IsNodeVisible(addonName, ...)
  if (IsAddonReady(addonName)) then
    local node = Addons.GetAddon(addonName):GetNode(...)
    return node.IsVisible
  else
    return false
  end
end

function GetNodeText(addonName, ...)
  if (IsAddonReady(addonName)) then
    local node = Addons.GetAddon(addonName):GetNode(...)
    return tostring(node.Text)
  else
    return ""
  end
end

function GetCharacterName()
	return Entity.Player.Name
end

function GetCharacterCondition(i, bool)
	return Svc.Condition[i] == bool
end

function IsInZone(i)
	return Svc.ClientState.TerritoryType == i
end

function GetTargetName()
  if (Entity.Target) then
    return Entity.Target.Name
  else
    return ""
  end
end

function GetDistanceToTarget()
  return Vector3.Distance(Entity.Player.Position, Entity.Target.Position)
end



function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end

function CountRetainers()
  if not IsAddonVisible("RetainerList") then verbose("RetainerList", "CountRetainers()") end
  while string.gsub(GetNodeText("RetainerList", 1, 27, 4, 2, 3),"%d","")=="" do -- 2, i, 13 becomes the 27, i (4, 41001, 41002, ...), 3
    yield("/wait 0.1")
  end
  yield("/wait 0.1")
  total_retainers = 0
  retainers_to_run = {}
  yield("/wait 0.1")
  for i= 1, 10 do
    yield("/wait 0.01")
    include_retainer = true
    nodeId = i == 1 and 4 or (i + 40999)
    retainer_name = GetNodeText("RetainerList", 1, 27, nodeId, 2, 3)
    if retainer_name~="" and retainer_name~=13 then
      if GetNodeText("RetainerList", 1, 27, nodeId, 2, 3)~="None" then
        if is_using_blacklist then
          for _, blacklist_test in pairs(blacklist_retainers) do
            if retainer_name==blacklist_test then
              include_retainer = false
              break
            end
          end
        end
      else
        include_retainer = false
      end
      if include_retainer then
        total_retainers = total_retainers + 1
        retainers_to_run[total_retainers] = i
      end
      if is_write_to_files and type(file_retainers)=="userdata" then
        is_add_to_file = true
        for _, known_retainer in pairs(my_retainers) do
          if retainer_name==known_retainer then
            is_add_to_file = false
            break
          end
        end
        if is_add_to_file then
          file_retainers = io.open(config_folder..retainers_file,"a")
          file_retainers:write("\n"..retainer_name)
          io.close(file_retainers)
        end
      end
    end
  end
  verbose("Retainers to run on this character: " .. total_retainers)
  return total_retainers
end

function OpenRetainer(r)
  r = r - 1
  if not IsAddonVisible("RetainerList") then SomethingBroke("RetainerList", "OpenRetainer("..r..")") end
  yield("/wait 0.3")
  --yield("/click RetainerList Retainers["..r.."].Select")
  SafeCallback("RetainerList", true, 2, r)
  yield("/wait 0.5")
  while IsAddonVisible("SelectString")==false do
    if IsAddonVisible("Talk") and IsAddonReady("Talk") then 
      --yield("/click Talk Click")
      SafeCallback("Talk", true)
    end
    yield("/wait 0.1")
  end
  if not IsAddonVisible("SelectString") then SomethingBroke("SelectString", "OpenRetainer("..r..")") end
  yield("/wait 0.3")
  --yield("/click SelectString Entries[3].Select")
  SafeCallback("SelectString", true, 3)
  if not IsAddonVisible("RetainerSellList") then SomethingBroke("RetainerSellList", "OpenRetainer("..r..")") end
end

function CloseRetainer()
  while not IsAddonVisible("RetainerList") do
    SafeCallback("RetainerSellList", true, -1)
    SafeCallback("SelectString", true, -1)
    if IsAddonVisible("Talk") and IsAddonReady("Talk") then
      --yield("/click Talk Click")
      SafeCallback("Talk", true)
    end
    yield("/wait 0.1")
  end
end

function CountItems()
  while IsAddonReady("RetainerSellList")==false do yield("/wait 0.1") end
  while string.gsub(GetNodeText("RetainerSellList", 1, 14, 19),"%d","")=="" do
    yield("/wait 0.1")
  end
  count_wait_tick = 0
  while GetNodeText("RetainerSellList", 1, 14, 19)==raw_item_count and count_wait_tick < 5 do
    count_wait_tick = count_wait_tick + 1
    yield("/wait 0.1")
  end
  yield("/wait 0.1")
  raw_item_count = GetNodeText("RetainerSellList", 1, 14, 19)
  item_count_trimmed = string.sub(raw_item_count,1,2)
  item_count = string.gsub(item_count_trimmed,"%D","")
  debug_log("Items for sale on this retainer: "..item_count)
  return tonumber(item_count)
end

function ClickItem()
  CloseSales()
  while IsAddonVisible("RetainerSell")==false do
    if IsAddonVisible("ContextMenu") then
      SafeCallback("ContextMenu", true, 0, 0)
      yield("/wait 0.2")
    else
      SomethingBroke("RetainerSellList", "ClickItem()")
    end
    yield("/wait 0.05")
  end
end

function ReadOpenItem()
  last_item = open_item
  open_item = ""
  item_name_checks = 0
  while item_name_checks < name_rechecks and ( open_item == last_item or open_item == "" ) do
    item_name_checks = item_name_checks + 1
    yield("/wait 0.1")
    --open_item = string.sub(string.gsub(GetNodeText("RetainerSell",18),"%W",""),3,-3)
    open_item = string.gsub(GetNodeText("RetainerSell",1,5,7),"%W","")
  end
  debug_log("Last item: "..last_item)
  debug_log("Open item: "..open_item)
end

function SearchResults()
  if IsAddonVisible("ItemSearchResult")==false then
    yield("/wait 0.1")
    if IsAddonVisible("ItemSearchResult")==false then
      SafeCallback("RetainerSell", true, 4)
    end
  end
  yield("/waitaddon ItemSearchResult")
  if IsAddonVisible("ItemHistory")==false then
    yield("/wait 0.1")
    if IsAddonVisible("ItemHistory")==false then
      SafeCallback("ItemSearchResult", true, 0)
    end
  end
  yield("/wait 0.1")
  ready = false
  search_hits = ""
  search_wait_tick = 10
  while ready==false do
    search_hits = GetNodeText("ItemSearchResult", 1, 29)
    
    first_price = string.gsub(GetNodeText("ItemSearchResult", 1, 26, 4, 5),"%D","")
    if search_wait_tick > 20 and string.find(GetNodeText("ItemSearchResult", 1, 5), "No items found.") then
      ready = true
      debug_log("No items found.")
    end
    if (string.find(search_hits, "hit") and first_price~="") and (old_first_price~=first_price or search_wait_tick>20) then
      ready = true
      debug_log("Ready!")
    else
      search_wait_tick = search_wait_tick + 1
      if (search_wait_tick > 50) or (string.find(GetNodeText("ItemSearchResult", 1, 5), "Please wait") and search_wait_tick > 10) then
        SafeCallback("RetainerSell", true, 4)
        yield("/wait 0.1")
        if IsAddonVisible("ItemHistory")==false then
          SafeCallback("ItemSearchResult", true, 0)
        end
        yield("/wait 0.1")
        search_wait_tick = 0
      end
    end
    yield("/wait 0.1")
  end
  old_first_price = first_price
  search_results = string.gsub(GetNodeText("ItemSearchResult", 1, 29),"%D","")
  debug_log("Search results: "..search_results)
  return search_results
end

function SearchPrices()
  yield("/waitaddon ItemSearchResult")
  prices_list = {}
  prices_list_length = 0

  for i = 1, 12 do
    nodeId = i == 1 and 4 or (i + 40999)
    raw_price = GetNodeText("ItemSearchResult", 1, 26, nodeId, 5)

    if raw_price ~= "" and raw_price ~= 10 then
      local is_visible = IsNodeVisible("ItemSearchResult", 1, 26, nodeId, 2, 3)
      local trimmed_price = string.gsub(raw_price, "%D", "")
      local raw_retainer = GetNodeText("ItemSearchResult", 1, 26, nodeId, 10)
      
      echo("is_visible: " .. tostring(is_visible))

      prices_list[i] = {
        price = tonumber(trimmed_price),
        isHQ = is_visible,
        retainer = raw_retainer
      }

      debug_log((is_visible and "" or "") .. trimmed_price)
    end
  end

  debug_log(open_item .. " Prices")

  for _, _ in pairs(prices_list) do
    prices_list_length = prices_list_length + 1
  end
end

function HistoryAverage()
  while not IsAddonVisible("ItemHistory") do
    SafeCallback("ItemSearchResult", true, 0)
    yield("/wait 0.3")
  end
  yield("/waitaddon ItemHistory")

  -- Wait for history table to finish loading
  local first_history = GetNodeText("ItemHistory", 1, 10, 4, 4)
  while string.gsub(first_history, "%d", "") == "" do
    yield("/wait 0.1")
    first_history = GetNodeText("ItemHistory", 1, 10, 4, 4)
  end
  yield("/wait 0.1")

  -- Always determine HQ/NQ status for the current item
  local hq_flag = GetNodeText("RetainerSell", 1, 5, 7)
  hq_flag = string.gsub(hq_flag, "%g", "")
  hq_flag = string.gsub(hq_flag, "%s", "")
  is_hq = (string.len(hq_flag) == 3)

  local raw_hist = {}
  for i = 1, 20 do
    nodeId = i == 1 and 4 or (i + 40999)
    local raw_history_price = GetNodeText("ItemHistory", 1, 10, nodeId, 4)
    local cleaned = string.gsub(raw_history_price, "[^%d,]", "")
    cleaned = string.gsub(cleaned, ",", "")
    local price_number = tonumber(cleaned)

    if price_number then
      local entry_isHQ = IsNodeVisible("ItemHistory", 1, 10, nodeId, 2, 3)
      table.insert(raw_hist, { price = price_number, isHQ = entry_isHQ })
    else
      debug_log("Skipped row "..i.." — cleaned: "..tostring(cleaned).." | raw: "..tostring(raw_history_price))
    end
  end
  debug_log("== Full raw_hist breakdown ==")
  for i, e in ipairs(raw_hist) do
    debug_log("Raw["..i.."] → Price: "..e.price.." | isHQ: "..tostring(e.isHQ))
  end


  local match_list = {}
  local mismatch_list = {}

  if is_check_for_hq then
    for _, e in ipairs(raw_hist) do
      if e.isHQ == is_hq then
        table.insert(match_list, e.price)
      else
        table.insert(mismatch_list, e.price)
      end
    end
  else
    for _, e in ipairs(raw_hist) do
      table.insert(match_list, e.price)
    end
  end

  local hist = match_list
  local apply_multiplier = false
  local multiplier = 1

  if is_check_for_hq then
    if #match_list > 0 then
      hist = match_list
    elseif #mismatch_list > 0 then
      debug_log("No matching HQ/NQ history found — falling back to "..(is_hq and "NQ" or "HQ").." history.")
      debug_log("Fallback history prices: "..table.concat(mismatch_list, ", "))
      hist = mismatch_list
      apply_multiplier = true
      if is_hq then
        multiplier = 1 / nq_price_drop_multiplier
      else
        multiplier = nq_price_drop_multiplier
      end
    else
      debug_log("No usable history entries at all.")
      history_trimmed_mean = 0
      return 0
    end
  end

  if #hist == 0 then
    debug_log("No valid history prices found.")
    history_trimmed_mean = 0
    return 0
  end

  table.sort(hist)
  local count = #hist

  -- Trim extremes if enough entries
  if count > history_trim_amount * 2 then
    for i = 1, history_trim_amount do
      table.remove(hist, count) -- highest
      table.remove(hist, 1)     -- lowest
      count = count - 2
    end
  end

  local total = 0
  for _, p in ipairs(hist) do
    total = total + p
  end

  history_trimmed_mean = total // #hist

  if apply_multiplier then
    debug_log("Adjusted history mean ("..history_trimmed_mean..") using multiplier: "..multiplier..", resulting mean: "..math.floor(history_trimmed_mean * multiplier))
    history_trimmed_mean = math.floor(history_trimmed_mean * multiplier)
  end

  debug_log("History items: "..#hist)
  debug_log("History trimmed mean: "..history_trimmed_mean)
  return history_trimmed_mean
end



function ItemOverride(mode)
  if is_using_overrides then
    itemor = nil
    is_price_overridden = false
    for item_test, _ in pairs(item_overrides) do
      if open_item == string.gsub(item_test,"%W","") then
        itemor = item_overrides[item_test]
        break
      end
    end
    if not itemor then return false end
    if itemor.default and mode == "default" then
      price = tonumber(itemor.default)
      is_price_overridden = true
      debug_log(open_item.." default price: "..itemor.default.." applied!")
    end
    if itemor.minimum then
      if price < itemor.minimum then
        price = tonumber(itemor.minimum)
        is_price_overridden = true
        debug_log(open_item.." minimum price: "..itemor.minimum.." applied!")
      end
    end
    if itemor.maximum then
      if price > itemor.maximum then
        price = tonumber(itemor.maximum)
        is_price_overridden = true
        debug_log(open_item.." maximum price: "..itemor.maximum.." applied!")
      end
    end
  end
end

function SetPrice(price)
  debug_log("Setting price to: "..price)
  CloseSearch()
  SafeCallback("RetainerSell", true, 2, price)
  SafeCallback("RetainerSell", true, 0)
  CloseSales()
end

function CloseSearch()
  while IsAddonVisible("ItemSearchResult") or IsAddonVisible("ItemHistory") do
    yield("/wait 0.1")
    if IsAddonVisible("ItemSearchResult") then SafeCallback("ItemSearchResult", true, -1) end
    if IsAddonVisible("ItemHistory") then SafeCallback("ItemHistory", true, -1) end
  end
end

function CloseSales()
  CloseSearch()
  while IsAddonVisible("RetainerSell") do
    yield("/wait 0.1")
    if IsAddonVisible("RetainerSell") then SafeCallback("RetainerSell", true, -1) end
  end
end

function SomethingBroke(what_should_be_visible, extra_info)
  for broken_rechecks=1, 20 do
    if IsAddonVisible(what_should_be_visible) then
      still_broken = false
      break
    else
      yield("/wait 0.1")
    end
  end
  if still_broken then
    yield("/echo It looks like something has gone wrong.")
    if what_should_be_visible then yield("/echo "..what_should_be_visible.." should be visible, but it isn't.") end
    yield("/echo Attempting to fix this, please wait.")
    if extra_info then yield("/echo "..extra_info) end
    --yield("")
    yield("/echo On second thought, I haven't finished this yet.")
    yield("/echo Oops!")
    yield("/pcraft stop all")
  end
end

function NextCharacter()
  current_character = GetCharacterName(true)
  next_character = nil
  debug_log("Current character: "..current_character)
  for character_number, character_name in pairs(my_characters) do
    if character_name == current_character then
      next_character = my_characters[character_number+1]
      break
    end
  end
  return next_character
end

function Relog(relog_character)
  verbose(relog_character)
  yield("/ays relog " .. relog_character)
  while GetCharacterCondition(1) do
    yield("/wait 1.01")
  end
  while GetCharacterCondition(1, false) do
    yield("/wait 1.02")
  end
  while GetCharacterCondition(45) or GetCharacterCondition(35) do
    yield("/wait 1.03")
  end
  yield("/wait 0.5")
  while GetCharacterCondition(35) do
    yield("/wait 1.04")
  end
  yield("/wait 2")
end

function EnterHouse()
  if IsInZone(339) or IsInZone(340) or IsInZone(341) or IsInZone(641) or IsInZone(979) or IsInZone(136) then
    debug_log("Entering house")
    if is_use_ar_to_enter_house then
      yield("/ays het")
    else
      yield("/target Entrance")
      yield("/target Apartment Building Entrance")
    end
    yield("/wait 1")
    if string.find(string.lower(GetTargetName()), "entrance") then
      while IsInZone(339) or IsInZone(340) or IsInZone(341) or IsInZone(641) or IsInZone(979) or IsInZone(136) do
        if not is_use_ar_to_enter_house then
          yield("/lockon on")
          yield("/automove on")
        end
        yield("/wait 1.2")
      end
      het_tick = 0
      while het_tick < 3 do
        if IsPlayerOccupied() then het_tick = 0
        elseif IsMoving() then het_tick = 0
        else het_tick = het_tick + 0.2
        end
        yield("/wait 0.200")
      end
    else
      debug_log("Not entering house?")
    end
  end
end

function OpenBell()
  EnterHouse()
  target_tick = 1
  while GetCharacterCondition(50, false) do
    if target_tick > 99 then
      break
    elseif string.lower(GetTargetName())~="summoning bell" then
      debug_log("Finding summoning bell...")
      yield("/target Summoning Bell")
      target_tick = target_tick + 1
    elseif GetDistanceToTarget()<20 then
      yield("/lockon on")
      yield("/automove on")
      yield("/pinteract")
    else
      yield("/automove off")
      yield("/pinteract")
    end
    yield("/lockon on")
    yield("/wait 0.511")
  end
  if GetCharacterCondition(50) then
    yield("/lockon off")
    while not IsAddonVisible("RetainerList") do yield("/wait 0.100") end
    yield("/wait 0.4")
    return true
  else
    return false
  end
end

function WaitARFinish(ar_time)
  title_wait = 0
  if not ar_time then ar_time = 10 end
  while IsAddonVisible("_TitleMenu")==false do
    yield("/wait 5.01")
  end
  while true do
    if IsAddonVisible("_TitleMenu") and IsAddonVisible("NowLoading")==false then
      title_wait = title_wait + 1
    else
      title_wait = 0
    end
    if title_wait > ar_time then
      break
    end
    yield("/wait 1.0"..ar_time - title_wait)
  end
end

function verbose(input)
  if is_verbose then
    yield("/echo [MarketBotty] "..tostring(input))
  else
    yield("/wait 0.01")
  end
end

function debug_log(debug_input)
  if is_debug then
    yield("/echo [MarketBotty][DEBUG] "..debug_input)
  else
    yield("/wait 0.01")
  end
end

function SafeCallback(...)  -- Could be safer, but this is a good start, right?
  local callback_table = table.pack(...)
  local addon = nil
  local update = nil
  if type(callback_table[1])=="string" then
    addon = callback_table[1]
    table.remove(callback_table, 1)
  end
  if type(callback_table[1])=="boolean" then
    update = tostring(callback_table[1])
    table.remove(callback_table, 1)
  elseif type(callback_table[1])=="string" then
    if string.find(callback_table[1], "t") then
      update = "true"
    elseif string.find(callback_table[1], "f") then
      update = "false"
    end
    table.remove(callback_table, 1)
  end

  local call_command = "/pcall " .. addon .. " " .. update
  for _, value in pairs(callback_table) do
    if type(value)=="number" then
      call_command = call_command .. " " .. tostring(value)
    end
  end
  if IsAddonReady(addon) and IsAddonVisible(addon) then
    yield(call_command)
  end
end

function Clear()
  next_retainer = 0
  prices_list = {}
  item_list = {}
  item_count = 0
  last_item = ""
  open_item = ""
  is_single_retainer_mode = false
  target_sale_slot = 1
end

------------------------------------------------------------------------------------------------------

-- Tried to do this as functions, but it was too hard. Oh well.
::Start::
if is_read_from_files then
  if file_exists(config_folder..marketbotty_settings) then
    chunk = loadfile(config_folder..marketbotty_settings)
    chunk()
  end
  file_characters = config_folder..characters_file
  if file_exists(file_characters) and is_multimode then
    my_characters = {}
    file_characters = io.input(file_characters)
    next_line = file_characters:read("l")
    i = 0
    while next_line do
      i = i + 1
      my_characters[i] = next_line
      if is_echo_during_read then debug_log("Character "..i.." from file: "..next_line) end
      next_line = file_characters:read("l")
    end
    file_characters:close()
    verbose("Characters loaded from file: "..i)
    if i <= 1 then
      is_multimode = false
    end
  else
    verbose(file_characters.." not found!")
  end
  file_retainers = config_folder..retainers_file
  if file_exists(file_retainers) and is_dont_undercut_my_retainers then
    my_retainers = {}
    file_retainers = io.input(file_retainers)
    next_line = file_retainers:read("l")
    i = 0
    while next_line do
      i = i + 1
      my_retainers[i] = next_line
      if is_echo_during_read then debug_log("Retainer "..i.." from file: "..next_line) end
      next_line = file_retainers:read("l")
    end
    file_retainers:close()
    verbose("Retainers loaded from file: "..i)
  else
    verbose(file_retainers.." not found!")
  end
  file_blacklist = config_folder..blacklist_file
  if file_exists(file_blacklist) and is_using_blacklist then
    blacklist_retainers = {}
    file_blacklist = io.input(file_blacklist)
    next_line = file_blacklist:read("l")
    i = 0
    while next_line do
      i = i + 1
      blacklist_retainers[i] = next_line
      if is_echo_during_read then debug_log("Blacklist "..i.." from file: "..next_line) end
      next_line = file_blacklist:read("l")
    end
    file_blacklist:close()
    verbose("Blacklist loaded from file: "..i)
  else
    verbose(file_blacklist.." not found!")
  end
  file_overrides = config_folder..overrides_file
  if file_exists(file_overrides) and is_using_overrides then
    chunk = nil
    item_overrides = {}
    chunk = loadfile(file_overrides)
    chunk()
    or_count = 0
    for _, i in pairs(item_overrides) do or_count = or_count + 1 end
    verbose("Overrides loaded from file: "..or_count)
  else
    verbose(file_overrides.." not found!")
  end
end
uc=1
if is_override_report then
  override_items_count = 0
  override_report = {}
end
if is_postrun_one_gil_report then
  one_gil_items_count = 0
  one_gil_report = {}
end
if is_postrun_sanity_report then
  sanity_items_count = 0
  sanity_report = {}
end

if IsAddonVisible("RetainerList") then is_multimode = false end

::MultiWait::
if start_wait and is_autoretainer_while_waiting then
    WaitARFinish()
    yield("/ays multi d")
end
after_multi = tostring(after_multi)
if string.find(after_multi, "wait logout") then
elseif string.find(after_multi, "wait") then
  multi_wait = string.gsub(after_multi,"%D","") * 60
  wait_until = os.time() + multi_wait
end

if is_write_to_files then
  is_add_to_file = true
  current_character = GetCharacterName(true)
  for _, character_name in pairs(my_characters) do
    if character_name == current_character then
      is_add_to_file = false
      break
    end
  end
  if is_add_to_file and current_character~="null" then
    file_characters = io.open(config_folder..characters_file,"a")
    file_characters:write("\n"..tostring(current_character))
    io.close(file_characters)
  end
end

::Startup::
Clear()
if GetCharacterCondition(1, false) then
  verbose("Not logged in?")
  yield("/wait 1")
  Relog(my_characters[1])
  goto Startup
elseif GetCharacterCondition(50, false) then
  verbose("Not at a summoning bell.")
  OpenBell()
  yield("/wait 0.3")
  goto Startup
elseif IsAddonVisible("RecommendList") then
  helper_mode = true
  while IsAddonVisible("RecommendList") do
    SafeCallback("RecommendList", true, -1)
    yield("/wait 0.1")
  end
  verbose("Starting in helper mode!")
  goto Helper
elseif IsAddonVisible("RetainerList") then
  CountRetainers()
  goto NextRetainer
elseif IsAddonVisible("RetainerSell") then
  verbose("Starting in single item mode!")
  is_single_item_mode = true
  goto RepeatItem
elseif IsAddonVisible("SelectString") then
  verbose("Starting in single retainer mode!")
  --yield("/click SelectString Entries[2].Select")
  SafeCallback("SelectString", true, 2)
  yield("/waitaddon RetainerSellList")
  is_single_retainer_mode = true
  goto Sales
elseif IsAddonVisible("RetainerSellList") then
  verbose("Starting in single retainer mode!")
  is_single_retainer_mode = true
  goto Sales
else
  verbose("Unexpected starting conditions!")
  verbose("You broke it. It's your fault.")
  verbose("Do not message me asking for help.")
  yield("/pcraft stop all")
end

------------------------------------------------------------------------------------------------------

::NextRetainer::
if next_retainer < total_retainers then
  next_retainer = next_retainer + 1
else
  goto MultiMode
end
yield("/wait 0.1")
target_sale_slot = 1
OpenRetainer(retainers_to_run[next_retainer])

::Sales::
if CountItems() == 0 then goto Loop end

::NextItem::
if IsAddonVisible("RetainerSellList") then
  SafeCallback("RetainerSellList", true, 0, target_sale_slot - 1, 1)
end
ClickItem()

::Helper::
uc = undercut
while IsAddonVisible("RetainerSell")==false do
  yield("/wait 0.5")
  if GetCharacterCondition(50, false) or IsAddonVisible("RecommendList") then
    goto EndOfScript
  end
end

::RepeatItem::
ReadOpenItem()
if last_item~="" then
  if open_item == last_item then
    debug_log("Repeat: "..open_item.." set to "..price)
    goto Apply
  end
end

::ReadPrices::
SearchResults()
current_price = string.gsub(GetNodeText("RetainerSell",1,17),"%D","")
if (string.find(GetNodeText("ItemSearchResult", 1, 5), "No items found.")) then
  if type(history_multiplier)=="number" then
    price = HistoryAverage() * history_multiplier
    price_length = string.len(tostring(price))
    if price_length >= 5 then
      exp = 10 ^ math.ceil(price_length * 0.6)
      price = math.tointeger(math.floor(price // exp) * exp)
    end
  else
    price_length = string.len(tostring(HistoryAverage()))
    price = math.tointeger(10 ^ price_length)
  end
  CloseSearch()
  ItemOverride("default")
  goto Apply
end

if is_check_for_hq then
  local hq = GetNodeText("RetainerSell",1,5,7)
  item_is_hq = hq:find("") ~= nil
  if item_is_hq then
    debug_log("High quality!")
  else
    debug_log("Normal quality.")
  end
end

target_price = 1
if is_blind then
  nodeId = i == 1 and 4 or (i + 40999)
  raw_price = GetNodeText("ItemSearchResult", 1, 26, nodeId, 5)
  if raw_price~="" and raw_price~=10 then
    trimmed_price = string.gsub(raw_price,"%D","")
    price = trimmed_price - uc
    goto Apply
  else
    verbose("Price not found")
    yield("/pcraft stop all")
  end
else
  SearchPrices()
  HistoryAverage()
  CloseSearch()
end
echo("Is HQ? " .. tostring(item_is_hq))

sanity_checks = 0
max_sanity_checks = price_sanity_check_depth * 2
::PricingLogic::
if is_price_sanity_checking and target_price < price_sanity_check_depth and target_price < prices_list_length and sanity_checks < max_sanity_checks then
  sanity_checks = sanity_checks + 1
  if prices_list[target_price].price == 1 then
    debug_log("prices_list[target_price].price == 1")
    target_price = target_price + 1
    goto PricingLogic
  end
  verbose(prices_list[target_price].price)
  verbose(history_trimmed_mean)
  if prices_list[target_price].price <= (history_trimmed_mean // 2) then
    if is_check_for_hq then
      if (item_is_hq and not prices_list[target_price].isHQ) or (not item_is_hq and prices_list[target_price].isHQ) then
        target_price = target_price + 1
        goto PricingLogic
      end
    end
    debug_log("prices_list[target_price].price <= (history_trimmed_mean // 2)")
    target_price = target_price + 1
    if target_price >= price_sanity_check_depth or target_price >= prices_list_length then
      target_price = 1
    else
      goto PricingLogic
    end
  end
  debug_log("Price sanity checking results:")
  debug_log("target_price " .. target_price)
  debug_log("prices_list[target_price].price " .. prices_list[target_price].price)
end

if is_check_for_hq and item_is_hq and target_price < prices_list_length then
  debug_log("Checking listing " .. target_price .. " for HQ...")
  if not prices_list[target_price].isHQ then
    debug_log(target_price .. " not HQ")
    target_price = target_price + 1
    goto PricingLogic
  end
end

if is_dont_undercut_my_retainers then
  for _, retainer_test in pairs(my_retainers) do
    if retainer_test == prices_list[target_price].retainer then
  if prices_list[target_price].isHQ == item_is_hq then
  uc = 0
  debug_log("Matching price with own retainer: " .. retainer_test)
  break
  end
    end
  end
end

if is_check_for_hq and not item_is_hq and prices_list[target_price].isHQ then
  price = math.floor(prices_list[target_price].price * nq_price_drop_multiplier + 0.5)
  echo("isNQ" .. price)
else
  price = prices_list[target_price].price - uc
  echo("isHQ" .. price)
end
ItemOverride()


if is_override_report and is_price_overridden then
  override_items_count = override_items_count + 1
  local lowest_price = nil

  -- Loop through prices_list to find the lowest price based on isHQ status
  for i, item in pairs(prices_list) do
    if item.isHQ then
      -- If HQ is available, set the lowest HQ price
      if not lowest_price or item.price < lowest_price then
        lowest_price = item.price
      end
    elseif not item.isHQ then
      -- If no HQ is set, find the lowest NQ price
      if not lowest_price or item.price < lowest_price then
        lowest_price = item.price
      end
    end
  end

  -- Report based on whether HQ price was found or not
  if is_multimode then
    override_report[override_items_count] = open_item.." on "..GetCharacterName().." set: "..price..". Low: "..lowest_price
  else
    override_report[override_items_count] = open_item.." set: "..price..". Low: "..lowest_price
  end
elseif price <= 1 then
  verbose("Should probably vendor this crap instead of setting it to 1. Since this script isn't *that* good yet, I'm just going to set it to...69. That's a nice number. You can deal with it yourself.")
  price = 69
  if is_postrun_one_gil_report then
    one_gil_items_count = one_gil_items_count + 1
    if is_multimode then
      one_gil_report[one_gil_items_count] = open_item.." on "..GetCharacterName()
    else
      one_gil_report[one_gil_items_count] = open_item
    end
  end
elseif is_postrun_sanity_report and target_price ~= 1 then
  sanity_items_count = sanity_items_count + 1
  if is_multimode then
    sanity_report[sanity_items_count] = open_item.." on "..GetCharacterName().." set: "..price..". Low: "..prices_list[1].price
  else
    sanity_report[sanity_items_count] = open_item.." set: "..price..". Low: "..prices_list[1].price
  end
end


::Apply::
if price ~= tonumber(string.gsub(GetNodeText("RetainerSell",1,17,19),"%D","")) then
  SetPrice(price)
end
CloseSales()

::Loop::
if helper_mode then
  yield("/wait 1")
  goto Helper
elseif is_single_item_mode then
  yield("/pcraft stop all")
elseif not (tonumber(item_count) <= target_sale_slot) then
  target_sale_slot = target_sale_slot + 1
  goto NextItem
elseif is_single_retainer_mode then
  goto EndOfScript
elseif is_single_retainer_mode==false then
  CloseRetainer()
  goto NextRetainer
end

::MultiMode::
if is_multimode then
  while IsAddonVisible("RetainerList") do
    SafeCallback("RetainerList", true, -1)
    yield("/wait 1")
  end
  NextCharacter()
  if not next_character then goto AfterMulti end
  Relog(next_character)
  if OpenBell()==false then goto MultiMode end
  goto Startup
else
  goto EndOfScript
end

::AfterMulti::
yield("/wait 3")
if string.find(after_multi, "logout") then
  yield("/logout")
  yield("/waitaddon SelectYesno")
  yield("/wait 0.5")
  SafeCallback("SelectYesno", true, 0)
  while GetCharacterCondition(1) do
    yield("/wait 1.1")
  end
elseif wait_until then
  if is_autoretainer_while_waiting then
    yield("/ays multi e")
    while GetCharacterCondition(1, false) do
      yield("/wait 10.1")
    end
  end
  while os.time() < wait_until do
    yield("/wait 12")
  end
  if is_autoretainer_while_waiting then
    WaitARFinish()
    yield("/ays multi d")
  end
  goto MultiWait
elseif type(after_multi) == "number" then
  Relog(my_characters[after_multi])
end

if string.find(after_multi, "wait logout") then
  if is_autoretainer_while_waiting then
    yield("/ays multi e")
    while GetCharacterCondition(1, false) do
      yield("/wait 10.2")
    end
  end
  WaitARFinish()
  if is_autoretainer_while_waiting then yield("/ays multi d") end
  goto MultiWait
end

if GetCharacterCondition(50, false) and multimode_ending_command then
  yield("/wait 3")
  yield(multimode_ending_command)
end

::EndOfScript::
while IsAddonVisible("RecommendList") do
  SafeCallback("RecommendList", true, -1)
  yield("/wait 0.1")
end
verbose("---------------------")
verbose("MarketBotty finished!")
verbose("---------------------")
if is_override_report and override_items_count ~= 0 then
  verbose("Items that triggered override: "..override_items_count)
  for i = 1, override_items_count do
    verbose(override_report[i])
  end
  verbose("---------------------")
end
if is_postrun_one_gil_report and one_gil_items_count ~= 0 then
  verbose("Items that triggered 1 gil check: "..one_gil_items_count)
  for i = 1, one_gil_items_count do
    verbose(one_gil_report[i])
  end
  verbose("---------------------")
end
if is_postrun_sanity_report and sanity_items_count ~= 0 then
  verbose("Items that triggered sanity check: "..sanity_items_count)
  for i = 1, sanity_items_count do
    verbose(sanity_report[i])
  end
  verbose("---------------------")
end
yield("/pcraft stop all")
yield("/pcraft stop all")
yield("/pcraft stop all")
