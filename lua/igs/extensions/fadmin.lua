-- Кто-то использует FAdmin, как отдельный аддон к другим гейммодам? О_о

local STORE_ITEM = FindMetaTable("IGSItem")

local function getGroupImmunity(group)
	if not FAdmin or not FAdmin.Access or not FAdmin.Access.Groups then return nil end
	local g = FAdmin.Access.Groups[group]
	return g and g.immunity
end

function STORE_ITEM:SetFAdminGroup(sGroup, iWeight)
	return self:SetInstaller(function(pl)
		-- Не понижаем привилегии: если текущая выше или равна, пропускаем
		local curGroup = pl:GetUserGroup()
		local curImm   = getGroupImmunity(curGroup)
		local newImm   = getGroupImmunity(sGroup)

		if curImm and newImm and curImm >= newImm then
			return
		end

		FAdmin.Access.PlayerSetGroup(pl, sGroup)
		pl.IGSFAdminWeight = iWeight
	end):SetValidator(function(pl)
		-- Если уже в нужной группе — ок
		if pl:IsUserGroup(sGroup) then
			return true
		end

		-- Проверяем иммунитеты из DarkRP/FAdmin
		local curImm = getGroupImmunity(pl:GetUserGroup())
		local newImm = getGroupImmunity(sGroup)
		if curImm and newImm and curImm >= newImm then
			return true
		end

		-- Фолбэк на старые веса, если иммунитетов нет
		if pl.IGSFAdminWeight then
			return iWeight < pl.IGSFAdminWeight
		end

		return false
	end)
end
