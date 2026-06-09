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

local ScreenBase        = require("screen_base")
local ChessBoard        = lrequire("board")
local CoursBoardWidget  = lrequire("board_widget")

local DeviceScreen = Device.screen

-- Category display labels
local CAT_LABEL = {
    mat1     = _("Mat en 1"),
    mat2     = _("Mat en 2"),
    tactique = _("Tactique"),
    finale   = _("Finale"),
}

-- ---------------------------------------------------------------------------
-- CoursEchecsScreen
-- ---------------------------------------------------------------------------

local CoursEchecsScreen = ScreenBase:extend{}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function CoursEchecsScreen:init()
    local state = self.plugin:loadState()
    self.lesson_idx = (state and state.lesson_idx) or 1
    self.board = ChessBoard:new()
    self:loadLesson(self.lesson_idx)
    ScreenBase.init(self)  -- calls buildLayout()
end

function CoursEchecsScreen:serializeState()
    return { lesson_idx = self.lesson_idx }
end

function CoursEchecsScreen:loadLesson(idx)
    local lessons = lrequire("lessons")
    local lesson  = lessons[idx]
    if not lesson then return end
    self.current_lesson   = lesson
    self.showing_solution = false
    self.move_count       = 0
    self.solved           = false
    self.board:loadFEN(lesson.fen)
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function CoursEchecsScreen:buildLayout()
    local board   = self.board
    local lessons = lrequire("lessons")
    local lesson  = self.current_lesson

    -- Board widget
    self.board_widget = CoursBoardWidget:new{
        board        = board,
        onCellAction = function(r, c) self:onCellAction(r, c) end,
    }

    local is_landscape = self:isLandscape()
    local sw = DeviceScreen:getWidth()
    local sh = DeviceScreen:getHeight()

    local board_frame = FrameContainer:new{
        padding = Size.padding.default,
        margin  = Size.margin.default,
        self.board_widget,
    }

    local board_frame_size = self.board_widget.size
        + (Size.padding.default + Size.margin.default) * 2

    local button_width
    if is_landscape then
        local right_w = sw - board_frame_size - Size.span.horizontal_default * 2
        button_width  = math.max(right_w - Size.span.horizontal_default, 120)
    else
        button_width = math.floor(sw * 0.92)
    end

    -- Lesson header: "N/30 · Category · Title"
    local cat   = lesson and (CAT_LABEL[lesson.category] or lesson.category) or ""
    local title = lesson and lesson.title or ""
    local header_text = string.format("%d/%d · %s · %s",
        self.lesson_idx, #lessons, cat, title)
    local header = TextWidget:new{
        text = header_text,
        face = Font:getFace("smallinfofont"),
    }

    -- Navigation row: Préc | Suivant | Indice | Solution | Close
    local nav_buttons = ButtonTable:new{
        width                 = button_width,
        shrink_unneeded_width = true,
        buttons = {{
            { text = _("Préc"),     callback = function() self:onPrev()         end },
            { text = _("Suivant"),  callback = function() self:onNext()         end },
            { text = _("Indice"),   callback = function() self:onHint()         end },
            { text = _("Solution"), callback = function() self:onShowSolution() end },
            self:makeCloseButtonConfig(),
        }},
    }

    -- Action row: Reset
    local action_buttons = ButtonTable:new{
        width                 = button_width,
        shrink_unneeded_width = true,
        buttons = {{
            { text = _("Réinitialiser"), callback = function() self:onReset() end },
            { text = _("Annuler"),       callback = function() self:onUndo()  end },
        }},
    }

    self.nav_buttons    = nav_buttons
    self.action_buttons = action_buttons

    if is_landscape then
        local right_panel = VerticalGroup:new{
            align = "center",
            header,
            VerticalSpan:new{ width = Size.span.vertical_large },
            nav_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            action_buttons,
        }
        self.layout = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            right_panel,
        }
    else
        self.layout = VerticalGroup:new{
            align = "center",
            VerticalSpan:new{ width = Size.span.vertical_large },
            header,
            VerticalSpan:new{ width = Size.span.vertical_large },
            nav_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            board_frame,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            action_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
        }
    end

    self[1] = self.layout
    self:updateStatus()
end

-- ---------------------------------------------------------------------------
-- Navigation
-- ---------------------------------------------------------------------------

function CoursEchecsScreen:onPrev()
    if self.lesson_idx > 1 then
        self.lesson_idx = self.lesson_idx - 1
        self:loadLesson(self.lesson_idx)
        self.plugin:saveState(self:serializeState())
        self:buildLayout()
        UIManager:setDirty(self, function() return "ui", self.dimen end)
    end
end

function CoursEchecsScreen:onNext()
    local lessons = lrequire("lessons")
    if self.lesson_idx < #lessons then
        self.lesson_idx = self.lesson_idx + 1
        self:loadLesson(self.lesson_idx)
        self.plugin:saveState(self:serializeState())
        self:buildLayout()
        UIManager:setDirty(self, function() return "ui", self.dimen end)
    end
end

