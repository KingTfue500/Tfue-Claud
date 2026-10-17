--!strict
-- Zugriff auf die RemoteEvents in ReplicatedStorage/Remotes (statisch im Projekt angelegt)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder == nil then
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return folder :: Folder
end

function Net.Event(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Net.Unreliable(name: string): UnreliableRemoteEvent
	return getFolder():WaitForChild(name) :: UnreliableRemoteEvent
end

return Net
