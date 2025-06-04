-- client/gui/TickTimerGui.client.lua
-- Main timer and evaluation display for SynRNG
-- Shows countdown, phase info, live evaluation progress, and hourly events

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = require(game.ReplicatedStorage.Shared.remotes)

-- ========================================
-- GUI CREATION
-- ========================================

-- Main ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TickTimerGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Main container frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainTimerFrame"
mainFrame.Size = UDim2.new(0, 400, 0, 170)
mainFrame.Position = UDim2.new(0.5, -200, 0, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
mainFrame.BackgroundTransparency = 0.4
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Add rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

-- Add gradient background
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 25))
})
gradient.Rotation = 45
gradient.Parent = mainFrame

-- Timer display
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, -20, 0, 60)
timerLabel.Position = UDim2.new(0, 10, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "60.0s"
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.SourceSansBold
timerLabel.Parent = mainFrame

-- Phase indicator
local phaseLabel = Instance.new("TextLabel")
phaseLabel.Name = "PhaseLabel"
phaseLabel.Size = UDim2.new(1, -20, 0, 30)
phaseLabel.Position = UDim2.new(0, 10, 0, 50)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Text = "BUILDING PHASE"
phaseLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
phaseLabel.TextScaled = true
phaseLabel.Font = Enum.Font.SourceSans
phaseLabel.Parent = mainFrame

-- Progress bar container
local progressContainer = Instance.new("Frame")
progressContainer.Name = "ProgressContainer"
progressContainer.Size = UDim2.new(1, -20, 0, 20)
progressContainer.Position = UDim2.new(0, 10, 0, 90)
progressContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
progressContainer.BorderSizePixel = 0
progressContainer.Parent = mainFrame

local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(0, 10)
progressCorner.Parent = progressContainer

-- Progress bar fill
local progressBar = Instance.new("Frame")
progressBar.Name = "ProgressBar"
progressBar.Size = UDim2.new(0, 0, 1, 0)
progressBar.Position = UDim2.new(0, 0, 0, 0)
progressBar.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
progressBar.BorderSizePixel = 0
progressBar.Parent = progressContainer

local progressBarCorner = Instance.new("UICorner")
progressBarCorner.CornerRadius = UDim.new(0, 10)
progressBarCorner.Parent = progressBar

-- Status text
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -20, 0, 25)
statusLabel.Position = UDim2.new(0, 10, 0, 115)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Configure your Astral Web"
statusLabel.TextSize = 20
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextScaled = false
statusLabel.Font = Enum.Font.SourceSans
statusLabel.Parent = mainFrame

-- Tick counter
local tickLabel = Instance.new("TextLabel")
tickLabel.Name = "TickLabel"
tickLabel.Size = UDim2.new(1, -20, 0, 20)
tickLabel.Position = UDim2.new(0, 10, 0, 140)
tickLabel.BackgroundTransparency = 1
tickLabel.Text = "Tick #1"
tickLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
tickLabel.TextScaled = true
tickLabel.Font = Enum.Font.SourceSans
tickLabel.Parent = mainFrame

-- ========================================
-- LIVE EVALUATION DISPLAY
-- ========================================

-- Evaluation overlay (shown during evaluation phase)
local evaluationOverlay = Instance.new("Frame")
evaluationOverlay.Name = "EvaluationOverlay"
evaluationOverlay.Size = UDim2.new(0, 350, 0, 180)
evaluationOverlay.Position = UDim2.new(0.5, 250, 0, 0)
evaluationOverlay.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
evaluationOverlay.BackgroundTransparency = 0.4
evaluationOverlay.BorderSizePixel = 0
evaluationOverlay.Visible = false
evaluationOverlay.Parent = screenGui

local evalCorner = Instance.new("UICorner")
evalCorner.CornerRadius = UDim.new(0, 12)
evalCorner.Parent = evaluationOverlay

-- Evaluation title
local evalTitle = Instance.new("TextLabel")
evalTitle.Name = "EvalTitle"
evalTitle.Size = UDim2.new(1, -20, 0, 30)
evalTitle.Position = UDim2.new(0, 10, 0, 10)
evalTitle.BackgroundTransparency = 1
evalTitle.Text = "EVALUATING..."
evalTitle.TextColor3 = Color3.fromRGB(255, 255, 100)
evalTitle.TextScaled = true
evalTitle.Font = Enum.Font.SourceSansBold
evalTitle.Parent = evaluationOverlay

