local self = {}
GLib.Threading.ThreadRunner = GLib.MakeConstructor (self)

function self:ctor ()
	self.Threads = {}
	self.RunnableThreads = {}
	
	self.CurrentThreadStack = {}
	self.CurrentThread = nil
	
	self:SetCurrentThread (GLib.Threading.MainThread)
	
	self.ExecutionSliceEndTime = 0
	
	hook.Add ("Think", "GLib.Threading",
		function ()
			self.ExecutionSliceEndTime = SysTime () + 0.005
			
			for thread, _ in pairs (self.RunnableThreads) do
				if SysTime () > self.ExecutionSliceEndTime then
					break
				end
				
				self:SetCurrentThread (thread)
				
				local success, error = coroutine.resume (thread:GetCoroutine ())
				if not success then
					thread:Terminate ()
					ErrorNoHalt ("GLib.Threading.ThreadRunner: Thread " .. thread:GetName () .. " (terminated): " .. error .. "\n")
				end
				
				if thread:IsTerminated () then
					thread:DispatchEvent ("Terminated")
				end
			end
			
			self:SetCurrentThread (GLib.Threading.MainThread)
			self.ExecutionSliceEndTime = SysTime () + 0.005
		end
	)
	
	GLib:AddEventListener ("Unloaded", "GLib.Threading",
		function ()
			self:dtor ()
		end
	)
end

function self:dtor ()
	hook.Remove ("Think", "GLib.Threading")
end

-- Threads
function self:AddThread (thread)
	if thread:IsTerminated () then return end
	
	if thread:IsMainThread () then
		thread:SetThreadRunner (self)
		return
	end
	
	self.Threads [thread] = thread
	
	if thread:IsRunnable () then
		self.RunnableThreads [thread] = thread
	end
	
	self:HookThread (thread)
end

function self:RemoveThread (thread)
	self.Threads [thread] = nil
	self.RunnableThreads [thread] = nil
	
	self:UnhookThread (thread)
end

-- Execution
function self:GetCurrentThread ()
	return self.CurrentThread
end

function self:GetExecutionSliceEndTime ()
	return self.ExecutionSliceEndTime
end

function self:RunThread (thread)
	if thread:IsRunnable () and not thread:IsMainThread () then
		self.ExecutionSliceEndTime = SysTime () + 0.005
		
		self:PushCurrentThread (thread)
		
		local success, error = coroutine.resume (thread:GetCoroutine ())
		self:PopCurrentThread ()
		
		if not success then
			thread:Terminate ()
			ErrorNoHalt ("GLib.Threading.ThreadRunner: Thread " .. thread:GetName () .. " (terminated): " .. error .. "\n")
		end
		
		if thread:IsTerminated () then
			thread:DispatchEvent ("Terminated")
		end
	end
end

-- Internal, do not call
function self:PopCurrentThread ()
	local currentThread = self.CurrentThread
	
	self:SetCurrentThread (self.CurrentThreadStack [#self.CurrentThreadStack])
	self.CurrentThreadStack [#self.CurrentThreadStack] = nil
	
	return currentThread
end
function self:PushCurrentThread (thread)
	self.CurrentThreadStack [#self.CurrentThreadStack + 1] = self.CurrentThread
	self:SetCurrentThread (thread)
end

function self:SetCurrentThread (thread)
	if self.CurrentThread == thread then return end
	
	self.CurrentThread = thread
	GLib.Threading.CurrentThread = self.CurrentThread
	GLib.CurrentThread = self.CurrentThread
end

function self:HookThread (thread)
	if not thread then return end
	
	thread:AddEventListener ("StateChanged", self:GetHashCode (),
		function (_, state, suspended)
			if thread:IsRunnable () then
				self.RunnableThreads [thread] = true
			else
				self.RunnableThreads [thread] = nil
			end
			
			if thread:IsTerminated () then
				self:RemoveThread (thread)
			end
		end
	)
end

function self:UnhookThread (thread)
	if not thread then return end
	
	thread:RemoveEventListener ("StateChanged", self:GetHashCode())
end

GLib.Threading.ThreadRunner = GLib.Threading.ThreadRunner ()