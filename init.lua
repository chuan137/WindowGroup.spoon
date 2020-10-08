-- WindowGroup
--

obj = {}
obj.__index = obj

-- Metadata
obj.name = "WindowGroup"
obj.version = "0.1"
obj.author = "CM"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- logger
obj.logger = hs.logger.new('WindowGroup')
obj.logger.setLogLevel('verbose')

function obj:init() 
    self.logger.v('Initializing spoon: WindowGroup')
    self._floatingWindow = {window=nil, focus=false}
    self._tiledWindows = {length=0, left=nil, right=nil, focused=nil}
    self._tiledWindows.leftRect = hs.geometry{0,0,0.6,1}
    self._tiledWindows.rightRect = hs.geometry{0.6,0,0.4,1}

    local wf = hs.window.filter
    self.wf_visibleWindows = wf.new{default={visible=true,currentSpace=true,allowScreens='0,0'}}

    self.wf_visibleWindows:subscribe(wf.windowFocused, {
        -- set floating window focus flag when it is not triggered by shortcut
        function (win, appName, e)
            local floating = self._floatingWindow
            if floating.window and floating.window:id() == win:id() then
                floating.focus = true
            end
            if floating.window and floating.window:id() ~= win:id() then
                floating.focus = false
            end
        end,
        -- set tiled focus window
        function (win, appName, e)
            local tiled = self._tiledWindows
            if tiled.left and tiled.left:id() == win:id() then
                tiled.focused = win
            end
            if tiled.right and tiled.right:id() == win:id() then
                tiled.focused = win
            end
        end,
    })

end

