---@diagnostic disable-next-line: invalid-class-name | Caused because of my KRNL LSP, cheaters don't have access to DataStore API so it wasn't included in their luaU server.
local datastore: DataStoreService = game:GetService("DataStore")



local module = {}

local stri = "SELECT * FROM {Some API DataStore's name, aka table}" --Gets all entries in that roblox datastore

function module:Run(commands: string)
	local commandsSplitTable: { [number]: string } = string.split(commands, " ")
	

	local statementName: string = commandsSplitTable[1]:upper()
	local queryAll: boolean = false
	local columnNames = {}
	
	if commandsSplitTable[2]:upper() == "*" then
		queryAll = true
	else
		for i = 2, #commandsSplitTable do
			local currentColumn = commandsSplitTable[i]
			local columnSplitTable = currentColumn:split("")
			if columnSplitTable[#columnSplitTable] == "," then
				table.insert(columnNames, currentColumn)
				continue
			else
				break
			end
		end
	end
	
	
	local targetTableName: string = commandsSplitTable[4 + #columnNames]:upper()
	
	local clause = commandsSplitTable[5 + #columnNames]:upper()
	local condition
	local conditionColumnNames: {}
	
	if clause == "WHERE" then
		condition = commandsSplitTable[6 + #columnNames]:upper()
	elseif clause == "ORDER" and "BY" == commandsSplitTable[6 + #columnNames]:upper() then
		conditionColumnNames = {}
		for i = 7 + #columnNames, commandsSplitTable[6 + #columnNames] do
            local currentColumn = commandsSplitTable[i]
			local columnSplitTable = currentColumn:split("")
			if columnSplitTable[#columnSplitTable] == "," then
				table.insert(conditionColumnNames, currentColumn)
				continue
			else
				break
			end
		end
	end

    local data
    local database: DataStore

    if statementName == "SELECT" then
        if queryAll then
            --database = datastore:GetDataStore(targetTableName)


        else

        end
    end
end


return module