-- Your damage display
local damageLabel = Instance.new("TextLabel")
damageLabel.Name = "DamageLabel"
damageLabel.Size = UDim2.new(1, -20, 0, 40)
damageLabel.Position = UDim2.new(0, 10, 0, 45)
damageLabel.BackgroundTransparency = 1
damageLabel.Text = "Your Damage: 0"
damageLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
damageLabel.TextScaled = true
damageLabel.Font = Enum.Font.SourceSansBold
damageLabel.Parent = evaluationOverlay

-- Active components display
local componentsLabel = Instance.new("TextLabel")
componentsLabel.Name = "ComponentsLabel"
componentsLabel.Size = UDim2.new(1, -20, 0, 25)
componentsLabel.Position = UDim2.new(0, 10, 0, 90)
componentsLabel.BackgroundTransparency = 1
componentsLabel.Text = "Active Components: 0/5"
componentsLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
componentsLabel.TextScaled = true
componentsLabel.Font = Enum.Font.SourceSans
componentsLabel.Parent = evaluationOverlay

-- Best component display
local bestComponentLabel = Instance.new("TextLabel")
bestComponentLabel.Name = "BestComponentLabel"
bestComponentLabel.Size = UDim2.new(1, -20, 0, 25)
bestComponentLabel.Position = UDim2.new(0, 10, 0, 120)
bestComponentLabel.BackgroundTransparency = 1
bestComponentLabel.Text = "Best: None"
bestComponentLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
bestComponentLabel.TextScaled = true
bestComponentLabel.Font = Enum.Font.SourceSans
bestComponentLabel.Parent = evaluationOverlay

-- Current rank display
local rankLabel = Instance.new("TextLabel")
rankLabel.Name = "RankLabel"
rankLabel.Size = UDim2.new(1, -20, 0, 25)
rankLabel.Position = UDim2.new(0, 10, 0, 150)
rankLabel.BackgroundTransparency = 1
rankLabel.Text = "Rank: --"
rankLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
rankLabel.TextScaled = true
rankLabel.Font = Enum.Font.SourceSans
rankLabel.Parent = evaluationOverlay

-- ========================================
-- HOURLY EVENT DISPLAY
-- ========================================

-- Hourly event warning
local hourlyWarning = Instance.new("Frame")
hourlyWarning.Name = "HourlyWarning"
hourlyWarning.Size = UDim2.new(0, 500, 0, 100)
hourlyWarning.Position = UDim2.new(0.5, -250, 0.3, -50)
hourlyWarning.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
hourlyWarning.BorderSizePixel = 0
hourlyWarning.Visible = false
hourlyWarning.Parent = screenGui

local hourlyCorner = Instance.new("UICorner")
hourlyCorner.CornerRadius = UDim.new(0, 15)
hourlyCorner.Parent = hourlyWarning

-- Hourly warning text
local hourlyText = Instance.new("TextLabel")
hourlyText.Name = "HourlyText"
hourlyText.Size = UDim2.new(1, -20, 1, -20)
hourlyText.Position = UDim2.new(0, 10, 0, 10)
hourlyText.BackgroundTransparency = 1
hourlyText.Text = "⚡ POWER SURGE IN 30s! ⚡"
hourlyText.TextColor3 = Color3.fromRGB(255, 255, 255)
hourlyText.TextScaled = true
hourlyText.Font = Enum.Font.SourceSansBold
hourlyText.Parent = hourlyWarning

-- ========================================
-- STATE MANAGEMENT
-- ========================================

local TimerGuiState = {
    currentPhase = "BUILDING",
    timeRemaining = 60,
    totalTickTime = 60,
    currentTick = 0,
    isHourlyEvent = false,
    hourlyEventWarning = false,
    
    -- Evaluation data
    evaluationInProgress = false,
    yourDamage = 0,
    activeComponents = 0,
    bestComponent = nil,
    currentRank = nil,
    
    -- Animation states
    pulseAnimation = nil,
    warningAnimation = nil
}

-- ========================================
-- PHASE COLORS AND STYLING
-- ========================================

local PHASE_COLORS = {
    BUILDING = {
        primary = Color3.fromRGB(100, 255, 100),
        secondary = Color3.fromRGB(50, 200, 50),
        background = Color3.fromRGB(30, 50, 30)
    },
    EVALUATING = {
        primary = Color3.fromRGB(255, 255, 100),
        secondary = Color3.fromRGB(200, 200, 50),
        background = Color3.fromRGB(50, 50, 30)
    },
    RESULTS = {
        primary = Color3.fromRGB(100, 150, 255),
        secondary = Color3.fromRGB(50, 100, 200),
        background = Color3.fromRGB(30, 30, 50)
    }
}

-- ========================================
-- MAIN UPDATE FUNCTIONS
-- ========================================