function CoursEchecsScreen:onReset()
    self:loadLesson(self.lesson_idx)
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function CoursEchecsScreen:onUndo()
    if self.board:undoMove() then
        if self.move_count > 0 then
            self.move_count = self.move_count - 1
        end
        self.solved = false
        self.board_widget:refresh()
        self:updateStatus()
    end
end

-- ---------------------------------------------------------------------------
-- Cell interaction
-- ---------------------------------------------------------------------------

function CoursEchecsScreen:onCellAction(r, c)
    if self.solved or self.showing_solution then return end
    local lesson = self.current_lesson
    if not lesson then return end

    local result = self.board:tapCell(r, c)
    self.board_widget:refresh()

    if result == "move" then
        -- Check whether the move matches the expected solution move
        local expected = lesson.solution and lesson.solution[self.move_count + 1]
        if expected and self:checkSolutionProgress() then
            self.move_count = self.move_count + 1

            -- If the next solution step is an opponent reply (even index), apply it automatically
            local reply = lesson.solution[self.move_count + 1]
            local is_opponent_reply = (self.move_count % 2 == 1) and reply ~= nil

            if self.move_count >= #lesson.solution then
                self.solved = true
                self:updateStatus(_("Bravo ! Vous avez trouvé la solution."))
            elseif is_opponent_reply then
                -- Apply opponent's forced reply after a short delay
                UIManager:scheduleIn(0.5, function()
                    self.board:makeMove(reply.fr, reply.fc, reply.tr, reply.tc)
                    self.move_count = self.move_count + 1
                    self.board_widget:refresh()
                    if self.move_count >= #lesson.solution then
                        self.solved = true
                        self:updateStatus(_("Bravo ! Puzzle résolu."))
                    else
                        self:updateStatus(_("Bon coup ! Continuez..."))
                    end
                end)
            else
                self:updateStatus(_("Bon coup ! Continuez..."))
            end
        else
            -- Wrong move: undo immediately
            self.board:undoMove()
            self.board_widget:refresh()
            self:updateStatus(_("Ce n'est pas la bonne solution. Essayez encore."))
        end
    elseif result == "select" or result == "deselect" then
        self:updateStatus()
    end
    -- "invalid": do nothing
end

-- Check if the last move on the board matches the expected solution move.
function CoursEchecsScreen:checkSolutionProgress()
    local lesson   = self.current_lesson
    local expected = lesson.solution and lesson.solution[self.move_count + 1]
    if not expected then return false end
    local lm = self.board.last_move
    if not lm then return false end
    return lm.fr == expected.fr and lm.fc == expected.fc
       and lm.tr == expected.tr and lm.tc == expected.tc
end

-- ---------------------------------------------------------------------------
-- Hint
-- ---------------------------------------------------------------------------

function CoursEchecsScreen:onHint()
    local lesson = self.current_lesson
    if lesson and lesson.hint then
        self:updateStatus(_("Indice: ") .. lesson.hint)
    end
end

-- ---------------------------------------------------------------------------
-- Show solution
-- ---------------------------------------------------------------------------

function CoursEchecsScreen:onShowSolution()
    self.showing_solution = true
    self:loadLesson(self.lesson_idx)  -- reset board to initial FEN
    local lesson = self.current_lesson
    if not lesson or not lesson.solution then return end

    local function playNext(idx)
        if idx > #lesson.solution then
            self.board_widget:refresh()
            self:updateStatus(_("Solution affichée. Appuyez sur Suivant pour continuer."))
            return
        end
        local m = lesson.solution[idx]
        self.board:makeMove(m.fr, m.fc, m.tr, m.tc)
        self.board_widget:refresh()
        UIManager:scheduleIn(0.8, function() playNext(idx + 1) end)
    end
    playNext(1)
end

-- ---------------------------------------------------------------------------
-- Status
-- ---------------------------------------------------------------------------

function CoursEchecsScreen:updateStatus(msg)
    if msg then
        ScreenBase.updateStatus(self, msg)
        return
    end

    local lesson  = self.current_lesson
    local lessons = lrequire("lessons")
    local board   = self.board

    local status
    if self.solved then
        status = _("Puzzle résolu ! Appuyez sur Suivant.")
    elseif board.status == "checkmate" then
        local winner = (board.winner == "white") and _("Blancs") or _("Noirs")
        status = winner .. " " .. _("gagnent par échec et mat !")
    elseif board.status == "stalemate" then
        status = _("Pat — partie nulle.")
    elseif board.status == "check" then
        local turn = (board.turn == "white") and _("Blancs") or _("Noirs")
        status = turn .. " " .. _("sont en échec.")
    else
        if lesson then
            local cat = CAT_LABEL[lesson.category] or lesson.category
            status = string.format("%d/%d · %s · %s",
                self.lesson_idx, #lessons, cat, lesson.desc)
        else
            local turn = (board.turn == "white") and _("Blancs") or _("Noirs")
            status = turn .. " " .. _("jouent.")
        end
    end
    ScreenBase.updateStatus(self, status)
end

return CoursEchecsScreen
