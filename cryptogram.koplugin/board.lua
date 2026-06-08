local PHRASES_EN = {
    "THE QUICK BROWN FOX",
    "TO BE OR NOT TO BE",
    "ALL THAT GLITTERS IS NOT GOLD",
    "ACTIONS SPEAK LOUDER THAN WORDS",
    "BETTER LATE THAN NEVER",
    "EVERY CLOUD HAS A SILVER LINING",
    "PRACTICE MAKES PERFECT",
    "TIME FLIES WHEN YOU HAVE FUN",
    "YOU ONLY LIVE ONCE",
    "KNOWLEDGE IS POWER",
    "LOOK BEFORE YOU LEAP",
    "BIRDS OF A FEATHER FLOCK TOGETHER",
    "A PENNY SAVED IS A PENNY EARNED",
    "THE EARLY BIRD CATCHES THE WORM",
    "HONESTY IS THE BEST POLICY",
    "LAUGHTER IS THE BEST MEDICINE",
    "FORTUNE FAVORS THE BRAVE",
    "WHERE THERE IS WILL THERE IS WAY",
    "ABSENCE MAKES THE HEART GROW FONDER",
    "UNITED WE STAND DIVIDED WE FALL",
}

local PHRASES_FR = {
    "LA VIE EST BELLE",
    "LE TEMPS C EST DE L ARGENT",
    "MIEUX VAUT TARD QUE JAMAIS",
    "LA PATIENCE EST UNE VERTU",
    "L UNION FAIT LA FORCE",
    "VOULOIR C EST POUVOIR",
    "CHAQUE CHOSE EN SON TEMPS",
    "LE MIEUX EST L ENNEMI DU BIEN",
    "LA VERITE SORTIRA TOUJOURS",
    "AIDE TOI ET LE CIEL T AIDERA",
    "LES PAROLES S ENVOLENT LES ECRITS RESTENT",
    "RIEN NE SERT DE COURIR IL FAUT PARTIR A POINT",
    "A COEUR VAILLANT RIEN D IMPOSSIBLE",
    "QUI SEME LE VENT RECOLTE LA TEMPETE",
    "TOUT VIENT A POINT A QUI SAIT ATTENDRE",
    "LA NUIT PORTE CONSEIL",
    "IL N Y A PAS DE FUMEE SANS FEU",
    "PIERRE QUI ROULE N AMASSE PAS MOUSSE",
    "LES EXTREMES SE TOUCHENT",
    "LA FIN JUSTIFIE LES MOYENS",
}

local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

-- ---------------------------------------------------------------------------
-- CryptogramBoard
-- ---------------------------------------------------------------------------

local CryptogramBoard = {}
CryptogramBoard.__index = CryptogramBoard

function CryptogramBoard:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        lang            = opts.lang or "en",
        phrase          = "",
        ciphered        = "",
        cipher_map      = {},
        decipher_map    = {},
        user_map        = {},
        selected_cipher = nil,
        wins            = opts.wins or 0,
    }, self)
    obj:newGame()
    return obj
end

function CryptogramBoard:_phraseList()
    return self.lang == "fr" and PHRASES_FR or PHRASES_EN
end

