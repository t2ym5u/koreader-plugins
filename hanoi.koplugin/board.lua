-- ---------------------------------------------------------------------------
-- HanoiBoard — Towers of Hanoi game logic
-- ---------------------------------------------------------------------------

local HanoiBoard = {}
HanoiBoard.__index = HanoiBoard

function HanoiBoard:new(opts)
    opts = opts or {}
    local num_disks = tonumber(opts.num_disks) or 3
    local o = setmetatable({}, self)
    o.num_disks     = num_disks
    o.pegs          = nil
    o.selected_peg  = nil
    o.moves         = 0
    o.won           = false
    o.optimal       = (1 << num_disks) - 1
    o:_reset()
    return o
end

function HanoiBoard:_reset()
    local nd = self.num_disks
    self.pegs = {{}, {}, {}}
    for i = nd, 1, -1 do
        self.pegs[1][#self.pegs[1] + 1] = i
    end
    self.selected_peg = nil
    self.moves        = 0
    self.won          = false
    self.optimal      = (1 << nd) - 1
end

function HanoiBoard:newGame(num_disks)
    if num_disks then self.num_disks = num_disks end
    self:_reset()
end

-- Returns top disk of peg p (nil if empty)
function HanoiBoard:_top(p)
    local peg = self.pegs[p]
    return peg[#peg]
end

-- selectPeg: tap action
-- Returns: "selected", "moved", "won", "invalid", "deselected"
function HanoiBoard:selectPeg(p)
    if self.won then return "invalid" end
    if self.selected_peg == nil then
        if #self.pegs[p] == 0 then return "invalid" end
        self.selected_peg = p
        return "selected"
    end
    if self.selected_peg == p then
        self.selected_peg = nil
        return "deselected"
    end
    -- attempt move
    local src = self.selected_peg
    local dst = p
    self.selected_peg = nil
    local top_src = self:_top(src)
    local top_dst = self:_top(dst)
    if top_src == nil then return "invalid" end
    if top_dst ~= nil and top_src > top_dst then return "invalid" end
    -- move
    table.remove(self.pegs[src])
    self.pegs[dst][#self.pegs[dst] + 1] = top_src
    self.moves = self.moves + 1
    -- check win: all disks on peg 3
    if #self.pegs[3] == self.num_disks then
        self.won = true
        return "won"
    end
    return "moved"
end

function HanoiBoard:serialize()
    local p1, p2, p3 = {}, {}, {}
    for _, v in ipairs(self.pegs[1]) do p1[#p1 + 1] = v end
    for _, v in ipairs(self.pegs[2]) do p2[#p2 + 1] = v end
    for _, v in ipairs(self.pegs[3]) do p3[#p3 + 1] = v end
    return {
        num_disks    = self.num_disks,
        peg1         = p1,
        peg2         = p2,
        peg3         = p3,
        selected_peg = self.selected_peg,
        moves        = self.moves,
        won          = self.won,
    }
end

function HanoiBoard:load(data)
    if type(data) ~= "table" or not data.peg1 then return false end
    self.num_disks    = tonumber(data.num_disks) or 3
    self.pegs         = { {}, {}, {} }
    for _, v in ipairs(data.peg1 or {}) do self.pegs[1][#self.pegs[1] + 1] = v end
    for _, v in ipairs(data.peg2 or {}) do self.pegs[2][#self.pegs[2] + 1] = v end
    for _, v in ipairs(data.peg3 or {}) do self.pegs[3][#self.pegs[3] + 1] = v end
    self.selected_peg = data.selected_peg
    self.moves        = data.moves or 0
    self.won          = data.won   or false
    self.optimal      = (1 << self.num_disks) - 1
    return true
end

return HanoiBoard
