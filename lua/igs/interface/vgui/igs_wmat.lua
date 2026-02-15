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
		-- Placeholder при загрузке. Оптимизация: простая статичная иконка вместо анимации (меньше нагрузка на FPS)
		draw.RoundedBox(0, 0, 0, w, h, Color(50, 50, 50, 100))
		local cx, cy = w / 2, h / 2
		local r = math.min(w, h) / 6
		draw.RoundedBox(r, cx - r, cy - r, r * 2, r * 2, Color(100, 100, 100, 150))
	end
end

function PANEL:SetURL(sUrl)
	self.url = sUrl or IGS.C.DefaultIcon
end


vgui.Register("igs_wmat",PANEL,"Panel")
-- IGS.UI()
