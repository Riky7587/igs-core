local function loadTab(activity,sidebar,dat)
	local bg = uigs.Create("Panel")
	
	bg.OnRemove = function()
		hook.Remove("IGS.PlayerPurchasedItem","UpdateInventoryView")
	end

	bg.OnOpen = function()
		local frame = activity:GetParent()
		if frame and frame.SetSidebarVisible then
			frame:SetSidebarVisible(false)
		end
	end

	local content_w = activity:GetContentWide()
	
	-- Если инвентарь пустой, показываем красивое сообщение
	if #dat == 0 then
		local emptyPanel = uigs.Create("Panel", function(p)
			p:SetSize(content_w - 40, 200)
			p:SetPos(20, (activity:GetTall() - 200) / 2)
			
			p.Paint = function(s, w, h)
				-- Размытие фона если включено
				if RNDX and Mantle and Mantle.ui.convar.blur then
					RNDX().Rect(0, 0, w, h)
						:Rad(8)
						:Blur(1.0)
					:Draw()
				end
				
				draw.RoundedBox(8, 0, 0, w, h, ColorAlpha(IGS.col.PASSIVE_SELECTIONS, 100))
				
				-- Иконка
				surface.SetDrawColor(IGS.col.TEXT_SOFT)
				surface.SetMaterial(Material("materials/icons/fa32/cart-arrow-down.png"))
				surface.DrawTexturedRect((w - 64) / 2, 30, 64, 64)
			end
			
			local title = uigs.Create("DLabel", p)
			title:SetPos(0, 110)
			title:SetWide(p:GetWide())
			title:SetFont("Fated.24")
			title:SetTextColor(IGS.col.TEXT_HARD)
			title:SetText("Инвентарь пуст")
			title:SetContentAlignment(5)
			
			local desc = uigs.Create("DLabel", p)
			desc:SetPos(20, 145)
			desc:SetWide(p:GetWide() - 40)
			desc:SetFont("Fated.18")
			desc:SetTextColor(IGS.col.TEXT_SOFT)
			desc:SetText("Купленные предметы будут находиться здесь.\nВы сможете активировать их или передать другим игрокам.")
			desc:SetWrap(true)
			desc:SetAutoStretchVertical(true)
			desc:SetContentAlignment(5)
		end, bg)
	else
		-- Создаем скролл панель для карточек
		local scr = uigs.Create("igs_scroll", bg)
		scr:SetSize(content_w, activity:GetTall())
		scr:SetPos(0, 0)
		scr:SetSpacing(10)
		scr:SetPadding(10)

		-- Создаем layout для карточек
		scr:AddItem(uigs.Create("DIconLayout", function(icons)
		icons:SetWide(content_w - 20)
		icons:SetSpaceX(10)
		icons:SetSpaceY(10)
		icons.Paint = function() end

		local function removeFromCanvas(itemPan)
			if IsValid(itemPan) then
				itemPan:Remove()
			end
		end

		function icons:AddItem(ITEM, dbID)
			local item = icons:Add("igs_item")
			item:SetSize(140, 170) -- Стандартный размер карточки как в услугах
			item:HidePrice(true) -- Скрываем цену в инвентаре
			item:SetIcon(ITEM:ICON())
			item:SetName(ITEM:Name())
			-- Убрана надпись "Срок" - карточка показывает только название
			
			-- При клике открываем меню действий
			item.DoClick = function()
				-- Создаем красивое модальное окно вместо обычного меню
				local frame = uigs.Create("igs_frame", function(f)
					f:SetSize(300, 200)
					f:Center()
					f:MakePopup()
					f:SetTitle(ITEM:Name())
				end)
				
				local y = frame:GetTitleHeight() + 10
				
				-- Кнопка активации
				local activateBtn = uigs.Create("igs_button", function(btn)
					btn:SetPos(10, y)
					btn:SetSize(frame:GetWide() - 20, 35)
					btn:SetText("✓ Активировать")
					btn:SetActive(true)
					btn.DoClick = function()
						frame:Close()
						IGS.ProcessActivate(dbID, function(ok)
							if !ok then return end
							removeFromCanvas(item)
						end)
					end
				end, frame)
				
				y = y + 40
				
				-- Кнопка информации
				local infoBtn = uigs.Create("igs_button", function(btn)
					btn:SetPos(10, y)
					btn:SetSize(frame:GetWide() - 20, 35)
					btn:SetText("ℹ Информация")
					btn.DoClick = function()
						frame:Close()
						IGS.WIN.Item(ITEM:UID())
					end
				end, frame)
				
				y = y + 40
				
				-- Кнопка отмены
				local cancelBtn = uigs.Create("igs_button", function(btn)
					btn:SetPos(10, y)
					btn:SetSize(frame:GetWide() - 20, 35)
					btn:SetText("✖ Отмена")
					btn.DoClick = function()
						frame:Close()
					end
				end, frame)
				
				y = y + 45
				frame:SetTall(y)
			end
		end

		for _, v in ipairs(dat) do
			-- Добавляем только валидные предметы (null предметы уже очищены на сервере)
			icons:AddItem(v.item, v.id)
		end

			hook.Add("IGS.PlayerPurchasedItem", "UpdateInventoryView", function(_, ITEM, invDbID)
				-- Не добавляем null предметы в UI
				if not ITEM.isnull then
					icons:AddItem(ITEM, invDbID)
				end
			end)
		end))
	end

	activity:AddTab("Инвентарь", bg, "materials/icons/fa32/cart-arrow-down.png")
end

hook.Add("IGS.CatchActivities","inventory",function(activity,sidebar)
	if !IGS.C.Inv_Enabled then return end

	IGS.GetInventory(function(items)
		if !IsValid(sidebar) then return end
		loadTab(activity,sidebar,items)
	end)
end)

-- IGS.UI()
