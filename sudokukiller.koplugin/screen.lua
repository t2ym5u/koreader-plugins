local ButtonTable = require("ui/widget/buttontable")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local Menu = require("ui/widget/menu")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local T = require("ffi/util").template

local board_module = require("board")
local KillerSudokuBoardWidget = require("board_widget")

local Screen = Device.screen

local DIFFICULTY_ORDER = { "easy", "medium", "hard" }
local DIFFICULTY_LABELS = {
    easy   = _("Easy"),
    medium = _("Medium"),
    hard   = _("Hard"),
}
local DIFFICULTY_CAGE_HINT = {
    easy   = "28-32",
    medium = "22-27",
    hard   = "16-21",
}

-- ---------------------------------------------------------------------------
-- KillerSudokuScreen — full-screen game UI
-- ---------------------------------------------------------------------------

local KillerSudokuScreen = InputContainer:extend{}

function KillerSudokuScreen:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.covers_fullscreen = true
    self.vertical_align = "center"
    self.note_mode = false
    self.undo_button = nil
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    self.status_text = TextWidget:new{
        text = _("Tap a cell, then pick a number."),
        face = Font:getFace("smallinfofont"),
    }
    self:buildLayout()
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function KillerSudokuScreen:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    local content_size = self.layout:getSize()
    local offset_x = x + math.floor((self.dimen.w - content_size.w) / 2)
    local offset_y = y
    if self.vertical_align == "center" then
        offset_y = offset_y + math.floor((self.dimen.h - content_size.h) / 2)
    end
    self.layout:paintTo(bb, offset_x, offset_y)
end

function KillerSudokuScreen:buildLayout()
    self.board_widget = KillerSudokuBoardWidget:new{
        board = self.board,
        onSelectionChanged = function()
            self:updateStatus()
        end,
    }

    local is_landscape = Screen:getWidth() > Screen:getHeight()
    local sw = Screen:getWidth()

    local board_frame = FrameContainer:new{
        padding = Size.padding.large,
        margin = Size.margin.default,
        self.board_widget,
    }

    local board_frame_size = self.board_widget.size + (Size.padding.large + Size.margin.default) * 2
    local right_panel_width = sw - board_frame_size - Size.span.horizontal_large
    local button_width = is_landscape
        and math.max(right_panel_width - Size.span.horizontal_large, 100)
        or math.floor(sw * 0.9)
    local keypad_width = is_landscape
        and button_width
        or math.floor(sw * 0.75)

    -- Top action bar: [New game] [Difficulty] [Show result] [Close]
    local top_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width = button_width,
        buttons = {
            {
                {
                    text = _("New game"),
                    callback = function()
                        self:onNewGame()
                    end,
                },
                {
                    id = "difficulty_button",
                    text = self:getDifficultyButtonText(),
                    callback = function()
                        self:openDifficultyMenu()
                    end,
                },
                {
                    id = "show_result",
                    text = _("Show result"),
                    callback = function()
                        self:toggleSolution()
                    end,
                },
                {
                    text = _("Close"),
                    callback = function()
                        self:onClose()
                        UIManager:close(self)
                        UIManager:setDirty(nil, "full")
                    end,
                },
            },
        },
    }
    self.show_result_button = top_buttons:getButtonById("show_result")
    self.difficulty_button  = top_buttons:getButtonById("difficulty_button")

    -- Digit keypad: 3 rows of 3 buttons (9×9 only), then an action row
    local n        = self.board.n
    local box_rows = self.board.box_rows
    local box_cols = self.board.box_cols
    local keypad_rows = {}
    local digit = 1
    for _ = 1, box_rows do
        local row = {}
        for _ = 1, box_cols do
            local d = digit
            row[#row + 1] = {
                id = "digit_" .. d,
                text = tostring(d),
                callback = function()
                    self:onDigit(d)
                end,
            }
            digit = digit + 1
        end
        keypad_rows[#keypad_rows + 1] = row
    end
    -- Action row
    keypad_rows[#keypad_rows + 1] = {
        {
            id = "note_button",
            text = self:getNoteButtonText(),
            callback = function()
                self:toggleNoteMode()
            end,
        },
        {
            text = _("Erase"),
            callback = function()
                self:onErase()
            end,
        },
        {
            text = _("Check"),
            callback = function()
                self:checkProgress()
            end,
        },
        {
            id = "undo_button",
            text = _("Undo"),
            callback = function()
                self:onUndo()
            end,
        },
    }
    local keypad = ButtonTable:new{
        width = keypad_width,
        shrink_unneeded_width = true,
        buttons = keypad_rows,
    }
    self.note_button = keypad:getButtonById("note_button")
    self.undo_button = keypad:getButtonById("undo_button")
    self.digit_buttons = {}
    for d = 1, n do
        self.digit_buttons[d] = keypad:getButtonById("digit_" .. d)
    end

    if is_landscape then
        local right_panel = VerticalGroup:new{
            align = "center",
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            keypad,
        }
        self.layout = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_large },
            right_panel,
        }
    else
        self.layout = VerticalGroup:new{
            align = "center",
            VerticalSpan:new{ width = Size.span.vertical_large },
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            board_frame,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            keypad,
            VerticalSpan:new{ width = Size.span.vertical_large },
        }
    end
    self[1] = self.layout
    self:ensureShowButtonState()
    self:updateNoteButton()
    self:updateUndoButton()
    self:updateDigitButtons()
    self:updateDifficultyButton()
    self:updateStatus()
