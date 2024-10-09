/******************************************************************************\
  Timer support
\******************************************************************************/

local timerid = 0

local function Execute(self, name)
	self.data.timer.runner = name

	self.data['timer'].timers[name] = nil

	if(self.entity and self.entity.Execute) then
		self.entity:Execute()
	end

	if !self.data['timer'].timers[name] then
		timer.Remove("e2_" .. self.data['timer'].timerid .. "_" .. name)
	end

	self.data.timer.runner = nil
end

local function AddTimer(self, name, delay)
	if delay < 10 then delay = 10 end

	local timerName = "e2_" .. self.data.timer.timerid .. "_" .. name

	if self.data.timer.runner == name and timer.Exists(timerName) then
		timer.Adjust(timerName, delay / 1000, 2, function()
			Execute(self, name)
		end)
		timer.Start(timerName)
	elseif !self.data['timer'].timers[name] then
		timer.Create(timerName, delay / 1000, 2, function()
			Execute(self, name)
		end)
	end

	self.data['timer'].timers[name] = true
end

local function RemoveTimer(self, name)
	if self.data['timer'].timers[name] then
		timer.Remove("e2_" .. self.data['timer'].timerid .. "_" .. name)
		self.data['timer'].timers[name] = nil
	end
end

/******************************************************************************/

registerCallback("construct", function(self)
	self.data['timer'] = {}
	self.data['timer'].timerid = timerid
	self.data['timer'].timers = {}

	timerid = timerid + 1
end)

registerCallback("destruct", function(self)
	for name,_ in pairs(self.data['timer'].timers) do
		RemoveTimer(self, name)
	end
end)

/******************************************************************************/

__e2setcost(20)

e2function void interval(rv1)
	AddTimer(self, "interval", rv1)
end

e2function void timer(string rv1, rv2)
	AddTimer(self, rv1, rv2)
end

__e2setcost(5)

e2function void stoptimer(string rv1)
	RemoveTimer(self, rv1)
end

__e2setcost(1)

[nodiscard]
e2function number clk()
	return self.data.timer.runner == "interval" and 1 or 0
end

[nodiscard]
e2function number clk(string rv1)
	return self.data.timer.runner == rv1 and 1 or 0
end

[nodiscard]
e2function string clkName()
	return self.data.timer.runner or ""
end

e2function array getTimers()
	local ret = {}
	local i = 0
	for name in pairs( self.data.timer.timers ) do
		i = i + 1
		ret[i] = name
	end
	self.prf = self.prf + i * 5
	return ret
end

e2function void stopAllTimers()
	for name in pairs(self.data.timer.timers) do
		self.prf = self.prf + 5
		RemoveTimer(self,name)
	end
end

/******************************************************************************/
-- Lambda timers
local gtimers = {
	/*EXAMPLE:
	'[342]e2entity' = {
		[342]e2entity_gmod_wire_expression2_gtimer_examplename = {
			context = {...} (e2 context),
			callback = {...} (e2 callback),
			delay = 1,
			repetitions = 1
		}
	} 
	*/
}

local gtimersIncrementalKeys = {}

local function gtimerGetNextIncrementalKey(self)
	local key = (gtimersIncrementalKeys[self.entity:EntIndex()] or 0)+1
	gtimersIncrementalKeys[self.entity:EntIndex()] = key
	return key
end

local function gtimerGetPrefix(name)
	return '_gmod_wire_expression2_gtimer_' .. name
end

local function gtimerExists(self, name)
	return gtimers[self.entity:EntIndex()] and gtimers[self.entity:EntIndex()][gtimerGetPrefix(name)] and true or false
end

local function createGTimer(self, name, delay, repetitions, callback)
	ogname = name
	name = gtimerGetPrefix(name)
	if not gtimers[self.entity:EntIndex()] then
		gtimers[self.entity:EntIndex()] = {}
	elseif gtimerExists(self, ogname) then
		return self:throw("Timer with name " .. name .. " already exists", nil)
	end

	gtimers[self.entity:EntIndex()][name] = {
		name = ogname,
		context = self,
		callback = callback,
		delay = delay,
		repetitions = repetitions
	}

	timer.Create(name, delay, repetitions, function()
		if timer.RepsLeft(name) == 0 then
			gtimers[name] = nil
		end

		callback:UnsafeExtCall({}, self)
	end)
