--[[-------------------------------------------------------------------------
	:SetIcon ДОЛЖЕН вызываться ДО :SetName
	а :SetName ДОЛЖЕН вызываться ДО :SetSign
---------------------------------------------------------------------------]]
local PANEL = {}

local function formatRub(iReal)
	return math.Truncate(tonumber(iReal),2) .. " ₽"
end

local function getBottomText(ITEM, bShowDiscounted)
	-- Приоритет: индивидуальная скидка > глобальная скидка > обычная цена
	local iDiscFrom = bShowDiscounted and ITEM.discounted_from
	local iReal = iDiscFrom or ITEM:Price()
	
	-- Если показываем скидку и нет индивидуальной скидки, применяем глобальную
	if bShowDiscounted and !iDiscFrom and IGS.HasGlobalDiscount() then
		iReal = IGS.GetDiscountedPrice(ITEM:Price())
	end

	local iCurr = IGS.PriceInCurrency(iReal)

	local real = formatRub(iReal)
	local curr = IGS.SignPrice(iCurr)

	if IGS.IsCurrencyEnabled() then
		return real .. " (" .. curr .. ")"
	else
		return real
	end
end

-- Оптимизация FPS: blur убран из DrawRoundedPanel для иконок (много вызовов = просадка)
local function DrawRoundedPanel(x, y, w, h, radius, outline_col, fill_col, outline_thick)
	if RNDX then
		RNDX.Draw(radius, x, y, w, h, fill_col)
		RNDX.DrawOutlined(radius, x, y, w, h, outline_col, outline_thick or 1)
		return
	end

	draw.RoundedBox(radius, x, y, w, h, outline_col)
	draw.RoundedBox(radius, x + 1, y + 1, w - 2, h - 2, fill_col)
end

local function DrawPriceTag(x, y, w, h, outline_col, fill_col, outline_thick)
	local r = h / 2
	if RNDX and RNDX.NO_TR and RNDX.NO_BL then
		-- TL rounded, TR sharp, BL sharp, BR rounded
		local flags = bit.bor(RNDX.NO_TR, RNDX.NO_BL)
		RNDX.Draw(r, x, y, w, h, fill_col, flags)
		RNDX.DrawOutlined(r, x, y, w, h, outline_col, outline_thick or 1, flags)
		return
	end

	draw.RoundedBoxEx(r, x, y, w, h, outline_col, true, false, false, true)
	draw.RoundedBoxEx(r, x + 1, y + 1, w - 2, h - 2, fill_col, true, false, false, true)
end

local function DrawPriceTagFilled(x, y, w, h, fill_col)
	local r = h / 2
	local r2 = r + 4
	if RNDX and RNDX.NO_TR and RNDX.NO_BL then
		local flags = bit.bor(RNDX.NO_TR, RNDX.NO_BL)
		RNDX.Draw(r, x, y, w, h, fill_col, flags)
		-- усиливаем скругление правого нижнего угла
		RNDX.DrawCircle(x + w - r2, y + h - r2, r2 * 2, fill_col)
		return
	end

	draw.RoundedBoxEx(r, x, y, w, h, fill_col, true, false, false, true)
	draw.RoundedBox(r2, x + w - r2 * 2, y + h - r2 * 2, r2 * 2, r2 * 2, fill_col)
end

local CARD_BG = Color(35, 35, 35, 220)
local NAME_BG = Color(45, 45, 45, 200)
local PRICE_BG = Color(55, 55, 55, 210)


function PANEL:Init()
	self:SetSize(140,170) -- увеличена высота для равных отступов сверху/снизу
	self.compact = false
	self.iconbg = uigs.Create("Panel", self)
	self.iconbg:SetSize(self:GetWide(), self:GetWide()) -- квадратная зона иконки
	self.iconbg:SetPos(0, 0)
	self.iconbg.Paint = function(_, w, h)
		DrawRoundedPanel(0, 0, w, h, 6, IGS.col.HARD_LINE, IGS.col.INNER_SELECTIONS)
	end

end

