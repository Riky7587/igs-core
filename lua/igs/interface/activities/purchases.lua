
hook.Add("IGS.CatchActivities","purchases",function(activity,sidebar)
	local bg = uigs.Create("Panel")
	
	bg.OnOpen = function()
		local frame = activity:GetParent()
		if frame and frame.SetSidebarVisible then
			frame:SetSidebarVisible(false)
		end
	end

	--[[-------------------------------------------------------------------------
		Основная часть фрейма
	---------------------------------------------------------------------------]]
	uigs.Create("igs_table", function(pnl)
		pnl:Dock(FILL)
		pnl:DockMargin(5,5,5,5)

		pnl:SetTitle("Активные покупки")

		local multisv = IGS.SERVERS.TOTAL > 1
		if multisv then
			pnl:AddColumn("Сервер",100)
		else
			pnl:AddColumn("#",40)
		end

		pnl:AddColumn("Предмет")
		pnl:AddColumn("Куплен",90)
		pnl:AddColumn("Истечет",90)
		pnl:AddColumn("Надето",70)


		IGS.GetMyPurchases(function(d)
			if !IsValid(pnl) then return end -- Долго данные получались, фрейм успели закрыть

			local function getEquippedText(purch, ITEM)
				if ITEM.isnull then return "Да" end

				-- Если покупка с другого сервера — статус надевания неизвестен (он локален для сервера)
				if purch.server and IGS.SERVERS and IGS.SERVERS:ID() and purch.server ~= IGS.SERVERS:ID() then
					return "—"
				end

				if not ITEM:HasReloadns() then
					return "Да"
				end

				local cat = ITEM:ReloadnsCategory()
				local equipped = LocalPlayer():GetIGSVar("igs_reloadns_equipped") or {}
				return equipped[cat] == ITEM:UID() and "Да" or "Нет"
			end

			local function updateAllEquipped()
				if not IsValid(pnl) then return end

				for _,line in ipairs(pnl.lines or {}) do
					local purch = line._igs_purchase
					local ITEM  = line._igs_item
					if purch and ITEM and line.columns and line.columns[5] then
						line.columns[5]:SetText( getEquippedText(purch, ITEM) )
					end
				end
			end

			local hookid = "IGS.ReloadnsEquippedUpdated.Purchases." .. tostring(pnl)
			hook.Add("IGS.ReloadnsEquippedUpdated", hookid, function()
				updateAllEquipped()
			end)
			pnl.OnRemove = function()
				hook.Remove("IGS.ReloadnsEquippedUpdated", hookid)
			end

			for i,v in ipairs(d) do
				local sv_name = IGS.ServerName(v.server)
				local ITEM    = IGS.GetItemByUID(v.item)
				local sName   = ITEM.isnull and v.item or ITEM:Name()

				local line = pnl:AddLine(
					-- v.id,
					multisv and sv_name or #d - i + 1,
					sName,
					IGS.TimestampToDate(v.purchase) or "Никогда",
					IGS.TimestampToDate(v.expire)   or "Никогда",
					getEquippedText(v, ITEM)
				)

				local tip = "Имя сервера: " .. sv_name .. "\nID в системе: " .. v.id .. "\nОригинальное название: " .. v.item
				if not ITEM.isnull and ITEM:HasReloadns() then
					tip = tip .. "\n\nПКМ по строке: Надеть/Снять"
				end

				line:SetTooltip(tip)
				line._igs_purchase = v
				line._igs_item = ITEM

				line.DoRightClick = function()
					if ITEM.isnull or not ITEM:HasReloadns() then return end

					-- Если в списке показываются покупки других серверов — не даем переключать
					if v.server and IGS.SERVERS and IGS.SERVERS:ID() and v.server ~= IGS.SERVERS:ID() then
						IGS.ShowNotify("Можно надевать/снимать только покупки текущего сервера", "IGS")
						return
					end

					local cat = ITEM:ReloadnsCategory()
					local equipped = LocalPlayer():GetIGSVar("igs_reloadns_equipped") or {}
					local currently = equipped[cat]
					local isEquipped = currently == ITEM:UID()

					local m = DermaMenu()
					if isEquipped then
						m:AddOption("Снять", function()
							IGS.ToggleReloadns(ITEM:UID())
						end)
					else
						m:AddOption("Надеть", function()
							IGS.ToggleReloadns(ITEM:UID())
						end)

						if currently then
							local CUR = IGS.GetItemByUID(currently)
							local curName = (not CUR.isnull) and CUR:Name() or currently
							m:AddOption(("Сейчас надето в категории %d: %s"):format(cat, curName), function() end):SetEnabled(false)
						else
							m:AddOption(("Категория %d сейчас пустая"):format(cat), function() end):SetEnabled(false)
						end
					end

					m:Open()
				end
			end

			-- На случай если netvar пришел чуть позже списка покупок
			updateAllEquipped()
		end)
	end, bg)

	activity:AddTab("Покупки",bg,"materials/icons/fa32/reorder.png")
end)

-- IGS.UI()
