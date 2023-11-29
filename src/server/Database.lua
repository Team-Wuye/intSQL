local datastoreService = game:GetService("DataStoreService")
local replicated = game:GetService("ReplicatedStorage")

local defaultStore = datastoreService:GetDataStore("Default")

local utility = require(replicated.Shared.Utility)



local module = {
	Soft = {},
    Cache = {} ::{ [number]: string | number | boolean | {} },
	CacheOld = {} ::{ [number]: string | number | boolean | {} },
    Data = {},
}

module.Data.__index = module.Data

--//
--** Creates a new table of data based on a required key and schema template.
--** It checks first to see if data is stored under the same key, and within the same store if provided. If success, it returns that data. Else, create new.
--** The function filterExistingData will fire and use existingData as its arguement, allowing one to change data upon retrieval and before load. 
--** This existingData table may be mutated or altered, but it must be returned by the filterExistingData function.
--** Returns true upon success and false upon failure.
--||
function module.new(key: (number | string), template: (number | string | boolean | {}), database: DataStore?): boolean
	local data = get(key, database or defaultStore)
	if data and typeof(data) == "table" and typeof(template) == "table" then
		for templateKey, templateValue in pairs(template) do
			if data[templateKey] then continue end
			data[templateKey] = templateValue
		end
	else
		data = template
    end

    local metaData = setmetatable({
        Key = key,
        Value = data,
        DataStoreName = (database and database.Name) or defaultStore.Name,
    }, module.Data)

    module.cache(key, metaData)

    return metaData
end

function module.cache(key: (number | string), value: (number | string | boolean | {}) ?): nil | (number | string | boolean | {})
    if value then
		if module.Cache[key] then
			module.CacheOld[key] = module.Cache[key]
		end
        module.Cache[key] = value
    else
        return module.Cache[key]
    end
end

function module.Data:Undo(): boolean
	local oldValue = module.CacheOld[self.Key]
	if oldValue then
		self.Value = oldValue
		return true
	else
		warn("Unable to undo data changes, there is no older version available.")
		return false
	end
end

function module.Data:Overwrite(value: (number | string | boolean | {})): {}
	self.Value = value
    return self
end

--[[
	Cycles through the provided variables and adds them to the self.Value table.
	If self.Value is not a table, it will warn but not through error. Please use self:Set() if you're interested in changing the value to a none table.
]]
function module.Data:Update(variablesToChange: { [number | string]: (number | string | boolean | {}) }): {}
    local newData = self.Value
	if typeof(self.Value) == "table" then
		for key, value in pairs(variablesToChange) do
			newData[key] = value
		end
	else
		warn("In order to update the data to the desired value(s), data must be of type table.")
	end

    self.Value = newData
    return self
end


--[[
    Slower version of self:Update().
    Searches through self.Value to find any variables with the same name as ones in variablesToChange.
    If it finds a match, set the self.Value's matched variables' value to the value from the matched variable in variablesToChange.
]]--
function module.Data:UpdateNested(variablesToChange: { [number | string]: (number | string | boolean | {}) }): {}
    local newData = self.Value
    for keyToMatch, valueToChange in pairs(self.Value) do
        for key, value in pairs(variablesToChange) do
            if keyToMatch == key then
                newData[key] = value
            end
        end
    end

    self.Value = newData
    return self
end



function module.Data:Save(parameters: { [string]: any }?): boolean
	self.Value = applyDefaultVariables(self.Value)

	return push(self.Key, self.Value, datastoreService:GetDataStore(self.DataStoreName))
end

function get(key: (number | string), store: DataStore): (number | string | boolean | {})
	local success, data = pcall(function()
		return store:GetAsync(key)
	end)
	if success then
		return data
	else
		warn(string.format("There was an issue loading data from %s based on the key: %i", store.Name, key))
		return false
	end
end

function push(key: number | string, value: number | string | boolean | {}, store: DataStore): boolean
	if not store then
		warn("You must provide a store, key, and a value in order to push data.")

		return false
	end

	local success, errorMessage = pcall(function()
		if typeof(value) == "table" then
			store:UpdateAsync(key, function(pastData)
				local newData = pastData
				if pastData and typeof(pastData) == "table" then
					for newKey, newValue in pairs(value) do
						newData[newKey] = newValue
					end
				end

				return newData
			end)
		else
			store:SetAsync(key, value)
		end
	end)
	
	if success then
		return true
	else
		warn(value)
		warn(errorMessage)

		return false
	end
end

function applyDefaultVariables(t: {}): {}
	if typeof(t) == "table" then
		if t["ChangeVersion"] then
			t.ChangeVersion += 1
		else
			t.ChangeVersion = 1
		end
		
		local formatedDateTime = utility.Time:DateFormatted()
		
		t["UpdatedAt"] = formatedDateTime
		
		if not t["CreatedAt"] then
			t["CreatedAt"] = formatedDateTime
		end
	else
		warn("To apply default variables, the provided t variable must be of type table.")
	end
	
	return t
end

function versionMatch(t: {}, t2: {}): boolean
	if t.ChangeVersion and t2.ChangeVersion then
		return (t.ChangeVersion <= t2.ChangeVersion)
	else
		return false
	end
end

return module
