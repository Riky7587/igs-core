-- #todo нужно переделывать, но только так:
-- https://trello.com/c/WfVYTIOF/544 (комменты)
CreateConVar("igs_debug", 0, FCVAR_NOTIFY)
cvars.AddChangeCallback("igs_debug", function(_, old, new)
	IGS.DEBUG = tobool(new)
	IGS.print("PEZuM OTJIA9Ku " .. (IGS.DEBUG and "AKTuBuPOBAH" or "BbIKJII04EH"))
end, "main")

-- Установка иконки для категории
IGS.CategoryIcons = IGS.CategoryIcons or {}
function IGS.SetCategoryIcon(sCategoryName, sIconPath)
	if CLIENT then
		IGS.CategoryIcons[sCategoryName] = sIconPath
	end
end

function IGS.GetCategoryIcon(sCategoryName)
	return IGS.CategoryIcons[sCategoryName]
end

-- Система глобальных скидок
IGS.GlobalDiscount = IGS.GlobalDiscount or {}

-- Установить глобальную процентную скидку (например, 15 = 15%)
function IGS.SetGlobalDiscountPercent(iPercent)
	IGS.GlobalDiscount.type = "percent"
	IGS.GlobalDiscount.value = iPercent
end

-- Установить глобальную фиксированную скидку в рублях (например, 100 = 100 рублей)
function IGS.SetGlobalDiscountFixed(iRubles)
	IGS.GlobalDiscount.type = "fixed"
	IGS.GlobalDiscount.value = iRubles
end

-- Убрать глобальную скидку
function IGS.RemoveGlobalDiscount()
	IGS.GlobalDiscount = {}
end

-- Получить скидочную цену с учетом глобальной скидки
function IGS.GetDiscountedPrice(iOriginalPrice)
	if !IGS.GlobalDiscount.type then
		return iOriginalPrice
	end
	
	if IGS.GlobalDiscount.type == "percent" then
		return iOriginalPrice * (1 - IGS.GlobalDiscount.value / 100)
	elseif IGS.GlobalDiscount.type == "fixed" then
		return math.max(0, iOriginalPrice - IGS.GlobalDiscount.value)
	end
	
	return iOriginalPrice
end

-- Проверить, есть ли глобальная скидка
function IGS.HasGlobalDiscount()
	return IGS.GlobalDiscount.type ~= nil
end


local PLAYER = FindMetaTable("Player")

function PLAYER:IGSFunds()
	return self:GetIGSVar("igs_balance") or 0
end

function PLAYER:HasPurchase(sUID)
	return IGS.PlayerPurchases(self)[sUID]
end

-- Надет ли предмет Reloadns (equipped-state), не влияет на владение покупкой
function PLAYER:HasPurchaseEquipped(sUID)
	local ITEM = IGS.GetItemByUID(sUID)
	if ITEM.isnull or not ITEM:HasReloadns() then return false end

	local cat = ITEM:ReloadnsCategory()
	if CLIENT then
		local equipped = self:GetIGSVar("igs_reloadns_equipped") or {}
		return equipped[cat] == sUID
	else
		local equipped = IGS.GetReloadnsEquipped and IGS.GetReloadnsEquipped(self) or {}
		return equipped[cat] == sUID
	end
end

-- true, если человек имеет хоть один итем из списка, nil, если итем не отслеживается, false, если нет права. Начало юзаться для упрощения кода модулей
function IGS.PlayerHasOneOf(pl,tItems)
	if !tItems then return end

	for _,ITEM in ipairs(tItems) do
		if pl:HasPurchase( ITEM:UID() ) then
			return ITEM
		end
	end

	return false
end

function IGS.isUser(pl) -- возвращает false, если чел никогда не юзал автодонат
	return pl:GetIGSVar("igs_balance") ~= nil
end


-- Может ли чел себе позволить покупку итема, ценой в sum IGS?
function IGS.CanAfford(pl,sum,assert)
	if sum >= 0 and pl:IGSFunds() - sum >= 0 then
		return true
	end

	if !assert then
		return false
	end

	if isfunction(assert) then
		assert()
	else
		local rub = IGS.RealPrice(sum)
		if SERVER then
			IGS.WIN.Deposit(pl,rub)
		else
			IGS.WIN.Deposit(rub)
		end
	end

	return false
end

