MountifulLocalization = {}
local L = MountifulLocalization
--@localization(locale="enUS", format="lua_table_additive",handle-unlocalized="english")@

setmetatable(MountifulLocalization, {__index = function(self, key)
	if MOdebug then ChatFrame3:AddMessage('Please localize: '..tostring(key)) end;
	rawset(self, key, key)
	return key
end })



