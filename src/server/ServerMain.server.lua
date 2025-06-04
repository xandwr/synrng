-- server/ServerMain.server.lua
-- Main server initialization script for SynRNG
-- Starts all services and connects them together

local Services = require(script.Parent.services)

print("🚀 Starting SynRNG server...")
print("📦 Available services:", Services)

-- Get services (handle different possible names)
local TickTimerService = Services.TickTimerService
local SynergyEvaluationService = Services.SynergyEvaluationService

if not TickTimerService then
    error("❌ TickTimerService not found! Cannot start server.")
end

print("✅ Found TickTimerService")

-- ========================================
-- SERVICE CONNECTIONS
-- ========================================

-- Only connect SynergyEvaluationService if it loaded successfully
if SynergyEvaluationService then
    print("✅ Found SynergyEvaluationService - connecting callbacks")
    
    -- Register SynergyEvaluationService to handle evaluations
    TickTimerService.RegisterEvaluationCallback(function(evaluationContext)
        print(string.format("📊 Evaluation triggered for tick #%d", evaluationContext.TickNumber))
        SynergyEvaluationService.StartEvaluation(evaluationContext)
    end)
    
    -- Register hourly event callback
    TickTimerService.RegisterHourlyEventCallback(function(eventData)
        print(string.format("🌟 Hourly event triggered! Multiplier: %dx", eventData.Multiplier))
    end)
else
    warn("⚠️ SynergyEvaluationService not available - timer will run without evaluations")
    
    -- Register a simple placeholder evaluation callback
    TickTimerService.RegisterEvaluationCallback(function(evaluationContext)
        print(string.format("📊 Evaluation placeholder for tick #%d (SynergyEvaluationService not loaded)", evaluationContext.TickNumber))
    end)
end

-- Register phase change callback for debugging (always available)
TickTimerService.RegisterPhaseChangeCallback(function(oldPhase, newPhase)
    print(string.format("🔄 Phase change: %s -> %s", oldPhase, newPhase))
end)

-- ========================================
-- START THE TIMER SYSTEM
-- ========================================

-- Start the main tick timer (this begins the 60-second cycles)
TickTimerService.StartTimer()

print("✅ SynRNG server started successfully!")
print("⏰ Timer system active - 60-second evaluation cycles")

if SynergyEvaluationService then
    print("🔮 Synergy evaluation service connected")
else
    print("⚠️ Running in timer-only mode")
end

print("🌟 Hourly 100x events enabled")

-- ========================================
-- ADMIN COMMANDS (for testing)
-- ========================================

-- Add some debug commands that can be run from the command bar
game.Players.PlayerAdded:Connect(function(player)
    -- Give a moment for player to fully load
    wait(2)
    
    print(string.format("👋 %s joined the game", player.Name))
    
    -- You can test these commands in the command bar:
    -- TickTimerService.ForceNextPhase() -- Force advance to next phase
    -- TickTimerService.ForceHourlyEvent() -- Trigger hourly event immediately
    -- TickTimerService.SetTickDuration(10) -- Set 10-second ticks for testing
    if SynergyEvaluationService then
        -- SynergyEvaluationService.DebugPlayerConfiguration(game.Players.YourName)
    end
end)