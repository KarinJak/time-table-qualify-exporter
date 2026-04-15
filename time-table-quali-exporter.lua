-- Save path: Assetto Corsa Root directory (bypasses OneDrive lock issues completely!)
local SAVE_PATH = ac.getFolder(ac.FolderID.Root) .. '\\bop_export.json'

local exportStatus = ""
local lastSavedPath = ""

-- Collect data from the live session
local function exportBoPData()
    local carCount = ac.getSim().carsCount
    local exportedCars = {}

    for i = 0, carCount - 1 do
        local car = ac.getCar(i)
        local carState = ac.getCarState(i)

        if car and carState and car.isConnected then
            table.insert(exportedCars, {
                acCarId = i,
                driver = car.driverName,
                model = car.name or car.carId,
                bestLap = car.bestLapTimeMs or 0,
                ballastKg = carState.addedMass or 0,
                restrictorPct = carState.engineRestrictor or 0
            })
        end
    end

    return exportedCars
end

-- Build JSON string and write to disk
local function executeSaveSafe()
    local carCount = ac.getSim().carsCount or 0
    local exportedCars = {}

    for i = 0, carCount - 1 do
        local car = ac.getCar(i)
        local carState = ac.getCarState(i)

        if car and carState and car.isConnected then
            local bestLap = tonumber(car.bestLapTimeMs) or 0
            local mass = tonumber(carState.ballast) or 0
            local res = tonumber(carState.restrictor) or 0
            
            local rawDriver = ac.getDriverName(i)
            if rawDriver == "" or not rawDriver then rawDriver = "Unknown" end
            
            local rawModel = ac.getCarName(i)
            if rawModel == "" or not rawModel then rawModel = ac.getCarID(i) end
            if rawModel == "" or not rawModel then rawModel = "Unknown" end

            local driverStr = tostring(rawDriver):gsub('"', '\\"')
            local modelStr = tostring(rawModel):gsub('"', '\\"')

            table.insert(exportedCars, string.format(
                '    {"acCarId": %d, "driver": "%s", "model": "%s", "bestLap": %d, "ballastKg": %d, "restrictorPct": %d}',
                i, driverStr, modelStr, math.floor(bestLap), math.floor(mass), math.floor(res)
            ))
        end
    end

    local rawTrackName = "Unknown Track"
    if type(ac.getTrackName) == "function" then
        local tName = ac.getTrackName()
        if tName and tName ~= "" then rawTrackName = tName end
    end
    if rawTrackName == "Unknown Track" and type(ac.getTrackID) == "function" then
        local tId = ac.getTrackID()
        if tId and tId ~= "" then rawTrackName = tId end
    end
    
    local rawTrackConfig = ""
    if type(ac.getTrackLayout) == "function" then
        local tLayout = ac.getTrackLayout()
        if tLayout and tLayout ~= "" then rawTrackConfig = tLayout end
    elseif type(ac.getTrackConfiguration) == "function" then
        local tConfig = ac.getTrackConfiguration()
        if tConfig and tConfig ~= "" then rawTrackConfig = tConfig end
    end

    local trackNameStr = tostring(rawTrackName):gsub('"', '\\"')
    local trackConfigStr = tostring(rawTrackConfig):gsub('"', '\\"')

    local jsonStr = '{\n  "TrackName": "' .. trackNameStr .. '",\n  "TrackConfig": "' .. trackConfigStr .. '",\n  "cars": [\n' .. table.concat(exportedCars, ",\n") .. '\n  ]\n}'

    local file = io.open(SAVE_PATH, 'w')
    if file then
        file:write(jsonStr)
        file:close()
        return "Saved", SAVE_PATH
    end
    
    -- Fallback local save
    file = io.open("bop_export.json", 'w')
    if file then
        file:write(jsonStr)
        file:close()
        return "Saved (Local Fallback)", "bop_export.json"
    end

    return "Failed", "Could not open file handlers"
end

-- Main UI window rendered every frame
function windowMain()
    ui.text("Quali & BoP Exporter")
    ui.text("Scanning " .. tostring(ac.getSim().carsCount) .. " vehicle(s)...")

    ui.dummy(vec2(0, 10))

    -- Export button
    if ui.button("Export JSON", vec2(ui.availableSpaceX(), 40)) then
        local success, state, path = pcall(executeSaveSafe)
        
        if success then
            if state == "Failed" then
                exportStatus = "FAILED: IO Blocked"
            else
                exportStatus = "Saved!"
                lastSavedPath = path
                ui.toast(ui.Icons.Confirm, "Export OK", path)
            end
        else
            -- An actual Lua code error happened inside the logic!
            exportStatus = "CRASH: " .. tostring(state)
        end
    end

    ui.dummy(vec2(0, 4))

    -- Open folder button — opens Explorer
    if ui.button("Open Output Folder", vec2(ui.availableSpaceX(), 32)) then
        if lastSavedPath == "" then
            os.execute('explorer "' .. ac.getFolder(ac.FolderID.Root) .. '"')
        elseif lastSavedPath == "bop_export.json" then
            os.execute('explorer "' .. ac.getFolder(ac.FolderID.ExtLua) .. '\\apps\\time-table-quali-exporter"')
        else
            os.execute('explorer /select,"' .. string.gsub(lastSavedPath, '/', '\\') .. '"')
        end
    end

    if exportStatus ~= "" then
        ui.dummy(vec2(0, 8))
        ui.text(exportStatus)
        
        -- Let the user copy the error easily!
        if string.find(exportStatus, "CRASH") then
            if ui.button("Copy Error to Clipboard", vec2(ui.availableSpaceX(), 26)) then
                ui.setClipboardText(exportStatus)
                ui.toast(ui.Icons.Confirm, "Copied", "Error text copied to clipboard!")
            end
        end
    end

    ui.dummy(vec2(0, 8))
    ui.text("Resolved System Path:")
    ui.textWrapped(tostring(SAVE_PATH))
end