end

-- ---------------------------------------------------------------------------
-- Button text helpers
-- ---------------------------------------------------------------------------

function KillerSudokuScreen:getNoteButtonText()
    return self.note_mode and _("Note: On") or _("Note: Off")
end

function KillerSudokuScreen:getDifficultyButtonText()
    local diff = self.board.difficulty
    local label = DIFFICULTY_LABELS[diff] or diff
    local hint  = DIFFICULTY_CAGE_HINT[diff] or ""
    return T(_("Diff: %1 (%2)"), label, hint)
end

-- ---------------------------------------------------------------------------
-- Button update helpers
-- ---------------------------------------------------------------------------

function KillerSudokuScreen:updateNoteButton()
    if not self.note_button then return end
    self.note_button:setText(self:getNoteButtonText(), self.note_button.width)
end

function KillerSudokuScreen:updateUndoButton()
    if not self.undo_button then return end
    self.undo_button:enableDisable(self.board:canUndo())
end

function KillerSudokuScreen:updateDigitButtons()
    if not self.digit_buttons then return end
    local n = self.board.n
    for d = 1, n do
        local btn = self.digit_buttons[d]
        if btn then
            btn:enableDisable(self.board:countDigit(d) < n)
        end
    end
end

function KillerSudokuScreen:updateDifficultyButton()
    if not self.difficulty_button then return end
    self.difficulty_button:setText(self:getDifficultyButtonText(), self.difficulty_button.width)
end

-- ---------------------------------------------------------------------------
-- Mode toggles
-- ---------------------------------------------------------------------------

function KillerSudokuScreen:toggleNoteMode()
    self.note_mode = not self.note_mode
    self:updateNoteButton()
    self:updateStatus(self.note_mode and _("Note mode enabled.") or _("Note mode disabled."))
end

-- ---------------------------------------------------------------------------
-- Difficulty menu
-- ---------------------------------------------------------------------------

function KillerSudokuScreen:openDifficultyMenu()
    local menu
    local function selectDifficulty(level)
        if level ~= self.board.difficulty then
            self.board:generate(level)
            self.plugin:saveState()
            self.board_widget:refresh()
            self:ensureShowButtonState()
            self:updateDigitButtons()
            self:updateStatus(T(_("Started a %1 game."), DIFFICULTY_LABELS[level] or level))
        else
            self:updateStatus()
        end
        self:updateDifficultyButton()
        if menu then UIManager:close(menu) end
        return true
    end

    local items = {}
    for _, level in ipairs(DIFFICULTY_ORDER) do
        local hint = DIFFICULTY_CAGE_HINT[level] or ""
        items[#items + 1] = {
            text = T(_("%1 (%2 cages)"), DIFFICULTY_LABELS[level] or level, hint),
            checked = (level == self.board.difficulty),
            callback = function() return selectDifficulty(level) end,
        }
    end
    menu = Menu:new{
        title = _("Select difficulty"),
        item_table = items,
        width = math.floor(Screen:getWidth() * 0.7),
        height = math.floor(Screen:getHeight() * 0.9),
        disable_footer_padding = true,
        show_parent = self,
    }
    UIManager:show(menu)
