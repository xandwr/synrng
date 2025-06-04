-- server/services/SynergyEvaluationService.server.lua
-- Core evaluation engine that processes all player astral web configurations
-- Calculates damage, handles synergies, and manages the 60-second evaluation cycle

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SynergyComponentsDB = require(game.ReplicatedStorage.Shared.data.SynergyComponentsDB)
local Remotes = require(game.ReplicatedStorage.Shared.remotes)

local SynergyEvaluationService = {}

-- ========================================
-- CONFIGURATION
-- ========================================

local CONFIG = {
    MAX_SEQUENCE_LENGTH = 5,        -- Maximum components in a sequence
    EVALUATION_TIMEOUT = 8.0,       -- Max time for evaluation (leave buffer for results phase)
    PROGRESS_UPDATE_INTERVAL = 0.5, -- Send progress updates every 0.5s
    
    -- Performance settings
    BATCH_SIZE = 10,                -- Process players in batches of 10
    BATCH_DELAY = 0.1,             -- Delay between batches (seconds)
    
    -- Validation settings
    REQUIRE_VALID_CONFIGURATION = true,
    ALLOW_EMPTY_SLOTS = true,       -- Allow gaps in sequence (position 3 empty, etc.)
    VALIDATE_COMPONENT_OWNERSHIP = true
}

-- ========================================
-- STATE MANAGEMENT
-- ========================================

local EvaluationState = {
    -- Current evaluation
    CurrentlyEvaluating = false,
    EvaluationStartTime = 0,
    EvaluationContext = nil,
    
    -- Player configurations (persistent between ticks)
    PlayerConfigurations = {},      -- [PlayerId] = {SequenceConfiguration = {...}, LastUpdated = tick()}
    
    -- Current evaluation results
    CurrentResults = {},            -- [PlayerId] = {TotalDamage = ..., ComponentResults = {...}}
    EvaluationProgress = 0,         -- 0.0 to 1.0
    
    -- Statistics
    TotalEvaluationsProcessed = 0,
    AveragePlayerDamage = 0,
    HighestSingleTickDamage = 0,
    HighestSingleComponentDamage = 0,
    
    -- Performance tracking
    LastEvaluationTime = 0,
    PlayerProcessingTimes = {}
}

-- ========================================
-- PLAYER CONFIGURATION MANAGEMENT
-- ========================================

function SynergyEvaluationService.RegisterPlayerConfiguration(player, configurationData)
    local playerId = player.UserId
    
    -- Validate configuration
    local isValid, validationError = SynergyEvaluationService.ValidateConfiguration(player, configurationData)
    
    if not isValid then
        Remotes.SafeFireClient("ErrorNotificationEvent", player, {
            ErrorType = "VALIDATION_FAILED",
            ErrorCode = "INVALID_SEQUENCE",
            Message = "Astral web configuration is invalid",
            Details = { Reason = validationError },
            Severity = "ERROR",
            AutoDismiss = true,
            DismissTime = 5.0
        })
        return false
    end
    
    -- Store configuration
    EvaluationState.PlayerConfigurations[playerId] = {
        SequenceConfiguration = configurationData.SequenceConfiguration,
        ConfigurationHash = configurationData.ConfigurationHash,
        LastUpdated = tick(),
        Player = player
    }
    
    print(string.format("📝 Registered configuration for %s (%d components)", 
        player.Name, SynergyEvaluationService.CountActiveComponents(configurationData.SequenceConfiguration)))
    
    return true
end

