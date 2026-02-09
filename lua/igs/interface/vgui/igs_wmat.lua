--[[-------------------------------------------------------------------------
	Запрещено использовать DOCK.
	Размер должен быть указан единоразово и четко

	:SetURL указывать ПОСЛЕ :SetSize
---------------------------------------------------------------------------]]
local PANEL = {}


function PANEL:GetTexture()
	return texture.Get(self.url)
end

function PANEL:GetURL()
	return self.url
end

function PANEL:RenderTexture()
	self.Rendering = true

	-- print("Render",self:GetURL())
	-- print("Size",self:GetSize())

	texture.Delete(self:GetURL())
	texture.Create(self:GetURL())
		:SetSize(self:GetSize())
		:SetFormat(self:GetURL():sub(-3) == "jpg" and "jpg" or "png")
		:Download(self:GetURL(), function()
			if !IsValid(self) then return end

			self.Rendering 	= false
			self.LastURL 	= self:GetURL()
		end, function()
			if !IsValid(self) then return end

			self.Rendering = false
		end)
end

function PANEL:Paint(w,h)
	if (!self:GetTexture() and !self.Rendering) or (self:GetURL() ~= self.LastURL and !self.Rendering) then
		self:RenderTexture()

	elseif self:GetTexture() then
		surface.SetDrawColor(IGS.col.ICON)
		surface.SetMaterial( self:GetTexture() )
		surface.DrawTexturedRect(0,0,w,h)
	elseif self.Rendering then
		-- Показываем placeholder во время загрузки
		draw.RoundedBox(0, 0, 0, w, h, Color(50, 50, 50, 100))
		
		-- Анимированная иконка загрузки
		local time = CurTime() * 2
		local angle = time % 360
		
		local cx, cy = w / 2, h / 2
		local radius = math.min(w, h) / 4
		
		for i = 0, 7 do
			local a = math.rad(angle + i * 45)
			local alpha = 255 - (i * 30)
			local size = radius / 3
			
			surface.SetDrawColor(200, 200, 200, alpha)
			surface.DrawRect(
				cx + math.cos(a) * radius - size / 2,
				cy + math.sin(a) * radius - size / 2,
				size, size
			)
		end
	end
end

function PANEL:SetURL(sUrl)
	self.url = sUrl or IGS.C.DefaultIcon
end


vgui.Register("igs_wmat",PANEL,"Panel")
-- IGS.UI()