end

-- ---------------------------------------------------------------------------
-- Status bar
-- ---------------------------------------------------------------------------

function KillerSudokuScreen:updateStatus(message)
    local status
    if message then
        status = message
    else
        local remaining = self.board:getRemainingCells()
        local row, col = self.board:getSelection()
        -- Cage info for selected cell
        local cage_info = ""
        local cage = self.board:getCage(row, col)
        if cage then
            local cage_filled = 0
            local cage_partial = 0
            for _, cell in ipairs(cage.cells) do
                local v = self.board:getWorkingValue(cell.r, cell.c)
                if v ~= 0 then
                    cage_filled = cage_filled + 1
                    cage_partial = cage_partial + v
                end
            end
            cage_info = T(_("  ·  Cage: %1/%2 cells, sum %3/%4"),
                cage_filled, #cage.cells, cage_partial, cage.sum)
        end
        status = T(_("Selected: %1,%2  ·  Empty: %3%4"), row, col, remaining, cage_info)
        if self.board:isShowingSolution() then
            status = status .. "\n" .. _("Result is being shown; editing is disabled.")
        elseif self.board:isSolved() then
            status = _("Congratulations! Puzzle solved.")
        elseif self.note_mode then
            status = status .. "\n" .. _("Note mode is ON.")
        end
    end
    self.status_text:setText(status)
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

-- ---------------------------------------------------------------------------
-- Game actions
-- ---------------------------------------------------------------------------

function KillerSudokuScreen:onDigit(value)
    if self.note_mode then
        local ok, err = self.board:toggleNoteDigit(value)
        if not ok then
            self:updateStatus(err)
            return
        end
        self.board_widget:refresh()
        self:updateStatus()
        self.plugin:saveState()
        self:updateUndoButton()
        return
    end
    local ok, err = self.board:setValue(value)
    if not ok then
        self:updateStatus(err)
        return
    end
    self.board_widget:refresh()
    self:updateStatus()
    self.plugin:saveState()
    self:updateUndoButton()
    self:updateDigitButtons()
    if self.board:isSolved() then
        UIManager:show(InfoMessage:new{ text = _("Puzzle complete!"), timeout = 4 })
    end
end

function KillerSudokuScreen:onErase()
    local row, col = self.board:getSelection()
    self.board:clearNotes(row, col)
    local ok, err = self.board:clearSelection()
    if not ok then
        self:updateStatus(err)
        return
    end
    self.board_widget:refresh()
    self:updateStatus()
    self.plugin:saveState()
    self:updateUndoButton()
    self:updateDigitButtons()
end

function KillerSudokuScreen:onNewGame()
    self.board:generate(self.board.difficulty)
    self.plugin:saveState()
    self.board_widget:refresh()
    self:ensureShowButtonState()
    self:updateUndoButton()
    self:updateDigitButtons()
    self:updateStatus(_("Started a new game."))
end

function KillerSudokuScreen:toggleSolution()
    self.board:toggleSolution()
    self.plugin:saveState()
    self.board_widget:refresh()
    self:ensureShowButtonState()
    self:updateStatus(self.board:isShowingSolution() and _("Showing the solution.") or nil)
end

function KillerSudokuScreen:ensureShowButtonState()
    if not self.show_result_button then return end
    local text = self.board:isShowingSolution() and _("Hide result") or _("Show result")
    self.show_result_button:setText(text, self.show_result_button.width)
end

function KillerSudokuScreen:checkProgress()
    self.board:updateWrongMarks()
    self.board_widget:refresh()
    self.plugin:saveState()
    if self.board:isSolved() then
        self:updateStatus(_("Everything looks good!"))
    elseif self.board:getRemainingCells() == 0 then
        self:updateStatus(_("There are mistakes highlighted in red."))
    else
        self:updateStatus(_("Keep going!"))
    end
end

function KillerSudokuScreen:onClose()
    self.plugin:saveState()
    self.plugin:onScreenClosed()
end

function KillerSudokuScreen:onUndo()
    local ok, err = self.board:undo()
    if not ok then
        self:updateStatus(err)
        return
    end
    self.board_widget:refresh()
    self:updateStatus(_("Last move undone."))
    self.plugin:saveState()
    self:updateUndoButton()
    self:updateDigitButtons()
end

return KillerSudokuScreen