function PANEL:SetItem(STORE_ITEM)
	self.item = STORE_ITEM

	self:SetIcon(STORE_ITEM:ICON())
	self:SetName(STORE_ITEM:Name())
	-- self:SetPrice(STORE_ITEM:Price())

	self:SetTitleColor(STORE_ITEM:GetHighlightColor()) -- nil
	self:SetPriceOnIcon( getBottomText(STORE_ITEM, true) )

	return self
end

function PANEL:SetName(sName)
	(self.icon or self):SetTooltip(sName .. (self.item and "\n\n" .. self.item:Description():gsub("\n\n","\n") or ""))

	self.name = self.name or uigs.Create("DLabel", function(lbl)
		lbl:SetTall(20)
		lbl:SetFont("Fated.15b")
		lbl:SetTextColor(color_white)
		lbl:SetText("")

		lbl.Paint = function(s,w,h)
			local text = s._igs_text or ""
			if text == "" then return end

			surface.SetFont(s:GetFont())
			DrawRoundedPanel(0, 0, w, h, 6, Color(128, 0, 32, 255), NAME_BG)
			draw.SimpleText(
				text,
				s:GetFont(),
				w / 2,
				h / 2,
				s:GetTextColor(),
				TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER
			)
		end
	end, self)

	self.name._igs_text = sName

	return self.name
end

function PANEL:SetPriceOnIcon(sPrice)
	if self.compact or !self.iconbg or self.hidePrice then return end

	self.price_on_icon = self.price_on_icon or uigs.Create("DLabel", function(lbl)
		lbl:SetFont("Fated.15b")
		lbl:SetTextColor(color_white)
		lbl:SetContentAlignment(5) -- центр
		lbl.Paint = function(s,w,h)
			DrawPriceTagFilled(0, 0, w, h, PRICE_BG)
			
			-- Рисуем старую цену зачеркнутой, если есть скидка
			if s.oldPrice then
				local font = "Fated.14"
				local oldPriceText = s.oldPrice
				local currentPriceText = s:GetText()
				
				surface.SetFont(font)
				local oldPriceWidth = surface.GetTextSize(oldPriceText)
				
				surface.SetFont(s:GetFont())
				local currentPriceWidth = surface.GetTextSize(currentPriceText)
				
				local totalWidth = oldPriceWidth + 8 + currentPriceWidth
				local startX = (w - totalWidth) / 2
				
				-- Рисуем старую цену слева (серая и меньше)
				draw.SimpleText(
					oldPriceText,
					font,
					startX,
					h / 2,
					Color(180, 180, 180, 200),
					TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER
				)
				
				-- Зачеркиваем старую цену
				surface.SetDrawColor(Color(200, 200, 200, 200))
				local lineY = h / 2
				surface.DrawLine(startX, lineY, startX + oldPriceWidth, lineY)
				
				-- Рисуем текущую цену справа
				draw.SimpleText(
					currentPriceText,
					s:GetFont(),
					startX + oldPriceWidth + 8,
					h / 2,
					s:GetTextColor(),
					TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER
				)
				
				return true
			end
		end
	end, self.iconbg)

	self.price_on_icon:SetText(sPrice)
	self.price_on_icon:SizeToContents()
	
	-- Проверяем, есть ли скидка (индивидуальная или глобальная)
	local hasDiscount = false
	if self.item then
		hasDiscount = self.item.discounted_from or IGS.HasGlobalDiscount()
	end
	
	-- Если есть скидка, добавляем место для старой цены
	if hasDiscount then
		local oldPrice = getBottomText(self.item, false)
		self.price_on_icon.oldPrice = oldPrice
		
		-- Увеличиваем ширину для двух цен
		surface.SetFont("Fated.14")
		local oldPriceWidth = surface.GetTextSize(oldPrice)
		surface.SetFont("Fated.15b")
		local currentPriceWidth = surface.GetTextSize(sPrice)
		
		local totalWidth = oldPriceWidth + 8 + currentPriceWidth + 10
		self.price_on_icon:SetSize(totalWidth, self.price_on_icon:GetTall() + 6)
	else
		self.price_on_icon.oldPrice = nil
		self.price_on_icon:SetSize(self.price_on_icon:GetWide() + 10, self.price_on_icon:GetTall() + 6)
	end
