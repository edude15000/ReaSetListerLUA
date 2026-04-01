--TODO 
-- editable song (region) name
-- choose to keep project vs load file for each region merge conflict
-- refresher from project updates

local setlistController = {}

local currentRegion, regions, markers = {}, {}, {}

package.path = package.path .. ';' .. reaper.GetResourcePath() .. '/Scripts/rtk/1/?.lua'
local rtk = require('rtk')

package.path = package.path .. ';' .. reaper.GetResourcePath() .. '/Scripts/SetlistDeps/?.lua'
local midiProgramming = require('midiProgramming')
local lyricProgramming = require('lyricProgramming')
local fileStorage = require('fileStorage')
local setlistUi = require('setlistUi')

rtk.add_image_search_path(fileStorage.getDirectory())

function lyricWriterLoop()
    lyricProgramming.lyricStuff()
    reaper.defer(lyricWriterLoop)
end

function midiWriterLoop()
    midiProgramming.midiStuff()
    reaper.defer(midiWriterLoop)
end

function uiRefreshLoop()
   -- setlistUi.refreshUiFromReaperChanges()
   -- reaper.defer(uiRefreshLoop)
end

function main()
  fileStorage.init(reaper, setlistController)
  midiProgramming.init(reaper)
  lyricProgramming.init(reaper, setlistController)
  setlistUi.init(reaper, rtk, fileStorage, midiProgramming, setlistController)
  
  reaper.defer(uiRefreshLoop)
  reaper.defer(midiWriterLoop)
  reaper.defer(lyricWriterLoop)
end

main()

return setlistController
