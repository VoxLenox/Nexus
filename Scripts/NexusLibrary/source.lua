--!strict
local Library = {}

-- [[ Types ]] --

export type BindableEventSignal = typeof(Instance.new("BindableEvent").Event)

export type Descriptors = {[any]: {
	Value: any,
	Writable: boolean?,
	Get: (() -> any)?,
	Set: ((value: any) -> ())?
}}

export type RobloxTopBarSubMenuButtonOptions = {
	Visible: boolean?,
	Order: number?,
	Icon: string?,
	IconColor3: Color3?,
	IconTransparency: number?,
	Text: string?,
	BackgroundColor3: Color3?,
	BackgroundTransparency: number?,
	TextColor3: Color3?,
	TextTransparency: number?
}

export type RobloxTopBarSubMenuButton = {
	-- Read-only properties
	Id: string,
	Removed: boolean,
	Instance: ImageButton?,
	MouseButton1Down: boolean,
	MouseButton2Down: boolean,
	MouseInside: boolean,
	-- Modifiable properties
	Visible: boolean,
	Order: number,
	Icon: string,
	IconColor3: Color3,
	IconTransparency: number,
	Text: string,
	BackgroundColor3: Color3,
	BackgroundTransparency: number,
	TextColor3: Color3,
	TextTransparency: number,
	-- Methods
	Remove: () -> (),
	Trigger: () -> (),
	-- Events
	Changed: BindableEventSignal,
	MouseButton1Click: BindableEventSignal,
	MouseButton2Click: BindableEventSignal,
	MouseMoved: BindableEventSignal,
	MouseWheelForward: BindableEventSignal,
	MouseWheelBackward: BindableEventSignal,
	Activated: BindableEventSignal,
	Triggered: BindableEventSignal
}

type RobloxTopBarSubMenu = {
	IsOpen: boolean,
	Canvas: ScrollingFrame?,
	
	OpenStateChanged: BindableEventSignal,
	Opened: BindableEventSignal,
	Closed: BindableEventSignal
}

-- [[ Variable Shortcuts ]] --

local min, max, floor = math.min, math.max, math.floor

-- [[ Services ]] --

local CoreGui = game:GetService("CoreGui")

-- [[ Script: Core Functions ]] --

local function createProxyWithPropertyDescriptors(descriptors: Descriptors)
	local proxy = newproxy(true)
	local metatable = getmetatable(proxy) :: {[string]: any}
	
	metatable.__index = function(userdata, index: any): any
		local descriptor = descriptors[index]
		assert(descriptor ~= nil, `Invalid property "{index}"`)
		local getFunc = descriptor.Get
		return if getFunc ~= nil then getFunc() else descriptor.Value
	end
	
	metatable.__newindex = function(userdata, index: any, value: any)
		local descriptor = descriptors[index]
		assert(descriptor ~= nil, `Invalid property "{index}"`)
		local setFunc = descriptor.Set
		local writable = descriptor.Writable
		if setFunc ~= nil then
			setFunc(value)
		elseif writable or writable == nil then
			descriptor.Value = value
		else
			error(`Property "{index}" is read-only`)
		end
	end
	
	return proxy
end

local function toBoolean(value: any): boolean
	return if value then true else false
end

local function isNaN(value: any): boolean
	return type(value) == "number" and value ~= value
end

local function deepCloneTable<K, V>(inputTable: {[K]: V}): {[K]: V}
	local clonedTable = table.clone(inputTable)
	for index, value in pairs(clonedTable) do
		if type(value) == "table" then
			clonedTable[index] = (deepCloneTable(value) :: any) :: V 
		end
	end
	return clonedTable
end

local function load(module: string | number | ModuleScript)
	return if type(module) == "string" then
		(loadstring(game:HttpGet(module) :: string) :: () -> any)()
	else
		require(module)
end

