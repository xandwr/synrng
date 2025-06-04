-- server/services/TickTimerService.server.lua
-- Core timing service that drives the SynRNG game loop
-- Manages 60-second evaluation cycles and special hourly events

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Remotes = require(game.ReplicatedStorage.Shared.remotes)

local TickTimerService = {}

-- ========================================
-- CONFIGURATION
-- ========================================

local CONFIG = {
    TICK_DURATION = 60,           -- Standard evaluation every 60 seconds
    HOURLY_EVENT_INTERVAL = 3600, -- Special event every hour (3600 seconds)
    UPDATE_FREQUENCY = 0.1,       -- Send client updates every 0.1 seconds
    
    -- Phase durations (in seconds)
    BUILDING_PHASE = 45,          -- 45s for players to build/modify
    EVALUATION_PHASE = 10,        -- 10s for server processing
    RESULTS_PHASE = 5,            -- 5s for showing results
    
    -- Special event settings
    HOURLY_MULTIPLIER = 100,      -- 100x damage for hourly events
    HOURLY_WARNING_TIME = 30,     -- Warn players 30s before hourly event
}

-- ========================================
-- STATE MANAGEMENT
-- ========================================

local TickTimerService_State = {
    -- Current tick information
    CurrentTick = 0,
    TickStartTime = 0,
    TimeRemaining = CONFIG.TICK_DURATION,
    
    -- Phase management
    CurrentPhase = "BUILDING",    -- "BUILDING", "EVALUATING", "RESULTS"
    PhaseStartTime = 0,
    
    -- Special events
    NextHourlyEventTime = 0,
    HourlyEventActive = false,
    HourlyEventWarning = false,
    
    -- Service state
    ServiceRunning = false,
    LastUpdateTime = 0,
    
    -- Statistics
    TotalTicksProcessed = 0,
    AverageEvaluationTime = 0,
    LastEvaluationDuration = 0,
    
    -- Connected events
    EvaluationCallbacks = {},
    PhaseChangeCallbacks = {},
    HourlyEventCallbacks = {}
}

-- ========================================
-- PHASE SYSTEM
-- ========================================

local PHASES = {
    BUILDING = {
        Name = "BUILDING",
        Description = "Configure your Astral Web",
        Duration = CONFIG.BUILDING_PHASE,
        AllowConfiguration = true,
        ShowCountdown = true
    },
    EVALUATING = {
        Name = "EVALUATING", 
        Description = "Processing all player webs...",
        Duration = CONFIG.EVALUATION_PHASE,
        AllowConfiguration = false,
        ShowCountdown = false
    },
    RESULTS = {
        Name = "RESULTS",
        Description = "Damage dealt! Preparing next round...",
        Duration = CONFIG.RESULTS_PHASE,
        AllowConfiguration = false,
        ShowCountdown = false
    }
}

-- ========================================
-- CORE TIMER LOGIC
-- ========================================

function TickTimerService.StartTimer()
    if TickTimerService_State.ServiceRunning then
        warn("TickTimerService is already running!")
        return
    end
    
    print("🕐 Starting TickTimerService...")
    
    -- Initialize state
    TickTimerService_State.ServiceRunning = true
    TickTimerService_State.CurrentTick = 0
    TickTimerService_State.TickStartTime = tick()
    TickTimerService_State.TimeRemaining = CONFIG.TICK_DURATION
    TickTimerService_State.CurrentPhase = "BUILDING"
    TickTimerService_State.PhaseStartTime = tick()
    
    -- Calculate next hourly event
    local currentTime = tick()
    TickTimerService_State.NextHourlyEventTime = currentTime + CONFIG.HOURLY_EVENT_INTERVAL
    
    -- Start the main timer loop
    TickTimerService.StartMainLoop()
    
    -- Send initial update to all clients
    TickTimerService.BroadcastTimerUpdate()
    
    print("✅ TickTimerService started successfully")
end

function TickTimerService.StopTimer()
    print("🛑 Stopping TickTimerService...")
    TickTimerService_State.ServiceRunning = false
end

function TickTimerService.StartMainLoop()
    spawn(function()
        local lastUpdateTime = tick()
        
        while TickTimerService_State.ServiceRunning do
            local currentTime = tick()
            local deltaTime = currentTime - lastUpdateTime
            
            -- Update timer state
            TickTimerService.UpdateTimerState(currentTime, deltaTime)
            
            -- Check for phase transitions
            TickTimerService.CheckPhaseTransitions(currentTime)
            
            -- Check for special events
            TickTimerService.CheckHourlyEvents(currentTime)
            
            -- Send updates to clients (throttled)
            if currentTime - TickTimerService_State.LastUpdateTime >= CONFIG.UPDATE_FREQUENCY then
                TickTimerService.BroadcastTimerUpdate()
                TickTimerService_State.LastUpdateTime = currentTime
            end
            
            lastUpdateTime = currentTime
            RunService.Heartbeat:Wait()
        end
    end)