function UpdateTimerDisplay(timerData)
    TimerGuiState.timeRemaining = timerData.TimeRemaining or 0
    TimerGuiState.totalTickTime = timerData.TotalTickTime or 60
    TimerGuiState.currentTick = timerData.CurrentTick or 0
    TimerGuiState.currentPhase = timerData.Phase or "BUILDING"
    TimerGuiState.isHourlyEvent = timerData.IsHourlyEvent or false
    TimerGuiState.hourlyEventWarning = timerData.HourlyEventWarning or false
    
    -- Update timer display
    timerLabel.Text = string.format("%.1fs", math.max(0, TimerGuiState.timeRemaining))
    
    -- Update tick counter
    tickLabel.Text = string.format("Tick #%d", TimerGuiState.currentTick)
    
    -- Update phase display
    UpdatePhaseDisplay(timerData)
    
    -- Update progress bar
    UpdateProgressBar()
    
    -- Handle hourly events
    HandleHourlyEvents(timerData)
    
    -- Update status based on phase
    UpdateStatusText(timerData)
end

function UpdatePhaseDisplay(timerData)
    local phase = TimerGuiState.currentPhase
    local phaseColors = PHASE_COLORS[phase] or PHASE_COLORS.BUILDING
    
    -- Update phase label
    local phaseText = phase .. " PHASE"
    if TimerGuiState.isHourlyEvent then
        phaseText = "💥 " .. phaseText .. " (100x DAMAGE!) 💥"
        phaseLabel.TextColor3 = Color3.fromRGB(255, 100, 255)
    else
        phaseLabel.TextColor3 = phaseColors.primary
    end
    
    phaseLabel.Text = phaseText
    
    -- Animate phase transitions
    if TimerGuiState.currentPhase ~= TimerGuiState.lastPhase then
        AnimatePhaseTransition(phase)
        TimerGuiState.lastPhase = phase
    end
    
    -- Show/hide evaluation overlay
    if phase == "EVALUATING" then
        evaluationOverlay.Visible = true
        TimerGuiState.evaluationInProgress = true
    elseif phase == "RESULTS" then
        evaluationOverlay.Visible = true
        TimerGuiState.evaluationInProgress = false
    else
        evaluationOverlay.Visible = false
        TimerGuiState.evaluationInProgress = false
    end
end

function UpdateProgressBar()
    local progress = 0
    
    if TimerGuiState.currentPhase == "BUILDING" then
        progress = 1 - (TimerGuiState.timeRemaining / TimerGuiState.totalTickTime)
    elseif TimerGuiState.currentPhase == "EVALUATING" then
        -- Progress bar shows evaluation progress (will be updated by live evaluation events)
        progress = TimerGuiState.evaluationProgress or 0
    elseif TimerGuiState.currentPhase == "RESULTS" then
        progress = 1
    end
    
    -- Animate progress bar
    local targetSize = UDim2.new(math.max(0, math.min(1, progress)), 0, 1, 0)
    
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(progressBar, tweenInfo, {Size = targetSize})
    tween:Play()
    
    -- Update progress bar color based on phase
    local phaseColors = PHASE_COLORS[TimerGuiState.currentPhase] or PHASE_COLORS.BUILDING
    progressBar.BackgroundColor3 = phaseColors.primary
end

function UpdateStatusText(timerData)
    local statusText = ""
    
    if TimerGuiState.currentPhase == "BUILDING" then
        statusText = "Configure your Astral Web"
        if TimerGuiState.timeRemaining <= 10 then
            statusText = "⚠️ Finalize your configuration!"
        end
    elseif TimerGuiState.currentPhase == "EVALUATING" then
        statusText = "Processing all player webs..."
        if timerData.CurrentlyProcessing then
            statusText = timerData.CurrentlyProcessing
        end
    elseif TimerGuiState.currentPhase == "RESULTS" then
        statusText = "Damage dealt! Preparing next round..."
    end
    
    -- Add hourly event info
    if TimerGuiState.isHourlyEvent then
        statusText = statusText .. " 🌟 POWER SURGE ACTIVE!"
    end
    
    statusLabel.Text = statusText
end

-- ========================================
-- LIVE EVALUATION UPDATES
-- ========================================

