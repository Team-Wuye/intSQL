local module = {
	Time = {},
	Threader = {},
}

function module.Time:DateFormatted(dateTime: DateTime?)
	local currentDateTime = (dateTime or DateTime.now()):ToUniversalTime()
	return string.format(
		"%02i:%02i %i.%i.%i", 
		currentDateTime.Hour, 
		currentDateTime.Minute, 
		currentDateTime.Day, 
		currentDateTime.Month, 
		currentDateTime.Year
	)
end

function module.Threader:Fast(connection: () -> ())
	local thread = Instance.new("BindableEvent")
	thread.Event:Connect(connection)
	thread:Fire()
	thread:Destroy()
end

return module