function CryptogramBoard:newGame()
    local list   = self:_phraseList()
    local phrase = list[math.random(#list)]
    self.phrase  = phrase

    -- build a random bijective substitution cipher (never map letter to itself)
    local letters = {}
    for i = 1, 26 do letters[i] = ALPHA:sub(i, i) end

    -- Fisher-Yates shuffle to get a derangement
    local perm = {}
    for i = 1, 26 do perm[i] = i end
    repeat
        for i = 26, 2, -1 do
            local j = math.random(i)
            perm[i], perm[j] = perm[j], perm[i]
        end
        -- check: no fixed points
        local ok = true
        for i = 1, 26 do
            if perm[i] == i then ok = false; break end
        end
        if ok then break end
    until false

    self.cipher_map   = {}
    self.decipher_map = {}
    for i = 1, 26 do
        local plain  = letters[i]
        local cipher = letters[perm[i]]
        self.cipher_map[plain]   = cipher
        self.decipher_map[cipher] = plain
    end

    -- encipher the phrase
    local ciphered = {}
    for i = 1, #phrase do
        local ch = phrase:sub(i, i)
        if ch >= "A" and ch <= "Z" then
            ciphered[i] = self.cipher_map[ch]
        else
            ciphered[i] = ch
        end
    end
    self.ciphered = table.concat(ciphered)

    self.user_map        = {}
    self.selected_cipher = nil
end

function CryptogramBoard:selectCipher(letter)
    if letter >= "A" and letter <= "Z" then
        self.selected_cipher = letter
    end
end

-- Assign a plain letter to the currently selected cipher letter
function CryptogramBoard:assignLetter(plain)
    local cipher = self.selected_cipher
    if not cipher then return end
    if self.user_map[cipher] == plain then
        self.user_map[cipher] = nil
    else
        -- remove any existing assignment for this plain letter
        for k, v in pairs(self.user_map) do
            if v == plain then self.user_map[k] = nil end
        end
        self.user_map[cipher] = plain
    end
end

function CryptogramBoard:clearAll()
    self.user_map        = {}
    self.selected_cipher = nil
end

-- Returns the phrase with user_map applied (? for undecoded letters)
function CryptogramBoard:getDisplayPhrase()
    local result = {}
    for i = 1, #self.ciphered do
        local ch = self.ciphered:sub(i, i)
        if ch >= "A" and ch <= "Z" then
            result[i] = self.user_map[ch] or "?"
        else
            result[i] = ch
        end
    end
    return table.concat(result)
end

function CryptogramBoard:isComplete()
    for i = 1, #self.ciphered do
        local ch = self.ciphered:sub(i, i)
        if ch >= "A" and ch <= "Z" then
            if self.user_map[ch] ~= self.decipher_map[ch] then
                return false
            end
        end
    end
    return true
end

function CryptogramBoard:decodedCount()
    local total   = 0
    local decoded = 0
    local seen    = {}
    for i = 1, #self.ciphered do
        local ch = self.ciphered:sub(i, i)
        if ch >= "A" and ch <= "Z" and not seen[ch] then
            seen[ch] = true
            total = total + 1
            if self.user_map[ch] then decoded = decoded + 1 end
        end
    end
    return decoded, total
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function CryptogramBoard:serialize()
    local cm, dm, um = {}, {}, {}
    for k, v in pairs(self.cipher_map)   do cm[#cm+1] = { k, v } end
    for k, v in pairs(self.decipher_map) do dm[#dm+1] = { k, v } end
    for k, v in pairs(self.user_map)     do um[#um+1] = { k, v } end
    return {
        lang            = self.lang,
        phrase          = self.phrase,
        ciphered        = self.ciphered,
        cipher_map      = cm,
        decipher_map    = dm,
        user_map        = um,
        selected_cipher = self.selected_cipher,
        wins            = self.wins,
    }
end

function CryptogramBoard:load(data)
    if type(data) ~= "table" or not data.phrase then return false end
    self.lang    = data.lang    or "en"
    self.phrase  = data.phrase  or ""
    self.ciphered = data.ciphered or ""
    self.wins    = data.wins    or 0
    self.selected_cipher = data.selected_cipher

    self.cipher_map   = {}
    self.decipher_map = {}
    self.user_map     = {}
    for _, pair in ipairs(data.cipher_map   or {}) do self.cipher_map[pair[1]]   = pair[2] end
    for _, pair in ipairs(data.decipher_map or {}) do self.decipher_map[pair[1]] = pair[2] end
    for _, pair in ipairs(data.user_map     or {}) do self.user_map[pair[1]]     = pair[2] end
    return true
end

return CryptogramBoard
