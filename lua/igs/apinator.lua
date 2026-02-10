if CLIENT then return end

IGS.DB = IGS.DB or {}
local DB = IGS.DB

local function cfg()
	local c = IGS.C.DB or {}
	local ykd = rawget(_G, "YKD") or {}
	return {
		HOST    = c.HOST or ykd.MYSQL_HOST or "127.0.0.1",
		PORT    = tonumber(c.PORT or ykd.MYSQL_PORT) or 3306,
		USER    = c.USER or ykd.MYSQL_USER or "root",
		PASS    = c.PASS or ykd.MYSQL_PASS or "",
		NAME    = c.NAME or ykd.MYSQL_DB   or "gmod_donate",
		CHARSET = c.CHARSET or "utf8mb4",
	}
end

local function esc(v)
	if v == nil then return "NULL" end
	local s = tostring(v)
	if DB.conn then
		s = DB.conn:escape(s)
	else
		s = s:gsub("\\", "\\\\"):gsub("'", "\\'")
	end
	return "'" .. s .. "'"
end

local function num(v, fallback)
	if type(v) == "boolean" then
		return v and "1" or "0"
	end
	local n = tonumber(v)
	if n == nil then n = tonumber(fallback) or 0 end
	return tostring(n)
end

function DB:Query(sql, onSuccess, onError)
	if not self.connected or not self.conn then
		if onError then onError("db_not_connected") end
		return
	end

	local q = self.conn:query(sql)
	function q:onSuccess(data)
		if onSuccess then onSuccess(data, self:lastInsert()) end
	end
	function q:onError(err)
		if onError then onError(err) end
	end
	q:start()
end

