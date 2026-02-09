--[[
    Клиентская предзагрузка иконок товаров
    Загружает все иконки в фоне при подключении к серверу
]]

if SERVER then return end

local preloadQueue = {}
local isPreloading = false
local preloadedCount = 0
local totalToPreload = 0

-- Функция для предзагрузки одной иконки
local function PreloadIcon(url, callback)
    if not url or not url:match("^https?://") then 
        if callback then callback(false) end
        return 
    end
    
    -- Проверяем, не загружена ли уже
    if texture.Get(url) then
        if callback then callback(true) end
        return
    end
    
    -- Создаем и загружаем текстуру
    texture.Create(url)
        :SetSize(256, 256) -- Оптимальный размер для качества/производительности
        :SetFormat(url:sub(-3) == "jpg" and "jpg" or "png")
        :Download(url, function()
            preloadedCount = preloadedCount + 1
            if callback then callback(true) end
        end, function()
            preloadedCount = preloadedCount + 1
            if callback then callback(false) end
        end)
end

-- Обработка очереди загрузки (параллельная загрузка)
local function ProcessPreloadQueue()
    if #preloadQueue == 0 then
        isPreloading = false
        print("[IGS] Все иконки предзагружены: " .. preloadedCount .. "/" .. totalToPreload)
        return
    end
    
    isPreloading = true
    
    -- Загружаем до 10 иконок параллельно для быстрой загрузки
    local batchSize = math.min(10, #preloadQueue)
    for i = 1, batchSize do
        local url = table.remove(preloadQueue, 1)
        if url then
            PreloadIcon(url, function(success)
                -- Продолжаем загрузку когда batch завершен
                if preloadedCount >= totalToPreload or #preloadQueue == 0 then
                    ProcessPreloadQueue()
                end
            end)
        end
    end
    
    -- Продолжаем загрузку следующего batch быстрее
    if #preloadQueue > 0 then
        timer.Simple(0.05, ProcessPreloadQueue)
    end
end

-- Запуск предзагрузки всех иконок товаров
local function StartPreloading()
    if isPreloading then return end
    
    preloadQueue = {}
    preloadedCount = 0
    totalToPreload = 0
    
    -- Собираем все уникальные URL иконок
    local urls = {}
    for uid, ITEM in pairs(IGS.ITEMS.STORED or {}) do
        local icon = ITEM:ICON()
        if icon and icon:match("^https?://") and not urls[icon] then
            urls[icon] = true
            table.insert(preloadQueue, icon)
            totalToPreload = totalToPreload + 1
        end
    end
    
    if totalToPreload > 0 then
        print("[IGS] Начинается предзагрузка " .. totalToPreload .. " иконок...")
        ProcessPreloadQueue()
    end
end

-- Автоматическая предзагрузка при инициализации IGS
hook.Add("IGS.Loaded", "PreloadItemIcons", function()
    timer.Simple(0.5, StartPreloading) -- Задержка 0.5 секунды после загрузки IGS
end)

-- Экспортируем функцию для вызова из других модулей
IGS.PreloadIcons = StartPreloading

-- Команда для ручной перезагрузки иконок
concommand.Add("igs_reload_icons", function()
    print("[IGS] Принудительная перезагрузка иконок...")
    StartPreloading()
end)

-- Очистка кэша иконок
concommand.Add("igs_clear_icon_cache", function()
    local files = file.Find("texture/*.png", "DATA")
    local count = 0
    for _, f in ipairs(files) do
        file.Delete("texture/" .. f)
        count = count + 1
    end
    print("[IGS] Очищено " .. count .. " кэшированных иконок")
    print("[IGS] Используйте 'igs_reload_icons' для повторной загрузки")
end)
