local null = function() end
local etoGlavnayaVkladkaBlya = true

hook.Add("IGS.CatchActivities","main",function(activity,sidebar)
	local bg = uigs.Create("Panel")

	-- Панель тегов и готовая кнопка сброса фильтров
	local tagspan = uigs.Create("Panel", bg)
	local content_w = activity:GetContentWide()
	tagspan:SetWide(content_w)
	tagspan:SetPos(0, 0)
	tagspan.Paint = function(s,w,h)
		IGS.S.Panel(s,w,h,nil,nil,nil,true)
	end

	-- сетка https://img.qweqwe.ovh/1487714173294.png
	bg.tags = uigs.Create("DIconLayout", function(tags)
		tags:SetWide(content_w - 5 - 5)
		tags:SetPos(5,5)
		tags:SetSpaceX(10)
		tags:SetSpaceY(10)
		tags.Paint = null

		function tags:AddTag(sName, doClick, sIcon)
			local tag = uigs.Create("igs_button")
			tag:SetTall(18)
			
			-- Если есть иконка, добавляем пробелы для смещения текста
			if sIcon then
				tag:SetText("      " .. sName .. " ") -- дополнительные пробелы для иконки
			else
				tag:SetText(" " .. sName .. " ") -- костыль для расширения кнопки
			end
			
			tag:SizeToContents()
			tag.DoClick = doClick
			
			-- Если есть иконка, рисуем её поверх
			if sIcon then
				tag.categoryIcon = Material(sIcon)
				tag.isCategory = true -- флаг для особого стиля категорий
				
				-- Устанавливаем яркий цвет текста для категории
				tag:SetTextColor(IGS.col.TEXT_ON_HIGHLIGHT)
				
				-- Рисуем иконку поверх всего (после текста)
				tag.PaintOver = function(s, w, h)
					if s.categoryIcon then
						-- Иконка всегда яркая
						surface.SetDrawColor(IGS.col.TEXT_ON_HIGHLIGHT)
						surface.SetMaterial(s.categoryIcon)
						surface.DrawTexturedRect(4, 2, 14, 14)
					end
				end
			end

			self:Add(tag)

			tags:InvalidateLayout(true) -- tags:GetTall()
			tagspan:SetTall(tags:GetTall() + 5 + 5)

			local y = tagspan:GetTall()

			-- Расхождение вот тут:
			-- https://img.qweqwe.ovh/1493840355855.png
			-- y = y - 10 -- UPD 2020 t.me/c/1353676159/7888

			bg.categs:SetTall(activity:GetTall() - y)
			bg.categs:SetPos(0,y)
			return tag
		end
	end, tagspan)

	bg.categs = uigs.Create("igs_panels_layout_list", bg) -- center panel
	bg.categs:DisableAlignment(true)
	bg.categs:SetWide(content_w)

	-- Раскомментить, если захочу убрать теги
	-- bg.categs:SetTall(activity:GetTall() - activity.tabBar:GetTall())
	-- bg.categs:SetPos(0,y)


	-- category = true
	local cats = {}

	local function addItems(fItemsFilter,fGroupFilter)
		local rows = {}

		for _,GROUP in pairs( IGS.GetGroups() ) do -- name
			if fGroupFilter and fGroupFilter(GROUP) == false then continue end

			local pnl = uigs.Create("igs_group"):SetGroup(GROUP)
			pnl.category = GROUP:Items()[1].item:Category() -- предполагаем, что в одной группе будут итемы одной категории

			table.insert(rows,pnl)
		end

		-- не (i)pairs, потому что какой-то ID в каком-то очень редком случае может отсутствовать
		-- если его кто-то принудительно занилит, чтобы убрать итем например.
		-- Хотя маловероятно, но все же
		for _,ITEM in pairs(IGS.GetItems()) do
			if fItemsFilter and fItemsFilter(ITEM) == false then continue end
			if ITEM:IsHidden() then continue end -- еще в IGS.WIN.Group
			if ITEM:Group()    then continue end -- группированные итемы засунуты в группу выше
			if ITEM.isnull     then continue end -- пустышка

			local pnl = uigs.Create("igs_item"):SetItem(ITEM)
			pnl.category = ITEM:Category()

			table.insert(rows,pnl)
		end

		for _,pnl in ipairs(rows) do
			bg.categs:Add(pnl,pnl.category or "Разное").title:SetTextColor(IGS.col.TEXT_HARD) -- http://joxi.ru/Y2LqqyBh5BODA6
			cats[pnl.category or "Разное"] = true
		end
	end
	addItems()



	--[[-------------------------------------------------------------------------
		Теги (Быстрый выбор категории)
	---------------------------------------------------------------------------]]
	local cat_list = {}
	for categ in pairs(cats) do
		table.insert(cat_list, categ)
	end
	table.sort(cat_list, function(a, b) return tostring(a) < tostring(b) end)

	for i, categ in ipairs(cat_list) do
		-- Получаем иконку для категории
		local categoryIcon = IGS.GetCategoryIcon(categ)
		
		local tag = bg.tags:AddTag(categ, function(self)
			-- Сбрасываем активное состояние со всех тегов
			for _, child in ipairs(bg.tags:GetChildren()) do
				if child.SetActive then
					child:SetActive(false)
				end
			end
			
			-- Устанавливаем активное состояние только на текущий тег
			self:SetActive(true)
			
			-- Предзагружаем иконки товаров этой категории
			for uid, ITEM in pairs(IGS.ITEMS.STORED or {}) do
				local itemCategory = ITEM:Category()
				local matchesCategory = (self.categ == "Разное" and !itemCategory) or (itemCategory == self.categ)
				
				if matchesCategory then
					local icon = ITEM:ICON()
					if icon and icon:match("^https?://") and not texture.Get(icon) then
						texture.Create(icon)
							:SetSize(256, 256)
							:SetFormat(icon:sub(-3) == "jpg" and "jpg" or "png")
							:Download(icon)
					end
				end
			end
			
			bg.categs:Clear()

			-- #todo переписать это говнище
			addItems(function(ITEM)
				return self.categ == "Разное" and !ITEM:Category() or (ITEM:Category() == self.categ)
			end,function(GROUP)
				return self.categ == "Разное" and !GROUP:Items()[1].item:Category() or (GROUP:Items()[1].item:Category() == self.categ)
			end)
		end, categoryIcon)
		tag.categ = categ

		if i == 1 then
			bg.firstTag = tag
			tag:SetActive(true)
			tag:DoClick()
		end
	end
	bg.OnOpen = function()
		local frame = activity:GetParent()
		if frame and frame.SetSidebarVisible then
			frame:SetSidebarVisible(false)
		end

		local new_w = activity:GetContentWide()
		tagspan:SetWide(new_w)
		tagspan:SetPos(0, 0)
		bg.tags:SetWide(new_w - 5 - 5)
		bg.categs:SetWide(new_w)
		bg.categs:SetTall(activity:GetTall() - tagspan:GetTall())
		bg.categs:SetPos(0, tagspan:GetTall())

		-- На первом открытии пересобираем список после корректной ширины
		if not bg._firstOpen then
			bg._firstOpen = true
			if IsValid(bg.firstTag) then
				bg.firstTag:DoClick()
			end
		end
	end

	activity:AddTab("Услуги",bg,"materials/icons/fa32/rub.png",etoGlavnayaVkladkaBlya)
end)

-- local p = IGS.UI()
-- timer.Simple(3,function() if IsValid(p) then p:Remove() end end)
