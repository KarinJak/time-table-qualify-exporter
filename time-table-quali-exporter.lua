local function exportBoPData()
    local carCount = ac.getSim().carsCount
    local exportedCars = {}

    for i = 0, carCount - 1 do
        local car = ac.getCar(i)
        local carState = ac.getCarState(i)
        
        if car and carState and car.isConnected then
            -- Note: car.carId provides the folder name natively (e.g. rss_gtm_akuro_v6_evo2)
            -- bestLapTime is commonly returned in milliseconds. If it's pure 0, no lap is set.
            local carData = {
                acCarId = i,
                driver = car.driverName,
                model = car.name or car.carId,
                bestLap = car.bestLapTimeMs or 0,
                ballastKg = carState.addedMass or 0, -- CSP refers to ballast commonly as addedMass
                restrictorPct = carState.engineRestrictor or 0
            }
            
            table.insert(exportedCars, carData)
        end
    end

    return exportedCars
end

local function saveToFile(data)
    -- Build JSON manually to ensure we don't rely on missing dependencies
    local jsonStr = "{\n  \"cars\": [\n"
    for i, car in ipairs(data) do
        -- sanitize strings just in case
        local safeDriver = string.gsub(car.driver, '"', '\\"')
        local safeModel = string.gsub(car.model, '"', '\\"')
        
        -- string format for the car object
        jsonStr = jsonStr .. string.format(
            '    {"acCarId": %d, "driver": "%s", "model": "%s", "bestLap": %d, "ballastKg": %d, "restrictorPct": %d}',
            car.acCarId, safeDriver, safeModel, math.floor(car.bestLap), math.floor(car.ballastKg), math.floor(car.restrictorPct)
        )
        
        if i < #data then
            jsonStr = jsonStr .. ",\n"
        else
            jsonStr = jsonStr .. "\n"
        end
    end
    jsonStr = jsonStr .. "  ]\n}"

    -- Target the out folder in My Documents exactly where Race_Out normally drops
    local path = ac.getFolder(ac.FolderID.Documents) .. "/Assetto Corsa/out/bop_export.json"
    
    local file = io.open(path, "w")
    if file then
        file:write(jsonStr)
        file:close()
        return true, path
    else
        return false, nil
    end
end

-- Primary UI Render loop requested by manifest.ini: FUNCTION_MAIN = windowMain
function windowMain()
    local padding = vec2(10, 10)
    
    ui.text("BoP Data Exporter")
    ui.textColored(rgbm(0.5, 0.5, 0.5, 1), "Currently scanning " .. tostring(ac.getSim().carsCount) .. " vehicles...")
    
    ui.dummy(vec2(0, 10))
    
    if ui.button("Harvest & Export JSON", vec2(ui.availableSpaceX(), 40)) then
        local data = exportBoPData()
        local success, path = saveToFile(data)
        
        if success then
            ui.toast(ui.Icons.Confirm, "Data exported successfully", "Saved to Assetto Corsa/out/bop_export.json")
            ac.log("Exported BoP to: " .. path)
        else
            ui.toast(ui.Icons.Warning, "Export Failed", "Could not write to Documents directory.")
        end
    end
    
    ui.dummy(vec2(0, 15))
    ui.textWrapped("Drop the generated bop_export.json directly into your BoP Calculator web app. You do not need to upload race.ini anymore!")
end
