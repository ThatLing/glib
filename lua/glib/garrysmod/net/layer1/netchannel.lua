local self = {}
GLib.Net.Layer1.NetChannel = GLib.MakeConstructor (self, GLib.Net.Layer1.Channel)

local function PlayerFromUserId (userId)
	if type (userId) == "table" then
		-- Assume it's a SubscriberSet
		return userId:GetRecipientFilter ()
	end
	
	if CLIENT and userId == GLib.GetServerId () then return nil end
	if userId == GLib.GetEveryoneId () then return player.GetAll () end
	
	local ply = GLib.PlayerMonitor:GetUserEntity (userId)
	if not ply then
		GLib.Error ("GLib: PlayerFromId (" .. tostring (userId) .. ") failed to find player!\n")
	end
	
	return ply
end

function self:ctor (channelName, handler)
	self.Open = false
	
	if SERVER then	
		self:SetOpen (true)
		util.AddNetworkString (self:GetName ())
		
		net.Receive (self:GetName (),
			function (_, ply)
				self:GetHandler () (GLib.GetPlayerId (ply), GLib.Net.Layer1.NetInBuffer ())
			end
		)
	else
		net.Receive (channelName,
			function (_)
				self:GetHandler () (GLib.GetServerId (), GLib.Net.Layer1.NetInBuffer ())
			end
		)
	end
end

function self:DispatchPacket (destinationId, packet)
	if not self:IsOpen () then
		GLib.Error ("UsermessageChannel:DispatchPacket : Channel isn't open! (" .. tostring (destinationId) .. "." .. self:GetName () .. ")")
	end
	if packet:GetSize () > self:GetMTU () then
		GLib.Error ("UsermessageChannel:DispatchPacket : Packet for " .. tostring (destinationId) .. "." .. self:GetName () .. " exceeds MTU (" .. (packet:GetSize ()) .. ")!")
	end
	
	destinationId = PlayerFromUserId (destinationId)
	GLib.Net.Layer1.NetDispatcher:Dispatch (destinationId, self:GetName (), packet)
end

function self:GetMTU ()
	return 65536 - #self:GetName () - 2
end