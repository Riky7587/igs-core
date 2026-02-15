IGS.WIN = IGS.WIN or {}

if CLIENT then
	if not Mantle then
		pcall(include, "mantle/init.lua")
	end

	-- Ensure Mantle fonts exist before any SetFont calls
	local function EnsureFatedFonts()
		local sizes = {15,16,17,18,19,20,22,24,40}
		for _, size in ipairs(sizes) do
			surface.CreateFont("Fated." .. size, {
				font = "Montserrat Medium",
				size = size,
				extended = true
			})
			surface.CreateFont("Fated." .. size .. "b", {
				font = "Montserrat Bold",
				size = size,
				extended = true
			})
		end
	end

	EnsureFatedFonts()
end

uigs = uigs or {}
function uigs.Create(t, f, p)
	local cb, parent = f, p

	if not isfunction(f) then -- nil or panel
		parent, cb = f, nil
	end

	local v = vgui.Create(t, parent)
	if cb then cb(v, parent) end
	return v
end
-- uigs.Create("name")
-- uigs.Create("name", parent)
-- uigs.Create("name", func, parent)
-- uigs.Create("name", func)


-- Чтобы не открывало F1 менюшку даркрпшевскую ебучую
hook.Add("DarkRPFinishedLoading","SupressDarkRPF1",function()
	if IGS.C.MENUBUTTON ~= KEY_F1 then return end

	local GM = GM or GAMEMODE
	function GM:ShowHelp() end
end)






-- чтобы аргументом не передалась панель
local function dep() IGS.WIN.Deposit() end


local mf -- антидубликат
function IGS.UI()
	if not IGS.IsLoaded() then
		LocalPlayer():ChatPrint("[IGS] Автодонат не загружен")
		return
	end

	if not IGS.C then -- Проблема AddCSLua. В консоли клиента должны быть ошибки инклюда нескольких базовых файлов
		LocalPlayer():ChatPrint("[IGS] Автодонат установлен неправильно. Сообщите администрации")
		return
	end

	if IsValid(mf) then
		if not mf:IsVisible() then
			IGS.ShowUI()
		end
		return
	end

	mf = uigs.Create("igs_frame", function(self)
		-- 700 = (items_in_line * item_pan_wide) + (10(margin) * (items_in_line + 1))
		self:SetSize(math.min(ScrW(), 900), math.min(ScrH(), 650)) -- позволяет закрыть окно на ущербных разрешениях
		-- Переопределяем RestoreLocation чтобы всегда центрировать окно
		self.RestoreLocation = function() self:Center() end
		self:RememberLocation("igs")
		self:MakePopup()

		-- если повесить на фрейм, то драг сломается
		local init = CurTime() -- https://t.me/c/1353676159/7185
		function self.btnClose:Think()
			if CurTime() - init > 1 and input.IsKeyDown(IGS.C.MENUBUTTON) then
				IGS.HideUI()
			end
		end
	end)

--баланс
-- Создаем контейнер для баланса и кнопок
local container = vgui.Create("Panel", mf)
local containerWidth = 150 + 100 + 110 -- баланс + купон + пополнить
container:SetPos(mf:GetWide() - 20 - containerWidth, 0)
container:SetSize(containerWidth, 23)

-- Общая обводка для всего блока. Оптимизация FPS: blur убран (просадка при открытом меню)
container.Paint = function(s, w, h)
    draw.RoundedBox(4, 0, 0, w, h, IGS.col.HIGHLIGHTING) -- outline
    draw.RoundedBox(4, 1, 1, w - 2, h - 2, IGS.col.PASSIVE_SELECTIONS) -- bg
end

-- Рисуем разделители поверх всего, чтобы они не перекрывались hover-эффектами
container.PaintOver = function(s, w, h)
    -- Жирные разделители между кнопками (строго одинаковая толщина 3 пикселя)
    draw.RoundedBox(0, 149, 2, 3, h - 4, IGS.col.HIGHLIGHTING) -- после баланса
    draw.RoundedBox(0, 249, 2, 3, h - 4, IGS.col.HIGHLIGHTING) -- после купона
end

-- Панель баланса (теперь просто информационная, не кнопка)
local balancePanel = vgui.Create("Panel", container)
balancePanel:SetPos(0, 0)
balancePanel:SetSize(150, 23)