-- Список активных покупок игрока
-- uid > amount
function IGS.PlayerPurchases(pl)
	-- ВАЖНО: как в PointShop — владение покупкой != надето.
	-- Тут возвращаем именно владение (uid -> amount). Состояние "надето" отдельно:
	-- PLAYER:HasPurchaseEquipped(uid)
	return CLIENT and (pl:GetIGSVar("igs_purchases") or {}) or pl:GetVar("igs_purchases",{})
end

-- Сумма в донат валюте всех операций пополнения счета (включая купоны и выдачу денег администратором)
function IGS.TotalTransaction(pl)
	return pl:GetIGSVar("igs_total_transactions") or 0
end

-- возврат объекта ЛВЛ на клиенте, номера уровня на сервере
function IGS.PlayerLVL(pl)
	return pl:GetIGSVar("igs_lvl")
end


-- Конвертирует IGS в реальную валюту
function IGS.RealPrice(iCurrencyAmount)
	return iCurrencyAmount * IGS.GetCurrencyPrice()
end

-- Реальная валюта в IGS по текущему курсу
function IGS.PriceInCurrency(iRealPrice)
	return iRealPrice / IGS.GetCurrencyPrice()
end


function IGS.IsCurrencyEnabled()
	return IGS.GetCurrencyPrice() ~= 1
end

local function getSettings()
	return IGS.nw.GetGlobal("igs_settings")
end

-- Минимальная сумма пополнения в рублях
function IGS.GetMinCharge()
	return getSettings()[1]
end

-- Стоимость 1 донат валюты в рублях
function IGS.GetCurrencyPrice()
	return getSettings()[2]
end

-- Не смог загрузиться или выключен в панели, меню открывать нельзя
function IGS.IsLoaded()
	return getSettings() and IGS.SERVERS:ID() and !GetGlobalBool("IGS_DISABLED")
end




local terms = {
	[1] = "бесконечно",
	[2] = "единоразово",
	[3] = "%s"
}

function IGS.TermType(term)
	return
		!term     and 1 or -- бесконечно
		term == 0 and 2 or -- мгновенно
		term      and 3    -- кол-во дней
end

function IGS.TermToStr(term)
	return terms[ IGS.TermType(term) ]:format(term and PL_DAYS(term))
end

function IGS.TimestampToDate(ts,bShowFull) -- в "купил до"
	if !ts then return end
	return os.date(bShowFull and IGS.C.DATE_FORMAT or IGS.C.DATE_FORMAT_SHORT,ts)
end


function IGS.FormItemInfo(ITEM)
	local finalPrice = ITEM:GetFinalPrice()
	local originalPrice = ITEM:Price()
	local hasDiscount = (finalPrice ~= originalPrice) or ITEM.discounted_from or IGS.HasGlobalDiscount()
	
	return {
		["Категория"] = ITEM:Category(),
		["Действует"] = IGS.TermToStr(ITEM:Term()),
		["Цена"]       = PL_MONEY(finalPrice),
		["Без скидки"] = hasDiscount and PL_MONEY(originalPrice) or nil,
		["Покупки суммируются"]  = ITEM:IsStackable() and "да" or "нет",
	}
end


function IGS.print(...)
	local args = {...}
	if !IsColor(args[1]) then
		table.insert(args,1,color_white)
	end

	args[#args] = args[#args] .. "\n"
	MsgC(Color(50,200,255), "[IGS] ", unpack(args))
end

function IGS.dprint(...)
	if IGS.DEBUG then
		IGS.print("DEBUG: ", Color(50,250,50), ...)
	end
end




function IGS.SignPrice(iPrice) -- 10 Alc
	return math.Truncate(tonumber(iPrice),2) .. " " .. IGS.C.CURRENCY_SIGN
end

local rubs = {"рубль", "рубля", "рублей"}
PL_MONEY = PL.Add("realmoney",rubs)
PL_IGS   = PL.Add("igs_currency",IGS.C.CurrencyPlurals or rubs)
PL_DAYS  = PL.Add("days",{"день", "дня", "дней"})


local PL_IGS_ORIGINAL
hook.Add("IGS.OnSettingsUpdated","PL_IGS = PL_MONEY",function()
	if !IGS.IsCurrencyEnabled() then -- Если донат валюта отключена
		PL_IGS_ORIGINAL = PL_IGS -- а это не таблица случайно? Мб table.copy?
		PL_IGS = PL_MONEY

	-- Валюта уже отключалась. Сейчас включилась
	elseif PL_IGS_ORIGINAL then
		PL_IGS = PL_IGS_ORIGINAL
	end
end)
