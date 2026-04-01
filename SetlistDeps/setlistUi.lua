local setlistUi = {}

local reaper, rtk, fileStorage, midiProgramming, setlistController = {}, {}, {}, {}, {}
local dragging, initialIndex = nil, nil
local activeFileName = ''
local window, container, fullContainer, topContainer = {}, {}, {}, {}

function setlistUi.init(r, rtkIn, fs, mp, controller)
  reaper = r
  rtk = rtkIn
  fileStorage = fs
  midiProgramming = mp
  setlistController = controller

  window = rtk.Window{}

  window.onclose = function()
    setlistController.currentRegion = nil
  end

  window.onkeypresspost = function(self, event)
    if (not event.handled and event.keycode == rtk.keycodes.SPACE) then
      reaper.OnPauseButtonEx(0)
    end
    if (not event.handled and event.keycode == rtk.keycodes.UP) then
      PlayNextSong(false)
    end
    if (not event.handled and event.keycode == rtk.keycodes.DOWN) then
      PlayNextSong(true)
    end
  end

  fullContainer = rtk.VBox{bg='grey', padding=10}
  window:add(fullContainer)
  container = rtk.VBox{bg='grey'}
  topContainer = rtk.VBox{bg='grey'}
  fullContainer:add(topContainer)
  fullContainer:add(rtk.Viewport{container, smoothscroll=true, scrollbar_size=5, vscrollbar=rtk.Viewport.SCROLLBAR_HOVER})

  local lastLoadedSet = fileStorage.readLastLoadedSet()
  if (lastLoadedSet ~= nil) then
    LoadFromFileAndRefresh(lastLoadedSet)
  else
    LoadRegionsFromProject()
    setlistUi.buildUI()
  end
  
end

function setlistUi.buildUI()
  BuildTopUI()
  BuildSetListArea()
  window:open{align='center'}
end

function setlistUi.updateProjectRegions()
  local regionsToCreate = {}
  local curProjRegs = {}
  local mrk_cnt = reaper.CountProjectMarkers(0)
  for i=0, mrk_cnt-1 do
    local _, isrgn, pos, rgnend, name, index, color = reaper.EnumProjectMarkers3( -1, i )
    if isrgn then
      curProjRegs[index] = {Start = pos, End = rgnend, 
        Name = name, Color = color, Index = index}
    end
  end
  
  for _, reg in ipairs(curProjRegs) do
    reaper.DeleteProjectMarker(0, _, true)
  end
  
  for _, reg in ipairs(setlistController.regions) do
    for _, curProjReg in ipairs(curProjRegs) do
      if (reg.Name == curProjReg.Name) then
        curProjReg.Match = true
      end
    end
    table.insert(regionsToCreate, reg)
  end
  
  for _, curProjReg in ipairs(curProjRegs) do
    if (curProjReg.Match == nil or curProjReg.Match ~= true) then
      table.insert(regionsToCreate, curProjReg)
    end
  end
  
  setlistController.regions = regionsToCreate
  for index, reg in ipairs(setlistController.regions) do
    reaper.AddProjectMarker2(0, true, reg.Start, reg.End, reg.Name, index, reg.Color)
  end
end

function setlistUi.refreshUiFromReaperChanges()
  local curProjRegs = {}
  local mrk_cnt = reaper.CountProjectMarkers(0)
  for i=0, mrk_cnt-1 do
    local _, isrgn, pos, rgnend, name, index, color = reaper.EnumProjectMarkers3( -1, i )
    if isrgn then
      curProjRegs[index] = {Start = pos, End = rgnend, Name = name, Color = color, Index = index}
    end
  end
  CompareTableFields(setlistController.regions, curProjRegs, {"Start", "End", "Name", "Color", "Index"})
end

function setlistUi.reloadData()
  container:remove_all()
  topContainer:remove_all()
  LoadRegionsFromProject()
  setlistUi.buildUI()
end

function PlaySong(region) 
  setlistController.currentRegion = region
  
  for k,v in pairs(setlistController.regions) do setlistController.regions[k].Playing = false end
  
  region.Played = true
  region.Playing = true
  
  setlistUi.reloadData()

  reaper.SetEditCurPos(region.Start + region.Jump, true, true)
  reaper.OnPlayButton()
  reaper.defer(RunSongPlayLoop)