end

local function destroyGTimer(self, name)
	
	if not gtimers[self.entity:EntIndex()] then
		gtimers[self.entity:EntIndex()] = {}
		return self:throw("Timer with name " .. name .. " does not exist", nil)
	elseif not gtimerExists(self, name) then
		return self:throw("Timer with name " .. name .. " does not exist", nil)
	end
	
	name = gtimerGetPrefix(name)
	timer.Remove(name)
	gtimers[self.entity:EntIndex()][name] = nil
end

registerCallback("destruct", function( self )
	for k, _ in pairs(gtimers[self.entity:EntIndex()] or {}) do
		timer.Remove(k)
	end

	gtimers[self.entity:EntIndex()] = nil
end)



__e2setcost(2)
e2function void gtimerSetDelay(string name, number delay)
	if not gtimerExists(self, name) then
		return self:throw("Timer with name " .. name .. " does not exist", nil)
	end

	local name = gtimerGetPrefix(name)
	gtimers[self.entity:EntIndex()][name].delay = delay
	timer.Adjust(name, delay, 0)
end

e2function number gtimerSetReps(string name, number repetitions)
	if not gtimerExists(self, name) then
		return self:throw("Timer with name " .. name .. " does not exist", nil)
	end

	local name = gtimerGetPrefix(name)
	gtimers[self.entity:EntIndex()][name].repetitions = repetitions
	timer.Adjust(name, gtimers[self.entity:EntIndex()][name].delay, repetitions)
end

__e2setcost(20)
e2function void gtimerSetCallback(string name, function callback)
	if not gtimerExists(self, name) then
		return self:throw("Timer with name " .. name .. " does not exist", nil)
	end

	local int_name = gtimerGetPrefix(name)
	local gtimer = table.Copy(gtimers[self.entity:EntIndex()][int_name])
	destroyGTimer(self, name)

	gtimer['callback'] = callback
	createGTimer(self, name, gtimer.delay, gtimer.repetitions, callback)
end

__e2setcost(10)
e2function void gtimerCreate(string name, number delay, number repetitions, function callback)
	createGTimer(self, name, delay, repetitions, callback)
end

e2function string gtimerCreate(number delay, number repetitions, function callback)
	local name = "simpletimer_"..gtimerGetNextIncrementalKey(self)
	createGTimer(self, name, delay, repetitions, callback)
	return name
end

e2function string gtimerCreate(number delay, function callback)
	local name = "simpletimer_"..gtimerGetNextIncrementalKey(self)
	createGTimer(self, "simpletimer_"..gtimerGetNextIncrementalKey(self), delay, 1, callback)
	return name
end

e2function void gtimerCreate(string name, number delay, function callback)
	createGTimer(self, name, delay, 1, callback)
end

-- Complete alias of gtimerCreate, but a lot of newbies will look for delay
e2function string delay(number delay, function callback)
	local name = "simpletimer_"..gtimerGetNextIncrementalKey(self)
	createGTimer(self, name, delay, 1, callback)
	return name
end

e2function void gtimerRestart(string name)
	if not gtimerExists(self, name) then
		return self:throw("Timer with name " .. name .. " does not exist", nil)
	end

	local name = gtimerGetPrefix(name)
	timer.Stop(name)
	timer.Start(name)
end

__e2setcost(1)
[nodiscard]
e2function number gtimerExists(string name)
	return gtimerExists(self, name) and 1 or 0
end

e2function void gtimerPause(string name)
	if not gtimerExists(self, name) then
		return self:throw("Timer with name " .. name .. " does not exist", 0)
	end

	--return timer.Pause(gtimerGetPrefix(name)) and 1 or 0
	timer.Pause(gtimerGetPrefix(name))
end