balancePanel.Paint = function(s, w, h)
    local font = "Fated.16"
    local text = s.balanceText or ""
    local col = IGS.col.TEXT_HARD or color_white
    
    draw.SimpleText(text, font, w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function balancePanel:UPDBalance()
    self.bal = LocalPlayer():IGSFunds()
    self.balanceText = "Баланс: " .. IGS.SignPrice(self.bal)
end

balancePanel:UPDBalance()

-- Оптимизация: проверка баланса по таймеру вместо каждого кадра (снижает нагрузку на FPS)
balancePanel.Think = function(s)
    if not s._nextBalanceCheck or CurTime() >= s._nextBalanceCheck then
        s._nextBalanceCheck = CurTime() + 0.5
        if s.bal ~= LocalPlayer():IGSFunds() then
            s:UPDBalance()
        end
    end
end

-- Кнопка "Купон"
    local coupon = vgui.Create("DButton", container)
    coupon:SetPos(150, 0)
    coupon:SetSize(100, 23)
    coupon:SetText("Купон")
    coupon:SetFont("Fated.18")
    coupon:SetTextColor(IGS.col.TEXT_ON_HIGHLIGHT)
    coupon:SetTooltip("Активировать купон")
    coupon.Paint = function(s, w, h)
        if s:IsHovered() then
            draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255, 15))
        elseif s:IsDown() then
            draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 30))
        end
    end
    coupon.DoClick = function()
        IGS.WIN.ActivateCoupon()
    end
    
    -- Кнопка "Пополнить"
    local add = vgui.Create("DButton", container)
    add:SetPos(250, 0)
    add:SetSize(110, 23)
    add:SetText("Пополнить")
    add:SetFont("Fated.18")
    add:SetTextColor(IGS.col.TEXT_ON_HIGHLIGHT)
    add:SetTooltip("Пополнение счета")
    add.Paint = function(s, w, h)
        -- Активная кнопка
        draw.RoundedBoxEx(4, 0, 0, w, h, Color(70, 70, 85, 230), false, true, false, true)
        
        if s:IsHovered() then
            draw.RoundedBoxEx(4, 0, 0, w, h, Color(255, 255, 255, 20), false, true, false, true)
        elseif s:IsDown() then
            draw.RoundedBoxEx(4, 0, 0, w, h, Color(0, 0, 0, 40), false, true, false, true)
        end
    end
add.DoClick = dep

	local framePad = 10
	mf.activity = uigs.Create("igs_tabbar", function(self)
		self:SetPos(framePad, mf:GetTitleHeight() + framePad)
		self:SetSize(700 - framePad * 2, mf:GetTall() - mf:GetTitleHeight() - framePad * 2)
	end, mf)

	-- Херня справа от лэйаута с услугами http://joxi.ru/52aQQ8Efzov120
	-- Вид без нее: http://joxi.ru/eAO44lGcXORlro
	mf._activityWidthDefault = mf.activity:GetWide()

	local x,y = mf.activity:GetPos()
	mf.sidebar = uigs.Create("igs_sidebar", mf)
	mf.sidebar:SetSize(mf:GetWide() - framePad * 2 - mf.activity:GetWide(), mf.activity:GetTall() + 1 + 1)
	mf.sidebar:SetPos(x + mf.activity:GetWide(),y - 1) -- -1 чтобы перекрыть подчеркивание хэдера
	mf.sidebar.PaintOver = function(_,_,h)
		surface.SetDrawColor(IGS.col.HARD_LINE)
		surface.DrawLine(0,0,0,h) -- линия слева
	end
	mf.sidebar.header.Paint = function(_,w,h)
		-- Оптимизация FPS: blur убран с header sidebar
		draw.RoundedBox(0,0,0,w,h,IGS.col.FRAME_HEADER)

		-- Убрана линия снизу header'а
		-- surface.SetDrawColor(IGS.col.HARD_LINE)
		-- surface.DrawLine(0,h - 1,w,h - 1)
	end

	mf.sidebar.activity = uigs.Create("igs_multipanel", mf.sidebar.sidebar)
	mf.sidebar.activity:Dock(FILL)

	function mf.sidebar:AddPanel(panel,active)
		return self.activity:AddPanel(panel,active)
	end

	function mf.sidebar:Show(iPanelID)
		return self.activity:SetActivePanel(iPanelID)
	end

	function mf:SetSidebarVisible(bVisible)
		local ax, ay = self.activity:GetPos()
		local activityWide = self._activityWidthDefault or self.activity:GetWide()

		if bVisible then
			self.sidebar:SetVisible(true)
			self.activity:SetSize(activityWide, self.activity:GetTall())
			self.sidebar:SetSize(self:GetWide() - framePad * 2 - activityWide, self.activity:GetTall() + 1 + 1)
			self.sidebar:SetPos(ax + activityWide, ay - 1)
		else
			self.sidebar:SetVisible(false)
			self.activity:SetSize(self:GetWide() - framePad * 2, self.activity:GetTall())
		end

		self.activity:InvalidateLayout(true)
		if self.activity.PerformLayout then
			self.activity:PerformLayout()
		end
	end

	function mf.sidebar:AddPage(sTitle)
		return uigs.Create("Panel", function(bg)
			bg.side = uigs.Create("igs_scroll")

			bg.SidePanelID = self:AddPanel(bg.side)
			bg.side:SetSize(self:GetSize()) -- если указать раньше, то сбросится
			bg.OnOpen = function(s)
				local frame = self:GetParent()
				if frame and frame.SetSidebarVisible then
					frame:SetSidebarVisible(true)
				end

				self:SetTitle(sTitle)
				self:Show(s.SidePanelID)

				-- Не знаю как сделать лучше.
				-- ЧТобы не оверрайдить полностью - сделал дополнительный метод
				if bg.OnOpenOver then
					bg.OnOpenOver()
				end
			end
		end, self)
	end

	-- Немного не правильно, но эта штука отключает
	for hook_name in pairs(IGS.C.DisabledFrames) do
		hook.Remove("IGS.CatchActivities",hook_name)
	end

	-- Собираем кнопочки в футере
	hook.Run("IGS.CatchActivities",mf.activity,mf.sidebar)

	return mf
