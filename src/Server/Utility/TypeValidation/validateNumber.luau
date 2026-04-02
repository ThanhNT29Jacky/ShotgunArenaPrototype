local function validateNumber(number: number): boolean
	-- Make sure this is actually a number
	if typeof(number) ~= "number" then
		return false
	end

	-- Make sure the number is not NaN
	if number ~= number then
		return false
	end

	-- Make sure the number is not ±Infinity
	if number == math.huge or number == -math.huge then
		return false
	end

	return true
end

return validateNumber
