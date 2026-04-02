local function validateSimpleTable(tbl: {[any]: any}, keyType: string, validator: (any) -> boolean, maxCount: number?): boolean
	-- Make sure this is actually a table
	if typeof(tbl) ~= "table" then
		return false
	end

	-- Validate all keys and values
	local count = 0
	for key, value in tbl do
		count += 1
		if maxCount and count > maxCount then return false end
		if typeof(key) ~= keyType then
			return false
		end

		if not validator(value) then
			return false
		end
	end

	return true
end

return validateSimpleTable
