--!strict
local Library = {}

-- [[ Types ]] --

export type Descriptors = {[any]: {
	Value: any,
	Writable: boolean?,
	Get: (() -> any)?,
	Set: ((value: any) -> ())?
}}

-- [[ Variable Shortcuts ]] --

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

-- [[ Exporting ]] --

Library.createProxyWithPropertyDescriptors = createProxyWithPropertyDescriptors
Library.toBoolean = toBoolean
Library.isNaN = isNaN
Library.deepCloneTable = deepCloneTable
Library.load = load

return Library