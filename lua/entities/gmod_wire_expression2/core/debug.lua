-- import some e2lib and math functions
local validEntity  = E2Lib.validEntity
local isOwner      = E2Lib.isOwner
local Clamp        = math.Clamp
local seq = table.IsSequential

/******************************************************************************/

local function checkOwner(self)
	return validEntity(self.player);
end

/******************************************************************************/

local print_delay = 0.3
local print_max = 15

local print_delays = {}

timer.Create("e2_printcolor_delays",print_delay,0,function()
	for k,v in pairs( print_delays ) do
		if (k and k:IsValid() and k:IsPlayer()) then
			if (print_delays[k] < print_max) then
				print_delays[k] = print_delays[k] + 1
			end
		else
			print_delays[k] = nil
		end
	end
end)

local function check_delay( ply )
	if (!print_delays[ply]) then
		print_delays[ply] = print_max - 1
		return true
	end

	if (print_delays[ply] > 0) then
		print_delays[ply] = print_delays[ply] - 1
		return true
	end

	return false
end

/******************************************************************************/

local function SpecialCase( arg )
	if (type(arg) == "table") then
		if (arg.isfunction) then
			return "function " .. arg[3] .. " = (" .. arg[2] .. ")"
		elseif (seq(arg)) then -- A table with only numerical indexes
			local str = "["
			for k,v in ipairs( arg ) do
				if (type(v) == "table") then
					if (k != #arg) then
						str = str .. SpecialCase( v ) .. ","
					else
						str = str .. SpecialCase( v ) .. "]"
					end
				else
					if (k != #arg) then
						str = str .. tostring(v) .. ","
					else
						str = str .. tostring(v) .. "]"
					end
				end
			end
			return str
		else -- Else it's a table with string indexes (which this function can't handle)
			return "[table]"
		end
	end
end

-- Prints <...> like lua's print(...), except to the chat area
e2function void print(...)
	if (not checkOwner(self)) then return; end
	local args = {...}
	if (#args>0) then
		local text = ""
		for k,v in ipairs( args ) do
			text = text .. (SpecialCase( v ) or tostring(v)) .. "\t"
		end
		if (text and #text>0) then
			self.player:ChatPrint(text)
		end
	end
end

--- Posts <text> to the chat area. (deprecated due to print(...))
--e2 function void print(string text)
--	self.player:ChatPrint(text)
--end

--- Posts a string to the chat of <this>'s driver. Returns 1 if the text was printed, 0 if not.
e2function number entity:printDriver(string text)
	if not validEntity(this) then return 0 end
	if not this:IsVehicle() then return 0 end
	if not isOwner(self, this) then return 0 end
	if text:find('"', 1, true) then return 0 end

	local driver = this:GetDriver()
	if not validEntity(driver) then return 0 end

	if (!check_delay( self.player )) then return 0 end

	driver:ChatPrint(text)
	return 1
end

/******************************************************************************/

--- Displays a hint popup with message <text> for <duration> seconds (<duration> being clamped between 0.7 and 7).
e2function void hint(string text, duration)
	if not validEntity(self.player) then return end
	WireLib.AddNotify(self.player, text, NOTIFY_GENERIC, Clamp(duration,0.7,7))
end

--- Displays a hint popup to the driver of vehicle E, with message <text> for <duration> seconds (<duration> being clamped between 0.7 and 7). Same return value as printDriver.
e2function number entity:hintDriver(string text, duration)
	if not validEntity(this) then return 0 end
	if not this:IsVehicle() then return 0 end
	if not isOwner(self, this) then return 0 end

	local driver = this:GetDriver()
	if not validEntity(driver) then return 0 end

	if (!check_delay( self.player )) then return 0 end

	WireLib.AddNotify(driver, text, NOTIFY_GENERIC, Clamp(duration,0.7,7))
	return 1
end

/******************************************************************************/

local valid_print_types = {}
for _,cname in ipairs({ "HUD_PRINTCENTER", "HUD_PRINTCONSOLE", "HUD_PRINTNOTIFY", "HUD_PRINTTALK" }) do
	local value = _G[cname]
	valid_print_types[value] = true
	E2Lib.registerConstant(cname, value)
end

--- Same as print(<text>), but can make the text show up in different places. <print_type> can be one of the following: _HUD_PRINTCENTER, _HUD_PRINTCONSOLE, _HUD_PRINTNOTIFY, _HUD_PRINTTALK.
e2function void print(print_type, string text)
	if (not checkOwner(self)) then return; end
	if not valid_print_types[print_type] then return end

	self.player:PrintMessage(print_type, text)
end

--- Same as <this>E:printDriver(<text>), but can make the text show up in different places. <print_type> can be one of the following: _HUD_PRINTCENTER, _HUD_PRINTCONSOLE, _HUD_PRINTNOTIFY, _HUD_PRINTTALK.
e2function number entity:printDriver(print_type, string text)
	if not validEntity(this) then return 0 end
	if not this:IsVehicle() then return 0 end
	if not isOwner(self, this) then return 0 end
	if not valid_print_types[print_type] then return 0 end
	if text:find('"', 1, true) then return 0 end

	local driver = this:GetDriver()
	if not validEntity(driver) then return 0 end

	if (!check_delay( self.player )) then return 0 end

	driver:PrintMessage(print_type, text)
	return 1
end

/******************************************************************************/

-- helper stuff for printTable
local _Msg = Msg
local msgbuf
local function MyMsg(s)
	table.insert(msgbuf, s)
end

--- Prints an array like the lua function [[G.PrintTable|PrintTable]] does, except to the chat area.
e2function void printTable(array arr)
	if (not checkOwner(self)) then return; end
	msgbuf = {}
	Msg = MyMsg
	PrintTable(arr)
	Msg = _Msg
	for _,line in ipairs(string.Explode("\n",table.concat(msgbuf))) do
		self.player:ChatPrint(line)
	end
	msgbuf = nil
end

-- The printTable(T) function is in table.lua because it uses a local function

/******************************************************************************/

__e2setcost(100)

local printColor_typeids = {
	n = tostring,
	s = tostring,
	v = function(v) return Color(v[1],v[2],v[3]) end,
	xv4 = function(v) return Color(v[1],v[2],v[3],v[4]) end,
	e = function(e) return validEntity(e) and e:IsPlayer() and e or "" end,
}

local function printColorVarArg(chip, ply, typeids, ...)
	if (not validEntity(ply)) then return; end
	local send_array = { ... }

	for i,tp in ipairs(typeids) do
		if printColor_typeids[tp] then
			send_array[i] = printColor_typeids[tp](send_array[i])
		else
			send_array[i] = ""
		end
	end

	send_array.chip = chip
	datastream.StreamToClients(ply, "wire_expression2_printColor", send_array)
end

local printColor_types = {
	number = tostring,
	string = tostring,
	Vector = function(v) return Color(v[1],v[2],v[3]) end,
	table = function(tbl)
		for i,v in pairs(tbl) do
			if type(i) ~= "number" then return "" end
			if type(v) ~= "number" then return "" end
			if i < 1 or i > 4 then return "" end
		end
		return Color(tbl[1] or 0, tbl[2] or 0,tbl[3] or 0,tbl[4])
	end,
	Player = function(e) return validEntity(e) and e:IsPlayer() and e or "" end,
}

local function printColorArray(chip, ply, arr)
	if (not validEntity(ply)) then return; end
	if (!check_delay( ply )) then return end

	local send_array = {}

	for i,tp in ipairs_map(arr,type) do
		if printColor_types[tp] then
			send_array[i] = printColor_types[tp](arr[i])
		else
			send_array[i] = ""
		end
	end

	send_array.chip = chip
	datastream.StreamToClients(ply, "wire_expression2_printColor", send_array)
end


--- Works like [[chat.AddText]](...). Parameters can be any amount and combination of numbers, strings, player entities, color vectors (both 3D and 4D).
e2function void printColor(...)
	printColorVarArg(nil, self.player, typeids, ...)
end

--- Like printColor(...), except taking an array containing all the parameters.
e2function void printColor(array arr)
	printColorArray(nil, self.player, arr)
end

--- Like printColor(...), except printing in <this>'s driver's chat area instead of yours.
e2function void entity:printColorDriver(...)
	if not validEntity(this) then return end
	if not this:IsVehicle() then return end
	if not isOwner(self, this) then return end

	local driver = this:GetDriver()
	if not validEntity(driver) then return end

	if (!check_delay( self.player )) then return 0 end

	printColorVarArg(self.entity, driver, typeids, ...)
end

--- Like printColor(R), except printing in <this>'s driver's chat area instead of yours.
e2function void entity:printColorDriver(array arr)
	if not validEntity(this) then return end
	if not this:IsVehicle() then return end
	if not isOwner(self, this) then return end

	local driver = this:GetDriver()
	if not validEntity(driver) then return end

	if (!check_delay( self.player )) then return 0 end

	printColorArray(self.entity, driver, arr)
end
