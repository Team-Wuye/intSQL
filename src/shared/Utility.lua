local module = {
	Time = {}
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

return module