function SynergyEvaluationService.ValidateConfiguration(player, configurationData)
    if not configurationData or not configurationData.SequenceConfiguration then
        return false, "Missing sequence configuration"
    end
    
    local sequence = configurationData.SequenceConfiguration
    
    -- Check sequence length
    if #sequence > CONFIG.MAX_SEQUENCE_LENGTH then
        return false, string.format("Sequence too long (max %d)", CONFIG.MAX_SEQUENCE_LENGTH)
    end
    
    -- Validate each position
    for position = 1, CONFIG.MAX_SEQUENCE_LENGTH do
        local nodeData = sequence[position]
        
        if nodeData then
            -- Check if component exists
            local component = SynergyComponentsDB.GetComponent(nodeData.ComponentId)
            if not component then
                return false, string.format("Invalid component at position %d: %s", position, nodeData.ComponentId or "nil")
            end
            
            -- Validate component ownership (if required)
            if CONFIG.VALIDATE_COMPONENT_OWNERSHIP then
                local ownsComponent = SynergyEvaluationService.PlayerOwnsComponent(player, nodeData.ComponentId)
                if not ownsComponent then
                    return false, string.format("Player doesn't own component: %s", nodeData.ComponentId)
                end
            end
            
            -- Validate node data structure
            local isValidNode, nodeError = SynergyComponentsDB.ValidateComponent(component)
            if not isValidNode then
                return false, string.format("Invalid component data: %s", nodeError)
            end
        elseif not CONFIG.ALLOW_EMPTY_SLOTS and position <= #sequence then
            return false, string.format("Empty slot at position %d (empty slots not allowed)", position)
        end
    end
    
    return true, "Valid configuration"
end

function SynergyEvaluationService.PlayerOwnsComponent(player, componentId)
    -- TODO: This would check against player inventory/collection
    -- For now, return true to allow testing
    return true
end

function SynergyEvaluationService.CountActiveComponents(sequence)
    local count = 0
    for _, nodeData in pairs(sequence) do
        if nodeData and nodeData.ComponentId then
            count = count + 1
        end
    end
    return count
end

-- ========================================
-- MAIN EVALUATION SYSTEM
-- ========================================

function SynergyEvaluationService.StartEvaluation(evaluationContext)
    if EvaluationState.CurrentlyEvaluating then
        warn("⚠️ Evaluation already in progress!")
        return
    end
    
    print(string.format("🔄 Starting synergy evaluation for tick #%d (Hourly: %s)", 
        evaluationContext.TickNumber, tostring(evaluationContext.IsHourlyEvent)))
    
    EvaluationState.CurrentlyEvaluating = true
    EvaluationState.EvaluationStartTime = tick()
    EvaluationState.EvaluationContext = evaluationContext
    EvaluationState.CurrentResults = {}
    EvaluationState.EvaluationProgress = 0
    
    -- Start asynchronous evaluation
    spawn(function()
        SynergyEvaluationService.ProcessAllPlayerConfigurations()
    end)
end

function SynergyEvaluationService.ProcessAllPlayerConfigurations()
    local startTime = tick()
    local participatingPlayers = {}
    
    -- Collect all players with valid configurations
    for playerId, configData in pairs(EvaluationState.PlayerConfigurations) do
        if configData.Player and configData.Player.Parent and configData.SequenceConfiguration then
            table.insert(participatingPlayers, {
                PlayerId = playerId,
                Player = configData.Player,
                ConfigData = configData
            })
        end
    end
    
    local totalPlayers = #participatingPlayers
    print(string.format("📊 Processing %d player configurations", totalPlayers))
    
    if totalPlayers == 0 then
        SynergyEvaluationService.CompleteEvaluation()
        return
    end
    
    -- Process players in batches for performance
    local playersProcessed = 0
    local batchIndex = 0
    
    while playersProcessed < totalPlayers do
        batchIndex = batchIndex + 1
        local batchStart = playersProcessed + 1
        local batchEnd = math.min(playersProcessed + CONFIG.BATCH_SIZE, totalPlayers)
        
        print(string.format("⚙️ Processing batch %d: players %d-%d", batchIndex, batchStart, batchEnd))
        
        -- Process batch
        for i = batchStart, batchEnd do
            local playerData = participatingPlayers[i]
            SynergyEvaluationService.ProcessPlayerConfiguration(playerData)
            playersProcessed = playersProcessed + 1
        end
        
        -- Update progress
        EvaluationState.EvaluationProgress = playersProcessed / totalPlayers
        SynergyEvaluationService.BroadcastEvaluationProgress()
        
        -- Small delay between batches to prevent lag
        if playersProcessed < totalPlayers then
            wait(CONFIG.BATCH_DELAY)
        end
        
        -- Check timeout
        if tick() - startTime > CONFIG.EVALUATION_TIMEOUT then
            warn("⏰ Evaluation timeout reached!")
            break
        end
    end
    
    SynergyEvaluationService.CompleteEvaluation()
end

