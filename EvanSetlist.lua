--TODO 
-- auto refresh
-- editable song name
-- test with markers
-- editing region index in daw doubles region
-- movesong visual bugs
-- making changes after saving reverts set name visually bug



package.path = reaper.GetResourcePath() .. '/Scripts/rtk/1/?.lua'
local rtk = require('rtk')

local window = rtk.Window{}
window.onkeypresspost = function(self, event)
  if (not event.handled and event.keycode == rtk.keycodes.SPACE) then
     reaper.OnPauseButtonEx(0)
  end
  if (not event.handled and event.keycode == rtk.keycodes.UP) then
     playNextSong(false)
  end
  if (not event.handled and event.keycode == rtk.keycodes.DOWN) then
     playNextSong(true)
  end
end

local fullContainer = rtk.VBox{bg='grey', padding=10}
window:add(fullContainer)
local container = rtk.VBox{bg='grey'}
local topContainer = rtk.VBox{bg='grey'}
fullContainer:add(topContainer)
local vp = fullContainer:add(rtk.Viewport{container, smoothscroll=true, scrollbar_size=5, 
  vscrollbar=rtk.Viewport.SCROLLBAR_HOVER})
  
  
function getOs()
    return package.config:sub(1,1) == "\\" and "win" or "unix"
end
  
function getDirectory()
  if (getOs() == "win") then
    return os.getenv( "USERPROFILE" ) .. '/Documents/ReaSetlister/'
  else
    return os.getenv( "HOME" ) .. '/Documents/ReaSetlister/'
  end   
end
      
local loadedSetName = ''
      
local markers, regions = {}, {}
local currentRegion = {}
local dragging, initialIndex = nil

function runloop()
  if (currentRegion ~= nil and reaper.GetPlayPosition() >= currentRegion.End) then
     if (currentRegion.StopAfter == 'true') then
       reaper.OnStopButton()
     else
       local nextRegion = regions[currentRegion.Index + 1]
       playSong(nextRegion)
     end
  else
    reaper.defer(runloop)
  end
end

function playNextSong(nextSong)
  if (currentRegion.Name ~= nil) then
    if (nextSong == true) then
      if (currentRegion.Index < #regions) then
        local nextRegion = regions[currentRegion.Index + 1]
        playSong(nextRegion)
      else
        playSong(currentRegion)
      end
    else
      if (currentRegion.Index > 1) then
        local nextRegion = regions[currentRegion.Index - 1]
        playSong(nextRegion)
      else
        playSong(currentRegion)
      end
    end
  end
end
 
function playSong(region) 
  currentRegion = region
  
  for k,v in pairs(regions) do regions[k].Playing = false end
  
  region.Played = true
  region.Playing = true
  
  reloadData()

  reaper.SetEditCurPos(region.Start, true, true)
  reaper.OnPlayButton()
  reaper.defer(runloop)
end

function rgb2num(red, green, blue)
  green = green * 256
  blue = blue * 256 * 256
  return red + green + blue
end

function helpPopUp()
  local box = rtk.VBox{spacing=20}
  local hbox = rtk.HBox{spacing=20}
  local popup = rtk.Popup{child=box,
    overlay='#000000cc', autoclose=true}
    
  box:add(rtk.Text{'HELP', wrap=rtk.Text.WRAP_NORMAL})
  box:add(rtk.Text{'PATH - Saved setlists are stored in ' .. getDirectory(), wrap=rtk.Text.WRAP_NORMAL})
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

function loadRegionsFromProject()

  local tableCopy = {}
  if (regions ~= nil and regions ~= empty) then
    for k,v in pairs(regions) do
      if (regions[k].StopAfter ~= nil) then
        if (regions[k].StopAfter == 'true') then
          tableCopy[k] = {StopAfter = 'true', Index = k, 
            Playing = regions[k].Playing, Played = regions[k].Played}
        else
          tableCopy[k] = {StopAfter = 'false', Index = k, 
            Playing = regions[k].Playing, Played = regions[k].Played}
        end
      else
        tableCopy[k] = {StopAfter = 'false', Index = k, 
          Playing = regions[k].Playing, Played = regions[k].Played}
      end
    end
  end
  
  local mrk_cnt = reaper.CountProjectMarkers(0)
  for i=0, mrk_cnt-1 do
    local _, isrgn, pos, rgnend, name, index, color = reaper.EnumProjectMarkers3( -1, i )
    if isrgn then
      local stopVar = 'false'
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
      
      regions[index] = {Start = pos, End = rgnend, 
        Name = name, Color = color, Index = index, 
        StopAfter = stopVar, Played = played, Playing = playing}
    else
      markers[index] = {Pos = pos, Name = name}
    end
  end
end

function buildTopUI()

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
    loadedSetName:gsub('.csv', ''), placeholder='SetlistA', 
    textwidth=15, fontsize=18,
    w=200, h=25, valign='center', halign='center'})
  setListNameEntry.onkeypress = function(self, event)
      if event.keycode == rtk.keycodes.ESCAPE then
          self:clear()
          self:animate{'bg', dst=rtk.Attribute.DEFAULT}
      elseif event.keycode == rtk.keycodes.ENTER then
          self:animate{'bg', dst='hotpink'}
      end
  end
  
  local saveButton = rtk.Button{'Save Setlist', color='gold', textcolor='black', valign='center', halign='center',
    fontsize=18, h=25, w=100}
  saveButton.onclick = function(self, event)
    saveSetlist(setListNameEntry)
  end
  topContainerRowA:add(saveButton)
  
  topContainerRowA:add(rtk.Box.FLEXSPACE)
  
  local loadButton = rtk.Button{'Setlists', valign='center', halign='center', color='gold', textcolor='black', 
    fontsize=18, h=25, w=100}
  loadButton.onclick = function(self, event)
    loadSongPopup()
  end
  topContainerRowA:add(loadButton)
  
  local topContainerRowA2 = rtk.HBox{bg='grey', tpadding=10, bpadding=10}
  topContainer:add(topContainerRowA2)
  
  
  topContainerRowA2:add(rtk.Box.FLEXSPACE)
  
  local refreshSessionButton = rtk.Button{'Refresh', color='gold', 
    textcolor='black', valign='center', halign='center',
    fontsize=18, h=25, w=100}
  refreshSessionButton.onclick = function(self, event)
    for k,v in pairs(regions) do
      regions[k].Played = false
    end
    reloadData()
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

