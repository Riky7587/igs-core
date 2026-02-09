-- Кто-то использует FAdmin, как отдельный аддон к другим гейммодам? О_о

local STORE_ITEM = FindMetaTable("IGSItem")

local function getGroupImmunity(group)
	if not FAdmin or not FAdmin.Access or not FAdmin.Access.Groups then return nil end
	local g = FAdmin.Access.Groups[group]
	return g and g.immunity
end

local function setGroupWithCAMI(pl, newGroup)
	if not IsValid(pl) then return end
	if not FAdmin or not FAdmin.Access or not FAdmin.Access.Groups then return end
	if not FAdmin.Access.Groups[newGroup] then return end

	local oldGroup = pl:GetUserGroup()
	if oldGroup == newGroup then return end

	FAdmin.Access.PlayerSetGroup(pl, newGroup)

	-- Сохраняем в FAdmin_PlayerGroup (через CAMI хук), чтобы переживало перезаход
	if CAMI and CAMI.SignalUserGroupChanged then
		CAMI.SignalUserGroupChanged(pl, oldGroup, newGroup, "IGS")
	end
end

function STORE_ITEM:SetFAdminGroup(sGroup, iWeight)
	-- Запоминаем группу для последующего восстановления
	if SERVER then
		self:SetMeta("fadmin_group", sGroup)
	end

	return self:SetInstaller(function(pl)
		-- Не понижаем привилегии: если текущая выше или равна, пропускаем
		local curGroup = pl:GetUserGroup()
		local curImm   = getGroupImmunity(curGroup)
		local newImm   = getGroupImmunity(sGroup)

		if curImm and newImm and curImm >= newImm then
			return
		end

		setGroupWithCAMI(pl, sGroup)
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

-- Восстановление максимальной купленной привилегии
if SERVER then
	function IGS.ApplyBestFAdminGroup(pl, purchases)
		if not IsValid(pl) then return end
		if not FAdmin or not FAdmin.Access or not FAdmin.Access.Groups then return end
		if not purchases then return end

		local bestGroup, bestImm

		for uid in pairs(purchases) do
			local ITEM = IGS.GetItemByUID(uid)
			if ITEM and ITEM.GetMeta then
				local grp = ITEM:GetMeta("fadmin_group")
				if grp then
					local imm = getGroupImmunity(grp)
					if imm and (not bestImm or imm > bestImm) then
						bestImm = imm
						bestGroup = grp
					end
				end
			end
		end

		if not bestGroup then return end

		local curGroup = pl:GetUserGroup()
		local curImm = getGroupImmunity(curGroup)

		-- Если текущая группа ниже купленной — возвращаем купленную
		if not curImm or (bestImm and bestImm > curImm) then
			setGroupWithCAMI(pl, bestGroup)
		end
	end
end
