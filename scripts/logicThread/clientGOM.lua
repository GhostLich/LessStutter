local mod = {
    loadOrder = 1,
}

function mod:onload(clientGOM)
    local lastRequestTimes = {}

    local prevRequestUnloadedObjectFromServer = clientGOM.requestUnloadedObjectFromServer
    clientGOM.requestUnloadedObjectFromServer = function(self, objectID)
        local now = os.clock()
        local lastTime = lastRequestTimes[objectID]
        if lastTime and now - lastTime < 10.0 then
            return
        end
        lastRequestTimes[objectID] = now
        prevRequestUnloadedObjectFromServer(self, objectID)
    end

    local cloneTable = mj.cloneTable
    local skipState = nil
    local skipClone = function(self, orig)
        mj.cloneTable = cloneTable
        if orig == skipState then
            return nil
        end
        return cloneTable(self, orig)
    end

    local prevServerUpdate = clientGOM.serverUpdate
    clientGOM.serverUpdate = function(self, object, incomingServerStateDelta, pos, rotation, scale)
        skipState = object.sharedState
        mj.cloneTable = skipClone
        prevServerUpdate(self, object, incomingServerStateDelta, pos, rotation, scale)
        mj.cloneTable = cloneTable
    end
end

return mod
