local lyricProgramming = {}

local reaper, setlistController = {}, {}

local str_no_text = "--XR-NO-TEXT--"
local ext_name = "XR_Lyrics"
local ext_keys = { "text", "next" }

function lyricProgramming.init(r, controller)
  reaper = r
  setlistController = controller
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  local state = reaper.GetToggleCommandStateEx( sec, cmd )
  reaper.SetToggleCommandState( sec, cmd, 1 )
  reaper.RefreshToolbar2( sec, cmd )
end

function lyricProgramming.lyricStuff()
  local lyrics_track = nil
  local count_tracks = reaper.CountTracks()
  for i = 0, count_tracks - 1 do
    local track = reaper.GetTrack(0,i)
    local retval, track_name = reaper.GetTrackName( track )
    if track_name:lower() == "lyrics" then
      lyrics_track = track
      break
    end
  end
  if lyrics_track ~= nil then
    local textToDisplay = ""
    item = GetTrackItemAtPos( lyrics_track, reaper.GetPlayPosition() ) 
    if item ~= nil and setlistController.currentRegion ~= nil and setlistController.currentRegion.Name ~= nil then
      textToDisplay = textToDisplay .. 'CURRENT SONG:<br><div style="background-color:#' 
        .. RgbToHex(reaper.ColorFromNative(setlistController.currentRegion.Color)) .. '">' .. setlistController.currentRegion.Name .. '</div><br>'
      local retVal, itemNotes = reaper.GetSetMediaItemInfo_String( item, "P_NOTES", textToDisplay, false )
      textToDisplay = textToDisplay .. itemNotes:gsub("\r?\n", "<br>") .. GetNextSongHtml()
      reaper.SetProjExtState( 0, ext_name, "text", textToDisplay )
      SendSetListHtml()
    end 
  end
end  

function RgbToHex(r,g,b)
    return string.format("%x", (r * 0x10000) + (g * 0x100) + b)
end

function GetTrackItemAtPos( track, pos )
  local count_track_items = reaper.GetTrackNumMediaItems( track )
  local current_item
  for i = 0, count_track_items - 1 do
    local item = reaper.GetTrackMediaItem( track, i )
    local item_pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
    if item_pos <= pos then -- if item is after cursor then ignore
      local item_len = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
      if item_pos + item_len > pos then -- if item end is after cursor, then item is under cusor
        current_item = item
        break
      end
    end
  end
  return current_item
end

function GetNextSongHtml()
  local text = ''
  if (setlistController.currentRegion.Index < #setlistController.regions) then
    local nextSong = setlistController.regions[setlistController.currentRegion.Index + 1]
    if nextSong.Color == 0 or nextSong.Color == nil then
      for _, region in ipairs(setlistController.regions) do
        if region.Index > nextSong.Index and region.Color ~= 0 and region.Color ~= nil then
          text = text .. '<br><br>NEXT SONGS:<br><div style="background-color:#' .. RgbToHex(reaper.ColorFromNative(nextSong.Color)) 
            .. '">' .. nextSong.Name .. '</div><div style="background-color:#' .. RgbToHex(reaper.ColorFromNative(region.Color)) 
              .. '">' .. region.Name .. '</div><br>'
            break
        end
      end
    else
      text = text .. '<br><br>NEXT SONG:<br><div style="background-color:#' .. RgbToHex(reaper.ColorFromNative(nextSong.Color)) 
        .. '">' .. nextSong.Name .. '</div><br>'
    end
  end
  return text
end

function SendSetListHtml()
  local setListHtml = '<table>'
  local stop = false
  for _, region in ipairs(setlistController.regions) do
    if setlistController.currentRegion.Name == region.Name then
      setListHtml = setListHtml .. '<div style="border:1px solid black;background-color:#'
        .. RgbToHex(reaper.ColorFromNative(region.Color)) .. '"><b>[--'
        .. region.Name .. '--]</b></div>'
    else
      setListHtml = setListHtml .. '<div style="border:1px solid black;background-color:#'
        .. RgbToHex(reaper.ColorFromNative(region.Color)) .. '">'
        .. region.Name .. '</div>'
    end
    if region.Name == '(SET END)' then
      setListHtml = setListHtml .. '</table>'
      reaper.SetProjExtState( 0, ext_name, "next", setListHtml )
      return
    end
  end
  setListHtml = setListHtml .. '</table>'
  reaper.SetProjExtState( 0, ext_name, "next", setListHtml )
end

return lyricProgramming