end

function errorPopup(message)
  local box = rtk.VBox{spacing=20}
  local popup = rtk.Popup{child=box,
    overlay='#000000cc', autoclose=true}
  local text = box:add(rtk.Text{message, wrap=rtk.Text.WRAP_NORMAL})
  local button = box:add(rtk.Button{'Close'}, {halign='right'})
  button.onclick = function(b, event)
      popup:close()
  end
  popup:open()
end

function confirmationPopup(message, fileName)
  local box = rtk.VBox{spacing=20}
  local hbox = rtk.HBox{spacing=20}
  local popup = rtk.Popup{child=box,
    overlay='#000000cc', autoclose=true}
    
  local choice = nil

  box:add(rtk.Text{message, wrap=rtk.Text.WRAP_NORMAL})
  box:add(hbox)
  hbox:add(rtk.Box.FLEXSPACE)
  
  local okButton = hbox:add(rtk.Button{'OK'}, {halign='right'})
  okButton.onclick = function(b, event)
    choice = true
    popup:close()
  end
  local cancelButton = hbox:add(rtk.Button{'Cancel'}, {halign='right'})
  cancelButton.onclick = function(b, event)
    choice = false
    popup:close()
  end
  
  popup.onclose = function(self, event)
    if (choice == true) then 
      LoadFromFileAndRefresh(fileName)
    end
  end
  
  popup:open()
end

function helpPopUp()
  local box = rtk.VBox{spacing=20}
  local hbox = rtk.HBox{spacing=20}
  local popup = rtk.Popup{child=box,
    overlay='#000000cc', autoclose=true}
    
  box:add(rtk.Text{'HELP', wrap=rtk.Text.WRAP_NORMAL})
  box:add(rtk.Text{"LIVE LYRICS - http://rc.reaper.fm/lyrics", wrap=rtk.Text.WRAP_NORMAL})
  box:add(rtk.Text{'PATH - Saved setlists are stored in ' .. fileStorage.getDirectory(), wrap=rtk.Text.WRAP_NORMAL})
  box:add(rtk.Text{'INDEX - (Region index) Type a number in the index column on a row and press enter to change that row to the input given.', wrap=rtk.Text.WRAP_NORMAL})
  box:add(rtk.Text{'PLAYED - Will show X if song has already played this session, P if song is currently playing, or O if not yet played this session.', wrap=rtk.Text.WRAP_NORMAL})
  box:add(rtk.Text{'NAME - (Region name) Will grey out if song has already played this session.', wrap=rtk.Text.WRAP_NORMAL})
  box:add(rtk.Text{'COLOR - (Region color) Click to change color of row and region in DAW.', wrap=rtk.Text.WRAP_NORMAL})
  box:add(rtk.Text{'STOP - If checked, will pause after region is finished playing. If not, will automatically start playing the next region after current is over.', wrap=rtk.Text.WRAP_NORMAL})
  box:add(rtk.Text{'KEY PRESSES - Press SPACE BAR to pause/unpause playback. Press DOWN to move to next region and start playing it. Press UP to move to previous region and start playing it.', wrap=rtk.Text.WRAP_NORMAL})
  
  
  box:add(hbox)
  
  
  hbox:add(rtk.Box.FLEXSPACE)
  
  local okButton = hbox:add(rtk.Button{'OK'}, {halign='right'})
  okButton.onclick = function(b, event)
    popup:close()
  end
  
  popup:open()
end

function LoadFromFileAndRefresh(fileName)
    fileStorage.loadRegionsFromFileCommand(fileName) 
    activeFileName = fileName:gsub('.csv', '')
    setlistUi.updateProjectRegions()
    setlistUi.reloadData()
  end

function LoadRegionsFromFile(fileName)
  confirmationPopup('Are you sure you want to load the setlist?\n'
      ..fileName..
      '\n\nThis will overwrite any changes you have made to regions in your DAW!', fileName)
end