function UpdateLiveEvaluation(evaluationData)
    if not evaluationData.YourResults then return end
    
    local results = evaluationData.YourResults
    
    -- Update damage display with animation
    if results.TotalDamage and results.TotalDamage ~= TimerGuiState.yourDamage then
        TimerGuiState.yourDamage = results.TotalDamage
        AnimateDamageUpdate(results.TotalDamage)
    end
    
    -- Update active components
    if results.ActiveComponents then
        TimerGuiState.activeComponents = results.ActiveComponents
        componentsLabel.Text = string.format("Active Components: %d/5", results.ActiveComponents)
    end
    
    -- Update best component
    if results.BestComponent then
        TimerGuiState.bestComponent = results.BestComponent
        bestComponentLabel.Text = string.format("Best: %s (%.0f dmg)", 
            results.BestComponent.ComponentName or results.BestComponent.ComponentId,
            results.BestComponent.Damage or 0)
    end
    
    -- Update rank
    if results.Rank then
        TimerGuiState.currentRank = results.Rank
        rankLabel.Text = string.format("Rank: #%d", results.Rank)
        
        -- Color based on rank
        if results.Rank <= 3 then
            rankLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold
        elseif results.Rank <= 10 then
            rankLabel.TextColor3 = Color3.fromRGB(192, 192, 192) -- Silver
        else
            rankLabel.TextColor3 = Color3.fromRGB(205, 127, 50) -- Bronze
        end
    end
    
    -- Update evaluation progress
    if evaluationData.Progress then
        TimerGuiState.evaluationProgress = evaluationData.Progress
        UpdateProgressBar()
    end
end

function AnimateDamageUpdate(newDamage)
    damageLabel.Text = string.format("Your Damage: %.0f", newDamage)
    
    -- Pulse animation for damage updates
    local originalSize = damageLabel.Size
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
    
    -- Scale up
    local scaleUpTween = TweenService:Create(damageLabel, tweenInfo, {
        Size = UDim2.new(originalSize.X.Scale * 1.1, originalSize.X.Offset, originalSize.Y.Scale * 1.1, originalSize.Y.Offset)
    })
    
    scaleUpTween:Play()
    
    -- Scale back down
    scaleUpTween.Completed:Connect(function()
        local scaleDownTween = TweenService:Create(damageLabel, tweenInfo, {Size = originalSize})
        scaleDownTween:Play()
    end)
end

-- ========================================
-- HOURLY EVENT HANDLING
-- ========================================

function HandleHourlyEvents(timerData)
    -- Show hourly warning
    if timerData.HourlyEventWarning and timerData.HourlyEventCountdown then
        ShowHourlyWarning(timerData.HourlyEventCountdown)
    elseif not timerData.HourlyEventWarning then
        HideHourlyWarning()
    end
    
    -- Handle active hourly event
    if timerData.IsHourlyEvent and not TimerGuiState.isHourlyEvent then
        StartHourlyEventEffects()
    elseif not timerData.IsHourlyEvent and TimerGuiState.isHourlyEvent then
        StopHourlyEventEffects()
    end
end

function ShowHourlyWarning(countdown)
    hourlyWarning.Visible = true
    hourlyText.Text = string.format("⚡ POWER SURGE IN %ds! ⚡", countdown)
    
    -- Pulsing animation
    if not TimerGuiState.warningAnimation then
        TimerGuiState.warningAnimation = true
        
        spawn(function()
            while hourlyWarning.Visible do
                local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                local brightTween = TweenService:Create(hourlyWarning, tweenInfo, {
                    BackgroundColor3 = Color3.fromRGB(255, 150, 0)
                })
                local dimTween = TweenService:Create(hourlyWarning, tweenInfo, {
                    BackgroundColor3 = Color3.fromRGB(255, 100, 0)
                })
                
                brightTween:Play()
                brightTween.Completed:Wait()
                dimTween:Play()
                dimTween.Completed:Wait()
            end
            TimerGuiState.warningAnimation = false
        end)
    end
end

function HideHourlyWarning()
    hourlyWarning.Visible = false
    TimerGuiState.warningAnimation = false
end

function StartHourlyEventEffects()
    -- Rainbow gradient effect on main frame
    spawn(function()
        while TimerGuiState.isHourlyEvent do
            local colors = {
                Color3.fromRGB(255, 0, 0),
                Color3.fromRGB(255, 127, 0),
                Color3.fromRGB(255, 255, 0),
                Color3.fromRGB(0, 255, 0),
                Color3.fromRGB(0, 0, 255),
                Color3.fromRGB(75, 0, 130),
                Color3.fromRGB(148, 0, 211)
            }
            
            for _, color in pairs(colors) do
                if not TimerGuiState.isHourlyEvent then break end
                
                local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine)
                local tween = TweenService:Create(gradient, tweenInfo, {
                    Color = ColorSequence.new(color, color)
                })
                tween:Play()
                tween.Completed:Wait()
            end
        end
        
        -- Reset to normal gradient
        local resetTween = TweenService:Create(gradient, TweenInfo.new(1, Enum.EasingStyle.Sine), {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 50)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 25))
            })
        })
        resetTween:Play()
    end)
