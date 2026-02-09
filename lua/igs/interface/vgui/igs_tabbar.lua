local PANEL = {}

local barWide = 80 -- ширина вертикальной панели кнопок
local btnTall = 70 -- высота кнопки
local btnWide = 70 -- ширина кнопки

function PANEL:Init()
	self.activity = uigs.Create("igs_multipanel",self)

	self.tabBar = uigs.Create("Panel",self)
	self.tabBar:SetWide(barWide)
	self.tabBar.Paint = function(_, w, h)
		-- Размытие фона панели кнопок
		if RNDX and Mantle and Mantle.ui.convar.blur then
			RNDX().Rect(0, 0, w, h)
				:Rad(0)
				:Blur(1.3)
			:Draw()
		end
		
		surface.SetDrawColor(IGS.col.TAB_BAR)
		surface.DrawRect(0,0,w,h) -- bg

		surface.SetDrawColor(IGS.col.HARD_LINE)
		surface.DrawLine(w,0,w,h) -- правая линия (разделитель)
	end

	self.btnsPan = uigs.Create("DIconLayout", self.tabBar)
	self.btnsPan.Paint = function() end
	self.btnsPan:SetSpaceY(5) -- вертикальные отступы между кнопками

	self.Buttons = {}
end

function PANEL:SetActiveTab(num)
	for _, btn in ipairs(self.Buttons) do
		btn.Active = (btn.ID == num) -- фикс подсветки
	end

	self.activity:SetActivePanel(num)
end

function PANEL:GetActiveTab()
	return self.activity:GetActivePanel()
end

function PANEL:GetContentWide()
	return self:GetWide() - barWide
end

function PANEL:UpdateButtonsLayout()
	local total_h = #self.Buttons * btnTall + math.max(#self.Buttons - 1, 0) * 5
	self.btnsPan:SetSize(barWide, total_h)
	self.btnsPan:SetPos((barWide - btnWide) / 2, (self.tabBar:GetTall() - total_h) / 2)
end

function PANEL:AddTab(sTitle,panel,sIcon,bActive)
	local ID = self.activity:AddPanel(panel,bActive)

	local button = uigs.Create("DButton", function(btn)
		btn:SetSize(btnWide, btnTall)
		btn:SetText("")

		btn:SetFont("Fated.24")

		btn.DoClick = function(s)
			self:SetActiveTab(s.ID)
		end

		--[[-------------------------------------------------------------------------
			TODO Сделать отрисовку скина через скин хук
			чтобы можно было юзать компонент не только в IGS без порчи дизайна
			В bar.Paint тоже
		---------------------------------------------------------------------------]]
		btn.Paint = function(s,w,h)
			if s.Active then
				surface.SetDrawColor(IGS.col.HIGHLIGHTING)
				surface.SetTextColor(IGS.col.HIGHLIGHTING)
			else
				surface.SetDrawColor(IGS.col.HIGHLIGHT_INACTIVE)
				surface.SetTextColor(IGS.col.HIGHLIGHT_INACTIVE)
			end

			if sIcon then
				surface.SetMaterial( Material(sIcon) )
				surface.DrawTexturedRect(w / 2 - 32 / 2, 5, 32, 32)
			end

			if sTitle then
				surface.SetFont("Fated.15")

				local tw = surface.GetTextSize(sTitle)
				surface.SetTextPos(w / 2 - tw / 2, h - 20)

				surface.DrawText( sTitle )
			end
		end

		btn.ID     = ID
		btn.Tab    = panel
		btn.Active = bActive
	end)

	function button:Name()
		return sTitle
	end

	self.btnsPan:Add(button)
	table.insert(self.Buttons, button)
	if bActive then
		self:SetActiveTab(ID)
	end
	-- Обновляем размеры вертикальной панели кнопок
	self:UpdateButtonsLayout()

	return button
end

function PANEL:PerformLayout()
	self.tabBar:SetTall(self:GetTall())
	self.tabBar:SetPos(0, 0)

	self.activity:SetPos(barWide, 0)
	self.activity:SetSize(self:GetWide() - barWide, self:GetTall())

	self:UpdateButtonsLayout()
end

function PANEL:Paint(w,h)
	-- Размытие основного фона
	if RNDX and Mantle and Mantle.ui.convar.blur then
		RNDX().Rect(0, 0, w, h)
			:Rad(0)
			:Blur(1.5)
		:Draw()
	end
	
	draw.RoundedBox(0,0,0,w,h,IGS.col.ACTIVITY_BG)
end

vgui.Register("igs_tabbar", PANEL, "Panel")
-- IGS.UI()