end

function TickTimerService.UpdateTimerState(currentTime, deltaTime)
    local elapsedSinceTickStart = currentTime - TickTimerService_State.TickStartTime
    TickTimerService_State.TimeRemaining = CONFIG.TICK_DURATION - elapsedSinceTickStart
    
    -- Check if tick should complete
    if TickTimerService_State.TimeRemaining <= 0 then
        TickTimerService.CompleteTick()
    end
end

function TickTimerService.CheckPhaseTransitions(currentTime)
    local elapsedInPhase = currentTime - TickTimerService_State.PhaseStartTime
    local currentPhaseData = PHASES[TickTimerService_State.CurrentPhase]
    
    if elapsedInPhase >= currentPhaseData.Duration then
        TickTimerService.AdvancePhase()
    end
end

function TickTimerService.AdvancePhase()
    local currentPhase = TickTimerService_State.CurrentPhase
    local nextPhase
    
    if currentPhase == "BUILDING" then
        nextPhase = "EVALUATING"
        -- Trigger evaluation start
        TickTimerService.TriggerEvaluation()
    elseif currentPhase == "EVALUATING" then
        nextPhase = "RESULTS"
        -- Evaluation should be complete, show results
        TickTimerService.TriggerResultsPhase()
    elseif currentPhase == "RESULTS" then
        -- Cycle back to building, but don't reset tick timer
        nextPhase = "BUILDING"
    end
    
    if nextPhase then
        local oldPhase = TickTimerService_State.CurrentPhase
        TickTimerService_State.CurrentPhase = nextPhase
        TickTimerService_State.PhaseStartTime = tick()
        
        print(string.format("📊 Phase transition: %s -> %s", oldPhase, nextPhase))
        
        -- Notify callbacks
        TickTimerService.NotifyPhaseChange(oldPhase, nextPhase)
    end
end

function TickTimerService.CompleteTick()
    TickTimerService_State.CurrentTick = TickTimerService_State.CurrentTick + 1
    TickTimerService_State.TotalTicksProcessed = TickTimerService_State.TotalTicksProcessed + 1
    
    print(string.format("⏰ Tick #%d completed", TickTimerService_State.CurrentTick))
    
    -- Reset timer for next tick
    TickTimerService_State.TickStartTime = tick()
    TickTimerService_State.TimeRemaining = CONFIG.TICK_DURATION
    TickTimerService_State.CurrentPhase = "BUILDING"
    TickTimerService_State.PhaseStartTime = tick()
    
    -- Clear any special event flags
    TickTimerService_State.HourlyEventActive = false
    TickTimerService_State.HourlyEventWarning = false
end

-- ========================================
-- EVALUATION TRIGGERING
-- ========================================

function TickTimerService.TriggerEvaluation()
    local evaluationStartTime = tick()
    print(string.format("🔄 Starting evaluation for tick #%d", TickTimerService_State.CurrentTick))
    
    -- Determine if this is a special hourly event
    local isHourlyEvent = TickTimerService_State.HourlyEventActive
    local damageMultiplier = isHourlyEvent and CONFIG.HOURLY_MULTIPLIER or 1
    
    -- Create evaluation context
    local evaluationContext = {
        TickNumber = TickTimerService_State.CurrentTick,
        IsHourlyEvent = isHourlyEvent,
        DamageMultiplier = damageMultiplier,
        EvaluationStartTime = evaluationStartTime,
        ParticipatingPlayers = TickTimerService.GetParticipatingPlayers()
    }
    
    -- Notify all registered evaluation callbacks
    for _, callback in pairs(TickTimerService_State.EvaluationCallbacks) do
        spawn(function()
            local success, result = pcall(callback, evaluationContext)
            if not success then
                warn("Evaluation callback error: " .. tostring(result))
            end
        end)
    end
    
    -- Track evaluation duration
    spawn(function()
        local evaluationEndTime = tick()
        local duration = evaluationEndTime - evaluationStartTime
        TickTimerService_State.LastEvaluationDuration = duration
        
        -- Update average evaluation time
        local totalEvaluations = TickTimerService_State.TotalTicksProcessed
        TickTimerService_State.AverageEvaluationTime = 
            ((TickTimerService_State.AverageEvaluationTime * (totalEvaluations - 1)) + duration) / totalEvaluations
        
        print(string.format("✅ Evaluation completed in %.2fs", duration))
    end)