function LoadSongPopup()
  local box = rtk.VBox{spacing=20, w=150}
  local popup = rtk.Popup{child=box, padding=30, 
    overlay='#000000cc', autoclose=true}
    
  box:add(rtk.Text{'Choose a setlist to load!', wrap=rtk.Text.WRAP_NORMAL})
    
  local fileList = {}
  
  if (GetOs() == "win") then
      for i = 0, math.huge do
      local file = reaper.EnumerateFiles(fileStorage.getDirectory(), i)
      if not file then break end
      fileList[#fileList + 1] = file
    end
  else
    local f = io.popen('ls ' .. fileStorage.getDirectory())
    for name in f:lines() do
    if (name:sub(-#'.csv') == '.csv') then
      fileList[#fileList+1]= name
    end
    end
  end   
   
  local fileListDropDown = box:add(rtk.OptionMenu{
      menu=fileList
  })
  
  local hBox = box:add(rtk.HBox{})
  
  local loadButton = hBox:add(rtk.Button{'Load'}, {halign='right'})
  loadButton.onclick = function(b, event)
      if (fileListDropDown.selected_item == nil) then
        popup:close()
        errorPopup('Please select a setlist to load!')
      else
        popup:close()
        LoadRegionsFromFile(fileListDropDown.selected_item.label)
      end
  end
  
  hBox:add(rtk.Box.FLEXSPACE)
  
  local deleteButton = hBox:add(rtk.Button{'Delete'}, {halign='right'})
  deleteButton.onclick = function(b, event)
    if (fileListDropDown.selected_item == nil) then
      errorPopup('Please select a setlist to delete!')
    else
      popup:close()
      DeleteFile(fileListDropDown.selected_item)
    end
    popup:close()
  end
  
  
  local cancelButton = box:add(rtk.Button{'Cancel'}, {halign='right'})
  cancelButton.onclick = function(b, event)
    popup:close()
  end 
  popup:open()
end

function RunSongPlayLoop()
  if (setlistController.currentRegion == nil) then 
  elseif (setlistController.currentRegion ~= nil and reaper.GetPlayPosition() >= setlistController.currentRegion.End 
      and reaper.GetPlayPosition() <= setlistController.currentRegion.End + 10) then
     if (setlistController.currentRegion.StopAfter == 'true' or setlistController.currentRegion.Index >= #setlistController.regions) then
       reaper.OnStopButton()
       midiProgramming.sendLightSignal(4)
     else
       local nextRegion = setlistController.regions[setlistController.currentRegion.Index + 1]
       PlaySong(nextRegion)
     end
  else
    reaper.defer(RunSongPlayLoop)
  end
end

function PlayNextSong(nextSong)
  if (setlistController.currentRegion.Name ~= nil) then
    if (nextSong == true) then
      if (setlistController.currentRegion.Index < #setlistController.regions) then
        local nextRegion = setlistController.regions[setlistController.currentRegion.Index + 1]
        PlaySong(nextRegion)
      else
        PlaySong(setlistController.currentRegion)
      end
    else
      if (setlistController.currentRegion.Index > 1) then
        local nextRegion = setlistController.regions[setlistController.currentRegion.Index - 1]
        PlaySong(nextRegion)
      else
        PlaySong(setlistController.currentRegion)
      end
    end
  end
end

function BuildTopUI()
  local topContainerRowA = rtk.HBox{bg='grey'}
  topContainer:add(topContainerRowA)
  
  local helpButton = rtk.Button{'?', color='gold', textcolor='black', valign='center', halign='center',
    fontsize=18, h=25, w=25}
  helpButton.onclick = function(self, event)
    helpPopUp()
  end
  
  topContainerRowA:add(helpButton)
  
  topContainerRowA:add(rtk.Box.FLEXSPACE)

  local setListNameEntry = topContainerRowA:add(rtk.Entry{
    activeFileName, placeholder='Setlist Name', 
    textwidth=15, fontsize=18,
    w=200, h=25, valign='center', halign='center'})
  
  local saveButton = rtk.Button{'Save Setlist', color='gold', textcolor='black', valign='center', halign='center',
    fontsize=18, h=25, w=100}
  saveButton.onclick = function(self, event)
    fileStorage.saveSetlist(setListNameEntry)
  end
  topContainerRowA:add(saveButton)
  
  topContainerRowA:add(rtk.Box.FLEXSPACE)
  
  local loadButton = rtk.Button{'Setlists', valign='center', halign='center', color='gold', textcolor='black', 
    fontsize=18, h=25, w=100}
  loadButton.onclick = function(self, event)
    LoadSongPopup()
    setlistUi.reloadData()
  end
  topContainerRowA:add(loadButton)
  
  local topContainerRowA2 = rtk.HBox{bg='grey', tpadding=10, bpadding=10}
  topContainer:add(topContainerRowA2)
  
  local whiteLightsButton = rtk.Button{'Lights On', color='gold', 
    textcolor='black', valign='center', halign='center',
    fontsize=18, h=25, w=100}
  whiteLightsButton.onclick = function(self, event)
    midiProgramming.sendLightSignal(4)
  end
  topContainerRowA2:add(whiteLightsButton)
  
  local lightsOffButton = rtk.Button{'Lights Off', color='gold', 
    textcolor='black', valign='center', halign='center',
    fontsize=18, h=25, w=100}
  lightsOffButton.onclick = function(self, event)
    midiProgramming.sendLightSignal(5)
  end
  topContainerRowA2:add(lightsOffButton)
  
  topContainerRowA2:add(rtk.Text{'http://192.160.*.*:8081'}, {valign='center', fontsize=18, lpadding=10})
  
  topContainerRowA2:add(rtk.Box.FLEXSPACE)
  
  local refreshSessionButton = rtk.Button{'Refresh', color='gold', 
    textcolor='black', valign='center', halign='center',
    fontsize=18, h=25, w=100}
  refreshSessionButton.onclick = function(self, event)
    for k,v in pairs(setlistController.regions) do
      setlistController.regions[k].Played = false
    end
    setlistUi.reloadData()
  end
  topContainerRowA2:add(refreshSessionButton)
  
  
  local topContainerRowB = rtk.HBox{bg='grey'}
  topContainer:add(topContainerRowB)
  
  topContainerRowB:add(rtk.Text{text='Index', halign='center', valign='center', 
    color='black', fontsize=14, h=25, w=40, fontflags=rtk.font.BOLD})
    
  topContainerRowB:add(rtk.Text{text='Played', halign='center', valign='center', 
    color='black', fontsize=14, h=25, w=40, fontflags=rtk.font.BOLD})

  topContainerRowB:add(rtk.Text{text='Name', halign='center', valign='center', 
    color='black', fontsize=14, h=25, w=300, fontflags=rtk.font.BOLD})
    
  topContainerRowB:add(rtk.Text{text='Color', halign='center', valign='center', 
    color='black', fontsize=14, h=25, w=40, fontflags=rtk.font.BOLD})
    
  topContainerRowB:add(rtk.Text{text='Stop', halign='center', valign='center', 
    color='black', fontsize=14, h=25, w=40, fontflags=rtk.font.BOLD})
    
  topContainerRowB:add(rtk.Text{text='Jump', halign='center', valign='center', 
    color='black', fontsize=14, h=25, w=40, fontflags=rtk.font.BOLD})

end

function SetCheckbox(self, region)
  if (self.value == rtk.CheckBox.CHECKED) then
   region.StopAfter = 'true'
  else
   region.StopAfter = 'false'
  end
end

function MoveSong(up, region, count)
  if (up == true) then
    count = count * -1
  end
  local oldIndex = region.Index
  local newIndex = region.Index + count
  if (newIndex > #setlistController.regions) then
    newIndex = #setlistController.regions
  end
  if (newIndex < 1) then
    newIndex = 1
  end
  
  for _, reg in ipairs(setlistController.regions) do
    if (up == true) then
      if (reg.Index < oldIndex and reg.Index >= newIndex) then
        reg.Index = reg.Index + 1
      end
    else
      if (reg.Index > oldIndex and reg.Index <= newIndex) then
        reg.Index = reg.Index - 1
      end
    end
  end
  
  region.Index = newIndex 

  table.sort(setlistController.regions, 
    function(a, b)
      return a.Index < b.Index
  end)
  
  for _, reg in ipairs(setlistController.regions) do
    reaper.DeleteProjectMarker(0, reg.Index, true)
  end
  
  for _, reg in ipairs(setlistController.regions) do
    reaper.AddProjectMarker2(0, true, reg.Start, reg.End, 
      reg.Name, reg.Index, reg.Color)
  end
  
end

function ChangedPlayedStatus(region)
  if (region.Played == true) then
    region.Played = false
  else
    region.Played = true
  end
  setlistUi.reloadData()
end

function CountNonNilValsInTable(t)
  local count = 0
  for _, t1data in ipairs(t) do
    if t1data ~= nil then count = count + 1 end
  end
  reaper.ShowConsoleMsg(count..'\n')
  return count
end

function CompareTableFields(t1, t2, fields_to_compare)
  local matchedTable = {}
  for i=1, #t1 do
    local t1Key = t1[i].Name..' '..t1[i].Start..' '..t1[i].End..' '..t1[i].Color..' '..t1[i].Index
    for j=1, #t2 do
      local t2Key = t2[j].Name..' '..t2[j].Start..' '..t2[j].End..' '..t2[j].Color..' '..t2[j].Index
      if (t1Key == t2Key) then
        table.insert(matchedTable, t1[i].Name)
        break -- TODO
      end
    end
  end
end

function MoveButton(src_button, target, box, region)
    local src_idx = box:get_child_index(src_button)
    local target_idx = box:get_child_index(target)
    if src_button ~= target and src_idx > target_idx then
        box:reorder_before(src_button, target)
    elseif src_button ~= target then
        box:reorder_after(src_button, target)
    end
end

function Rgb2num(red, green, blue)
  green = green * 256
  blue = blue * 256 * 256
  return red + green + blue
end

function BuildSetListArea()
  for _, region in ipairs(setlistController.regions) do
  
    local r, g, b = reaper.ColorFromNative(region.Color)
    if (region.Color == 0) then
      color = 'white'
    else 
      color = Rgb2num(r, g, b)
    end
    
    local row = rtk.HBox{bg='grey', border='2px black', drag=true}
    
     row.ondragstart = function(self, event)
         dragging = self
         initialIndex = container:get_child_index(self)
         return true
     end
   
     row.ondragend = function(self, event)
         dragging = nil
         local index = container:get_child_index(self)
         if (initialIndex > index) then
            MoveSong(true, region, initialIndex - index)
         else
            MoveSong(false, region, index - initialIndex)
         end
         return true
     end
  
     row.ondropfocus = function(self, event, _, src_button)
         return true
     end
  
     row.ondropmousemove = function(self, event, _, src_button)
         if dragging then
             MoveButton(dragging, self, container, region)
         end
         return true
     end
  
     row.onmouseenter = function(self, event)
         if dragging then
             MoveButton(dragging, self, container, region)
         end
         return true
     end
      
    row.scroll_on_drag = true
    
    local idEntry = rtk.Entry{region.Index, halign='center', valign='center', 
      color='black', fontsize=14, h=25, w=40, textwidth=4}
    idEntry:push_undo()
      
    idEntry.onkeypress = function(self, event)
        if event.keycode == rtk.keycodes.ENTER then
          if (tonumber(idEntry.value)) then
            if (tonumber(idEntry.value) > region.Index) then
              MoveSong(false, region, tonumber(idEntry.value) - region.Index)
            else
              MoveSong(true, region, region.Index - tonumber(idEntry.value))
            end
          else 
            idEntry:undo()
            setlistUi.reloadData()
          end
        end
    end
    
    row:add(idEntry)
    
    if (region.Playing == true) then
      local playedCb = rtk.Button{'P', color=color, 
        textcolor='black', valign='center', halign='center', fontsize=16, h=25, w=40, 
        border='1px black'}
      playedCb.onclick = function(self)
         ChangedPlayedStatus(region)
      end
      row:add(playedCb)
    elseif (region.Played == true) then
      local playedCb = rtk.Button{'X', color=color, 
        textcolor='black', valign='center', halign='center', fontsize=16, h=25, w=40, 
        border='1px black'}
      playedCb.onclick = function(self)
         ChangedPlayedStatus(region)
      end
      row:add(playedCb)
    else
      local playedCb = rtk.Button{'O', color=color, 
        textcolor='black', valign='center', halign='center', fontsize=16, h=25, w=40, 
        border='1px black'}
      playedCb.onclick = function(self)
         ChangedPlayedStatus(region)
      end
      row:add(playedCb)
    end
    
    -- Played
    if (region.Played == true and (region.Playing == false or region.Playing == nil)) then
      local button = rtk.Button{region.Name, alpha=0.5, color=color, 
        textcolor='black', valign='center', fontsize=16, h=25,
        w=300, border='1px black'}
      button.onclick = function(self, event)
        PlaySong(region)
      end
      row:add(button)
    -- Playing
    elseif (region.Playing == true) then
      local button = rtk.Button{region.Name, color=color, 
        textcolor='black', valign='center', fontsize=16, h=25,
        w=300, border='1px black'}
      button.onclick = function(self, event)
        PlaySong(region)
      end
      row:add(button)
    -- Not Played
    else
      local button = rtk.Button{region.Name, color=color, 
        textcolor='black', valign='center', fontsize=16, h=25,
        w=300, border='1px black'}
      button.onclick = function(self, event)
        PlaySong(region)
      end
      row:add(button)
    end
    
    local colorPicker = rtk.Button{'O', color=color, halign='center', 
      textcolor='black', valign='center', fontsize=16, h=25, w=40, border='1px black'}
    colorPicker.onclick = function(self, event)
      local _, colorSelected = reaper.GR_SelectColor(reaper.GetMainHwnd())
      if (_ ~= 0) then
        local r, g, b = reaper.ColorFromNative(colorSelected)
        reaper.DeleteProjectMarker(0, region.Index, true)
        reaper.AddProjectMarker2(0, true, region.Start, region.End,
          region.Name, region.Index, reaper.ColorToNative(r,g,b)|0x1000000)
        setlistUi.reloadData()
      end
    end
    row:add(colorPicker)
    
    local cb = rtk.CheckBox{h=25, w=40, valign='center', halign='center'}
    if (region.StopAfter == 'true') then
      cb:toggle()
    end
    cb.onchange = function(self)
       SetCheckbox(self, region)
    end
    row:add(cb)
    
    local startPoint = rtk.Entry{region.Jump, halign='center', valign='center', 
      color='black', fontsize=14, h=25, w=40, textwidth=4}
    
    startPoint.onchange = function(self, event)
        region.Jump = tonumber(startPoint.value)
    end
    
    row:add(startPoint)
    
    container:add(row)
    
  end
  
end

function LoadRegionsFromProject()
  local tableCopy = {}
  if (setlistController.regions ~= nil and setlistController.regions ~= empty) then
    for k,v in pairs(setlistController.regions) do
      if (setlistController.regions[k].StopAfter ~= nil) then
        if (setlistController.regions[k].StopAfter == 'true') then
          tableCopy[k] = {StopAfter = 'true', Index = k, 
            Playing = setlistController.regions[k].Playing, Played = setlistController.regions[k].Played, Jump = setlistController.regions[k].Jump}
        else
          tableCopy[k] = {StopAfter = 'false', Index = k, 
            Playing = setlistController.regions[k].Playing, Played = setlistController.regions[k].Played, Jump = setlistController.regions[k].Jump}
        end
      else
        tableCopy[k] = {StopAfter = 'false', Index = k, 
          Playing = setlistController.regions[k].Playing, Played = setlistController.regions[k].Played, Jump = setlistController.regions[k].Jump}
      end
    end
  end
  
  local mrk_cnt = reaper.CountProjectMarkers(0)
  for i=0, mrk_cnt-1 do
    local _, isrgn, pos, rgnend, name, index, color = reaper.EnumProjectMarkers3( -1, i )
    if isrgn then
      local stopVar = 'false'
      local jumpVar = 0
      local playing = false
      local played = false
      
      if (tableCopy ~= empty and tableCopy[index] ~= nil 
        and tableCopy[index].StopAfter ~= nil) then
          stopVar = tableCopy[index].StopAfter
      end
      
      if (tableCopy ~= empty and tableCopy[index] ~= nil 
        and tableCopy[index].Playing ~= nil) then
          playing = tableCopy[index].Playing
      end
      
      if (tableCopy ~= empty and tableCopy[index] ~= nil 
        and tableCopy[index].Played ~= nil) then
          played = tableCopy[index].Played
      end
      
      if (tableCopy ~= empty and tableCopy[index] ~= nil 
        and tableCopy[index].Jump ~= nil) then
          jumpVar = tableCopy[index].Jump
      end
      
      setlistController.regions[index] = {Start = pos, End = rgnend, 
        Name = name, Color = color, Index = index, 
        StopAfter = stopVar, Played = played, Playing = playing,
        Jump = jumpVar}
    else
      setlistController.markers[index] = {Start = pos, End = rgnend, 
        Name = name, Color = color, Index = index}
    end
  end
end

return setlistUi