end

function PANEL:HidePrice(bHide)
	self.hidePrice = bHide
	if self.price_on_icon then
		self.price_on_icon:SetVisible(!bHide)
	end
	return self
end

function PANEL:SetCompact(bCompact)
	self.compact = bCompact

	if IsValid(self.iconbg) then
		local size = self.compact and 40 or 90
		self.iconbg:SetSize(size, size)
	end

	if self.price_on_icon then
		self.price_on_icon:SetVisible(!self.compact)
	end
end

function PANEL:SetSign(sSignature)
	self.sign = self.sign or uigs.Create("DLabel", function(lbl)
		lbl:SetTall(15)
		lbl:SetFont("Fated.15")
		lbl:SetTextColor(IGS.col.TEXT_SOFT)
	end, self)

	self.sign:SetText(sSignature)

	return self.sign
end

function PANEL:SetBottomText(sBottomText)
	self.bottom = self.bottom or uigs.Create("DLabel", function(lbl)
		lbl:SetTall(15)
		lbl:SetFont("Fated.15")
		lbl:SetTextColor(IGS.col.TEXT_SOFT)
		lbl:SetContentAlignment(5)
		-- lbl:SetWrap(true)
		-- lbl:SetAutoStretchVertical(true)
	end, self)

	self.bottom:SetText(sBottomText)

	return self.bottom
end

-- TODO снизу в рамочку и DOCK RIGHT вместе с док фильным сроком
-- function PANEL:SetPrice(iPrice)
-- 	self.price = iPrice
-- 	return self
-- end

function PANEL:SetIcon(sIco,bIsModel) -- :SetIcon() для сброса
	if !sIco then return self end

	if bIsModel and !file.Exists(sIco, "GAME") then
		sIco = "models/props_lab/huladoll.mdl"
	end

	if !self.icon then
		self.icon = bIsModel and uigs.Create("DModelPanel", function(mdl)
			mdl:Dock(FILL)
			mdl:DockMargin(2,2,2,2)
			mdl:SetModel(sIco)

			local mn, mx = mdl.Entity:GetRenderBounds()
			local size = 0
			size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
			size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
			size = math.max(size, math.abs(mn.z) + math.abs(mx.z))

			mdl:SetFOV(30)
			mdl:SetCamPos(Vector(size, size, size))
			mdl:SetLookAt((mn + mx) * 0.5)
			mdl.LayoutEntity = function() return false end -- отключаем анимацию для экономии FPS
		end, self.iconbg)

		-- НЕ моделька (Ссылка на иконку)
		or

		uigs.Create("igs_wmat", function(ico)
			ico:Dock(FILL)
			ico:DockMargin(2,2,2,2)
		end, self.iconbg)
	end

	if bIsModel then
		self.icon:SetModel(sIco)
	else
		self.icon:SetURL(sIco)
	end

	return self
end

function PANEL:DoClick()
	IGS.WIN.Item(self.item:UID()) -- Обязательно предварительно SetItem
end

-- Оптимизация FPS: скрываем DModelPanel когда карточка вне видимой области скролла
function PANEL:Think()
	if not self.icon or self.icon.ClassName ~= "DModelPanel" then return end
	local scroll = self
	while IsValid(scroll) and scroll.yOffset == nil do
		scroll = scroll:GetParent()
	end
	if not IsValid(scroll) then
		self.icon:SetVisible(true)
		return
	end
	if not self._nextVisCheck or CurTime() >= self._nextVisCheck then
		self._nextVisCheck = CurTime() + 0.1
		local itemY = select(2, self:GetPos())
		local p = self:GetParent()
		while IsValid(p) and p ~= scroll do
			itemY = itemY + select(2, p:GetPos())
			p = p:GetParent()
		end
		-- itemY = позиция в viewport (учитывая canvas.y = -yOffset)
		local vis = (itemY >= 0) and (itemY + self:GetTall() <= scroll:GetTall())
		self.icon:SetVisible(vis)
	end
