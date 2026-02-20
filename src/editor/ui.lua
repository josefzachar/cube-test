-- editor/ui.lua  (Aseprite-inspired redesign)
-- Layout:
--   TOP:    Menu bar  (File | Edit | Level | View)         H = MENU_H
--   LEFT:   Tool panel (tools + brush size + material)     W = LEFT_W
--   RIGHT:  Properties panel (balls, actions, info)        W = RIGHT_W
--   BOTTOM: Status bar                                     H = STATUS_H
--   CENTRE: Canvas (owned by core / camera)

local Cell      = require("cell")
local CellTypes = require("src.cell_types")
local Balls     = require("src.balls")

-- ══════════════════════════════════════════════════
--  Layout constants
-- ══════════════════════════════════════════════════
local MENU_H   = 26
local LEFT_W   = 180
local RIGHT_W  = 180
local STATUS_H = 22

-- ══════════════════════════════════════════════════
--  Colour palette (dark Aseprite-ish theme)
-- ══════════════════════════════════════════════════
local C = {
    bg          = {0.14, 0.14, 0.14, 1},
    panel       = {0.18, 0.18, 0.18, 1},
    panelBorder = {0.10, 0.10, 0.10, 1},
    menuBg      = {0.22, 0.22, 0.22, 1},
    menuHover   = {0.30, 0.30, 0.30, 1},
    dropBg      = {0.20, 0.20, 0.20, 1},
    dropHover   = {0.28, 0.40, 0.62, 1},
    dropSep     = {0.30, 0.30, 0.30, 1},
    toolBg      = {0.22, 0.22, 0.22, 1},
    toolSel     = {0.28, 0.40, 0.62, 1},
    toolHover   = {0.28, 0.28, 0.28, 1},
    accent      = {0.28, 0.40, 0.62, 1},
    accentBrt   = {0.38, 0.54, 0.82, 1},
    text        = {0.88, 0.88, 0.88, 1},
    textDim     = {0.52, 0.52, 0.52, 1},
    textWhite   = {1.00, 1.00, 1.00, 1},
    red         = {0.72, 0.22, 0.22, 1},
    green       = {0.22, 0.65, 0.32, 1},
    yellow      = {0.80, 0.72, 0.15, 1},
    inputBg     = {0.11, 0.11, 0.11, 1},
    inputBorder = {0.38, 0.54, 0.82, 1},
    modalBg     = {0.12, 0.12, 0.12, 0.96},
    modalBorder = {0.38, 0.54, 0.82, 1},
    shadow      = {0.00, 0.00, 0.00, 0.55},
}

-- Material swatch colours
local MAT_COLOR = {
    EMPTY = {0.18, 0.18, 0.18, 1},
    DIRT  = {0.45, 0.28, 0.12, 1},
    SAND  = {0.82, 0.72, 0.28, 1},
    STONE = {0.50, 0.50, 0.50, 1},
    WATER = {0.22, 0.42, 0.78, 1},
    FIRE  = {0.88, 0.38, 0.08, 1},
}

-- ══════════════════════════════════════════════════
--  Module table
-- ══════════════════════════════════════════════════
local EditorUI = {
    editor   = nil,
    fontSm   = nil,
    fontMd   = nil,
    menus    = {},
    openMenu = nil,   -- index of open dropdown (or nil)
    tooltip  = nil,
    tooltipTimer = 0,
    -- internal hit-test tables rebuilt each draw
    _brushBtns  = {},
    _matBtns    = {},
    _ballBtns   = {},
    _actionBtns = {},
}

-- ══════════════════════════════════════════════════
--  Low-level helpers
-- ══════════════════════════════════════════════════
local function setC(c) love.graphics.setColor(c[1], c[2], c[3], c[4] or 1) end

local function roundRect(mode, x, y, w, h, r)
    love.graphics.rectangle(mode, x, y, w, h, r or 0, r or 0)
end

local function inRect(px, py, x, y, w, h)
    return px >= x and px <= x+w and py >= y and py <= y+h
end

local function drawShadow(x, y, w, h)
    setC(C.shadow)
    roundRect("fill", x+3, y+3, w, h, 3)
end

local function drawPanel(x, y, w, h, r)
    setC(C.panel)
    roundRect("fill", x, y, w, h, r or 0)
    setC(C.panelBorder)
    roundRect("line", x, y, w, h, r or 0)
end

-- Reusable section header with dim text
local function sectionHeader(font, text, x, y, w)
    setC(C.panelBorder)
    love.graphics.setLineWidth(1)
    local mid = y + 9
    love.graphics.line(x+4, mid, x+12, mid)
    love.graphics.line(x+w-12, mid, x+w-4, mid)
    love.graphics.setFont(font)
    setC(C.textDim)
    local tw = font:getWidth(text)
    love.graphics.print(text, x + (w-tw)/2, y)
end

-- ══════════════════════════════════════════════════
--  Layout  (recomputed every frame)
-- ══════════════════════════════════════════════════
local function getLayout()
    local sw, sh = love.graphics.getDimensions()
    return {
        sw=sw, sh=sh,
        leftX=0, leftY=MENU_H, leftW=LEFT_W, leftH=sh-MENU_H-STATUS_H,
        rightX=sw-RIGHT_W, rightY=MENU_H, rightW=RIGHT_W, rightH=sh-MENU_H-STATUS_H,
        statusY=sh-STATUS_H,
        canvasX=LEFT_W, canvasY=MENU_H, canvasW=sw-LEFT_W-RIGHT_W, canvasH=sh-MENU_H-STATUS_H,
    }
