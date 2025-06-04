-- server/services/init.lua
-- Exports all server services for easy importing

-- Simple approach - just try to require what exists
local services = {}
local loadedCount = 0

-- Check what's actually in this folder
print("🔍 Services folder contents:")
for _, child in pairs(script:GetChildren()) do
    if child:IsA("ModuleScript") then
        print(string.format("  Found: %s (ModuleScript)", child.Name))
        
        -- Try to require each ModuleScript we find
        local success, result = pcall(require, child)
        if success then
            services[child.Name] = result
            loadedCount = loadedCount + 1
            print(string.format("  ✅ Successfully loaded: %s", child.Name))
        else
            warn(string.format("  ❌ Failed to load %s: %s", child.Name, result))
        end
    end
end

print(string.format("📦 Services loaded: %d", loadedCount))
return services