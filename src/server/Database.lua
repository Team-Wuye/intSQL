local datastoreService = game:GetService("DataStoreService")
local replicated = game:GetService("ReplicatedStorage")

local defaultStore = datastoreService:GetDataStore("Default")

local utility = require(replicated.Shared.Utility)



local module = {
	Soft = {},
	Ordered = {},
    Cache = {} ::{ [number]: string | number | boolean | {} },
    Data = {},
	Datastores = {},
	OrderedDataStores = {},
}

module.Data.__index = module.Data

--[[
	First it attempts to load data using the @key, if none could be loaded it builds new data using the @template.

	@key
		A unique key used to identify data.

	@template
		Default data that should be present within the data entry, if pre-existing data is found it will fold the tables.

	@datastoreName
		Case sensitive string that will determine in which datastore the data will be loaded and saved from.
		Also sets the ordered data store which holds the keys.
	
]]
function module.new(key: (number | string), template: (number | string | boolean | {}), datastoreName: string?): boolean
	local datastore = if datastoreName then module.datastore(datastoreName) else nil
	local data = get(key, datastore or defaultStore)
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
		Versions = {},
        DataStoreName = datastoreName or defaultStore.Name,
    }, module.Data)

    module.cache(key, metaData)

	if not module.OrderedDataStores[datastoreName] then
		module.Ordered.datastore(datastoreName)
	end

    return metaData
end

--[[
	Returns, and creates, if nil, a datastore based on the provided name.

	string @name 
		| A string specifying which datastore is to be used.
]]
function module.datastore(name: string): DataStore
	local datastore = module.Datastores[name]
	if not datastore then
		datastore = datastoreService:GetDataStore(name)
		module.Datastores[name] = datastore
	end

	return datastore
end

--[[
	Returns, and creates, if nil, an ordered datastore based on the provided name.

	string @name 
		| A string specifying which ordered datastore is to be used.
]]
function module.Ordered.datastore(name: string): OrderedDataStore
	local orderedStore = module.OrderedDataStores[name]
	if not orderedStore then
		orderedStore = datastoreService:GetDataStore(name)
		module.OrderedDataStores[name] = orderedStore
	end

	return orderedStore
end


function module.Ordered.load(name: string): Pages

end

--[[
	Caches data based on the @key, the data's value is set to @value.

	ID @key
		| A unique key used to identify data.

	any @value
		| The value to be set as the cache data's value.
	
	nil @value
		| returns the cache based on the @key
]]
function module.cache(key: (number | string), value: any?): nil | (number | string | boolean | {})
    if value then
        module.Cache[key] = value
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



function module.Data:Save(parameters: { [string]: any }?): boolean
	self.Value = applyDefaultVariables(self.Value)

	local storePushSuccess = push(self.Key, self.Value, module.datastore(self.DataStoreName))
	local orderedPushSuccess = push(self.Key, self.Value.ChangeVersion, module.orderedstore(self.DataStoreName))

	return (storePushSuccess and orderedPushSuccess)
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

function push(key: number | string, value: number | string | boolean | {}, datastore: DataStore | OrderedDataStore): boolean
	if not datastore then
		warn(string.format("You must provide a key ( %s ), value ( %s ), and a datastore or ordered datastore in order to push data.", tostring(datastore.Name), tostring(key)))
		warn("You must provide a store, key, and a value in order to push data.")

		return false
	end

	local success, errorMessage = pcall(function()
		if typeof(value) == "table" then
			datastore:UpdateAsync(key, function(pastData)
				local newData = pastData
				if pastData and typeof(pastData) == "table" then
					for newKey, newValue in pairs(value) do
						newData[newKey] = newValue
					end
				end

				return newData
			end)
		else
			datastore:SetAsync(key, value)
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
