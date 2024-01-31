local dataStoreService = game:GetService("DataStoreService")
local replicated = game:GetService("ReplicatedStorage")

local defaultStore = dataStoreService:GetDataStore("Default")

local utility = require(replicated.Shared.Utility)



local module = {
	Soft = {},
    Cache = {} ::{ [number]: string | number | boolean | {} },
    Data = {},
	Ordered = {},
	DataStores = {},
	OrderedDataStores = {
		["Global"] = dataStoreService:GetDataStore("OrderedDataStores")
	},
}

module.Data.__index = module.Data

--[[
	| First it attempts to load data using the @key, if none could be loaded it builds new data using the @template.

	@key
		| A unique key used to identify data.

	@template
		| Default data that should be present within the data entry, if pre-existing data is found it will fold the tables.

	@dataStoreName
		| Case sensitive string that will determine in which dataStore the data will be loaded from and saved to.
		| Also sets the ordered data store which holds the keys.

]]
function module.new(key: (number | string), template: (number | string | boolean | {}), dataStoreName: string?): { [string]: any }
	if not dataStoreName then dataStoreName = defaultStore.Name end
	local dataStore, _ = getDataStore(tostring(dataStoreName)), getOrderedDataStore(tostring(dataStoreName))

	local data = get(key, dataStore)
	if data then
		if typeof(data) == "table" and typeof(template) == "table" then
			for templateKey, templateValue in pairs(template) do
				if data[templateKey] then continue end
				data[templateKey] = templateValue
			end
		end
	else
		warn("Database was unable to load data located under the specified key, using template instead. Key: ", key)
		data = template
    end

    local metaData = setmetatable({
        Key = key,
        Value = data,
		Versions = {},
        DataStoreName = dataStoreName,
    }, module.Data)

    module.cache(key, metaData)

    return metaData
end

--[[
	| Stores the @key @value pair's using the provided ordered DataStore, found with @orderedDataStoreName.

	number @key
		| A unique key used to identify data.

	string @key

	string @orderedDataStoreName
		| Case sensitive string that will determine in which ordered dataStore the data will be loaded from and saved to.
		| Also sets the ordered data store which holds the key for all ordered dataStores.

]]
function module.Ordered.new(key: (number | string), orderedDataStoreName: string): { [string]: any }
	if not orderedDataStoreName then orderedDataStoreName = module.OrderedDataStores.Global.Name end
	local orderedStore = getOrderedDataStore(orderedDataStoreName)

    local metaData = setmetatable({
        Key = key,
        Value = 1,
		Versions = {},
        DataStoreName = orderedStore.Name,
		Type = "OrderedDataStore",
    }, module.Data)

    module.cache(key, metaData)

    return metaData
end

function getDataStore(dataStoreName: string): DataStore
	local dataStore = module.DataStores[dataStoreName]
	if not dataStore then
		dataStore = dataStoreService:GetDataStore(dataStoreName)
		module.DataStores[dataStoreName] = dataStore
	end

	return dataStore
end

function getOrderedDataStore(dataStoreName: string): OrderedDataStore
	local orderedStoreName = dataStoreName .. "_Ordered"
	local orderedDataStore = module.OrderedDataStores[orderedStoreName]
	if not orderedDataStore then
		orderedDataStore = dataStoreService:GetOrderedDataStore(orderedStoreName)
		module.OrderedDataStores[orderedStoreName] = orderedDataStore
	end

	return orderedDataStore
end

--[[
	Returns, and creates, if found nil, a dataStore based on the provided name.
]]
function module.Data:DataStore(): DataStore
	return getDataStore(self.DataStoreName)
end

--[[
	Returns, and creates, if found nil, an ordered dataStore based on the provided name.
]]
function module.Data:OrderedDataStore(): OrderedDataStore
	return getOrderedDataStore(self.DataStoreName)
end

--[[
	Incomplete
]]
function module.Ordered.get(name: string, isAscending: boolean?, pageSize: number?): Pages?
	local orderedDataStore = getOrderedDataStore(name)

	local pages = orderedDataStore:GetSortedAsync(isAscending or false, pageSize or 10)
	local pagesTable = pages:GetCurrentPage()

	for rank, data in ipairs(pagesTable) do
		local dataName = data.key
		local points = data.value
		print(dataName .. " is ranked #" .. rank .. " with " .. points .. " points")
	end

	return
end

--[[
	Caches data based on the @key, the data's value is set to @value, unless @value is nil in which case it returns the cache.

	ID @key
		| A unique key used to identify data.

	any @value
		| The value to be set as the cache data's value.

	nil @value
		| returns the cache based on the @key
]]
function module.cache(key: (string | number), value: any?): (number | string | boolean | {})
    if value then
        module.Cache[key] = value
		return true
    else
        return module.Cache[key]
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

    I am aware that recursive function calls could've been used here.
]]--
function module.Data:UpdateNested(variablesToChange: { [number | string]: (number | string | boolean | {}) }): {}
    local newData = self.Value
    for keyToMatch, _ in pairs(self.Value) do
        for key, value in pairs(variablesToChange) do
            if keyToMatch == key then
                newData[key] = value
            end
        end
    end

    self.Value = newData
    return self
end


function module.Data:Find(variablesToFind: { [string | number]: (number | string | boolean | {}) }): boolean | {}
	local variablesFound = {}
	for key, value in pairs(self.Value) do
		if variablesToFind[key] then
			variablesFound[key] = value
			continue
		end
	end

	return if #variablesFound == 0 then false else variablesFound
end


function module.Data:Save(parameters: { [string]: any }?): boolean
	self.Value = applyDefaultVariables(self.Value)

	local orderedDataStorePushSuccess = push(self.Key, self.Value.ChangeVersion, self:OrderedDataStore())
	if "OrderedDataStore" == self.Type then
		return orderedDataStorePushSuccess
	end

	local dataStorePushSuccess = push(self.Key, self.Value, self:DataStore())
	return dataStorePushSuccess
end

function get(key: (number | string), store: DataStore): (number | string | boolean | {})
	local success, data = pcall(function()
		return store:GetAsync(tostring(key))
	end)
	if success then
		return data
	else
		warn(string.format("There was an issue while running get data from %s based on the key: %s", (store and store.Name), tostring(key)))
		return false
	end
end

function push(key: number | string, value: number | string | boolean | {}, dataStore: DataStore | OrderedDataStore): boolean
	if not dataStore then
		warn(string.format("You must provide a key ( %s ), value ( %s ), and a dataStore or ordered dataStore ( nil ) in order to push data.", tostring(key), tostring(value)))

		return false
	end

	local success, errorMessage = pcall(function()
		if typeof(value) == "table" and dataStore:IsA("DataStore") then
			dataStore:UpdateAsync(tostring(key), function(pastData)
				local newData = pastData
				if pastData and typeof(pastData) == "table" then
					for newKey, newValue in pairs(value) do
						newData[newKey] = newValue
					end
				else
					return value
				end

				return newData
			end)
		else
			dataStore:SetAsync(key, value)
		end
	end)

	if success then
		warn("Saved data:", value, "to", key, "in datastore:", dataStore.Name)
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
			t["ChangeVersion"] += 1
		else
			t["ChangeVersion"] = 1
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
	if t["ChangeVersion"] and t2["ChangeVersion"] then
		return (t["ChangeVersion"] <= t2["ChangeVersion"])
	else
		return false
	end
end

return module
