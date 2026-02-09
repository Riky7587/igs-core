local PANEL = {}

function PANEL:Init()
	self:SetTextColor(IGS.col.HIGHLIGHTING)
	self:SetFont("Fated.18")
end

-- Как блять по человечески оверрайднуть эту хуетоту?
-- function PANEL:SetText(text)
-- 	self.BaseClass:SetText(" " .. text .. " ") -- чтобы при SizeToContent было не вплотную к стенкам
-- end

function PANEL:SetActive(bActive)
	self.active = bActive

	-- Для кнопок категорий текст всегда яркий
	if self.isCategory then
		self:SetTextColor(IGS.col.TEXT_ON_HIGHLIGHT)
	else
		self:SetTextColor(self.active and IGS.col.TEXT_ON_HIGHLIGHT or IGS.col.HIGHLIGHTING)
	end
end

function PANEL:IsActive()
	return self.active
end

function PANEL:Paint(w,h)
	-- Размытие фона кнопки
	if RNDX and Mantle and Mantle.ui.convar.blur then
		RNDX().Rect(0, 0, w, h)
			:Rad(4)
			:Blur(0.8)
		:Draw()
	end
	
	if self.active then
		-- Особый стиль для кнопок категорий
		if self.isCategory then
			-- Активная категория - прозрачно-бордовый фон
			draw.RoundedBox(4, 0, 0, w, h, Color(120, 30, 40, 180))
			
			if self:IsHovered() then
				draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 20))
			elseif self:IsDown() then
				draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 30))
			end
		else
			-- Обычная активная кнопка - заливка цветом
			draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 85, 230))
			
			if self:IsHovered() then
				draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 20))
			elseif self:IsDown() then
				draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 40))
			end
		end
	else
		-- Неактивная кнопка - только обводка
		draw.RoundedBox(4, 0, 0, w, h, IGS.col.HIGHLIGHTING) -- outline
		draw.RoundedBox(4, 1, 1, w - 2, h - 2, IGS.col.PASSIVE_SELECTIONS) -- bg
		
		if self:IsHovered() then
			draw.RoundedBox(4, 1, 1, w - 2, h - 2, Color(255, 255, 255, 15))
		elseif self:IsDown() then
			draw.RoundedBox(4, 1, 1, w - 2, h - 2, Color(0, 0, 0, 30))
		end
	end
end

vgui.Register("igs_button",PANEL,"DButton")

-- IGS.UI()