local function findFirstChild(startChild: Instance, ...: string): Instance?
	local childNames = {...}
	assert(#childNames > 0, "\"findFirstChild\" need at least one child name")
	local child = startChild
	for _, childName in pairs(childNames) do
		local currentChild = child:FindFirstChild(childName)
		if currentChild then
			child = currentChild
		else
			return nil
		end
	end
	return child
end

-- [[ Script: Roblox Core GUI Extensions ]] --

local RobloxTopBarSubMenu = (function()
	local OpenStateChangedEvent = Instance.new("BindableEvent")
	local OpenedEvent = Instance.new("BindableEvent")
	local ClosedEvent = Instance.new("BindableEvent")
	
	local MenuProxy: RobloxTopBarSubMenu
	
	local Descriptors = {
		IsOpen = {
			Get = function()
				return MenuProxy.Canvas ~= nil
			end,
			Writable = false
		},
		Canvas = {
			Get = function()
				return findFirstChild(CoreGui, "TopBarApp", "UnibarLeftFrame", "UnibarMenu", "SubMenuHost", "nine_dot", "ScrollingFrame", "MainCanvas")
			end,
			Writable = false
		},
		
		OpenStateChanged = {Value = OpenStateChangedEvent.Event, Writable = false},
		Opened = {Value = OpenedEvent.Event, Writable = false},
		ClosedEvent = {Value = ClosedEvent.Event, Writable = false}
	}
	
	MenuProxy = createProxyWithPropertyDescriptors(Descriptors)
	
	local PreviousOpenState = MenuProxy.IsOpen
	
	local function UpdateState()
		local isOpen = MenuProxy.IsOpen
		if PreviousOpenState ~= isOpen then
			PreviousOpenState = isOpen
			OpenStateChangedEvent:Fire()
			if isOpen then
				OpenedEvent:Fire()
			else
				ClosedEvent:Fire()
			end
		end
	end
	
	CoreGui.DescendantAdded:Connect(UpdateState)
	CoreGui.DescendantRemoving:Connect(UpdateState)
	
	return MenuProxy
end)()

local RobloxTopBarSubMenuButton = (function()
	local RobloxTopBarSubMenuButton = {}
	local RobloxTopBarSubMenuButtons: {RobloxTopBarSubMenuButton} = {}

	function RobloxTopBarSubMenuButton.new(id: string, options: RobloxTopBarSubMenuButtonOptions?): RobloxTopBarSubMenuButton
		assert(type(id) == "string", "The id of RobloxTopBarSubMenuButton must be a string")
		assert(not RobloxTopBarSubMenuButton.getButtonFromId(id, true), `RobloxTopBarSubMenuButton with id "{id}" already exists`)

		local changedEvent = Instance.new("BindableEvent")
		local mouseButton1ClickEvent = Instance.new("BindableEvent")
		local mouseButton2ClickEvent = Instance.new("BindableEvent")
		local mouseMovedEvent = Instance.new("BindableEvent")
		local mouseWheelForwardEvent = Instance.new("BindableEvent")
		local mouseWheelBackwardEvent = Instance.new("BindableEvent")
		local activatedEvent = Instance.new("BindableEvent")
		local triggeredEvent = Instance.new("BindableEvent")

		local buttonDescriptors: Descriptors
		local buttonProxy: RobloxTopBarSubMenuButton
		
		local menuOpenStateChangedConnection: RBXScriptConnection
		local subConnections: {RBXScriptConnection} = {}
		
		local function killSubConnections()
			for _, connection in pairs(subConnections) do
				connection:Disconnect()
			end
			table.clear(subConnections)
		end
		
		buttonDescriptors = {
			Id = {Value = id, Writable = false},
			Removed = {Value = false, Writable = false},
			Instance = {Value = nil, Writable = false},
			MouseButton1Down = {Value = false, Writable = false},
			MouseButton2Down = {Value = false, Writable = false},
			MouseInside = {Value = false, Writable = false},

			Visible = {
				Value = nil,
				Set = function(value: boolean)
					value = toBoolean(value)
					local valueChanged = buttonDescriptors.Visible.Value ~= value
					buttonDescriptors.Visible.Value = value
					local instance = buttonProxy.Instance
					if instance then
						instance.Visible = value
					end
					if valueChanged then
						changedEvent:Fire("Visible")
					end
				end
			},
			Order = {
				Value = nil,
				Set = function(value: number)
					value = floor(min(999999999, max(-999999999, value)))
					local valueChanged = buttonDescriptors.Order.Value ~= value
					buttonDescriptors.Order.Value = value
					local instance = buttonProxy.Instance
					if instance then
						instance.LayoutOrder = value
					end
					if valueChanged then
						changedEvent:Fire("Order")
					end
				end
			},
			Icon = {
				Value = nil,
				Set = function(value: string)
					value = tostring(value)
					local valueChanged = buttonDescriptors.Icon.Value ~= value
					buttonDescriptors.Icon.Value = value
					local instance = buttonProxy.Instance
					if instance then
						local iconLabel = findFirstChild(instance, "RowLabel", "IconHost", "IntegrationIconFrame", "IntegrationIcon") :: ImageLabel?
						if iconLabel then
							iconLabel.Image = value
						end
					end
					if valueChanged then
						changedEvent:Fire("Icon")
					end
				end
			},
			IconColor3 = {
				Value = nil,
				Set = function(value: Color3)
					assert(typeof(value) == "Color3", `Property "IconColor3" only accept Color3 values`)
					local valueChanged = buttonDescriptors.IconColor3.Value ~= value
					buttonDescriptors.IconColor3.Value = value
					local instance = buttonProxy.Instance
					if instance then
						local iconLabel = findFirstChild(instance, "RowLabel", "IconHost", "IntegrationIconFrame", "IntegrationIcon") :: ImageLabel?
						if iconLabel then
							iconLabel.ImageColor3 = value
						end
					end
					if valueChanged then
						changedEvent:Fire("IconColor3")
					end
				end
			},
			IconTransparency = {
				Value = nil,
				Set = function(value: number)
					value = min(1, max(0, value))
					local valueChanged = buttonDescriptors.IconTransparency.Value ~= value
					buttonDescriptors.IconTransparency.Value = value
					local instance = buttonProxy.Instance
					if instance then
						local iconLabel = findFirstChild(instance, "RowLabel", "IconHost", "IntegrationIconFrame", "IntegrationIcon") :: ImageLabel?
						if iconLabel then
							iconLabel.ImageTransparency = value
						end
					end
					if valueChanged then
						changedEvent:Fire("IconTransparency")
					end
				end
			},
			Text = {
				Value = nil,
				Set = function(value: string)
					value = tostring(value)
					local valueChanged = buttonDescriptors.Text.Value ~= value
					buttonDescriptors.Text.Value = value
					local instance = buttonProxy.Instance
					if instance then
						local textLabel = findFirstChild(instance, "RowLabel", "StyledTextLabel") :: TextLabel?
						if textLabel then
							textLabel.Text = value
						end
					end
					if valueChanged then
						changedEvent:Fire("Text")
					end
				end
			},
			BackgroundColor3 = {
				Value = nil,
				Set = function(value: Color3)
					assert(typeof(value) == "Color3", `Property "BackgroundColor3" only accept Color3 values`)
					local valueChanged = buttonDescriptors.BackgroundColor3.Value ~= value
					buttonDescriptors.BackgroundColor3.Value = value
					local instance = buttonProxy.Instance
					if instance then
						instance.BackgroundColor3 = value
					end
					if valueChanged then
						changedEvent:Fire("BackgroundColor3")
					end
				end
			},
			BackgroundTransparency = {
				Value = nil,
				Set = function(value: number)
					value = min(1, max(0, value))
					local valueChanged = buttonDescriptors.BackgroundTransparency.Value ~= value
					buttonDescriptors.BackgroundTransparency.Value = value
					local instance = buttonProxy.Instance
					if instance then
						instance.BackgroundTransparency = value
					end
					if valueChanged then
						changedEvent:Fire("BackgroundTransparency")
					end
				end
			},
			TextColor3 = {
				Value = nil,
				Set = function(value: Color3)
					assert(typeof(value) == "Color3", `Property "TextColor3" only accept Color3 values`)
					local valueChanged = buttonDescriptors.TextColor3.Value ~= value
					buttonDescriptors.TextColor3.Value = value
					local instance = buttonProxy.Instance
					if instance then
						local textLabel = findFirstChild(instance, "RowLabel", "StyledTextLabel") :: TextLabel?
						if textLabel then
							textLabel.TextColor3 = value
						end
					end
					if valueChanged then
						changedEvent:Fire("TextColor3")
					end
				end
			},
			TextTransparency = {
				Value = nil,
				Set = function(value: number)
					value = min(1, max(0, value))
					local valueChanged = buttonDescriptors.TextTransparency.Value ~= value
					buttonDescriptors.TextTransparency.Value = value
					local instance = buttonProxy.Instance
					if instance then
						local textLabel = findFirstChild(instance, "RowLabel", "StyledTextLabel") :: TextLabel?
						if textLabel then
							textLabel.TextTransparency = value
						end
					end
					if valueChanged then
						changedEvent:Fire("TextTransparency")
					end
				end
			},

			Remove = {
				Value = function()
					if not buttonDescriptors.Removed.Value then
						buttonDescriptors.Removed.Value = true
						if menuOpenStateChangedConnection then
							menuOpenStateChangedConnection:Disconnect()
						end
						killSubConnections()
						local instance = buttonProxy.Instance
						if instance then
							instance:Destroy()
						end
						changedEvent:Fire("Removed")
					end
				end,
				Writable = false
			},
			Trigger = {
				Value = function()
					triggeredEvent:Fire()
				end,
				Writable = false
			},

			Changed = {Value = changedEvent.Event, Writable = false},
			MouseButton1Click = {Value = mouseButton1ClickEvent.Event, Writable = false},
			MouseButton2Click = {Value = mouseButton2ClickEvent.Event, Writable = false},
			MouseMoved = {Value = mouseMovedEvent.Event, Writable = false},
			MouseWheelForward = {Value = mouseWheelForwardEvent.Event, Writable = false},
			MouseWheelBackward = {Value = mouseWheelBackwardEvent.Event, Writable = false},
			Activated = {Value = activatedEvent.Event, Writable = false},
			Triggered = {Value = triggeredEvent.Event, Writeable = false}
		}

		buttonProxy = createProxyWithPropertyDescriptors(buttonDescriptors)
		
		local buttonOptions = options or {} :: RobloxTopBarSubMenuButtonOptions
		local visible = buttonOptions.Visible
		
		buttonProxy.Order = buttonOptions.Order or 0
		buttonProxy.Icon = buttonOptions.Icon or ""
		buttonProxy.IconColor3 = buttonOptions.IconColor3 or Color3.new(1, 1, 1)
		buttonProxy.IconTransparency = buttonOptions.IconTransparency or 0
		buttonProxy.Text = buttonOptions.Text or "Button"
		buttonProxy.BackgroundColor3 = buttonOptions.BackgroundColor3 or Color3.new(0, 0, 0)
		buttonProxy.BackgroundTransparency = buttonOptions.BackgroundTransparency or 1
		buttonProxy.TextColor3 = buttonOptions.TextColor3 or Color3.new(1, 1, 1)
		buttonProxy.TextTransparency = buttonOptions.TextTransparency or 0
		buttonProxy.Visible = if visible == nil then true else visible
		
		local function Update()
			if not buttonProxy.Removed then
				local canvas = RobloxTopBarSubMenu.Canvas
				if canvas then
					local baseButton: ImageButton? = canvas:FindFirstChild("trust_and_safety") :: ImageButton
					if baseButton then
						local button = baseButton:Clone()
						button.Name = `custom_{id}`
						buttonDescriptors.Instance.Value = button

						buttonProxy.Order = buttonProxy.Order
						buttonProxy.Icon = buttonProxy.Icon
						buttonProxy.IconColor3 = buttonProxy.IconColor3
						buttonProxy.IconTransparency = buttonProxy.IconTransparency
						buttonProxy.Text = buttonProxy.Text
						buttonProxy.BackgroundColor3 = buttonProxy.BackgroundColor3
						buttonProxy.BackgroundTransparency = buttonProxy.BackgroundTransparency
						buttonProxy.TextColor3 = buttonProxy.TextColor3
						buttonProxy.TextTransparency = buttonProxy.TextTransparency
						buttonProxy.Visible = buttonProxy.Visible

						table.insert(subConnections, button.MouseButton1Down:Connect(function()
							buttonDescriptors.MouseButton1Down.Value = true
							changedEvent:Fire("MouseButton1Down")
						end))

						table.insert(subConnections, button.MouseButton1Up:Connect(function()
							buttonDescriptors.MouseButton1Down.Value = false
							changedEvent:Fire("MouseButton1Down")
						end))

						table.insert(subConnections, button.MouseEnter:Connect(function()
							buttonDescriptors.MouseInside.Value = true
							changedEvent:Fire("MouseInside")
						end))

						table.insert(subConnections, button.MouseLeave:Connect(function()
							buttonDescriptors.MouseInside.Value = false
							changedEvent:Fire("MouseInside")
						end))

						table.insert(subConnections, button.MouseButton1Click:Connect(function()
							mouseButton1ClickEvent:Fire()
							buttonProxy.Trigger()
						end))

						table.insert(subConnections, button.MouseButton2Click:Connect(function()
							mouseButton2ClickEvent:Fire()
						end))

						table.insert(subConnections, button.MouseMoved:Connect(function(x, y)
							mouseMovedEvent:Fire(x, y)
						end))

						table.insert(subConnections, button.MouseWheelForward:Connect(function(x, y)
							mouseWheelForwardEvent:Fire(x, y)
						end))

						table.insert(subConnections, button.MouseWheelBackward:Connect(function(x, y)
							mouseWheelBackwardEvent:Fire(x, y)
						end))

						table.insert(subConnections, button.Activated:Connect(function(inputObject, clickCount)
							activatedEvent:Fire(inputObject, clickCount)
						end))

						button.Parent = canvas

						changedEvent:Fire("Instance")
					end
				else
					killSubConnections()
					local instance = buttonProxy.Instance
					if instance then
						instance:Destroy()
						buttonDescriptors.Instance.Value = nil
						changedEvent:Fire("Instance")
					end
				end
			end
		end
		
		menuOpenStateChangedConnection = RobloxTopBarSubMenu.OpenStateChanged:Connect(Update)
		Update()
		
		table.insert(RobloxTopBarSubMenuButtons, buttonProxy)

		return buttonProxy
	end

	function RobloxTopBarSubMenuButton.getAllButtons(includeRemovedButtons: boolean?): {RobloxTopBarSubMenuButton}
		local buttons = {}
		for _, button in pairs(RobloxTopBarSubMenuButtons) do
			if includeRemovedButtons or not button.Removed then
				table.insert(buttons, button)
			end
		end
		return buttons
	end

	function RobloxTopBarSubMenuButton.getButtonFromId(id: string, acceptRemovedButton: boolean?): RobloxTopBarSubMenuButton?
		for _, button in pairs(RobloxTopBarSubMenuButtons) do
			if button.Id == id and (acceptRemovedButton or not button.Removed) then
				return button
			end
		end
		return nil
	end
	
	return RobloxTopBarSubMenuButton
end)()

-- [[ Exporting ]] --

Library.createProxyWithPropertyDescriptors = createProxyWithPropertyDescriptors
Library.toBoolean = toBoolean
Library.isNaN = isNaN
Library.deepCloneTable = deepCloneTable
Library.load = load

Library.RobloxTopBarSubMenuButton = RobloxTopBarSubMenuButton

return Library