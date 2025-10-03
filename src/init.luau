local CollectionService = game:GetService("CollectionService")

local GoodSignal = require(script.Parent.GoodSignal)

local Binder = {}
Binder.__index = Binder

local activeBinders = {} -- [tagName] = Binder

function Binder.new(tagName: string, classModule)
	local self = setmetatable({}, Binder)
	self._tagName = tagName
	self._classModule = classModule
	self._activeObjects = {} -- [Instance] = classInstance

	-- Signals
	self.InstanceAdded = GoodSignal.new()
	self.InstanceRemoving = GoodSignal.new()

	-- Connect CollectionService events
	self._connectionAdded = CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
		self:_bind(instance)
	end)

	self._connectionRemoved = CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance)
		self:_unbind(instance)
	end)

	-- Bind already-tagged instances
	for _, instance in CollectionService:GetTagged(tagName) do
		self:_bind(instance)
	end

	activeBinders[tagName] = self

	return self
end

function Binder:_bind(instance)
	if self._activeObjects[instance] then
		return
	end

	local success, classObject = pcall(self._classModule.new, self._classModule, instance)

	if not success then
		warn(string.format("[%s] Bind failed for %s: %s", self._tagName, instance:GetFullName(), classObject))
		return
	end

	if not classObject then
		return
	end

	self._activeObjects[instance] = classObject
	self.InstanceAdded:Fire(instance, classObject)
end

function Binder:_unbind(instance)
	local classObject = self._activeObjects[instance]
	if not classObject then
		return
	end

	self.InstanceRemoving:Fire(instance, classObject)
	self._activeObjects[instance] = nil

	if typeof(classObject.Destroy) == "function" then
		pcall(function()
			classObject:Destroy()
		end)
	end
end

function Binder:GetAll()
	local allObjects = {}
	for _, classObject in self._activeObjects do
		table.insert(allObjects, classObject)
	end
	return allObjects
end

function Binder:Get(instance)
	return self._activeObjects[instance]
end

function Binder.GetBinderByTag(tagName)
	return activeBinders[tagName]
end

function Binder:Destroy()
	self._connectionAdded:Disconnect()
	self._connectionRemoved:Disconnect()

	for instance in self._activeObjects do
		self:_unbind(instance)
	end
	table.clear(self._activeObjects)

	activeBinders[self._tagName] = nil
end

return Binder
