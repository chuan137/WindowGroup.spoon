-- WindowGroups
--

obj = {}
obj.__index = {}

-- Metadata
obj.name = "WindowGroups"
obj.version = "0.1"
obj.author = "CM"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- logger
obj.logger = hs.logger.new('WindowGroups')
obj.logger.setLogLevel('verbose')

local function getNumberOfWindows()
    local counter = 0
    for _, _ in pairs(obj._windowGroupCache) do
        counter = counter + 1
    end
    return counter
end

function obj:init() 
    self.logger.v('Initializing spoon: WindowGroups')
    self._floatingWindow = { window=nil, focus=false }
    self._tiledWindowsList = {length=0, first=nil, last=nil}
    -- self._floatingWindwFocus = false
    -- self._tiledWindows = {}
    -- self._windowGroupCache = {}
    local wf = hs.window.filter

    self.wf_visibleWindows = wf.new{default={visible=true,currentSpace=true,allowScreens='0,0'}}

    -- set floating window focus flag when it is not triggered by shortcut
    self.wf_visibleWindows:subscribe(wf.windowFocused, function (win, appName, e) 
            if self._floatingWindow.window then
                if win:id() == self._floatingWindow.window:id() then
                    if not self._floatingWindow.focus then
                        self._floatingWindow.focus = true
                    end
                end
            end
        end)
    
    
    -- obj.wf_active = wf.new{override={visible=true,currentSpace=true,allowScreens='0,0'}}:setAppFilter('Chrome', true)
    -- -- obj.wf_chrome = obj.wf_active:setAppFilter('Chrome', true)
    -- obj.wf_active:setAppFilter('Microsoft Teams', {rejectTitles="Notification"})
    -- for _, win in pairs(obj.wf_active:getWindows()) do
    --     obj.logger.v(win)
    -- end
    -- for _, win in pairs(obj.wf_chrome:getWindows()) do
    --     obj.logger.v(win)
    -- end
end

function obj:bindHotkeys(mapping)
    local spec = {
        addToLeft = hs.fnutils.partial(self.toggleTiledWindow, self, 'left'),
        addToRight = hs.fnutils.partial(self.toggleTiledWindow, self, 'right'),
        addToFloat = hs.fnutils.partial(self.toggleFloatingWindow, self),
        toggleFocus = hs.fnutils.partial(self.toggleFocus, self),
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
    return self
end

local function insertTiledWindows(win, pos)
    if obj._tiledWindowsList.last == nil then
        local t = {
            _next = nil,
            _prev = nil,
            _window = win,
        }
        obj._tiledWindowsList = {
            first = t,
            last = t,
            length = 1,
        }
    else
        if pos == 'left' then
            local t = {
                _next = obj._tiledWindowsList.first,
                _prev = nil,
                _window = win,
            }
            t._next._prev = t
            obj._tiledWindowsList.first = t
            obj._tiledWindowsList.length = obj._tiledWindowsList.length + 1
        elseif pos == 'right' then 
            local t = {
                _next = nil,
                _prev = obj._tiledWindowsList.last,
                _window = win,
            }
            t._prev._next = t
            obj._tiledWindowsList.last = t
            obj._tiledWindowsList.length = obj._tiledWindowsList.length + 1
        end
    end
end

local function removeTiledWindow(node) 
    if obj._tiledWindowsList.length == 1 then
        obj._tiledWindowsList.length = 0
        obj._tiledWindowsList.first = nil
        obj._tiledWindowsList.last = nil
        return
    else
        -- at least 2 tiled windows
        if node._prev == nil then
            node._next._prev = nil
            obj._tiledWindowsList.first = node._next
            obj._tiledWindowsList.length = obj._tiledWindowsList.length - 1
        elseif node._next == nil then
            node._prev._next = nil
            obj._tiledWindowsList.last = node._prev
            obj._tiledWindowsList.length = obj._tiledWindowsList.length - 1
        else
            node._prev._next = node._next
            node._next._prev = node._prev
            obj._tiledWindowsList.length = obj._tiledWindowsList.length - 1
        end
    end
end

local function getTiledWindows()
    local windows = {}
    current = obj._tiledWindowsList.first
    while current ~= nil do
        windows[#windows+1] = current._window
        current = current._next
    end
    return windows
end

function obj:paintTiledWindows()
    local screenSize = hs.screen.primaryScreen():frame()
    local screenWidth = screenSize.w
    local screenHeight = screenSize.h
    if self._tiledWindowsList.length == 1 then
        self._tiledWindowsList.first._window:maximize(0)
    elseif self._tiledWindowsList.length == 2 then
        local width = screenWidth/2
        local height = screenHeight
        local windows = getTiledWindows()
        for k, win in pairs(windows) do
            if k == 1 then
                win:setTopLeft(hs.geometry{x=0,y=0})
                win:setSize(hs.geometry{w=width,h=height})
            elseif k == 2 then
                win:setTopLeft(hs.geometry{x=width,y=0})
                win:setSize(hs.geometry{w=width,h=height})
            end
        end
    end
end

function obj:toggleTiledWindow(pos)
    local win = hs.window.focusedWindow()
    current = self._tiledWindowsList.first
    while current ~= nil and current._window:id() ~= win:id() do
        current = current._next
    end
    if current ~= nil then
        removeTiledWindow(current)
    else
        insertTiledWindows(win, pos)
    end
    current = self._tiledWindowsList.first
    while current ~= nil do
        self.logger.vf('tiled window id = %d', current._window:id())
        current = current._next
    end
    self:paintTiledWindows()
end

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
        for _, win in pairs(getTiledWindows()) do
            win:focus()
        end
    else
        fw.focus = true
        fw.window:focus()
    end
end


return obj