function SynergyEvaluationService.ProcessPlayerConfiguration(playerData)
    local playerId = playerData.PlayerId
    local player = playerData.Player
    local configData = playerData.ConfigData
    
    local processingStartTime = tick()
    
    -- Convert configuration to ordered sequence for processing
    local orderedSequence = SynergyEvaluationService.ConvertToOrderedSequence(configData.SequenceConfiguration)
    
    if #orderedSequence == 0 then
        -- No components to process
        EvaluationState.CurrentResults[playerId] = {
            TotalDamage = 0,
            ComponentResults = {},
            ActiveComponents = 0,
            ErrorReason = "No components configured"
        }
        return
    end
    
    -- Create web context for sequential evaluation
    local webContext = SynergyComponentsDB.CreateWebContext(orderedSequence)
    
    -- Process the sequence using the components database
    local sequenceResult = SynergyComponentsDB.SimulateSequence(orderedSequence)
    
    -- Apply evaluation context modifiers (hourly events, etc.)
    local finalDamage = sequenceResult.TotalDamage
    if EvaluationState.EvaluationContext.IsHourlyEvent then
        finalDamage = finalDamage * EvaluationState.EvaluationContext.DamageMultiplier
    end
    
    -- Store results
    EvaluationState.CurrentResults[playerId] = {
        TotalDamage = finalDamage,
        BaseDamage = sequenceResult.TotalDamage,
        ComponentResults = sequenceResult.IndividualResults,
        ActiveComponents = sequenceResult.ActiveComponents,
        SequenceLength = sequenceResult.SequenceLength,
        AllEffects = sequenceResult.AllEffects,
        WebContext = webContext,
        
        -- Evaluation metadata
        EvaluationTime = tick() - processingStartTime,
        IsHourlyEvent = EvaluationState.EvaluationContext.IsHourlyEvent,
        DamageMultiplier = EvaluationState.EvaluationContext.DamageMultiplier
    }
    
    -- Send live feedback to player
    Remotes.SafeFireClient("LiveEvaluationUpdateEvent", player, {
        Phase = "EVALUATING",
        Progress = EvaluationState.EvaluationProgress,
        CurrentlyProcessing = "Your astral web",
        YourResults = {
            TotalDamage = finalDamage,
            ActiveComponents = sequenceResult.ActiveComponents,
            BestComponent = SynergyEvaluationService.FindBestComponent(sequenceResult.IndividualResults)
        }
    })
    
    -- Track performance
    EvaluationState.PlayerProcessingTimes[playerId] = tick() - processingStartTime
    
    print(string.format("✅ Processed %s: %.0f damage (%d active components)", 
        player.Name, finalDamage, sequenceResult.ActiveComponents))
end

function SynergyEvaluationService.ConvertToOrderedSequence(sequenceConfiguration)
    local orderedSequence = {}
    
    -- Convert positional configuration to ordered array
    for position = 1, CONFIG.MAX_SEQUENCE_LENGTH do
        local nodeData = sequenceConfiguration[position]
        if nodeData and nodeData.ComponentId then
            -- Ensure nodeData has required fields for evaluation
            nodeData.Position = position
            nodeData.Rarity = nodeData.Rarity or "COMMON"
            nodeData.EvolutionLevel = nodeData.EvolutionLevel or 0
            
            table.insert(orderedSequence, nodeData)
        end
    end
    
    return orderedSequence
end

function SynergyEvaluationService.FindBestComponent(componentResults)
    local bestComponent = nil
    local highestDamage = 0
    
    for position, result in pairs(componentResults or {}) do
        if result and result.Damage and result.Damage > highestDamage then
            highestDamage = result.Damage
            bestComponent = {
                ComponentId = result.ComponentId,
                ComponentName = result.ComponentName,
                Damage = result.Damage,
                Position = position
            }
        end
    end
    
    return bestComponent
end

-- ========================================
-- EVALUATION COMPLETION & RESULTS
-- ========================================

function SynergyEvaluationService.CompleteEvaluation()
    local evaluationEndTime = tick()
    local totalEvaluationTime = evaluationEndTime - EvaluationState.EvaluationStartTime
    
    print(string.format("✅ Evaluation completed in %.2fs", totalEvaluationTime))
    
    -- Calculate global statistics
    local globalStats = SynergyEvaluationService.CalculateGlobalStatistics()
    
    -- Send final results to all players
    SynergyEvaluationService.BroadcastFinalResults(globalStats)
    
    -- Update service statistics
    EvaluationState.TotalEvaluationsProcessed = EvaluationState.TotalEvaluationsProcessed + 1
    EvaluationState.LastEvaluationTime = totalEvaluationTime
    
    -- Clean up
    EvaluationState.CurrentlyEvaluating = false
    EvaluationState.EvaluationContext = nil
    EvaluationState.EvaluationProgress = 1.0
