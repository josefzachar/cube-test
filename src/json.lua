-- json.lua - Simple JSON encoder/decoder for Square Golf

local json = {}

-- Encode a Lua table to a JSON string
function json.encode(data)
    local t = type(data)
    
    -- Handle simple types
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return data and "true" or "false"
    elseif t == "number" then
        return tostring(data)
    elseif t == "string" then
        return '"' .. json.escapeString(data) .. '"'
    elseif t == "table" then
        -- Check if it's an array or an object
        local isArray = true
        local maxIndex = 0
        
        for k, v in pairs(data) do
            if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, k)
        end
        
        -- Check if it's a sparse array
        if isArray and maxIndex > #data * 2 then
            isArray = false
        end
        
        local result = {}
        
        if isArray then
            -- Encode as JSON array
            for i = 1, #data do
                table.insert(result, json.encode(data[i]))
            end
            return "[" .. table.concat(result, ",") .. "]"
        else
            -- Encode as JSON object
            for k, v in pairs(data) do
                if type(k) == "string" or type(k) == "number" then
                    table.insert(result, '"' .. json.escapeString(tostring(k)) .. '":' .. json.encode(v))
                end
            end
            return "{" .. table.concat(result, ",") .. "}"
        end
    else
        error("Cannot encode " .. t .. " to JSON")
    end
end

-- Escape special characters in a string
function json.escapeString(s)
    local escapes = {
        ['"'] = '\\"',
        ['\\'] = '\\\\',
        ['/'] = '\\/',
        ['\b'] = '\\b',
        ['\f'] = '\\f',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t'
    }
    
    return s:gsub('["\\/\b\f\n\r\t]', escapes)
end

-- Decode a JSON string to a Lua table
function json.decode(str)
    -- Initialize the position
    local pos = 1
    
    -- Skip whitespace
    local function skipWhitespace()
        pos = str:match("^%s*()%S", pos) or #str + 1
    end
    
    -- Forward declarations
    local parseValue, parseObject, parseArray, parseString, parseNumber
    
    -- Parse a JSON value
    parseValue = function()
        skipWhitespace()
        local c = str:sub(pos, pos)
        
        if c == '{' then
            return parseObject()
        elseif c == '[' then
            return parseArray()
        elseif c == '"' then
            return parseString()
        elseif c == '-' or (c >= '0' and c <= '9') then
            return parseNumber()
        elseif str:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif str:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif str:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        else
            error("Invalid JSON at position " .. pos .. ": " .. str:sub(pos, pos + 10))
        end
    end
    
    -- Parse a JSON object
    parseObject = function()
        local obj = {}
        pos = pos + 1 -- Skip '{'
        
        skipWhitespace()
        if str:sub(pos, pos) == "}" then
            pos = pos + 1
            return obj
        end
        
        while true do
            skipWhitespace()
            
            -- Parse key
            if str:sub(pos, pos) ~= '"' then
                error("Expected string key at position " .. pos)
            end
            
            local key = parseString()
            
            skipWhitespace()
            if str:sub(pos, pos) ~= ":" then
                error("Expected ':' at position " .. pos)
            end
            pos = pos + 1
            
            -- Parse value
            obj[key] = parseValue()
            
            skipWhitespace()
            if str:sub(pos, pos) == "}" then
                pos = pos + 1
                return obj
            end
            
            if str:sub(pos, pos) ~= "," then
                error("Expected ',' or '}' at position " .. pos)
            end
            pos = pos + 1
        end
    end
    
    -- Parse a JSON array
    parseArray = function()
        local arr = {}
        pos = pos + 1 -- Skip '['
        
        skipWhitespace()
        if str:sub(pos, pos) == "]" then
            pos = pos + 1
            return arr
        end
        
        while true do
            table.insert(arr, parseValue())
            
            skipWhitespace()
            if str:sub(pos, pos) == "]" then
                pos = pos + 1
                return arr
            end
            
            if str:sub(pos, pos) ~= "," then
                error("Expected ',' or ']' at position " .. pos)
            end
            pos = pos + 1
        end
    end
    
    -- Parse a JSON string
    parseString = function()
        local startPos = pos + 1 -- Skip opening quote
        local endPos = startPos
        
        while true do
            endPos = str:find('"', endPos, true)
            if not endPos then
                error("Unterminated string at position " .. pos)
            end
            
            -- Check if the quote is escaped
            local backslashes = 0
            local i = endPos - 1
            while str:sub(i, i) == '\\' do
                backslashes = backslashes + 1
                i = i - 1
            end
            
            if backslashes % 2 == 0 then
                break
            end
            
            endPos = endPos + 1
        end
        
        local s = str:sub(startPos, endPos - 1)
        pos = endPos + 1
        
        -- Unescape the string
        s = s:gsub('\\(.)', {
            ['"'] = '"',
            ['\\'] = '\\',
            ['/'] = '/',
            ['b'] = '\b',
            ['f'] = '\f',
            ['n'] = '\n',
            ['r'] = '\r',
            ['t'] = '\t'
        })
        
        return s
    end
    
    -- Parse a JSON number
    parseNumber = function()
        local numStr = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
        pos = pos + #numStr
        return tonumber(numStr)
    end
    
    -- Start parsing
    local result = parseValue()
    skipWhitespace()
    
    if pos <= #str then
        error("Unexpected trailing characters at position " .. pos)
    end
    
    return result
end

return json
