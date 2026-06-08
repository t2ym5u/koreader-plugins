local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local ButtonTable     = require("ui/widget/buttontable")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("gettext")
local T               = require("ffi/util").template

local ScreenBase           = require("screen_base")
local CrosswordBoard       = lrequire("board")
local CrosswordBoardWidget = lrequire("board_widget")

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- CrosswordScreen
-- ---------------------------------------------------------------------------

local CrosswordScreen = ScreenBase:extend{}

local KEY_ROWS = {
    {"Q","W","E","R","T","Y","U","I","O","P"},
    {"A","S","D","F","G","H","J","K","L"},
    {"↵","Z","X","C","V","B","N","M","⌫"},
}

function CrosswordScreen:init()
    local state = self.plugin:loadState()
    local idx   = self.plugin:getSetting("puzzle_idx", 1)
    self.board  = CrosswordBoard:new{ puzzle_idx = idx }
    if not self.board:load(state) then
        -- fresh puzzle
    end
    self.wrong_cells = nil
    ScreenBase.init(self)
end

function CrosswordScreen:serializeState()
    return self.board:serialize()
end

function CrosswordScreen:buildLayout()
    local sw           = DeviceScreen:getWidth()
    local sh           = DeviceScreen:getHeight()
    local is_landscape = self:isLandscape()

    local btn_width = is_landscape
        and math.max(math.floor(sw * 0.38), 120)
        or  math.floor(sw * 0.9)

    -- Top bar
    local top_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = {{
            { text = "\xe2\x97\x80", callback = function() self:onPrevPuzzle() end },
            { id = "puzzle_btn", text = self:_puzzleLabel(),
              callback = function() end },
            { text = "\xe2\x96\xb6", callback = function() self:onNextPuzzle() end },
            { id = "dir_btn", text = self:_dirLabel(),
              callback = function() self:toggleDirection() end },
            self:makeCloseButtonConfig(),
        }},
    }
    self.puzzle_btn = top_buttons:getButtonById("puzzle_btn")
    self.dir_btn    = top_buttons:getButtonById("dir_btn")

    -- Board widget
    local board_max
    if is_landscape then
        board_max = math.min(math.floor(sw * 0.45), sh - 40)
    else
        board_max = math.min(sw - Size.margin.default * 4, sh - 250)
    end
    board_max = math.max(board_max, 80)

    self.board_widget = CrosswordBoardWidget:new{
        board       = self.board,
        wrong_cells = self.wrong_cells,
        max_width   = board_max,
        max_height  = board_max,
        onCellTap   = function(r, c) self:onCellTap(r, c) end,
    }

    local board_frame = FrameContainer:new{
        padding = Size.padding.default,
        margin  = Size.margin.default,
        self.board_widget,
    }

    -- Clue text
    self.clue_widget = TextWidget:new{
        text  = self:_clueText(),
        face  = Font:getFace("smallinfofont"),
        width = btn_width,
    }

    -- Keyboard
    local key_rows_cfg = {}
    for _, row in ipairs(KEY_ROWS) do
        local btns = {}
        for _, key in ipairs(row) do
            local k = key
            btns[#btns + 1] = {
                text     = k,
                callback = function() self:onKeyPress(k) end,
            }
        end
        key_rows_cfg[#key_rows_cfg + 1] = btns
    end
    self.keyboard_widget = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = key_rows_cfg,
    }

    -- Bottom action buttons
    local action_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = {{
            { text = _("Check"),  callback = function() self:onCheck() end },
            { text = _("Reveal"), callback = function() self:onReveal() end },
            { text = _("Undo"),   callback = function() self:onUndo() end },
        }},
    }

    if is_landscape then
        local right = VerticalGroup:new{
            align = "center",
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.clue_widget,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.keyboard_widget,
            VerticalSpan:new{ width = Size.span.vertical_large },
            action_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
        }
        self.layout = HorizontalGroup:new{
            align  = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            right,
        }
    else
        self.layout = VerticalGroup:new{
            align = "center",
            VerticalSpan:new{ width = Size.span.vertical_large },
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            board_frame,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.clue_widget,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.keyboard_widget,
            VerticalSpan:new{ width = Size.span.vertical_large },
            action_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
        }
    end
    self[1] = self.layout
    self:updateStatus()
end

function CrosswordScreen:onCellTap(r, c)
    self.board:selectCell(r, c)
    self.wrong_cells = nil
    if self.board_widget then
        self.board_widget.wrong_cells = nil
        self.board_widget:refresh()
    end
    self:_refreshClue()
    self:updateStatus()
    if self.dir_btn then
        self.dir_btn:setText(self:_dirLabel(), self.dir_btn.width)
    end