end

-- ══════════════════════════════════════════════════
--  Menu definitions
-- ══════════════════════════════════════════════════
local DROP_ITEM_H = 22
local DROP_W      = 220
local MENU_PAD    = 12

local function buildMenus(ed)
    local function getFile()  return require("src.editor.file") end
    local function getLvl()   return require("src.editor.level") end
    local function getCam()   return require("src.editor.camera") end
    return {
        { name="File", items={
            { label="New Level",        shortcut="Ctrl+N", action=function() getLvl().clearLevel() end },
            { label="Open…",            shortcut="Ctrl+O", action=function() getFile().loadLevel() end },
            { label="Save",             shortcut="Ctrl+S", action=function() getFile().saveLevel() end },
            { sep=true },
            { label="Exit Editor",      shortcut="Esc",    action=function() ed.active=false end },
        }},
        { name="Edit", items={
            { label="Clear Level",      action=function() getLvl().clearLevel() end },
            { label="Fill Boundaries",  action=function() getLvl().createBoundaries() end },
            { label="Toggle Grass",     action=function() ed.toggleGrass() end },
        }},
        { name="Level", items={
            { label="Set Name…",        action=function()
                ed.textInput.active=true; ed.textInput.text=ed.levelName
                ed.textInput.cursor=#ed.levelName; ed.textInput.mode="levelName"
                EditorUI.openMenu=nil end },
            { label="Set Width…",       action=function()
                ed.textInput.active=true; ed.textInput.text=tostring(ed.level.width)
                ed.textInput.cursor=#ed.textInput.text; ed.textInput.mode="levelWidth"
                EditorUI.openMenu=nil end },
            { label="Set Height…",      action=function()
                ed.textInput.active=true; ed.textInput.text=tostring(ed.level.height)
                ed.textInput.cursor=#ed.textInput.text; ed.textInput.mode="levelHeight"
                EditorUI.openMenu=nil end },
            { sep=true },
            { label="Test Play",        shortcut="F5", action=function()
                local Game=require("src.game"); Game.testPlayMode=true
                Game.ball=getLvl().testPlay(); Game.level=ed.level
                EditorUI.openMenu=nil end },
        }},
        { name="View", items={
            { label="Toggle UI",        shortcut="Space", action=function() ed.showUI=not ed.showUI end },
            { label="Toggle Grid",      shortcut="G",     action=function() ed.showGrid=not ed.showGrid end },
            { label="Zoom In",          shortcut="Ctrl++",action=function() local c=getCam(); c.zoom=math.min(c.zoom*1.25,8) end },
            { label="Zoom Out",         shortcut="Ctrl+-",action=function() local c=getCam(); c.zoom=math.max(c.zoom*0.80,0.15) end },
            { label="Reset Zoom",       shortcut="Ctrl+0",action=function() getCam().zoom=1.0 end },
        }},
    }
end

-- ══════════════════════════════════════════════════
--  Tool icon draw functions  (all draw around 0,0)
-- ══════════════════════════════════════════════════
-- FA-6 Solid Unicode codepoints (rendered via fa-solid-900.ttf)
local FA = {
    pencil  = "\u{f303}",  -- fa-pencil
    eraser  = "\u{f12d}",  -- fa-eraser
    fill    = "\u{f576}",  -- fa-fill-drip
    flag    = "\u{f024}",  -- fa-flag  (start position)
    bullseye= "\u{f140}",  -- fa-bullseye (win hole)
    mountain= "\u{f6fc}",  -- fa-mountain (boulder)
    bomb    = "\u{f1e2}",  -- fa-bomb  (barrel)
}

-- Shared FA icon draw helper: centred on (0,0), honours selected state
local function drawFA(glyph, sel, tint)
    local fnt = EditorUI.fontFA
    if not fnt then return end
    local col = tint or (sel and C.textWhite or C.text)
    setC(col)
    love.graphics.setFont(fnt)
    local w = fnt:getWidth(glyph)
    local h = fnt:getHeight()
    love.graphics.print(glyph, -w/2, -h/2)
    love.graphics.setFont(EditorUI.fontSm) -- restore
end

local TOOLS = {
    {id="draw",    label="Pencil",    key="T", icon=function(s) drawFA(FA.pencil,   s) end},
    {id="erase",   label="Eraser",    key="X", icon=function(s) drawFA(FA.eraser,   s, s and {0.95,0.65,0.65,1} or {0.80,0.50,0.50,1}) end},
    {id="fill",    label="Fill",      key="F", icon=function(s) drawFA(FA.fill,     s) end},
    {id="start",   label="Start Pos", key="P", icon=function(s) drawFA(FA.flag,     s, s and C.green or {0.40,0.75,0.40,1}) end},
    {id="winhole", label="Win Hole",  key="H", icon=function(s) drawFA(FA.bullseye, s, s and C.yellow or {0.85,0.80,0.25,1}) end},
    {id="boulder", label="Boulder",   key="B", icon=function(s) drawFA(FA.mountain, s, s and {0.85,0.85,0.85,1} or {0.65,0.65,0.65,1}) end},
    {id="barrel",  label="Barrel",    key="E", icon=function(s) drawFA(FA.bomb,     s, s and {1.00,0.45,0.20,1} or {0.75,0.30,0.15,1}) end},
}

