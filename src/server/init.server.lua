local replicated = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local database = require(script.Database)

players.PlayerAdded:Connect(function(player: Player)
    local playerData = database.new(player.UserId, {
        Name = player.Name,
        Key = player.UserId,
    }, database.datastore("Players"))
    if playerData then
        playerData:Update({ Online = true }):Save()
    end
end)

players.PlayerRemoving:Connect(function(player: Player)
    local playerData = database.cache(player.UserId)
    if playerData then
        playerData:Update({ Online = false }):Save() --or just playerData:Save()
    end
end)