function DB:EnsureSchema()
	local queries = {
		[[
			CREATE TABLE IF NOT EXISTS gmod_users (
				steamid64 VARCHAR(32) PRIMARY KEY,
				name VARCHAR(128) NULL,
				balance DECIMAL(12,2) NOT NULL DEFAULT 0,
				updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
		]],
		[[
			CREATE TABLE IF NOT EXISTS gmod_payments (
				id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
				payment_id VARCHAR(64) NOT NULL,
				steamid64 VARCHAR(32) NOT NULL,
				rub_amount DECIMAL(10,2) NOT NULL,
				coin_amount BIGINT NOT NULL,
				status VARCHAR(32) NOT NULL,
				created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
				updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
				UNIQUE KEY uq_payment_id (payment_id),
				KEY idx_steamid64 (steamid64),
				KEY idx_status (status)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
		]],
		[[
			CREATE TABLE IF NOT EXISTS igs_transactions (
				id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
				steamid64 VARCHAR(32) NOT NULL,
				sum DECIMAL(12,2) NOT NULL,
				note VARCHAR(80) NULL,
				server_id INT NULL,
				time INT UNSIGNED NOT NULL,
				KEY idx_steamid64 (steamid64),
				KEY idx_time (time)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
		]],
		[[
			CREATE TABLE IF NOT EXISTS igs_purchases (
				id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
				steamid64 VARCHAR(32) NOT NULL,
				item_uid VARCHAR(128) NOT NULL,
				server_id INT NULL,
				purchase_ts INT UNSIGNED NOT NULL,
				expire_ts INT UNSIGNED NULL,
				active TINYINT(1) NOT NULL DEFAULT 1,
				KEY idx_steamid64 (steamid64),
				KEY idx_item_uid (item_uid),
				KEY idx_active (active)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
		]],
		[[
			CREATE TABLE IF NOT EXISTS igs_inventory (
				id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
				steamid64 VARCHAR(32) NOT NULL,
				item_uid VARCHAR(128) NOT NULL,
				created_ts INT UNSIGNED NOT NULL,
				KEY idx_steamid64 (steamid64)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
		]],
		[[
			CREATE TABLE IF NOT EXISTS igs_coupons (
				code VARCHAR(64) PRIMARY KEY,
				value DECIMAL(12,2) NOT NULL,
				note VARCHAR(50) NULL,
				expire_ts INT UNSIGNED NULL,
				used_by VARCHAR(32) NULL,
				used_ts INT UNSIGNED NULL,
				created_ts INT UNSIGNED NOT NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
		]],
		[[
			CREATE TABLE IF NOT EXISTS igs_servers (
				id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
				name VARCHAR(64) NOT NULL,
				ip VARCHAR(45) NOT NULL,
				port INT NOT NULL,
				socket_port INT NULL,
				disabled TINYINT(1) NOT NULL DEFAULT 0,
				version INT NULL,
				created_ts INT UNSIGNED NOT NULL,
				updated_ts INT UNSIGNED NOT NULL,
				KEY idx_ip_port (ip, port)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
		]],
	}

	for _,sql in ipairs(queries) do
		self:Query(sql, nil, function(err)
			IGS.print(Color(255,0,0), "IGS DB schema error: " .. tostring(err))
		end)
	end

	-- MySQL < 8 does not support IF NOT EXISTS for columns, ignore errors
	self:Query("ALTER TABLE gmod_users ADD COLUMN name VARCHAR(128) NULL", nil, function() end)
end

function DB:Connect()
	if not mysqloo then
		IGS.print(Color(255,0,0), "[IGS] mysqloo module not found. Install MySQLOO.")
		return
	end

	local c = cfg()
	self.conn = mysqloo.connect(c.HOST, c.USER, c.PASS, c.NAME, c.PORT)

	-- Настройка SSL если требуется
	if c.USE_SSL then
		-- Проверяем доступные методы для SSL
		if type(self.conn.setSSL) == "function" then
			-- mysqloo с поддержкой SSL (новые версии)
			self.conn:setSSL(true)
		elseif type(self.conn.setOption) == "function" then
			-- Альтернативный способ через опции
			pcall(function() self.conn:setOption("SSL_ENABLED", true) end)
		elseif type(self.conn.enableSSL) == "function" then
			-- Еще один вариант
			self.conn:enableSSL()
		else
			-- Если SSL методы недоступны, предупреждаем
			IGS.print(Color(255,165,0), "[IGS] ВНИМАНИЕ: USE_SSL включен, но ваша версия mysqloo не поддерживает SSL. Обновите mysqloo или отключите require_secure_transport на MySQL.")
		end
	end

	function self.conn:onConnected()
		DB.connected = true
		IGS.print("MySQL connected" .. (c.USE_SSL and " (SSL)" or ""))
		DB:EnsureSchema()
		hook.Run("IGS.DBConnected")
	end

	function self.conn:onConnectionFailed(err)
		DB.connected = false
		local errMsg = tostring(err)
		if errMsg:find("require_secure_transport") then
			IGS.print(Color(255,0,0), "MySQL требует SSL. Установите USE_SSL = true в config_sv.lua или отключите require_secure_transport на MySQL сервере.")
		else
			IGS.print(Color(255,0,0), "MySQL connection failed: " .. errMsg)
		end
	end

	self.conn:connect()
end

hook.Add("Initialize", "IGS_DB_Init", function()
	DB:Connect()
end)

concommand.Add("igs_reload_db", function(ply)
	if IsValid(ply) then return end
	DB:Connect()
end)

local function ensureUserRow(s64, name_, cb)
	local sid = esc(s64)
	local name = name_ and esc(name_) or "NULL"
	local sql =
		"INSERT INTO gmod_users (steamid64, name, balance) VALUES (" ..
		sid .. "," .. name .. ",0) " ..
		"ON DUPLICATE KEY UPDATE " ..
		(name_ and ("name = " .. name .. ", ") or "") ..
		"steamid64 = steamid64;"

	DB:Query(sql, cb, function(err)
		hook.Run("IGS.OnApiError", "db.ensureUserRow", err, {sid = s64})
	end)
end

--[[
>----------------------------<
	ДЕЙСТВИЯ С ИГРОКОМ
>----------------------------<
]]
function IGS.UpdatePlayerName(s64, sName, fCallback)
	ensureUserRow(s64, sName, function()
		if fCallback then fCallback(true) end
	end)
end

function IGS.GetPlayer(s64, fCallback)
	if not DB.connected then
		if fCallback then fCallback() end
		return
	end
	local sql = "SELECT steamid64, name, balance FROM gmod_users WHERE steamid64 = " .. esc(s64) .. " LIMIT 1;"
	DB:Query(sql, function(data)
		local row = data and data[1]
		if not row then
			ensureUserRow(s64, nil, function()
				if fCallback then fCallback({Name = nil, Balance = 0}) end
			end)
			return
		end
		local bal = tonumber(row.balance) or 0
		if fCallback then
			fCallback({Name = row.name, Balance = bal})
		end
	end, function(err)
		hook.Run("IGS.OnApiError", "db.getPlayer", err, {sid = s64})
		if fCallback then fCallback() end
	end)
end

function IGS.GetBalance(s64, fCallback)
	IGS.GetPlayer(s64, function(player)
		if not player then
			fCallback(nil)
			return
		end
		fCallback(player["Balance"] or 0)
	end)
end

function IGS.GetName(s64, fCallback)
	IGS.GetPlayer(s64, function(player)
		fCallback(player and player["Name"] or nil)
	end)
end

--[[
>----------------------------<
	ТРАНЗАКЦИИ
>----------------------------<
]]
function IGS.Transaction(s64, iSum, sNote_, fCallback)
	local sum = tonumber(iSum) or 0
	local note = sNote_ and esc(sNote_) or "NULL"
	local server_id = IGS.SERVERS and IGS.SERVERS:ID() or nil
	local time = os.time()

	local sid = esc(s64)
	local upd =
		"INSERT INTO gmod_users (steamid64, balance) VALUES (" .. sid .. "," .. num(sum) .. ") " ..
		"ON DUPLICATE KEY UPDATE balance = balance + " .. num(sum) .. ";"

	DB:Query(upd, function()
		local sql =
			"INSERT INTO igs_transactions (steamid64, sum, note, server_id, time) VALUES (" ..
			sid .. "," .. num(sum) .. "," .. note .. "," .. (server_id and num(server_id) or "NULL") .. "," .. num(time) .. ");"

		DB:Query(sql, function(_, last_id)
			if fCallback then fCallback(last_id) end
			hook.Run("IGS.OnApiSuccess", "transactions.create", {sid = s64})
		end, function(err)
			hook.Run("IGS.OnApiError", "transactions.create", err, {sid = s64, sum = sum})
		end)
	end, function(err)
		hook.Run("IGS.OnApiError", "db.updateBalance", err, {sid = s64, sum = sum})
	end)
end

function IGS.GetTransactions(fCallback, s64_, bGlobal_, iLimit_, iOffset_)
	local limit  = math.min(tonumber(iLimit_) or 255, 255)
	local offset = tonumber(iOffset_) or 0
	local where = {}

	if s64_ then
		where[#where + 1] = "steamid64 = " .. esc(s64_)
	end
	if not bGlobal_ and IGS.SERVERS and IGS.SERVERS:ID() then
		where[#where + 1] = "server_id = " .. num(IGS.SERVERS:ID())
	end

	local where_sql = (#where > 0) and (" WHERE " .. table.concat(where, " AND ")) or ""
	local sql =
		"SELECT id, steamid64, sum, note, server_id, time FROM igs_transactions" ..
		where_sql .. " ORDER BY id DESC LIMIT " .. num(limit) .. " OFFSET " .. num(offset) .. ";"

	DB:Query(sql, function(data)
		local res = {}
		for i = 1, #(data or {}) do
			local v = data[i]
			res[#res + 1] = {
				ID      = tonumber(v.id),
				Sum     = tonumber(v.sum),
				Time    = tonumber(v.time),
				Note    = v.note,
				Server  = v.server_id and tonumber(v.server_id) or nil,
				SteamID = v.steamid64,
			}
		end
		fCallback(res)
	end, function(err)
		hook.Run("IGS.OnApiError", "transactions.get", err, {sid = s64_})
		fCallback({})
	end)
end

function IGS.GetPlayerTransactions(fCallback, s64)
	IGS.GetTransactions(fCallback, s64, true, 255)
end

function IGS.GetLatestTransactions(fCallback, iLimit_)
	IGS.GetTransactions(fCallback, nil, true, iLimit_)
end

--[[
>----------------------------<
	ПОКУПКИ
>----------------------------<
]]
function IGS.StorePurchase(s64, sItemUID, iDaysTerm_, iServerID, fCallback)
	local term = tonumber(iDaysTerm_)
	local expire = term and (os.time() + term * 86400) or nil
	local sql =
		"INSERT INTO igs_purchases (steamid64, item_uid, server_id, purchase_ts, expire_ts, active) VALUES (" ..
		esc(s64) .. "," .. esc(sItemUID) .. "," .. (iServerID and num(iServerID) or "NULL") .. "," ..
		num(os.time()) .. "," .. (expire and num(expire) or "NULL") .. ",1);"

	DB:Query(sql, function(_, last_id)
		if fCallback then fCallback(last_id) end
	end, function(err)
		hook.Run("IGS.OnApiError", "purchases.create", err, {sid = s64})
	end)
end

function IGS.StoreLocalPurchase(s64, sItemUID, iDaysTerm_, fCallback)
	IGS.StorePurchase(s64, sItemUID, iDaysTerm_, IGS.SERVERS:ID(), fCallback)
end

function IGS.MovePurchase(db_id, iNewServer_, fCallback)
	local set_server = (iNewServer_ == nil) and "server_id = NULL" or ("server_id = " .. num(iNewServer_))
	local set_active = (iNewServer_ == 0) and ", active = 0" or ""
	local sql = "UPDATE igs_purchases SET " .. set_server .. set_active .. " WHERE id = " .. num(db_id) .. " LIMIT 1;"

	DB:Query(sql, function()
		if fCallback then fCallback(true) end
	end, function(err)
		hook.Run("IGS.OnApiError", "purchases.move", err, {id = db_id})
		if fCallback then fCallback(false) end
	end)
end

function IGS.DisablePurchase(db_id, fCallback)
	IGS.MovePurchase(db_id, 0, fCallback)
end

function IGS.GetPurchases(fCallback, tParams)
	tParams = tParams or {}
	local where = {}
	local limit = math.min(tonumber(tParams.limit) or 127, 127)
	local offset = tonumber(tParams.offset) or 0

	if tParams.sid then
		where[#where + 1] = "p.steamid64 = " .. esc(tParams.sid)
	end

	if tParams.s then
		local s = num(tParams.s)
		where[#where + 1] = "(p.server_id = " .. s .. " OR p.server_id IS NULL)"
	end

	if tParams.only_active then
		where[#where + 1] = "p.active = 1"
		where[#where + 1] = "(p.expire_ts IS NULL OR p.expire_ts > " .. num(os.time()) .. ")"
	end

	local where_sql = (#where > 0) and (" WHERE " .. table.concat(where, " AND ")) or ""
	local sql =
		"SELECT p.id, p.server_id, p.item_uid, p.purchase_ts, p.expire_ts, p.steamid64, u.name " ..
		"FROM igs_purchases p " ..
		"LEFT JOIN gmod_users u ON u.steamid64 = p.steamid64 " ..
		where_sql ..
		" ORDER BY p.id DESC LIMIT " .. num(limit) .. " OFFSET " .. num(offset) .. ";"

	DB:Query(sql, function(data)
		local res = {}
		for i = 1, #(data or {}) do
			local v = data[i]
			res[#res + 1] = {
				ID      = tonumber(v.id),
				Server  = v.server_id and tonumber(v.server_id) or nil,
				Item    = v.item_uid,
				Purchase= tonumber(v.purchase_ts),
				Expire  = v.expire_ts and tonumber(v.expire_ts) or nil,
				SteamID = v.steamid64,
				Nick    = v.name,
			}
		end
		fCallback(res)
	end, function(err)
		hook.Run("IGS.OnApiError", "purchases.get", err, tParams)
		fCallback({})
	end)
end

function IGS.GetPlayerPurchases(s64, fCallback)
	IGS.GetPurchases(fCallback, {sid = s64, only_active = 1, s = IGS.SERVERS:ID()})
end

function IGS.GetLatestPurchases(fCallback, iLimit_)
	IGS.GetPurchases(fCallback, {limit = iLimit_ or 10})
end

--[[
>----------------------------<
	ССЫЛКИ
>----------------------------<
]]
function IGS.GetPaymentURL(fCallback, s64, iSum, sDescription_)
	local ykd = rawget(_G, "YKD") or {}
	local base = IGS.C.PAY_URL or ykd.PAY_URL
	if not base or base == "" then
		hook.Run("IGS.OnApiError", "url.getPayment", "pay_url_missing", {})
		return
	end

	local url = string.format("%s?steamid64=%s&amount=%s", base, s64, tostring(iSum))
	fCallback(url)
end

--[[
>----------------------------<
	ПРОЕКТ (Локальные настройки)
>----------------------------<
]]
function IGS.GetProjectData(fCallback)
	local settings = {
		MinCharge     = tonumber(IGS.C.MIN_CHARGE) or 0,
		CurrencyPrice = tonumber(IGS.C.CURRENCY_PRICE) or 1,
	}
	fCallback({
		settings = settings,
		name = IGS.C.PROJECT_NAME or "Local Project",
		coowners = {},
	})
end

function IGS.GetSettings(fCallback)
	IGS.GetProjectData(function(proj)
		fCallback(proj["settings"])
	end)
end

--[[
>----------------------------<
	СЕРВЕРЫ
>----------------------------<
]]
function IGS.AddServer(ip, port, fCallback)
	local now = os.time()
	local sql =
		"INSERT INTO igs_servers (name, ip, port, socket_port, disabled, version, created_ts, updated_ts) VALUES (" ..
		esc(GetConVarString("hostname")) .. "," .. esc(ip) .. "," .. num(port) .. ",NULL,0,NULL," ..
		num(now) .. "," .. num(now) .. ");"

	DB:Query(sql, function(_, last_id)
		if fCallback then fCallback(last_id) end
	end, function(err)
		hook.Run("IGS.OnApiError", "servers.create", err, {ip = ip, port = port})
	end)
end

function IGS.GetServers(fCallback, bIncludeDisabled_, iID_)
	local where = {}
	if iID_ then
		where[#where + 1] = "id = " .. num(iID_)
	end
	if not bIncludeDisabled_ then
		where[#where + 1] = "disabled = 0"
	end
	local where_sql = (#where > 0) and (" WHERE " .. table.concat(where, " AND ")) or ""
	local sql = "SELECT id, name, ip, port, socket_port, disabled FROM igs_servers" .. where_sql .. ";"

	DB:Query(sql, function(data)
		local res = {}
		for i = 1, #(data or {}) do
			local v = data[i]
			res[#res + 1] = {
				ID = tonumber(v.id),
				Name = v.name,
				IP = v.ip,
				Port = tonumber(v.port),
				SocketPort = v.socket_port and tonumber(v.socket_port) or nil,
				Disabled = tonumber(v.disabled) == 1,
			}
		end
		fCallback(res)
	end, function(err)
		hook.Run("IGS.OnApiError", "servers.get", err, {})
		fCallback({})
	end)
end

function IGS.GetExternalIP(fCallback)
	http.Fetch("https://api.ipify.org", function(body)
		fCallback(tostring(body))
	end, function()
		fCallback(nil)
	end)
end

function IGS.UpdateServer(iServerID, tParams, fCallback)
	if not tParams then
		if fCallback then fCallback(false) end
		return
	end

	local sets = {}
	if tParams.name then sets[#sets + 1] = "name = " .. esc(tParams.name) end
	if tParams.version then sets[#sets + 1] = "version = " .. num(tParams.version) end
	if tParams.state then sets[#sets + 1] = "disabled = " .. num(tParams.state ~= 0) end
	if tParams.ip then sets[#sets + 1] = "ip = " .. esc(tParams.ip) end
	if tParams.hostport then sets[#sets + 1] = "port = " .. num(tParams.hostport) end
	if tParams.s then iServerID = tParams.s end
	if tParams.port then sets[#sets + 1] = "socket_port = " .. num(tParams.port) end

	sets[#sets + 1] = "updated_ts = " .. num(os.time())

	local sql = "UPDATE igs_servers SET " .. table.concat(sets, ", ") .. " WHERE id = " .. num(iServerID) .. " LIMIT 1;"
	DB:Query(sql, function()
		if fCallback then fCallback(true) end
	end, function(err)
		hook.Run("IGS.OnApiError", "servers.update", err, {s = iServerID})
		if fCallback then fCallback(false) end
	end)
end

function IGS.UpdateCurrentServer(tParams, fCallback)
	IGS.UpdateServer(IGS.SERVERS:ID(), tParams, fCallback)
end

function IGS.SetServerName(sName, fCallback)
	IGS.UpdateCurrentServer({name = sName}, fCallback)
end

function IGS.SetServerSocketPort(iPort, fCallback)
	IGS.UpdateCurrentServer({port = iPort}, fCallback)
end

function IGS.SetServerVersion(iVersion, fCallback)
	IGS.UpdateCurrentServer({version = iVersion}, fCallback)
end

function IGS.UpdateServerAddress(iServerID, ip, port, fCallback)
	IGS.UpdateServer(iServerID, {ip = ip, hostport = port}, fCallback)
end

--[[
>----------------------------<
	ИНВЕНТАРЬ
>----------------------------<
]]
function IGS.StoreInventoryItem(fCallback, s64, sUid)
	local sql =
		"INSERT INTO igs_inventory (steamid64, item_uid, created_ts) VALUES (" ..
		esc(s64) .. "," .. esc(sUid) .. "," .. num(os.time()) .. ");"

	DB:Query(sql, function(_, last_id)
		if fCallback then fCallback(last_id) end
	end, function(err)
		hook.Run("IGS.OnApiError", "inventory.addItem", err, {sid = s64})
	end)
end

function IGS.FetchInventory(fCallback, s64)
	local sql = "SELECT id, item_uid FROM igs_inventory WHERE steamid64 = " .. esc(s64) .. " ORDER BY id ASC;"
	DB:Query(sql, function(data)
		local res = {}
		for i = 1, #(data or {}) do
			local v = data[i]
			res[#res + 1] = {ID = tonumber(v.id), Item = v.item_uid}
		end
		fCallback(res)
	end, function(err)
		hook.Run("IGS.OnApiError", "inventory.get", err, {sid = s64})
		fCallback({})
	end)
end

function IGS.DeleteInventoryItem(fCallback, iID)
	local sql = "DELETE FROM igs_inventory WHERE id = " .. num(iID) .. " LIMIT 1;"
	DB:Query(sql, function(_, _)
		if fCallback then fCallback(true) end
	end, function(err)
		hook.Run("IGS.OnApiError", "inventory.deleteItem", err, {id = iID})
		if fCallback then fCallback(false) end
	end)
end

--[[
>----------------------------<
	КУПОНЫ
>----------------------------<
]]
local function generateCouponCode()
	return hash.SHA256(tostring(os.time()) .. ":" .. tostring(math.random()) .. ":" .. tostring(SysTime()))
end

function IGS.CreateCoupon(iGiveMoney, iDaysTerm_, sNote_, fCallback)
	local code = generateCouponCode()
	local expire = iDaysTerm_ and (os.time() + tonumber(iDaysTerm_) * 86400) or nil
	local sql =
		"INSERT INTO igs_coupons (code, value, note, expire_ts, used_by, used_ts, created_ts) VALUES (" ..
		esc(code) .. "," .. num(iGiveMoney) .. "," .. (sNote_ and esc(sNote_) or "NULL") .. "," ..
		(expire and num(expire) or "NULL") .. ",NULL,NULL," .. num(os.time()) .. ");"

	DB:Query(sql, function()
		if fCallback then fCallback(code) end
	end, function(err)
		hook.Run("IGS.OnApiError", "coupons.create", err, {})
	end)
end

function IGS.GetCoupon(sCouponCode, fCallback)
	local sql = "SELECT code, value, expire_ts, used_by FROM igs_coupons WHERE code = " .. esc(sCouponCode) .. " LIMIT 1;"
	DB:Query(sql, function(data)
		local row = data and data[1]
		if not row then fCallback() return end
		fCallback({
			Value = tonumber(row.value),
			DateExpire = row.expire_ts and tonumber(row.expire_ts) or nil,
			UsedBy = row.used_by,
		})
	end, function(err)
		hook.Run("IGS.OnApiError", "coupons.get", err, {coupon = sCouponCode})
		fCallback()
	end)
end

function IGS.DeactivateCoupon(sActivatorSteamID, sCouponCode, fCallback)
	local now = os.time()
	local sql =
		"UPDATE igs_coupons SET used_by = " .. esc(sActivatorSteamID) .. ", used_ts = " .. num(now) ..
		" WHERE code = " .. esc(sCouponCode) .. " AND used_by IS NULL LIMIT 1;"

	DB:Query(sql, function()
		if fCallback then fCallback(true) end
	end, function(err)
		hook.Run("IGS.OnApiError", "coupons.deactivate", err, {coupon = sCouponCode})
		if fCallback then fCallback(false) end
	end)
end

--[[
>----------------------------<
	META
>----------------------------<
]]
kvapi = kvapi or {}

function kvapi.set(key, value, ttl, cb)
	http.Post("https://kv.gmod.app/set", {
		key = key,
		value = tostring(value),
		ttl = tostring(ttl),
	}, cb, error)
end

function kvapi.get(key, cb)
	http.Post("https://kv.gmod.app/get", {
		key = key,
	}, function(value, _, headers)
		cb(value ~= "" and value or nil, tonumber(headers.Expires))
	end, error)
end

function IGS.SetSharedKV(key, value, ttl, cb)
	kvapi.set((IGS.C.PROJECT_NAME or "local") .. ":" .. key:URLEncode(), value, ttl, cb)
end

function IGS.GetSharedKV(key, cb)
	kvapi.get((IGS.C.PROJECT_NAME or "local") .. ":" .. key:URLEncode(), cb)
end