end

function StopHourlyEventEffects()
    -- Effects will stop automatically when TimerGuiState.isHourlyEvent becomes false
end

-- ========================================
-- ANIMATION HELPERS
-- ========================================

function AnimatePhaseTransition(newPhase)
    local phaseColors = PHASE_COLORS[newPhase] or PHASE_COLORS.BUILDING
    
    -- Fade transition
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
    
    -- Update background gradient (CORRECT PROPERTY - Color, not ColorSequence)
    local newColorSequence = ColorSequence.new({
        ColorSequenceKeypoint.new(0, phaseColors.background),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(
            phaseColors.background.R * 255 * 0.5,
            phaseColors.background.G * 255 * 0.5,
            phaseColors.background.B * 255 * 0.5
        ))
    })
    gradient.Color = newColorSequence  -- FIXED: Use .Color property, not .ColorSequence
    -- Removed gradientTween:Play() - no longer needed since we set gradient.Color directly
    
    -- Pulse the phase label
    local originalSize = phaseLabel.Size
    local pulseTween = TweenService:Create(phaseLabel, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), {
        Size = UDim2.new(originalSize.X.Scale * 1.05, originalSize.X.Offset, originalSize.Y.Scale * 1.05, originalSize.Y.Offset)
    })
    
    pulseTween:Play()
    pulseTween.Completed:Connect(function()
        local returnTween = TweenService:Create(phaseLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size = originalSize
        })
        returnTween:Play()
    end)
end

-- ========================================
-- REMOTE EVENT HANDLERS
-- ========================================

function OnTimerUpdate(timerData)
    print("📱 Timer update received:", timerData.CurrentTick, timerData.TimeRemaining, timerData.Phase)
    UpdateTimerDisplay(timerData)
end

function OnLiveEvaluationUpdate(evaluationData)
    print("📊 Evaluation update received")
    UpdateLiveEvaluation(evaluationData)
end

function OnTickResults(resultsData)
    print("🏆 Tick results received")
    -- Handle final tick results
    if resultsData.Results and resultsData.Results.YourPerformance then
        local performance = resultsData.Results.YourPerformance
        
        -- Update final damage display
        TimerGuiState.yourDamage = performance.TotalDamage
        damageLabel.Text = string.format("Final Damage: %.0f", performance.TotalDamage)
        
        -- Show final rank
        if performance.Rank then
            rankLabel.Text = string.format("Final Rank: #%d", performance.Rank)
        end
        
        -- Show active components
        if performance.ActiveComponents then
            componentsLabel.Text = string.format("Active Components: %d/5", performance.ActiveComponents)
        end
    end
end

-- ========================================
-- INITIALIZATION
-- ========================================

-- Connect remote events
print("🔌 Connecting to timer remotes...")
print("UpdateAstralWebTimerEvent remote:", Remotes.UpdateAstralWebTimerEvent)
print("LiveEvaluationUpdateEvent remote:", Remotes.LiveEvaluationUpdateEvent)
print("TickResultsEvent remote:", Remotes.TickResultsEvent)

-- Connect with error handling
if Remotes.UpdateAstralWebTimerEvent then
    Remotes.UpdateAstralWebTimerEvent.OnClientEvent:Connect(OnTimerUpdate)
    print("✅ Connected to UpdateAstralWebTimerEvent")
else
    warn("❌ UpdateAstralWebTimerEvent not found")
end

if Remotes.LiveEvaluationUpdateEvent then
    Remotes.LiveEvaluationUpdateEvent.OnClientEvent:Connect(OnLiveEvaluationUpdate)
    print("✅ Connected to LiveEvaluationUpdateEvent")
else
    warn("❌ LiveEvaluationUpdateEvent not found")
end

if Remotes.TickResultsEvent then
    Remotes.TickResultsEvent.OnClientEvent:Connect(OnTickResults)
    print("✅ Connected to TickResultsEvent")
else
    warn("❌ TickResultsEvent not found")
end

print("✅ Timer remote connections attempted")

-- Initial setup
TimerGuiState.lastPhase = ""
UpdateProgressBar()

print("📱 TickTimerGui initialized")

-- ========================================
-- CLEANUP
-- ========================================

-- Handle player leaving
game.Players.PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == player then
        -- Cleanup any running animations or connections
        TimerGuiState.isHourlyEvent = false
        TimerGuiState.warningAnimation = false
    end
end)