-- ══════════════════════════════════════════════════
--  Init / createUI
-- ══════════════════════════════════════════════════
function EditorUI.init(editor)
    EditorUI.editor = editor

    local ok1, f1 = pcall(love.graphics.newFont, "fonts/pixel_font.ttf", 13)
    local ok2, f2 = pcall(love.graphics.newFont, "fonts/pixel_font.ttf", 16)
    EditorUI.fontSm = ok1 and f1 or love.graphics.newFont(13)
    EditorUI.fontMd = ok2 and f2 or love.graphics.newFont(16)

    local ok3, f3 = pcall(love.graphics.newFont, "fonts/fa-solid-900.ttf", 18)
    EditorUI.fontFA = ok3 and f3 or nil  -- nil → fallback to hand-drawn skipped gracefully

    -- Backward-compat stubs (some old code iterates these)
    editor.buttonFont   = EditorUI.fontSm
    editor.toolButtons  = {}
    editor.brushButtons = {}
    editor.ballButtons  = {}
    editor.buttons      = {}

    EditorUI.menus    = buildMenus(editor)
    EditorUI.openMenu = nil
    EditorUI.tooltip  = nil
    EditorUI.tooltipTimer = 0
end

function EditorUI.createUI()
    -- Called on resize — just rebuild menus in case editor ref changed
    if EditorUI.editor then
        EditorUI.menus = buildMenus(EditorUI.editor)
    end
end

-- ══════════════════════════════════════════════════
--  Update
-- ══════════════════════════════════════════════════
function EditorUI.update(dt)
    if EditorUI.tooltip then
        EditorUI.tooltipTimer = EditorUI.tooltipTimer + dt
    else
        EditorUI.tooltipTimer = 0
    end
end

-- ══════════════════════════════════════════════════
--  Draw: Menu bar
-- ══════════════════════════════════════════════════
local function drawMenuBar(L)
    setC(C.menuBg)
    love.graphics.rectangle("fill", 0, 0, L.sw, MENU_H)
    setC(C.panelBorder)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, MENU_H, L.sw, MENU_H)

    local mx, my = love.mouse.getPosition()
    love.graphics.setFont(EditorUI.fontSm)
    local fh  = EditorUI.fontSm:getHeight()
    local ix  = 6
    for i, menu in ipairs(EditorUI.menus) do
        local tw  = EditorUI.fontSm:getWidth(menu.name)
        local mw  = tw + MENU_PAD * 2
        local sel = (EditorUI.openMenu == i)
        local hov = inRect(mx, my, ix, 0, mw, MENU_H)
        if sel then
            setC(C.accent)
            love.graphics.rectangle("fill", ix, 0, mw, MENU_H)
        elseif hov and not EditorUI.openMenu then
            setC(C.menuHover)
            love.graphics.rectangle("fill", ix, 0, mw, MENU_H)
        end
        setC(sel and C.textWhite or C.text)
        love.graphics.print(menu.name, ix + MENU_PAD, (MENU_H - fh)/2)
        menu._x = ix;  menu._w = mw
        ix = ix + mw + 2
    end

    -- Centred title
    local title = "Square Golf  ·  Level Editor"
    local tw2   = EditorUI.fontSm:getWidth(title)
    setC(C.textDim)
    love.graphics.print(title, (L.sw - tw2)/2, (MENU_H - fh)/2)
end