end

function setCheckbox(self, region)
  if (self.value == rtk.CheckBox.CHECKED) then
   region.StopAfter = 'true'
  else
   region.StopAfter = 'false'
  end
end

function movesong(up, region, count)
  if (up == true) then
    count = count * -1
  end
  
  local oldIndex = region.Index
  local newIndex = region.Index + count
  if (newIndex > #regions) then
    newIndex = #regions
  end

  if (newIndex < 1) then
    newIndex = 1
  end
  
  local stopVar = 'false'
  if (region.StopAfter == 'true') then
    stopVar = 'true'
  end
  
  local playing = false
  if (region.Playing == true) then
    playing = true
  end
  
  local played = false
  if (region.Played == true) then
    played = true
  end
  
  local stopVarBefore = 'false'
  if (regions[newIndex].StopAfter == 'true') then
    stopVarBefore = 'true'
  end
  
  local playingBefore = false
  if (regions[newIndex].Playing == true) then
    playingBefore = true
  end
  
  local playedBefore = false
  if (regions[newIndex].Played == true) then
    playedBefore = true
  end
  
  for _, reg in ipairs(regions) do
  
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
  
  regions[newIndex].StopAfter = stopVar
  regions[newIndex].Played = played
  regions[newIndex].Playing = playing
  
  regions[oldIndex].StopAfter = stopVarBefore
  regions[oldIndex].Played = played
  regions[oldIndex].Playing = playing
  
  updateProjectRegions()
  
  reloadData()
  
end

function changedPlayedStatus(region)
  if (region.Played == true) then
    region.Played = false
  else
    region.Played = true
  end
  reloadData()
end

function updateProjectRegions()
  for _, reg in ipairs(regions) do
    reaper.DeleteProjectMarker(0, reg.Index, true)
  end
  
  for _, reg in ipairs(regions) do
    reaper.AddProjectMarker2(0, true, reg.Start, reg.End, 
      reg.Name, reg.Index, reg.Color)
  end
end

function reloadData()
  container:remove_all()
  topContainer:remove_all()
  loadRegionsFromProject()
  buildUI()
  -- TODO save if file already exists
end

local function move_button(src_button, target, box, region)
    local src_idx = box:get_child_index(src_button)
    local target_idx = box:get_child_index(target)
    if src_button ~= target and src_idx > target_idx then
        box:reorder_before(src_button, target)
    elseif src_button ~= target then
        box:reorder_after(src_button, target)
    end
end

function buildSetListArea()
  for _, region in ipairs(regions) do
  
    local r, g, b = reaper.ColorFromNative(region.Color)
    if (region.Color == 0) then
      color = 'white'
    else 
      color = rgb2num(r, g, b)
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
            movesong(true, region, initialIndex - index)
         else
            movesong(false, region, index - initialIndex)
         end
         return true
     end
  
     row.ondropfocus = function(self, event, _, src_button)
         return true
     end
  
     row.ondropmousemove = function(self, event, _, src_button)
         if dragging then
             move_button(dragging, self, container, region)
         end
         return true
     end
  
     row.onmouseenter = function(self, event)
         if dragging then
             move_button(dragging, self, container, region)
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
              movesong(false, region, tonumber(idEntry.value) - region.Index)
            else
              movesong(true, region, region.Index - tonumber(idEntry.value))
            end
          else 
            idEntry:undo()
            reloadData()
          end
        end
    end
    
    row:add(idEntry)
    
    
    
    
    if (region.Playing == true) then
      local playedCb = rtk.Button{'P', color=color, 
        textcolor='black', valign='center', halign='center', fontsize=16, h=25, w=40, 
        border='1px black'}
      playedCb.onclick = function(self)
         changedPlayedStatus(region)
      end
      row:add(playedCb)
    elseif (region.Played == true) then
      local playedCb = rtk.Button{'X', color=color, 
        textcolor='black', valign='center', halign='center', fontsize=16, h=25, w=40, 
        border='1px black'}
      playedCb.onclick = function(self)
         changedPlayedStatus(region)
      end
      row:add(playedCb)
    else
      local playedCb = rtk.Button{'O', color=color, 
        textcolor='black', valign='center', halign='center', fontsize=16, h=25, w=40, 
        border='1px black'}
      playedCb.onclick = function(self)
         changedPlayedStatus(region)
      end
      row:add(playedCb)
    end
    
    
    
    
    -- Played
    if (region.Played == true and (region.Playing == false or region.Playing == nil)) then
      local button = rtk.Button{region.Name, alpha=0.5, color=color, 
        textcolor='black', valign='center', fontsize=16, h=25,
        w=300, border='1px black'}
      button.onclick = function(self, event)
        playSong(region)
      end
      row:add(button)
    -- Playing
    elseif (region.Playing == true) then
      local button = rtk.Button{region.Name, color=color, 
        textcolor='black', valign='center', fontsize=16, h=25,
        w=300, border='1px black'}
      button.onclick = function(self, event)
        playSong(region)
      end
      row:add(button)
    -- Not Played
    else
      local button = rtk.Button{region.Name, color=color, 
        textcolor='black', valign='center', fontsize=16, h=25,
        w=300, border='1px black'}
      button.onclick = function(self, event)
        playSong(region)
      end
      row:add(button)
    end
    
    
    local colorPicker = rtk.Button{'O', color=color, halign='center', 
      textcolor='black', valign='center', fontsize=16, h=25, w=40, border='1px black'}
    colorPicker.onclick = function(self, event)
      local _, colorSelected = reaper.GR_SelectColor(reaper.GetMainHwnd())
      if (_ ~= 0) then
        local r, g, b = reaper.ColorFromNative(colorSelected)
        local colorChanged = rgb2num(r,g,b)
        reaper.DeleteProjectMarker(0, region.Index, true)
        reaper.AddProjectMarker2(0, true, region.Start, region.End,
          region.Name, region.Index, reaper.ColorToNative(r,g,b)|0x1000000)
        reloadData()
      end
    end
    row:add(colorPicker)
    
    local cb = rtk.CheckBox{h=25, w=40, valign='center', halign='center'}
    if (region.StopAfter == 'true') then
      cb:toggle()
    end
    cb.onchange = function(self)
       setCheckbox(self, region)
    end
    row:add(cb)
    
    container:add(row)
    
  end
  
end

function buildUI()
  buildTopUI()
  buildSetListArea()
end

function saveSetlist(setListNameEntry)
  if (regions ~= nil and regions ~= empty and 
      setListNameEntry.value ~= nil and setListNameEntry.value ~= '') then
      os.execute( 'mkdir -p ' .. getDirectory() .. ' 2>/dev/null')
      local file = io.open(getDirectory() ..setListNameEntry.value..'.csv', "r")
      if (file ~= nil) then
        file:close()
        local func = function() nt2_write(getDirectory()..setListNameEntry.value..'.csv', regions) end
        confirmationPopup("A file with the name "
          ..setListNameEntry.value..".csv' already exists, do you want to replace it?",
          func)
      else
        nt2_write(getDirectory()..setListNameEntry.value..'.csv', regions)
      end
  else
    errorPopup('Please type a setlist name and have at least one song in the set!')
  end
  
end

function nt2_write(path, data)
    local file = assert(io.open(path, "w"))
    for k, v in pairs(data) do
      file:write(v["Index"] .. "," .. v["Name"] .. "," .. 
        v["Start"] .. "," .. v["End"] .. "," .. v["Color"] 
        .. "," .. v["StopAfter"])
      file:write('\n')
    end
    file:close()
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



function confirmationPopup(message, func)
  local box = rtk.VBox{spacing=20}
  local hbox = rtk.HBox{spacing=20}
  local popup = rtk.Popup{child=box,
    overlay='#000000cc', autoclose=true}
    
  local choice = nil
    
  local text = box:add(rtk.Text{message, wrap=rtk.Text.WRAP_NORMAL})
  
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
      func()
    end
  end
  
  popup:open()
end


function loadRegionsFromFile(fileName)
  local func = function() return loadRegionsFromFileCommand(fileName) end
  confirmationPopup('Are you sure you want to load the setlist?\n'
      ..fileName..
      '\n\nThis will overwrite any changes you have made to regions in your DAW!', 
    func)
end

function loadRegionsFromFileCommand(fileName)
  local path = getDirectory()..fileName
  for k in pairs (regions) do regions[k] = nil end
  
  local file = io.open(path, "r") 
  for line in io.lines(path) do
    local index, name, start, ending, color, stopAfter = 
      line:match("%s*(.*),%s*(.*),%s*(.*),%s*(.*),%s*(.*),%s*(.*)")
    
    regions[#regions+1] = {Start = tonumber(start), End = tonumber(ending), 
            Name = name, Color = tonumber(color), Index = tonumber(index), 
            StopAfter = stopAfter}
    
  end
  
  file:close()
  
  loadedSetName = fileName
  saveLastLoadedFile()
  
  updateProjectRegions()
  reloadData()
end

function saveLastLoadedFile()
  local file = assert(io.open(getDirectory()..'lastSetName.txt', "w"))
  file:write(loadedSetName)
  file:close()
end

function deleteFile(fileName)
  local path = getDirectory()..fileName.label
  local func = function() assert(os.remove(path)) end
  confirmationPopup('Are you sure you want to delete the setlist: '..fileName.label..' ?', func)
end

function loadSongPopup()
  local box = rtk.VBox{spacing=20, w=150}
  local popup = rtk.Popup{child=box, padding=30, 
    overlay='#000000cc', autoclose=true}
    
  local text = box:add(rtk.Text{'Choose a setlist to load!', wrap=rtk.Text.WRAP_NORMAL})
    
  local fileList = {}
    
  local f = io.popen('ls ' .. getDirectory())
  for name in f:lines() do
    if (name:sub(-#'.csv') == '.csv') then
      fileList[#fileList+1]= name
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
        loadRegionsFromFile(fileListDropDown.selected_item.label)
      end
  end
  
  hBox:add(rtk.Box.FLEXSPACE)
  
  local deleteButton = hBox:add(rtk.Button{'Delete'}, {halign='right'})
  deleteButton.onclick = function(b, event)
    if (fileListDropDown.selected_item == nil) then
      errorPopup('Please select a setlist to delete!')
    else
      popup:close()
      deleteFile(fileListDropDown.selected_item)
    end
    popup:close()
  end
  
  
  local cancelButton = box:add(rtk.Button{'Cancel'}, {halign='right'})
  cancelButton.onclick = function(b, event)
    popup:close()
  end
  popup:open()
end

function main()
  loadRegionsFromProject()
  buildUI()
end




main()

window:open{align='center'}
