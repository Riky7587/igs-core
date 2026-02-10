
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


		IGS.GetMyPurchases(function(d)
			if !IsValid(pnl) then return end -- Долго данные получались, фрейм успели закрыть

			for i,v in ipairs(d) do
				local sv_name = IGS.ServerName(v.server)
				local ITEM    = IGS.GetItemByUID(v.item)
				local sName   = ITEM.isnull and v.item or ITEM:Name()

				pnl:AddLine(
					-- v.id,
					multisv and sv_name or #d - i + 1,
					sName,
					IGS.TimestampToDate(v.purchase) or "Никогда",
					IGS.TimestampToDate(v.expire)   or "Никогда"
				):SetTooltip("Имя сервера: " .. sv_name .. "\nID в системе: " .. v.id .. "\nОригинальное название: " .. v.item)
			end
		end)
	end, bg)

	activity:AddTab("Покупки",bg,"materials/icons/fa32/reorder.png")
end)

-- IGS.UI()