function obj:bindHotkeys(mapping)
    local spec = {
        addToLeft = hs.fnutils.partial(self.addTiledWindow, self, 'left'),
        addToRight = hs.fnutils.partial(self.addTiledWindow, self, 'right'),
        addToFloat = hs.fnutils.partial(self.toggleFloatingWindow, self),
        toggleFocus = hs.fnutils.partial(self.toggleFocus, self),
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
    return self
end

tiledWindow = {}

function tiledWindow.new(win)
    local tw = {}
    local size = win:size()
    local pos = win:topLeft()
    tw.window = win
    tw.posOutOfTile = {x=pos.x,y=pos.y,h=size.h,w=size.w}
    tw.posInTile = {}
    return setmetatable(tw, {__index=tiledWindow})
end

function tiledWindow:id()
    if self.window == nil then return nil end
    return self.window:id()
end

function tiledWindow:moveOutOfTile()
    self.posInTile = {}
    self.window:move(self.posOutOfTile)
end

function tiledWindow:moveToLeft(rect)
    local rect = rect or hs.geometry{x=0,y=0,w=0.5,h=1}
    self.window:move(rect, 0)
    self.posInTile = rect
end

function tiledWindow:moveToRight(rect)
    local rect = rect or hs.geometry{x=0.5,y=0,w=0.5,h=1}
    self.window:move(rect, 0)
    self.posInTile = rect
end

function tiledWindow:focus()
    self.window:focus()
end

function obj:toggleLeftWindow(win)
    local tiled = self._tiledWindows
    if tiled.left and tiled.left:id() == win:id() then
        tiled.other = tiled.left
        tiled.left = nil
        tiled.focused = tiled.right
    elseif tiled.right and tiled.right:id() == win:id() then
        tiled.left = tiled.right
        tiled.right = nil
        tiled.focused = win
    else
        tiled.other = tiled.left
        tiled.left = tiledWindow.new(win)
        tiled.focused = win
    end
end

function obj:toggleRightWindow(win)
    local tiled = self._tiledWindows
    if tiled.right and tiled.right:id() == win:id() then
        tiled.other = tiled.right
        tiled.right = nil
        tiled.focused = tiled.left
    elseif tiled.left and tiled.left:id() == win:id() then
        tiled.right = tiled.left
        tiled.left = nil
        tiled.focused = win
    else
        tiled.other = tiled.right
        tiled.right = tiledWindow.new(win)
        tiled.focused = win
    end
end

function obj:setFocusedTiledWindow(win)
    self._tiledWindows.focused = win
end

function obj:moveTiledWindows()
    local tiled = self._tiledWindows
    if tiled.left then
        tiled.left:moveToLeft(tiled.leftRect)
    end
    if tiled.right then
        tiled.right:moveToRight(tiled.rightRect)
    end
    if tiled.other then
        tiled.other:moveOutOfTile()
        tiled.other = nil
    end
end

function obj:focusTiledWindows()
    local tiled = self._tiledWindows
    if tiled.left then tiled.left:focus() end
    if tiled.right then tiled.right:focus() end
    if tiled.focused then tiled.focused:focus() end
end

function obj:addTiledWindow(pos)
    local win = hs.window.focusedWindow()
    if pos == 'left' then self:toggleLeftWindow(win) end
    if pos == 'right' then self:toggleRightWindow(win) end
    self:moveTiledWindows()
end

-- function obj:addTiledWindow(pos)
--     if pos == 'left' then
--         self.addLeftWindow()
--     else
--         self.addRightWindow()
--     end
--     redoTiledWindows()
-- end
--
--
-- local function insertTiledWindows(win, pos)
--     if obj._tiledWindowsList.last == nil then
--         local t = {
--             _next = nil,
--             _prev = nil,
--             _window = win,
--         }
--         obj._tiledWindowsList = {
--             first = t,
--             last = t,
--             length = 1,
--         }
--     else
--         if pos == 'left' then
--             local t = {
--                 _next = obj._tiledWindowsList.first,
--                 _prev = nil,
--                 _window = win,
--             }
--             t._next._prev = t
--             obj._tiledWindowsList.first = t
--             obj._tiledWindowsList.length = obj._tiledWindowsList.length + 1
--         elseif pos == 'right' then 
--             local t = {
--                 _next = nil,
--                 _prev = obj._tiledWindowsList.last,
--                 _window = win,
--             }
--             t._prev._next = t
--             obj._tiledWindowsList.last = t
--             obj._tiledWindowsList.length = obj._tiledWindowsList.length + 1
--         end
--     end
-- end
--
-- local function removeTiledWindow(node) 
--     if obj._tiledWindowsList.length == 1 then
--         obj._tiledWindowsList.length = 0
--         obj._tiledWindowsList.first = nil
--         obj._tiledWindowsList.last = nil
--         return
--     else
--         -- at least 2 tiled windows
--         if node._prev == nil then
--             node._next._prev = nil
--             obj._tiledWindowsList.first = node._next
--             obj._tiledWindowsList.length = obj._tiledWindowsList.length - 1
--         elseif node._next == nil then
--             node._prev._next = nil
--             obj._tiledWindowsList.last = node._prev
--             obj._tiledWindowsList.length = obj._tiledWindowsList.length - 1
--         else
--             node._prev._next = node._next
--             node._next._prev = node._prev
--             obj._tiledWindowsList.length = obj._tiledWindowsList.length - 1
--         end
--     end
-- end
--
-- local function getTiledWindows()
--     local windows = {}
--     current = obj._tiledWindowsList.first
--     while current ~= nil do
--         windows[#windows+1] = current._window
--         current = current._next
--     end
--     return windows
-- end
--
-- function obj:paintTiledWindows()
--     local screenSize = hs.screen.primaryScreen():frame()
--     local screenWidth = screenSize.w
--     local screenHeight = screenSize.h
--     if self._tiledWindowsList.length == 1 then
--         self._tiledWindowsList.first._window:maximize(0)
--     elseif self._tiledWindowsList.length == 2 then
--         local width = screenWidth/2
--         local height = screenHeight
--         local windows = getTiledWindows()
--         for k, win in pairs(windows) do
--             if k == 1 then
--                 win:setTopLeft(hs.geometry{x=0,y=0})
--                 win:setSize(hs.geometry{w=width,h=height})
--             elseif k == 2 then
--                 win:setTopLeft(hs.geometry{x=width,y=0})
--                 win:setSize(hs.geometry{w=width,h=height})
--             end
--         end
--     end
-- end
--
-- function obj:toggleTiledWindow(pos)
--     local win = hs.window.focusedWindow()
--     current = self._tiledWindowsList.first
--     while current ~= nil and current._window:id() ~= win:id() do
--         current = current._next
--     end
--     if current ~= nil then
--         removeTiledWindow(current)
--     else
--         insertTiledWindows(win, pos)
--     end
--     current = self._tiledWindowsList.first
--     while current ~= nil do
--         self.logger.vf('tiled window id = %d', current._window:id())
--         current = current._next
--     end
--     self:paintTiledWindows()
-- end
--
function obj:toggleFloatingWindow()
    local win = hs.window.focusedWindow()
    local fw = self._floatingWindow
    if fw.window ~= nil and fw.window:id() == win:id() then
        fw.window = nil
        fw.focus = false
    else
        fw.window = win
        fw.focus = true
    end
    if fw.window then
        self.logger.vf('floating window id = %d', self._floatingWindow.window:id())
    end
end

function obj:toggleFocus()
    local fw = self._floatingWindow
    if fw.window == nil then
        return
    end
    if fw.focus then
        fw.focus = false
        self:focusTiledWindows()
    else
        fw.focus = true
        fw.window:focus()
    end
end


return obj