end

function IGS.GetUI()
	return IsValid(mf) and mf or nil
end

function IGS.CloseUI()
	if IsValid(mf) then
		mf:Close()
	end
end

local lastX,lastY -- remember
function IGS.HideUI()
	if not mf.moving then
		mf.moving = true
		lastX,lastY = mf:GetPos()
		mf:MoveTo(-mf:GetWide(), lastY, .2)
		timer.Simple(.2, function()
			mf:SetVisible(false)
			mf.moving = false
		end)
	end
end

function IGS.ShowUI()
	if not mf.moving then
		mf.moving = true
		mf:SetVisible(true)
		mf:MoveTo(lastX, lastY, .2)
		timer.Simple(.2, function() mf.moving = false end)
	end
end

function IGS.OpenUITab(sName)
	local iui = IGS.GetUI() or IGS.UI()

	for _,btn in ipairs(iui.activity.Buttons) do
		if btn:Name() == sName then
			btn:DoClick()
		end
	end
end

-- Добавляет блок текста к скролл панели. К обычной не вижу смысла
-- scroll Должен иметь статический размер. Никаких доков!
-- Сетка: https://img.qweqwe.ovh/1487023074990.png
function IGS.AddTextBlock(scroll,sTitle,sText) -- используется в фрейме хелпа и чартов
	-- \/ вставленная панель
	return scroll:AddItem(uigs.Create("Panel", function(pnl)
		local y = 3

		-- Title
		if sTitle then
			for _,line in ipairs( string.Wrap("Fated.20",sTitle,scroll:GetWide() - 5 - 5) ) do
				local t = uigs.Create("DLabel", pnl)
				t:SetPos(5,y)
				t:SetFont("Fated.20")
				t:SetText(line)
				t:SetTextColor(IGS.col.TEXT_HARD)
				t:SizeToContents()

				y = y + t:GetTall()
			end

			y = y + 2
		end

		for _,line in ipairs( string.Wrap("Fated.18",sText,scroll:GetWide() - 5 - 5) ) do
			local lbl = uigs.Create("DLabel", pnl)
			lbl:SetPos(5,y)
			lbl:SetFont("Fated.18")
			lbl:SetText(line)
			lbl:SetTextColor(IGS.col.TEXT_SOFT)
			lbl:SizeToContents()

			y = y + lbl:GetTall()
		end

		pnl:SetTall(y + 10)
	end))
end

function IGS.AddButton(pScroll,sName,fDoClick) -- используется в инвентаре и профиле для юза купонов
	-- \/ вставленная панель
	return pScroll:AddItem(uigs.Create("Panel", function(pan)
		pan.button = uigs.Create("igs_button", function(s)
			s:SetSize(pScroll:GetWide() - 5 - 5,50)
			s:SetPos(5,5)
			s:SetText(sName)
			s.DoClick = fDoClick
		end, pan)

		pan:SetTall(pan.button:GetTall() + 5)
	end))
end

-- IGS.UI()

-- timer.Create("IGSUI",30,1,function()
-- 	if IsValid(mf) then
-- 		mf:Close()
-- 	end
-- end)