end

function SynergyEvaluationService.CalculateGlobalStatistics()
    local totalDamage = 0
    local playerCount = 0
    local topDamage = 0
    local topPerformers = {}
    
    -- Calculate totals and find top performers
    for playerId, result in pairs(EvaluationState.CurrentResults) do
        if result.TotalDamage then
            totalDamage = totalDamage + result.TotalDamage
            playerCount = playerCount + 1
            
            if result.TotalDamage > topDamage then
                topDamage = result.TotalDamage
            end
            
            table.insert(topPerformers, {
                PlayerId = playerId,
                Damage = result.TotalDamage,
                Player = EvaluationState.PlayerConfigurations[playerId].Player
            })
        end
    end
    
    -- Sort top performers
    table.sort(topPerformers, function(a, b)
        return a.Damage > b.Damage
    end)
    
    -- Take top 10
    local topTen = {}
    for i = 1, math.min(10, #topPerformers) do
        local performer = topPerformers[i]
        table.insert(topTen, {
            PlayerId = performer.PlayerId,
            Name = performer.Player.Name,
            Damage = performer.Damage,
            Rank = i
        })
    end
    
    -- Update service-wide statistics
    if topDamage > EvaluationState.HighestSingleTickDamage then
        EvaluationState.HighestSingleTickDamage = topDamage
    end
    
    if playerCount > 0 then
        EvaluationState.AveragePlayerDamage = totalDamage / playerCount
    end
    
    return {
        TotalDamage = totalDamage,
        PlayerCount = playerCount,
        AverageDamage = playerCount > 0 and totalDamage / playerCount or 0,
        TopDamage = topDamage,
        TopPerformers = topTen,
        EvaluationTime = EvaluationState.LastEvaluationTime
    }
end

function SynergyEvaluationService.BroadcastFinalResults(globalStats)
    for playerId, result in pairs(EvaluationState.CurrentResults) do
        local player = EvaluationState.PlayerConfigurations[playerId].Player
        
        if player and player.Parent then
            -- Find player's rank
            local playerRank = nil
            for rank, performer in pairs(globalStats.TopPerformers) do
                if performer.PlayerId == playerId then
                    playerRank = rank
                    break
                end
            end
            
            if not playerRank then
                -- Player not in top 10, calculate their rank
                local playersAbove = 0
                for _, otherResult in pairs(EvaluationState.CurrentResults) do
                    if otherResult.TotalDamage > result.TotalDamage then
                        playersAbove = playersAbove + 1
                    end
                end
                playerRank = playersAbove + 1
            end
            
            -- Send individual results
            Remotes.SafeFireClient("TickResultsEvent", player, {
                TickNumber = EvaluationState.EvaluationContext.TickNumber,
                Results = {
                    YourPerformance = {
                        TotalDamage = result.TotalDamage,
                        BaseDamage = result.BaseDamage,
                        Rank = playerRank,
                        ActiveComponents = result.ActiveComponents,
                        ComponentBreakdown = SynergyEvaluationService.CreateComponentBreakdown(result),
                        IsHourlyEvent = result.IsHourlyEvent,
                        DamageMultiplier = result.DamageMultiplier
                    },
                    GlobalResults = {
                        TopPerformers = globalStats.TopPerformers,
                        TotalDamage = globalStats.TotalDamage,
                        PlayerCount = globalStats.PlayerCount,
                        AverageDamage = globalStats.AverageDamage
                    }
                }
            })
        end
    end
    
    -- Also broadcast global results to all clients
    Remotes.SafeFireAllClients("LiveEvaluationUpdateEvent", {
        Phase = "RESULTS",
        Progress = 1.0,
        GlobalStats = globalStats,
        EvaluationComplete = true
    })
end

function SynergyEvaluationService.CreateComponentBreakdown(result)
    local breakdown = {}
    
    for position, componentResult in pairs(result.ComponentResults or {}) do
        breakdown[position] = {
            ComponentId = componentResult.ComponentId,
            ComponentName = componentResult.ComponentName,
            Damage = componentResult.Damage or 0,
            Active = componentResult.Active,
            RequirementsMet = componentResult.RequirementsMet,
            SequencePosition = componentResult.SequencePosition
        }
    end
    
    return breakdown
end

function SynergyEvaluationService.BroadcastEvaluationProgress()
    local progressData = {
        Phase = "EVALUATING",
        Progress = EvaluationState.EvaluationProgress,
        CurrentlyProcessing = string.format("Processing player configurations... (%.0f%%)", 
            EvaluationState.EvaluationProgress * 100)
    }
    
    Remotes.SafeFireAllClients("LiveEvaluationUpdateEvent", progressData)
end

-- ========================================
-- REMOTE EVENT HANDLERS
-- ========================================

function SynergyEvaluationService.OnSubmitConfiguration(player, configurationData)
    print(string.format("📥 Received configuration from %s", player.Name))
    SynergyEvaluationService.RegisterPlayerConfiguration(player, configurationData)
end

function SynergyEvaluationService.OnPlayerRemoving(player)
    local playerId = player.UserId
    
    -- Clean up player data
    if EvaluationState.PlayerConfigurations[playerId] then
        EvaluationState.PlayerConfigurations[playerId] = nil
        print(string.format("🧹 Cleaned up configuration for %s", player.Name))
    end
    
    if EvaluationState.CurrentResults[playerId] then
        EvaluationState.CurrentResults[playerId] = nil
    end
    
    if EvaluationState.PlayerProcessingTimes[playerId] then
        EvaluationState.PlayerProcessingTimes[playerId] = nil
    end
end

-- ========================================
-- UTILITY & DEBUG FUNCTIONS
-- ========================================

function SynergyEvaluationService.GetServiceStatistics()
    return {
        TotalEvaluationsProcessed = EvaluationState.TotalEvaluationsProcessed,
        AveragePlayerDamage = EvaluationState.AveragePlayerDamage,
        HighestSingleTickDamage = EvaluationState.HighestSingleTickDamage,
        HighestSingleComponentDamage = EvaluationState.HighestSingleComponentDamage,
        LastEvaluationTime = EvaluationState.LastEvaluationTime,
        ActivePlayerConfigurations = 0,
        CurrentlyEvaluating = EvaluationState.CurrentlyEvaluating
    }
end

function SynergyEvaluationService.GetPlayerConfiguration(player)
    local playerId = player.UserId
    return EvaluationState.PlayerConfigurations[playerId]
end

function SynergyEvaluationService.DebugPlayerConfiguration(player)
    local config = SynergyEvaluationService.GetPlayerConfiguration(player)
    if not config then
        print(string.format("❌ No configuration found for %s", player.Name))
        return
    end
    
    print(string.format("🔍 Configuration for %s:", player.Name))
    for position, nodeData in pairs(config.SequenceConfiguration) do
        if nodeData then
            print(string.format("  Position %d: %s (%s)", position, nodeData.ComponentId, nodeData.Rarity or "COMMON"))
        else
            print(string.format("  Position %d: [empty]", position))
        end
    end
end

function SynergyEvaluationService.ForceEvaluatePlayer(player)
    local playerData = {
        PlayerId = player.UserId,
        Player = player,
        ConfigData = EvaluationState.PlayerConfigurations[player.UserId]
    }
    
    if not playerData.ConfigData then
        warn(string.format("No configuration found for %s", player.Name))
        return
    end
    
    print(string.format("🔧 Force evaluating %s...", player.Name))
    SynergyEvaluationService.ProcessPlayerConfiguration(playerData)
    
    local result = EvaluationState.CurrentResults[player.UserId]
    if result then
        print(string.format("✅ Result: %.0f damage (%d active components)", 
            result.TotalDamage, result.ActiveComponents))
    end
end

-- ========================================
-- INITIALIZATION
-- ========================================

-- Connect remote events
Remotes.SubmitAstralWebConfiguration.OnServerEvent:Connect(SynergyEvaluationService.OnSubmitConfiguration)

-- Connect player events
Players.PlayerRemoving:Connect(SynergyEvaluationService.OnPlayerRemoving)

print("📦 SynergyEvaluationService module loaded")

return SynergyEvaluationService