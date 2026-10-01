local gameObject = mjrequire "common/gameObject"

local mod = {
    loadOrder = 1,
}

function mod:onload(clientFlora)
    local clientGOM = nil
    local parkedBirdTypes = {}
    local loadingObjectID = nil
    local farLevel = mj.SUBDIVISIONS - 3

    local vanillaObjectWasLoaded = clientFlora.objectWasLoaded
    local birdIndex = nil
    local updateBirdSongCallback = nil
    for i = 1, 50 do
        local name, value = debug.getupvalue(vanillaObjectWasLoaded, i)
        if not name then
            break
        end
        if name == "updateBirdSongCallback" then
            birdIndex = i
            updateBirdSongCallback = value
            break
        end
    end

    local seasonalByType = {}
    local function isSeasonal(objectTypeIndex)
        local seasonal = seasonalByType[objectTypeIndex]
        if seasonal == nil then
            seasonal = false
            local modelFunction = gameObject.types[objectTypeIndex].modelFunction
            if modelFunction then
                seasonal = true
                local namesBySeason = nil
                local isSapling = false
                local hasSnow = false
                for i = 1, 50 do
                    local name, value = debug.getupvalue(modelFunction, i)
                    if not name then
                        break
                    end
                    if name == "namesBySeason" then
                        namesBySeason = value
                    elseif name == "treeKey" then
                        isSapling = true
                    elseif name == "snowVarient" and value then
                        hasSnow = true
                    end
                end
                if namesBySeason and not isSapling and not hasSnow and namesBySeason[1] == namesBySeason[2] and namesBySeason[1] == namesBySeason[3] and namesBySeason[1] == namesBySeason[4] then
                    seasonal = false
                end
            end
            seasonalByType[objectTypeIndex] = seasonal
        end
        return seasonal
    end

    local seasonIndex = nil
    local updateSeasonChangeCallback = nil
    for i = 1, 50 do
        local name, value = debug.getupvalue(vanillaObjectWasLoaded, i)
        if not name then
            break
        end
        if name == "updateSeasonChangeCallback" then
            seasonIndex = i
            updateSeasonChangeCallback = value
            break
        end
    end

    if seasonIndex then
        debug.setupvalue(vanillaObjectWasLoaded, seasonIndex, function(object)
            if isSeasonal(object.objectTypeIndex) then
                updateSeasonChangeCallback(object)
            end
        end)
    else
        mj:warn("LessStutter: updateSeasonChangeCallback not found")
    end

    if birdIndex then
        debug.setupvalue(vanillaObjectWasLoaded, birdIndex, function(object, birdType, firstAdd)
            if object.subdivLevel <= farLevel then
                parkedBirdTypes[object.uniqueID] = birdType
                return
            end
            updateBirdSongCallback(object, birdType, firstAdd)
        end)

        local prevDetailLevelChanged = clientFlora.objectDetailLevelChanged
        clientFlora.objectDetailLevelChanged = function(objectID, newDetailLevel)
            prevDetailLevelChanged(objectID, newDetailLevel)
            local birdType = parkedBirdTypes[objectID]
            if birdType and newDetailLevel > farLevel then
                parkedBirdTypes[objectID] = nil
                local object = clientGOM:getObjectWithID(objectID)
                if object then
                    updateBirdSongCallback(object, birdType, true)
                end
            end
        end
    else
        mj:warn("LessStutter: updateBirdSongCallback not found")
    end

    clientFlora.objectWasLoaded = function(object, pos, rotation, scale)
        loadingObjectID = object.uniqueID
        vanillaObjectWasLoaded(object, pos, rotation, scale)
        loadingObjectID = nil
    end

    local prevInit = clientFlora.init
    clientFlora.init = function(self, clientGOM_)
        clientGOM = clientGOM_
        prevInit(self, clientGOM_)

        local prevSetTransparentBuildObject = clientGOM.setTransparentBuildObject
        clientGOM.setTransparentBuildObject = function(gom, objectID, transparentBuildObject)
            if transparentBuildObject or objectID ~= loadingObjectID then
                prevSetTransparentBuildObject(gom, objectID, transparentBuildObject)
            end
        end

        local prevWillBeUnloaded = clientGOM.gameObjectWillBeUnloaded
        clientGOM.gameObjectWillBeUnloaded = function(gom, objectID, objectWasRemovedFromWorld)
            parkedBirdTypes[objectID] = nil
            return prevWillBeUnloaded(gom, objectID, objectWasRemovedFromWorld)
        end
    end
end

return mod