end

function CrosswordScreen:onKeyPress(key)
    if key == "↵" then
        self:_advance()
    elseif key == "⌫" then
        self.board:deleteLetter()
    else
        self.board:typeLetter(key)
    end
    self.wrong_cells = nil
    if self.board_widget then
        self.board_widget.wrong_cells = nil
        self.board_widget:refresh()
    end
    self:_refreshClue()
    self:updateStatus()
    self.plugin:saveState(self.board:serialize())
end

function CrosswordScreen:_advance()
    -- Move to next empty cell in current direction
    local board = self.board
    local r, c = board.sel_r, board.sel_c
    if board.direction == "across" then
        local nc = c + 1
        while nc <= board.cols do
            if board.grid[r][nc] ~= "#" then
                board.sel_c = nc; break
            end
            nc = nc + 1
        end
    else
        local nr = r + 1
        while nr <= board.rows do
            if board.grid[nr][c] ~= "#" then
                board.sel_r = nr; break
            end
            nr = nr + 1
        end
    end
end

function CrosswordScreen:toggleDirection()
    self.board.direction = self.board.direction == "across" and "down" or "across"
    if self.dir_btn then
        self.dir_btn:setText(self:_dirLabel(), self.dir_btn.width)
    end
    if self.board_widget then self.board_widget:refresh() end
    self:_refreshClue()
end

function CrosswordScreen:onCheck()
    self.wrong_cells = self.board:checkLetters()
    if self.board_widget then
        self.board_widget.wrong_cells = self.wrong_cells
        self.board_widget:refresh()
    end
    local wrong_cnt = 0
    for r = 1, self.board.rows do
        for c = 1, self.board.cols do
            if self.wrong_cells[r] and self.wrong_cells[r][c] then
                wrong_cnt = wrong_cnt + 1
            end
        end
    end
    if wrong_cnt == 0 then
        self:updateStatus(_("No errors found!"))
    else
        self:updateStatus(T(_("Errors: %1"), wrong_cnt))
    end
end

function CrosswordScreen:onReveal()
    self.board:reveal()
    self.wrong_cells = nil
    if self.board_widget then
        self.board_widget.wrong_cells = nil
        self.board_widget:refresh()
    end
    self:updateStatus(_("Solution revealed."))
    self.plugin:saveState(self.board:serialize())
end

function CrosswordScreen:onUndo()
    self.board:undoMove()
    self.wrong_cells = nil
    if self.board_widget then
        self.board_widget.wrong_cells = nil
        self.board_widget:refresh()
    end
    self:updateStatus()
    self.plugin:saveState(self.board:serialize())
end

function CrosswordScreen:onNextPuzzle()
    local next_idx = (self.board.puzzle_idx % CrosswordBoard.NUM_PUZZLES) + 1
    self.board = CrosswordBoard:new{ puzzle_idx = next_idx }
    self.plugin:saveSetting("puzzle_idx", next_idx)
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function CrosswordScreen:onPrevPuzzle()
    local prev_idx = self.board.puzzle_idx - 1
    if prev_idx < 1 then prev_idx = CrosswordBoard.NUM_PUZZLES end
    self.board = CrosswordBoard:new{ puzzle_idx = prev_idx }
    self.plugin:saveSetting("puzzle_idx", prev_idx)
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function CrosswordScreen:_refreshClue()
    if not self.clue_widget then return end
    self.clue_widget:setText(self:_clueText())
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function CrosswordScreen:_clueText()
    local num, dir, clue = self.board:getCurrentClue()
    if num and clue ~= "" then
        local dir_str = dir == "across" and _("Across") or _("Down")
        return string.format("%d %s: %s", num, dir_str, clue)
    end
    return ""
end

function CrosswordScreen:updateStatus(msg)
    local status
    if msg then
        status = msg
    elseif self.board.won then
        status = T(_("Puzzle %1 solved!"), self.board.puzzle_idx)
    else
        -- Count filled vs total white cells
        local filled, total = 0, 0
        for r = 1, self.board.rows do
            for c = 1, self.board.cols do
                if self.board.grid[r][c] ~= "#" then
                    total = total + 1
                    if self.board.user[r][c] ~= "" then filled = filled + 1 end
                end
            end
        end
        status = T(_("%1/%2  %3"), filled, total, self.board.title)
    end
    ScreenBase.updateStatus(self, status)
end

function CrosswordScreen:_puzzleLabel()
    return T(_("%1/%2"), self.board.puzzle_idx, CrosswordBoard.NUM_PUZZLES)
end

function CrosswordScreen:_dirLabel()
    return self.board.direction == "across" and _("↔") or _("↕")
end

return CrosswordScreen
