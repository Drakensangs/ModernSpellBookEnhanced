-- Minimal class system:
--   MSB_class "MSB_CName" :extends("MSB_CBase") { __init = function(self, ...) end; Method = ...; }
-- defines the global MSB_CName; MSB_CName(...) creates an instance.
-- extends copies the base's methods that the class doesn't define, so call
-- it before the definition table, as above.

local function ClassCreate(name)
	if (getglobal(name) ~= nil) then
		error("Class " .. name .. " already exists!")
	end

	local class = {}
	class.__index = class
	class.__classname = name
	class.__init = function(self) end

	setmetatable(class, {
		__call = function(cls, ...)
			local object = setmetatable({}, cls)
			object.__init(object, unpack(arg))
			return object
		end
	})
	setglobal(name, class)
	return class
end

local function ClassAddSuper(class, superName)
	local superclass = getglobal(superName)
	if (not superclass) then
		error("Base class " .. superName .. " not found!")
	end
	for name, method in pairs(superclass) do
		if (class[name] == nil) then
			class[name] = method
		end
	end
end

local function ClassDefinition(class)
	local definer = {
		extends = function(self, superName)
			ClassAddSuper(class, superName)
			return self
		end
	}
	return setmetatable(definer, {
		__call = function(self, definition)
			for name, method in pairs(definition) do
				class[name] = method
			end
		end
	})
end

function MSB_class(name)
	return ClassDefinition(ClassCreate(name))
end
