-- Produces almanac.koplugin/images/almanac.png (English README screenshot).
-- cd "$KOREADER_EMU" && SEED=7 STATE_FILE=$REPO/scripts/dev/scenes/almanac.lua \
--   ./luajit $REPO/scripts/dev/render_screen.lua almanac out.png 758 1024 en
local scr = ...
-- Pin "today" so the screenshot does not depend on the day it is rendered.
scr.today = { 2026, 11, 24 }
scr.view_y, scr.view_m = 2026, 11
scr:select({ 2026, 11, 26 })