-- ══════════════════════════════════════════════════
--  Draw: Dropdown
-- ══════════════════════════════════════════════════
local function drawDropdown(L)
    if not EditorUI.openMenu then return end
    local menu = EditorUI.menus[EditorUI.openMenu]
    if not menu or not menu._x then return end

    local mx, my = love.mouse.getPosition()
    local nSeps  = 0
    for _, it in ipairs(menu.items) do if it.sep then nSeps=nSeps+1 end end
    local h  = (#menu.items - nSeps) * DROP_ITEM_H + nSeps * 8 + 8
    local dx = menu._x
    if dx + DROP_W > L.sw then dx = L.sw - DROP_W - 4 end
    local dy = MENU_H

    drawShadow(dx, dy, DROP_W, h)
    setC(C.dropBg)
    roundRect("fill", dx, dy, DROP_W, h, 3)
    setC(C.panelBorder)
    roundRect("line", dx, dy, DROP_W, h, 3)

    love.graphics.setFont(EditorUI.fontSm)
    local fh = EditorUI.fontSm:getHeight()
    local iy = dy + 4
    for _, item in ipairs(menu.items) do
        if item.sep then
            setC(C.dropSep)
            love.graphics.line(dx+6, iy+3, dx+DROP_W-6, iy+3)
            iy = iy + 8
        else
            local hov = inRect(mx, my, dx, iy, DROP_W, DROP_ITEM_H)
            item._iy = iy
            if hov then
                setC(C.dropHover)
                roundRect("fill", dx+2, iy, DROP_W-4, DROP_ITEM_H, 2)
            end
            setC(hov and C.textWhite or C.text)
            love.graphics.print(item.label, dx+10, iy+(DROP_ITEM_H-fh)/2)
            if item.shortcut then
                setC(C.textDim)
                local sw2 = EditorUI.fontSm:getWidth(item.shortcut)
                love.graphics.print(item.shortcut, dx+DROP_W-sw2-10, iy+(DROP_ITEM_H-fh)/2)
            end
            iy = iy + DROP_ITEM_H
        end
    end
end

-- ══════════════════════════════════════════════════
--  Draw: Left panel
-- ══════════════════════════════════════════════════
local TOOL_W  = 38
local TOOL_H  = 34
local TOOL_P  = 3
local TOOL_COLS = 2

local function drawLeftPanel(L)
    local ed  = EditorUI.editor
    local mx, my = love.mouse.getPosition()
    drawPanel(L.leftX, L.leftY, L.leftW, L.leftH)

    local py = L.leftY + 6

    -- ── Tools ────────────────────────────────────
    sectionHeader(EditorUI.fontSm, "TOOLS", L.leftX, py, L.leftW)
    py = py + 18 + 4

    local cols    = TOOL_COLS
    local rowsW   = cols * TOOL_W + (cols-1) * TOOL_P
    local startX  = L.leftX + (L.leftW - rowsW) / 2

    for i, tool in ipairs(TOOLS) do
        local col = (i-1) % cols
        local row = math.floor((i-1) / cols)
        local bx  = startX + col * (TOOL_W + TOOL_P)
        local by  = py + row * (TOOL_H + TOOL_P)
        local sel = (ed.currentTool == tool.id)
        local hov = inRect(mx, my, bx, by, TOOL_W, TOOL_H)

        if sel then setC(C.toolSel) elseif hov then setC(C.toolHover) else setC(C.toolBg) end
        roundRect("fill", bx, by, TOOL_W, TOOL_H, 4)
        setC(sel and C.accentBrt or C.panelBorder)
        roundRect("line", bx, by, TOOL_W, TOOL_H, 4)

        -- Icon (drawn around centre)
        love.graphics.push()
        love.graphics.translate(bx + TOOL_W/2, by + TOOL_H/2 - 4)
        tool.icon(sel)
        love.graphics.pop()

        -- Key hint
        love.graphics.setFont(EditorUI.fontSm)
        setC(sel and C.textWhite or C.textDim)
        local kw = EditorUI.fontSm:getWidth(tool.key)
        love.graphics.print(tool.key, bx+(TOOL_W-kw)/2, by+TOOL_H-13)

        if hov then EditorUI.tooltip = tool.label .. "  [" .. tool.key .. "]" end
        tool._bx=bx; tool._by=by; tool._bw=TOOL_W; tool._bh=TOOL_H
    end

    local toolRows = math.ceil(#TOOLS / cols)
    py = py + toolRows * (TOOL_H + TOOL_P) + 10

    -- ── Brush size ───────────────────────────────
    sectionHeader(EditorUI.fontSm, "BRUSH SIZE", L.leftX, py, L.leftW)
    py = py + 18 + 4

    local brushSizes = {1, 2, 3, 5, 7}
    local nB    = #brushSizes
    local bBtnW = math.floor((L.leftW - 16) / nB) - 2
    local bBtnH = 22
    local bSX   = L.leftX + 8
    EditorUI._brushBtns = {}

    for i, sz in ipairs(brushSizes) do
        local bx  = bSX + (i-1) * (bBtnW + 2)
        local by  = py
        local sel = (ed.brushSize == sz)
        local hov = inRect(mx, my, bx, by, bBtnW, bBtnH)

        if sel then setC(C.toolSel) elseif hov then setC(C.toolHover) else setC(C.toolBg) end
        roundRect("fill", bx, by, bBtnW, bBtnH, 3)
        setC(sel and C.accentBrt or C.panelBorder)
        roundRect("line", bx, by, bBtnW, bBtnH, 3)

        love.graphics.setFont(EditorUI.fontSm)
        setC(sel and C.textWhite or C.text)
        local lbl = tostring(sz)
        local lw  = EditorUI.fontSm:getWidth(lbl)
        love.graphics.print(lbl, bx+(bBtnW-lw)/2, by+(bBtnH-EditorUI.fontSm:getHeight())/2)

        if hov then EditorUI.tooltip = "Brush size " .. sz .. "  (scroll wheel)" end
        table.insert(EditorUI._brushBtns, {sz=sz, _bx=bx, _by=by, _bw=bBtnW, _bh=bBtnH})
    end
    py = py + bBtnH + 10

    -- ── Material palette ─────────────────────────
    sectionHeader(EditorUI.fontSm, "MATERIAL", L.leftX, py, L.leftW)
    py = py + 18 + 4

    local matNames = {"EMPTY","DIRT","SAND","STONE","WATER","FIRE"}
    local mW = L.leftW - 16
    local mH = 22
    local mX = L.leftX + 8
    EditorUI._matBtns = {}

    for _, name in ipairs(matNames) do
        local bx  = mX
        local by  = py
        local sel = (ed.currentCellType == name)
        local hov = inRect(mx, my, bx, by, mW, mH)

        if sel then setC(C.toolSel) elseif hov then setC(C.toolHover) else setC(C.toolBg) end
        roundRect("fill", bx, by, mW, mH, 3)
        setC(sel and C.accentBrt or C.panelBorder)
        roundRect("line", bx, by, mW, mH, 3)

        -- Swatch
        local cc = MAT_COLOR[name] or C.toolBg
        setC(cc)
        roundRect("fill", bx+3, by+4, 14, mH-8, 2)
        setC(C.panelBorder)
        roundRect("line", bx+3, by+4, 14, mH-8, 2)

        -- Label
        love.graphics.setFont(EditorUI.fontSm)
        setC(sel and C.textWhite or C.text)
        love.graphics.print(name, bx+22, by+(mH-EditorUI.fontSm:getHeight())/2)

        if hov then EditorUI.tooltip = name end
        table.insert(EditorUI._matBtns, {name=name, _bx=bx, _by=by, _bw=mW, _bh=mH})
        py = py + mH + 2
    end
end

-- ══════════════════════════════════════════════════
--  Draw: Right panel
-- ══════════════════════════════════════════════════
local function drawRightPanel(L)
    local ed = EditorUI.editor
    local mx, my = love.mouse.getPosition()
    drawPanel(L.rightX, L.rightY, L.rightW, L.rightH)

    local rx = L.rightX
    local rw = L.rightW
    local py = L.rightY + 6

    -- ── Level info ───────────────────────────────
    sectionHeader(EditorUI.fontSm, "LEVEL INFO", rx, py, rw)
    py = py + 18 + 4

    love.graphics.setFont(EditorUI.fontSm)
    local fh = EditorUI.fontSm:getHeight()
    local function infoRow(label, value)
        setC(C.textDim)
        love.graphics.print(label, rx+8, py)
        setC(C.text)
        local vw = EditorUI.fontSm:getWidth(value)
        love.graphics.print(value, rx+rw-vw-8, py)
        py = py + fh + 3
    end

    local cam = require("src.editor.camera")
    infoRow("Name:",  ed.levelName)
    infoRow("Size:",  ed.level.width .. " × " .. ed.level.height)
    infoRow("Start:", ed.startX .. ", " .. ed.startY)
    infoRow("Zoom:",  string.format("%.0f%%", cam.zoom * 100))

    py = py + 8

    -- ── Available balls ──────────────────────────
    sectionHeader(EditorUI.fontSm, "BALLS", rx, py, rw)
    py = py + 18 + 4

    local ballDefs = {
        {id="standard",  label="Standard" },
        {id="heavy",     label="Heavy"    },
        {id="exploding", label="Exploding"},
        {id="sticky",    label="Sticky"   },
        {id="spraying",  label="Spraying" },
        {id="bullet",    label="Bullet"   },
        {id="ice",       label="Ice"      },
    }
    EditorUI._ballBtns = {}

    local cw = 14
    for _, bt in ipairs(ballDefs) do
        local bx  = rx + 8
        local bw  = rw - 16
        local bh  = 22
        local by  = py
        local sel = ed.availableBalls[bt.id]
        local hov = inRect(mx, my, bx, by, bw, bh)

        if hov then setC(C.toolHover) else setC(C.toolBg) end
        roundRect("fill", bx, by, bw, bh, 3)
        setC(C.panelBorder)
        roundRect("line", bx, by, bw, bh, 3)

        -- Checkbox
        love.graphics.setLineWidth(1.5)
        setC(C.text)
        roundRect("line", bx+4, by+(bh-cw)/2, cw, cw, 2)
        if sel then
            setC(C.green)
            roundRect("fill", bx+6, by+(bh-cw)/2+2, cw-4, cw-4, 1)
        end
        love.graphics.setLineWidth(1)

        love.graphics.setFont(EditorUI.fontSm)
        setC(sel and C.textWhite or C.text)
        love.graphics.print(bt.label, bx+cw+10, by+(bh-fh)/2)

        bt._bx=bx; bt._by=by; bt._bw=bw; bt._bh=bh
        table.insert(EditorUI._ballBtns, bt)
        py = py + bh + 2
    end
    py = py + 8

    -- ── Actions ──────────────────────────────────
    sectionHeader(EditorUI.fontSm, "ACTIONS", rx, py, rw)
    py = py + 18 + 4

    local actionDefs = {
        {label="▶  Test Play",      bg=C.green,  action=function()
            local Game=require("src.game"); local EL=require("src.editor.level")
            Game.testPlayMode=true; Game.ball=EL.testPlay(); Game.level=ed.level end},
        {label="💾  Save",          bg=C.accent, action=function() require("src.editor.file").saveLevel() end},
        {label="📂  Open…",         bg=C.accent, action=function() require("src.editor.file").loadLevel() end},
        {label="🗑  Clear",          bg=nil,      action=function() require("src.editor.level").clearLevel() end},
        {label="▭  Boundaries",    bg=nil,      action=function() require("src.editor.level").createBoundaries() end},
        {label="✖  Exit Editor",   bg=C.red,   action=function() ed.active=false end},
    }
    EditorUI._actionBtns = {}

    local aBtnH = 24
    for _, act in ipairs(actionDefs) do
        local bx  = rx + 8
        local bw  = rw - 16
        local by  = py
        local hov = inRect(mx, my, bx, by, bw, aBtnH)
        local bg  = act.bg or C.toolBg

        if hov then
            setC({math.min(1,bg[1]+0.12), math.min(1,bg[2]+0.12), math.min(1,bg[3]+0.12), 1})
        else
            setC({bg[1], bg[2], bg[3], 0.90})
        end
        roundRect("fill", bx, by, bw, aBtnH, 3)
        setC(C.panelBorder)
        roundRect("line", bx, by, bw, aBtnH, 3)

        love.graphics.setFont(EditorUI.fontSm)
        setC(C.textWhite)
        local tw = EditorUI.fontSm:getWidth(act.label)
        love.graphics.print(act.label, bx+(bw-tw)/2, by+(aBtnH-fh)/2)

        act._bx=bx; act._by=by; act._bw=bw; act._bh=aBtnH
        table.insert(EditorUI._actionBtns, act)
        py = py + aBtnH + 3
    end
end

-- ══════════════════════════════════════════════════
--  Draw: Status bar
-- ══════════════════════════════════════════════════
local function drawStatusBar(L)
    local ed  = EditorUI.editor
    setC(C.menuBg)
    love.graphics.rectangle("fill", 0, L.statusY, L.sw, STATUS_H)
    setC(C.panelBorder)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, L.statusY, L.sw, L.statusY)

    love.graphics.setFont(EditorUI.fontSm)
    local fh = EditorUI.fontSm:getHeight()
    local ty = L.statusY + (STATUS_H - fh) / 2

    -- Left: tool + material
    local toolStr = ed.currentTool:upper()
    if ed.currentTool == "draw" or ed.currentTool == "fill" then
        toolStr = toolStr .. "  ·  " .. ed.currentCellType
    end
    setC(C.text)
    love.graphics.print(toolStr, 8, ty)

    -- Centre: grid position
    local cam      = require("src.editor.camera")
    local mx, my_p = love.mouse.getPosition()
    local gx_f, gy_f = cam.screenToGameCoords(mx, my_p)
    local gx = math.floor(gx_f / Cell.SIZE)
    local gy = math.floor(gy_f / Cell.SIZE)
    local posStr = "cell (" .. gx .. ", " .. gy .. ")"
    setC(C.textDim)
    local sw2 = EditorUI.fontSm:getWidth(posStr)
    love.graphics.print(posStr, (L.sw - sw2)/2, ty)

    -- Right: zoom %
    local zStr = string.format("Zoom: %.0f%%", cam.zoom * 100)
    setC(C.textDim)
    local zw = EditorUI.fontSm:getWidth(zStr)
    love.graphics.print(zStr, L.sw - zw - 8, ty)

    -- Tooltip bubble
    if EditorUI.tooltip and EditorUI.tooltipTimer > 0.35 then
        local tip = EditorUI.tooltip
        local ttw = EditorUI.fontSm:getWidth(tip)
        local tx  = mx + 14
        local tty = my_p - 22
        if tx + ttw + 12 > L.sw then tx = L.sw - ttw - 14 end
        if tty < MENU_H + 4 then tty = my_p + 18 end
        setC({0.08,0.08,0.08,0.93})
        roundRect("fill", tx-4, tty-2, ttw+8, fh+4, 2)
        setC(C.panelBorder)
        roundRect("line", tx-4, tty-2, ttw+8, fh+4, 2)
        setC(C.textWhite)
        love.graphics.print(tip, tx, tty)
    end
end

-- ══════════════════════════════════════════════════
--  Draw: Text input modal
-- ══════════════════════════════════════════════════
local function drawTextInputModal(L)
    local ed = EditorUI.editor
    if not ed.textInput.active then return end

    local mw, mh = 420, 112
    local mx2    = (L.sw - mw) / 2
    local my2    = (L.sh - mh) / 2

    drawShadow(mx2, my2, mw, mh)
    setC(C.modalBg)
    roundRect("fill", mx2, my2, mw, mh, 5)
    setC(C.modalBorder)
    roundRect("line", mx2, my2, mw, mh, 5)

    -- Title bar
    setC(C.accent)
    roundRect("fill", mx2, my2, mw, 24, 5)
    love.graphics.rectangle("fill", mx2, my2+14, mw, 10)  -- flatten bottom corners
    love.graphics.setFont(EditorUI.fontSm)
    setC(C.textWhite)
    local titles = {
        levelName   = "Set Level Name",
        levelWidth  = "Set Level Width  (20 – 500)",
        levelHeight = "Set Level Height  (20 – 500)",
        levelSize   = "Set Level Size  (width, height)",
    }
    love.graphics.print(titles[ed.textInput.mode] or "Input", mx2+10, my2+5)

    -- Input box
    local iy  = my2 + 34
    local iBx = mx2 + 12
    local iBw = mw - 24
    local iBh = 28
    setC(C.inputBg)
    roundRect("fill", iBx, iy, iBw, iBh, 3)
    setC(C.inputBorder)
    roundRect("line", iBx, iy, iBw, iBh, 3)

    love.graphics.setFont(EditorUI.fontSm)
    local fh = EditorUI.fontSm:getHeight()
    setC(C.textWhite)
    love.graphics.print(ed.textInput.text, iBx+6, iy+(iBh-fh)/2)

    if ed.textInput.cursorVisible then
        local cx = iBx+6 + EditorUI.fontSm:getWidth(string.sub(ed.textInput.text,1,ed.textInput.cursor))
        setC(C.textWhite)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(cx, iy+4, cx, iy+iBh-4)
        love.graphics.setLineWidth(1)
    end

    setC(C.textDim)
    love.graphics.print("Enter = confirm    Esc = cancel", mx2+10, my2+80)
end

-- ══════════════════════════════════════════════════
--  Cursor preview  (drawn in world space)
-- ══════════════════════════════════════════════════
function EditorUI.drawCursorPreview()
    local ed = EditorUI.editor
    if not ed then return end
    if ed.fileSelector.active or ed.textInput.active then return end

    local L  = getLayout()
    local mx, my = love.mouse.getPosition()
    if mx < LEFT_W or mx > L.sw - RIGHT_W then return end
    if my < MENU_H or my > L.sh - STATUS_H then return end

    local cam   = require("src.editor.camera")
    local IU    = require("src.input_utils")
    local Brl   = require("src.barrel")
    local ET    = require("src.editor.tools")

    local gx_f, gy_f = cam.screenToGameCoords(mx, my)
    local gridX, gridY = IU.gameToGridCoords(gx_f, gy_f, Cell.SIZE)
    if gridX < 0 or gridX >= ed.level.width or
       gridY < 0 or gridY >= ed.level.height then return end

    love.graphics.push()
    love.graphics.scale(cam.zoom, cam.zoom)
    love.graphics.translate(-ed.cameraX, -ed.cameraY)

    local cs   = Cell.SIZE
    local tool = ed.currentTool

    if tool == "draw" or tool == "fill" or tool == "erase" then
        local sx, sy = ET.calculateBrushPosition(gridX, gridY, ed.brushSize)
        local cc     = MAT_COLOR[ed.currentCellType] or {1,1,1,1}
        for bRow = 0, ed.brushSize-1 do
            for bCol = 0, ed.brushSize-1 do
                local cx2 = (sx+bCol)*cs
                local cy2 = (sy+bRow)*cs
                if tool == "erase" then
                    love.graphics.setColor(1, 0.28, 0.28, 0.22)
                    love.graphics.rectangle("fill", cx2, cy2, cs, cs)
                    love.graphics.setColor(1, 0.28, 0.28, 0.70)
                    love.graphics.rectangle("line", cx2, cy2, cs, cs)
                else
                    love.graphics.setColor(cc[1], cc[2], cc[3], 0.35)
                    love.graphics.rectangle("fill", cx2, cy2, cs, cs)
                    love.graphics.setColor(cc[1], cc[2], cc[3], 0.75)
                    love.graphics.rectangle("line", cx2, cy2, cs, cs)
                end
            end
        end

    elseif tool == "start" then
        local wx, wy = gridX*cs, gridY*cs
        love.graphics.setColor(0.20, 0.85, 0.30, 0.40)
        love.graphics.rectangle("fill", wx, wy, cs, cs)
        love.graphics.setColor(0.20, 0.85, 0.30, 0.90)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", wx, wy, cs, cs)
        -- mini flag
        love.graphics.setColor(0.6, 0.4, 0.2, 0.85)
        love.graphics.line(wx+cs/2, wy+cs, wx+cs/2, wy-12)
        love.graphics.setColor(0.2, 0.85, 0.3, 0.9)
        love.graphics.polygon("fill", wx+cs/2, wy-12, wx+cs/2+8, wy-8, wx+cs/2, wy-4)
        love.graphics.setLineWidth(1)

    elseif tool == "winhole" then
        local pattern = {{0,0,1,0,0},{0,1,1,1,0},{1,1,1,1,1},{0,1,1,1,0},{0,0,1,0,0}}
        love.graphics.setColor(0.95, 0.88, 0.15, 0.40)
        for dy=0,4 do for dx=0,4 do
            if pattern[dy+1][dx+1]==1 then
                love.graphics.rectangle("fill",(gridX-2+dx)*cs,(gridY-2+dy)*cs,cs,cs)
            end
        end end
        love.graphics.setColor(0.95, 0.88, 0.15, 0.85)
        love.graphics.setLineWidth(1.5)
        for dy=0,4 do for dx=0,4 do
            if pattern[dy+1][dx+1]==1 then
                love.graphics.rectangle("line",(gridX-2+dx)*cs,(gridY-2+dy)*cs,cs,cs)
            end
        end end
        love.graphics.setLineWidth(1)

    elseif tool == "boulder" then
        local bx2 = (gridX+0.5)*cs
        local by2 = (gridY+0.5)*cs
        love.graphics.setColor(0.5, 0.5, 0.5, 0.45)
        love.graphics.circle("fill", bx2, by2, 20)
        love.graphics.setColor(0.72, 0.72, 0.72, 0.85)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", bx2, by2, 20)
        love.graphics.setLineWidth(1)

    elseif tool == "barrel" then
        local bx2 = (gridX+0.5)*cs
        local by2 = (gridY+0.5)*cs
        local hw  = Brl.WIDTH/2
        local hh  = Brl.HEIGHT/2
        love.graphics.setColor(0.55, 0.18, 0.15, 0.45)
        love.graphics.rectangle("fill", bx2-hw, by2-hh, Brl.WIDTH, Brl.HEIGHT, 2, 2)
        love.graphics.setColor(0.80, 0.30, 0.20, 0.85)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", bx2-hw, by2-hh, Brl.WIDTH, Brl.HEIGHT, 2, 2)
        love.graphics.setColor(1.0, 0.55, 0.0, 0.80)
        love.graphics.rectangle("fill", bx2-hw, by2-3, Brl.WIDTH, 3)
        love.graphics.rectangle("fill", bx2-hw, by2+1, Brl.WIDTH, 3)
        love.graphics.setLineWidth(1)
    end

    love.graphics.pop()
end

-- ══════════════════════════════════════════════════
--  Main draw entry
-- ══════════════════════════════════════════════════
function EditorUI.draw()
    local ed = EditorUI.editor
    if not ed then return end

    EditorUI.tooltip = nil   -- reset each frame; re-set on hover

    local L = getLayout()

    love.graphics.push()
    love.graphics.origin()

    drawLeftPanel(L)
    drawRightPanel(L)
    drawMenuBar(L)      -- on top so menu bar sits above panels
    drawStatusBar(L)

    if EditorUI.openMenu then
        drawDropdown(L)
    end

    drawTextInputModal(L)

    love.graphics.pop()
end

-- ══════════════════════════════════════════════════
--  Mouse press
-- ══════════════════════════════════════════════════
function EditorUI.handleMousePressed(x, y, button)
    local ed = EditorUI.editor
    if not ed then return false end
    local L = getLayout()

    -- ── Close/interact with open dropdown first ──
    if EditorUI.openMenu then
        local menu = EditorUI.menus[EditorUI.openMenu]
        local dx   = menu._x
        if dx + DROP_W > L.sw then dx = L.sw - DROP_W - 4 end
        local dy   = MENU_H
        local nSeps = 0
        for _, it in ipairs(menu.items) do if it.sep then nSeps=nSeps+1 end end
        local dh = (#menu.items - nSeps) * DROP_ITEM_H + nSeps*8 + 8

        if inRect(x, y, dx, dy, DROP_W, dh) then
            for _, item in ipairs(menu.items) do
                if not item.sep and item._iy and
                   inRect(x, y, dx, item._iy, DROP_W, DROP_ITEM_H) then
                    EditorUI.openMenu = nil
                    if item.action then item.action() end
                    return true
                end
            end
            return true  -- clicked inside dropdown but not on an item
        else
            EditorUI.openMenu = nil
            -- fall-through to check if menu bar was clicked
        end
    end

    -- ── Text input modal ──
    if ed.textInput.active then
        local mw, mh = 420, 112
        local mx2, my2 = (L.sw-mw)/2, (L.sh-mh)/2
        if not inRect(x, y, mx2, my2, mw, mh) then
            if ed.textInput.mode == "levelName" then
                ed.levelName = ed.textInput.text
            elseif ed.textInput.mode == "levelWidth" then
                local v = tonumber(ed.textInput.text)
                if v and v>=20 and v<=500 then ed.resizeLevel(v, ed.level.height) end
            elseif ed.textInput.mode == "levelHeight" then
                local v = tonumber(ed.textInput.text)
                if v and v>=20 and v<=500 then ed.resizeLevel(ed.level.width, v) end
            elseif ed.textInput.mode == "levelSize" then
                local w2, h2 = ed.textInput.text:match("(%d+),(%d+)")
                w2, h2 = tonumber(w2), tonumber(h2)
                if w2 and h2 and w2>=20 and w2<=500 and h2>=20 and h2<=500 then
                    ed.resizeLevel(w2, h2)
                end
            end
            ed.textInput.active = false
        end
        return true
    end

    -- ── Menu bar ──
    if y >= 0 and y <= MENU_H then
        for i, menu in ipairs(EditorUI.menus) do
            if menu._x and inRect(x, y, menu._x, 0, menu._w or 60, MENU_H) then
                EditorUI.openMenu = (EditorUI.openMenu == i) and nil or i
                return true
            end
        end
        return true  -- bar click consumed
    end

    -- ── Left panel ──
    if x >= L.leftX and x <= L.leftX + L.leftW then
        for _, tool in ipairs(TOOLS) do
            if tool._bx and inRect(x, y, tool._bx, tool._by, tool._bw, tool._bh) then
                ed.currentTool = tool.id
                return true
            end
        end
        for _, bb in ipairs(EditorUI._brushBtns) do
            if bb._bx and inRect(x, y, bb._bx, bb._by, bb._bw, bb._bh) then
                ed.brushSize = bb.sz
                return true
            end
        end
        for _, mb in ipairs(EditorUI._matBtns) do
            if mb._bx and inRect(x, y, mb._bx, mb._by, mb._bw, mb._bh) then
                ed.currentCellType = mb.name
                return true
            end
        end
        return true  -- absorbed
    end

    -- ── Right panel ──
    if x >= L.rightX and x <= L.rightX + L.rightW then
        for _, bt in ipairs(EditorUI._ballBtns) do
            if bt._bx and inRect(x, y, bt._bx, bt._by, bt._bw, bt._bh) then
                ed.availableBalls[bt.id] = not ed.availableBalls[bt.id]
                return true
            end
        end
        for _, act in ipairs(EditorUI._actionBtns) do
            if act._bx and inRect(x, y, act._bx, act._by, act._bw, act._bh) then
                if act.action then act.action() end
                return true
            end
        end
        return true  -- absorbed
    end

    -- ── Status bar ──
    if y >= L.statusY then return true end

    return false
end

-- ══════════════════════════════════════════════════
--  Canvas / panel geometry (used by core & camera)
-- ══════════════════════════════════════════════════
function EditorUI.getCanvasBounds()
    local L = getLayout()
    return L.canvasX, L.canvasY, L.canvasW, L.canvasH
end

function EditorUI.getPanelSizes()
    return LEFT_W, RIGHT_W, MENU_H, STATUS_H
end

return EditorUI
