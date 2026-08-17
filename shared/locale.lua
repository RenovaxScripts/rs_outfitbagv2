local fallbackLocale = 'en'

function _L(key, replacements)
    local locale = Locales[Config.Locale] or Locales[fallbackLocale] or {}
    local fallback = Locales[fallbackLocale] or {}
    local value = locale[key] or fallback[key] or key

    if replacements then
        for name, replacement in pairs(replacements) do
            value = value:gsub('{' .. name .. '}', function()
                return tostring(replacement)
            end)
        end
    end

    return value
end

function GetLocaleData()
    return Locales[Config.Locale] or Locales[fallbackLocale] or {}
end