end

function TickTimerService.TriggerResultsPhase()
    print("📊 Entering results phase")
    
    -- This is where you'd trigger any results-specific callbacks
    -- Like updating leaderboards, distributing rewards, etc.
end

-- ========================================
-- HOURLY EVENTS SYSTEM
-- ========================================

function TickTimerService.CheckHourlyEvents(currentTime)
    local timeUntilHourly = TickTimerService_State.NextHourlyEventTime - currentTime
    
    -- Warning phase (30 seconds before)
    if timeUntilHourly <= CONFIG.HOURLY_WARNING_TIME and not TickTimerService_State.HourlyEventWarning then
        TickTimerService_State.HourlyEventWarning = true
        TickTimerService.BroadcastHourlyWarning(timeUntilHourly)
        print(string.format("⚠️  Hourly event warning: %.0f seconds remaining", timeUntilHourly))
    end
    
    -- Check if hourly event should trigger
    if timeUntilHourly <= 0 and not TickTimerService_State.HourlyEventActive then
        TickTimerService.TriggerHourlyEvent()
    end
end

function TickTimerService.TriggerHourlyEvent()
    print("🌟 HOURLY EVENT TRIGGERED!")
    
    TickTimerService_State.HourlyEventActive = true
    TickTimerService_State.NextHourlyEventTime = tick() + CONFIG.HOURLY_EVENT_INTERVAL
    
    -- Broadcast hourly event to all clients
    if Remotes.UpdateAstralWebTimerEvent then
        Remotes.UpdateAstralWebTimerEvent:FireAllClients({
            TimeRemaining = TickTimerService_State.TimeRemaining,
            TotalTickTime = CONFIG.TICK_DURATION,
            CurrentTick = TickTimerService_State.CurrentTick,
            Phase = TickTimerService_State.CurrentPhase,
            IsHourlyEvent = true,
            HourlyMultiplier = CONFIG.HOURLY_MULTIPLIER,
            SpecialMessage = "💥 POWER SURGE! 100x DAMAGE! 💥"
        })
    else
        warn("❌ UpdateAstralWebTimerEvent not found")
    end
    
    -- Notify hourly event callbacks
    for _, callback in pairs(TickTimerService_State.HourlyEventCallbacks) do
        spawn(function()
            local success, result = pcall(callback, {
                EventType = "HOURLY_EVENT",
                Multiplier = CONFIG.HOURLY_MULTIPLIER,
                TickNumber = TickTimerService_State.CurrentTick
            })
            if not success then
                warn("Hourly event callback error: " .. tostring(result))
            end
        end)
    end
end

function TickTimerService.BroadcastHourlyWarning(timeRemaining)
    if Remotes.UpdateAstralWebTimerEvent then
        Remotes.UpdateAstralWebTimerEvent:FireAllClients({
            TimeRemaining = TickTimerService_State.TimeRemaining,
            TotalTickTime = CONFIG.TICK_DURATION,
            CurrentTick = TickTimerService_State.CurrentTick,
            Phase = TickTimerService_State.CurrentPhase,
            HourlyEventWarning = true,
            HourlyEventCountdown = math.ceil(timeRemaining),
            SpecialMessage = string.format("⚡ Power surge in %ds! ⚡", math.ceil(timeRemaining))
        })
    else
        warn("❌ UpdateAstralWebTimerEvent not found")
    end
end

-- ========================================
-- CLIENT SYNCHRONIZATION
-- ========================================

function TickTimerService.BroadcastTimerUpdate()
    local timerData = {
        TimeRemaining = math.max(0, TickTimerService_State.TimeRemaining),
        TotalTickTime = CONFIG.TICK_DURATION,
        CurrentTick = TickTimerService_State.CurrentTick,
        Phase = TickTimerService_State.CurrentPhase,
        PhaseData = PHASES[TickTimerService_State.CurrentPhase],
        
        -- Special event info
        IsHourlyEvent = TickTimerService_State.HourlyEventActive,
        HourlyEventWarning = TickTimerService_State.HourlyEventWarning,
        NextHourlyEvent = TickTimerService_State.NextHourlyEventTime - tick(),
        
        -- Server performance info
        ServerPerformance = {
            AverageEvaluationTime = TickTimerService_State.AverageEvaluationTime,
            LastEvaluationTime = TickTimerService_State.LastEvaluationDuration,
            TotalTicks = TickTimerService_State.TotalTicksProcessed
        }
    }
    
    -- Safe fire with error handling
    if Remotes.UpdateAstralWebTimerEvent then
        Remotes.UpdateAstralWebTimerEvent:FireAllClients(timerData)
    else
        warn("❌ UpdateAstralWebTimerEvent not found")
    end
