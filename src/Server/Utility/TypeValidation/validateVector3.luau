local function validateVector3(vector3: Vector3): boolean
	-- Make sure this is actually a Vector3
	if typeof(vector3) ~= "Vector3" then
		return false
	end

	-- Make sure the vector3 does not contain any NaN components
	if vector3 ~= vector3 then
		return false
	end

	-- Make sure the vector3 does not contain any ±Infinity components
	if vector3.X == math.huge or vector3.X == -math.huge then
		return false
	end
	if vector3.Y == math.huge or vector3.Y == -math.huge then
		return false
	end
	if vector3.Z == math.huge or vector3.Z == -math.huge then
		return false
	end

	return true
end

return validateVector3
