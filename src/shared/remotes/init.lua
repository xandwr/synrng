-- ReplicatedStorage/Shared/data/remotes/init.lua
-- Exports all RemoteEvents and RemoteFunctions for easy access

local Remotes = {}

-- Debug: Show what's actually in the remotes folder
print("🔍 Remotes folder contents:")
for _, child in pairs(script:GetChildren()) do
    print(string.format("  Found: %s (%s)", child.Name, child.ClassName))
end

-- ========================================
-- AUTO-DETECT ALL REMOTES
-- ========================================
for _, child in pairs(script:GetChildren()) do
    if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
        Remotes[child.Name] = child
        print(string.format("  ✅ Exported: %s", child.Name))
    end
end

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

-- Safe fire functions with error handling
function Remotes.SafeFireAllClients(eventName, ...)
    local event = Remotes[eventName]
    if event and event:IsA("RemoteEvent") then
        event:FireAllClients(...)
    else
        warn("RemoteEvent not found: " .. tostring(eventName))
    end
end

function Remotes.SafeFireClient(eventName, player, ...)
    local event = Remotes[eventName]
    if event and event:IsA("RemoteEvent") then
        event:FireClient(player, ...)
    else
        warn("RemoteEvent not found: " .. tostring(eventName))
    end
end

function Remotes.SafeFireServer(eventName, ...)
    local event = Remotes[eventName]
    if event and event:IsA("RemoteEvent") then
        event:FireServer(...)
    else
        warn("RemoteEvent not found: " .. tostring(eventName))
    end
end

function Remotes.SafeInvokeServer(functionName, ...)
    local func = Remotes[functionName]
    if func and func:IsA("RemoteFunction") then
        return func:InvokeServer(...)
    else
        warn("RemoteFunction not found: " .. tostring(functionName))
        return nil
    end
end

-- Get remote by name (for backwards compatibility)
function Remotes.GetRemote(remoteName)
    return Remotes[remoteName]
end

-- Debug function to list all remotes
function Remotes.ListAllRemotes()
    print("📡 Available Remotes:")
    for name, remote in pairs(Remotes) do
        if typeof(remote) == "Instance" then
            print(string.format("  %s: %s", name, remote.ClassName))
        end
    end
end

-- Initialize message
print(string.format("✅ All SynRNG remotes initialized successfully (%d total)", #script:GetChildren()))

return Remotes