end

function TickTimerService.GetParticipatingPlayers()
    local participatingPlayers = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player and player.Parent then
            table.insert(participatingPlayers, {
                Player = player,
                PlayerId = player.UserId,
                JoinedTick = TickTimerService_State.CurrentTick  -- Could track when they joined
            })
        end
    end
    
    return participatingPlayers
end

-- ========================================
-- CALLBACK SYSTEM
-- ========================================

function TickTimerService.RegisterEvaluationCallback(callback)
    if type(callback) ~= "function" then
        error("Evaluation callback must be a function")
    end
    
    table.insert(TickTimerService_State.EvaluationCallbacks, callback)
    print("📝 Registered evaluation callback")
end

function TickTimerService.RegisterPhaseChangeCallback(callback)
    if type(callback) ~= "function" then
        error("Phase change callback must be a function")
    end
    
    table.insert(TickTimerService_State.PhaseChangeCallbacks, callback)
    print("📝 Registered phase change callback")
end

function TickTimerService.RegisterHourlyEventCallback(callback)
    if type(callback) ~= "function" then
        error("Hourly event callback must be a function")
    end
    
    table.insert(TickTimerService_State.HourlyEventCallbacks, callback)
    print("📝 Registered hourly event callback")
end

function TickTimerService.NotifyPhaseChange(oldPhase, newPhase)
    for _, callback in pairs(TickTimerService_State.PhaseChangeCallbacks) do
        spawn(function()
            local success, result = pcall(callback, oldPhase, newPhase)
            if not success then
                warn("Phase change callback error: " .. tostring(result))
            end
        end)
    end
end

-- ========================================
-- PLAYER CONNECTION HANDLING
-- ========================================

function TickTimerService.OnPlayerAdded(player)
    -- Send current timer state to newly joined player
    spawn(function()
        wait(1) -- Give time for player to fully load
        
        local timerData = {
            TimeRemaining = math.max(0, TickTimerService_State.TimeRemaining),
            TotalTickTime = CONFIG.TICK_DURATION,
            CurrentTick = TickTimerService_State.CurrentTick,
            Phase = TickTimerService_State.CurrentPhase,
            PhaseData = PHASES[TickTimerService_State.CurrentPhase],
            IsHourlyEvent = TickTimerService_State.HourlyEventActive,
            NextHourlyEvent = TickTimerService_State.NextHourlyEventTime - tick(),
            WelcomeMessage = string.format("Welcome to SynRNG! Currently in tick #%d", TickTimerService_State.CurrentTick)
        }
        
        if Remotes.UpdateAstralWebTimerEvent then
            Remotes.UpdateAstralWebTimerEvent:FireClient(player, timerData)
            print(string.format("👋 Sent timer sync to %s", player.Name))
        else
            warn("❌ UpdateAstralWebTimerEvent not found - cannot sync timer to player")
        end
    end)
end

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

function TickTimerService.GetCurrentState()
    return {
        CurrentTick = TickTimerService_State.CurrentTick,
        TimeRemaining = TickTimerService_State.TimeRemaining,
        Phase = TickTimerService_State.CurrentPhase,
        IsHourlyEvent = TickTimerService_State.HourlyEventActive,
        NextHourlyEvent = TickTimerService_State.NextHourlyEventTime - tick(),
        ServiceRunning = TickTimerService_State.ServiceRunning,
        Statistics = {
            TotalTicksProcessed = TickTimerService_State.TotalTicksProcessed,
            AverageEvaluationTime = TickTimerService_State.AverageEvaluationTime,
            LastEvaluationDuration = TickTimerService_State.LastEvaluationDuration
        }
    }
end

function TickTimerService.ForceNextPhase()
    print("🔧 Forcing phase advance (admin command)")
    TickTimerService.AdvancePhase()
end

function TickTimerService.ForceHourlyEvent()
    print("🔧 Forcing hourly event (admin command)")
    TickTimerService.TriggerHourlyEvent()
end

function TickTimerService.SetTickDuration(newDuration)
    if newDuration and newDuration > 0 then
        CONFIG.TICK_DURATION = newDuration
        print(string.format("🔧 Tick duration changed to %d seconds", newDuration))
    else
        warn("Invalid tick duration")
    end
end

-- ========================================
-- INITIALIZATION
-- ========================================

-- Connect player events
Players.PlayerAdded:Connect(TickTimerService.OnPlayerAdded)

-- Handle server shutdown gracefully
game:BindToClose(function()
    print("🛑 Server shutting down, stopping TickTimerService...")
    TickTimerService.StopTimer()
end)

print("📦 TickTimerService module loaded")

return TickTimerService