e2function void gtimerResume(string name)
	if not gtimerExists(self, name) then
		return self:throw("Timer with name " .. name .. " does not exist", 0)
	end

	-- return timer.UnPause(gtimerGetPrefix(name)) and 1 or 0
	timer.UnPause(gtimerGetPrefix(name))
end
-- This and that^ is commented due to timer.Pause being broken for some reason. It just does not return anything.
-- e2function number gtimerToggle(string name)
-- 	if not gtimerExists(self, name) then
-- 		return self:throw("Timer with name " .. name .. " does not exist", 0)
-- 	end
-- 	return timer.Toggle(gtimerGetPrefix(name)) and 1 or 0
-- end

__e2setcost(5)
e2function void gtimerRemove(string name)
	destroyGTimer(self, name)
end

__e2setcost(10)
e2function void gtimerPurge()
	for _, tbl in pairs(gtimers[self.entity:EntIndex()]) do
		destroyGTimer(self, tbl.name)
	end
end

__e2setcost(5)
[nodiscard]
e2function number gtimerRepsLeft(string name)
	if not gtimerExists(self, name) then
		return self:throw("Timer with name " .. name .. " does not exist", 0)
	end
	return timer.RepsLeft(gtimerGetPrefix(name))
end

[nodiscard]
e2function number gtimerTimeLeft(string name)
	if not gtimerExists(self, name) then
		return self:throw("Timer with name " .. name .. " does not exist", 0)
	end
	return timer.TimeLeft(gtimerGetPrefix(name))
end

[nodiscard]
e2function array gtimerList()
	for _, timerTbl in pairs(gtimers[self.entity:EntIndex()]) do
		ret[#ret+1] = timerTbl.name
	end
end

/******************************************************************************/
__e2setcost(1)
[nodiscard]
e2function number curtime()
	return CurTime()
end

[nodiscard]
e2function number realtime()
	return RealTime()
end

[nodiscard]
e2function number systime()
	return SysTime()
end

-----------------------------------------------------------------------------------

local function luaDateToE2Table( time, utc )
	local ret = E2Lib.newE2Table()
	local time = os.date((utc and "!" or "") .. "*t",time)

	if not time then return ret end -- this happens if you give it a negative time

	for k,v in pairs( time ) do
		if k == "isdst" then
			ret.s.isdst = (v and 1 or 0)
			ret.stypes.isdst = "n"
		else
			ret.s[k] = v
			ret.stypes[k] = "n"
		end

		ret.size = ret.size + 1
	end

	return ret
end
__e2setcost(10)
-- Returns the server's current time formatted neatly in a table
e2function table date()
	return luaDateToE2Table()
end

-- Returns the specified time formatted neatly in a table
e2function table date( time )
	return luaDateToE2Table(time)
end

-- Returns the server's current time formatted neatly in a table using UTC
e2function table dateUTC()
	return luaDateToE2Table(nil,true)
end

-- Returns the specified time formatted neatly in a table using UTC
e2function table dateUTC( time )
	return luaDateToE2Table(time,true)
end

-- This function has a strange and slightly misleading name, but changing it might break older E2s, so I'm leaving it
-- It's essentially the same as the date function above
e2function number time(string component)
	local ostime = os.date("!*t")
	local ret = ostime[component]

	return tonumber(ret) or ret and 1 or 0 -- the later parts account for invalid components and isdst
end


-----------------------------------------------------------------------------------

__e2setcost(2)
-- Returns the time in seconds
[nodiscard]
e2function number time()
	return os.time()
end

-- Attempts to construct the time from the data in the given table (same as lua's os.time)
-- The table structure must be the same as in the above date functions
-- If any values are missing or of the wrong type, that value is ignored (it will be nil)
local validkeys = {hour = true, min = true, day = true, sec = true, yday = true, wday = true, month = true, year = true, isdst = true}
[nodiscard]
e2function number time(table data)
	local args = {}

	for k,v in pairs( data.s ) do
		if data.stypes[k] ~= "n" or not validkeys[k] then continue end

		if k == "isdst" then
			args.isdst = (v == 1)
		else
			args[k] = v
		end
	end

	return os.time( args )
end