end

function PANEL:PerformLayout()
	if self.compact then
		if IsValid(self.iconbg) then
			self.iconbg:SetSize(40, 40)
			self.iconbg:SetPos(2, 2)
		end

		if self.name then
			local x = 2 + (self.iconbg and self.iconbg:GetWide() or 0) + 5
			self.name:SetPos(x, 2)
			self.name:SetWide(self:GetWide() - x - 2)
			self.name:SetContentAlignment(4)
		end

		if self.name and self.sign then
			local nx,ny = self.name:GetPos()
			self.sign:SetPos(nx, ny + self.name:GetTall() + 2)
			self.sign:SetWide(self.name:GetWide())
			self.sign:SetContentAlignment(4)
		end
	else
		-- Иконка сверху (квадратная), название ниже
		if IsValid(self.iconbg) then
			local name_h = self.name and self.name:GetTall() or 20
			local gap = 6
			local icon_size = self:GetWide() - 20
			local max_size = self:GetTall() - name_h - gap - 2
			icon_size = math.min(icon_size, max_size)
			local pad = math.max((self:GetTall() - icon_size - name_h - gap) / 2, 0)
			self.iconbg:SetSize(icon_size, icon_size)
			self.iconbg:SetPos((self:GetWide() - icon_size) / 2, pad)
		end

		if self.name then
			local gap = 6
			local pad = math.max((self:GetTall() - self.iconbg:GetTall() - self.name:GetTall() - gap) / 2, 0)
			self.name:SetPos(5, pad + self.iconbg:GetTall() + gap)
			self.name:SetWide(self:GetWide() - 10)
			self.name:SetContentAlignment(5)
		end

		if self.price_on_icon and IsValid(self.iconbg) then
			self.price_on_icon:SetPos(
				self.iconbg:GetWide() - self.price_on_icon:GetWide() + 1,
				self.iconbg:GetTall() - self.price_on_icon:GetTall() + 1
			)
		end
	end

	if self.title_color and self.name then
		self.name:SetTextColor(self.title_color)
	end
end

function PANEL:SetTitleColor(c)
	self.title_color = c
end


-- Оптимизация FPS: blur отключен для карточек товаров (много элементов = сильная просадка)
function PANEL:Paint(w,h)
	DrawRoundedPanel(0, 0, w, h, 6, IGS.col.HARD_LINE, CARD_BG)
	return true
end

--[[-------------------------------------------------------------------------
	Жто все нужно было для отрисовки лейбла с размером скидки
	Проблема оказалась на этапе рисования повернутого текста
	Набросы: https://gist.github.com/AMD-NICK/7f2aeb674763fe91c2d0668f84357f2e
	Карточка: https://trello.com/c/Zx6qTzBn/303

	Color(220,30,70) -- Штуки за биркой
	Color(255,30,85) -- Цвет бирки
	Color(255,255,255) -- Текст бирки
	draw.RotatedText
---------------------------------------------------------------------------]]
-- local function draw_TextRotated(text, x, y, color, font, ang)
-- 	surface.SetFont(font)
-- 	surface.SetTextColor(color)
-- 	surface.GetTextSize(text)

-- 	local m = Matrix()
-- 	m:SetAngles(Angle(0, ang, 0))
-- 	m:SetTranslation(Vector(x, y, 0))

-- 	cam.PushModelMatrix(m)
-- 		surface.SetTextPos(0, 0)
-- 		surface.DrawText(text)
-- 	cam.PopModelMatrix()
-- end

-- local function draw_Poly(tVertices,tColor_)
-- 	surface.SetDrawColor(tColor_ or color_white)
-- 	draw.NoTexture()
-- 	surface.DrawPoly(tVertices)
-- end

-- 2250, 3000 = 25
-- local function diffNumsPercent(a, b)
-- 	return math.ceil(100 - a / (b / 100))
-- end

-- Вс. функцию можно назвать пиздецкой костылякой
function PANEL:PaintOver(w,h) end


vgui.Register("igs_item",PANEL,"DButton")

-- IGS.CloseUI()
-- IGS.UI()