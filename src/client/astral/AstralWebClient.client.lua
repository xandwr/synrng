-- client/astral/AstralWebClient.client.lua
-- Interactive node graph visualization for all synergy components
-- Handles sequence configuration, rolling/unlocking, and visual display

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local SynergyComponentsDB = require(game.ReplicatedStorage.Shared.data.SynergyComponentsDB)
local Remotes = require(game.ReplicatedStorage.Shared.remotes)

-- ========================================
-- CONFIGURATION
-- ========================================

local CONFIG = {
    -- Node Graph Layout
    NODE_SIZE = 80,
    NODE_SPACING = 200,
    GRAPH_RADIUS = 300,
    
    -- Visual Settings
    LOCKED_TRANSPARENCY = 0.7,
    UNLOCKED_TRANSPARENCY = 0.2,
    SELECTED_GLOW_SIZE = 1.2,
    CONNECTION_THICKNESS = 2,
    CONNECTION_TRANSPARENCY = 0.85,
    
    -- Animation Settings
    ROLL_SPEED_START = 0.05,    -- Starting delay between nodes
    ROLL_SPEED_END = 0.5,       -- Ending delay (slowing down)
    ROLL_DURATION = 5,          -- Total roll duration
    ROLL_MIN_HOPS = 20,         -- Minimum nodes to visit
    
    -- Sequence Configuration
    MAX_SEQUENCE_LENGTH = 5,
    SLOT_SIZE = 100,
    
    -- UI Layout
    SEQUENCE_PANEL_HEIGHT = 150,
    INFO_PANEL_WIDTH = 350,

    -- Zoom
    MIN_ZOOM = 0.5,
    MAX_ZOOM = 2.0,
    ZOOM_STEP = 0.1,
}

-- ========================================
-- STATE MANAGEMENT
-- ========================================

local AstralWebState = {
    -- Component Management
    AllComponents = {},         -- All components from DB
    UnlockedComponents = {},    -- Player's unlocked components (component IDs)
    
    -- Node Graph
    NodeFrames = {},           -- [componentId] = Frame
    NodePositions = {},        -- [componentId] = Vector2 position
    NodeConnections = {},      -- Visual connection lines
    GraphCenter = Vector2.new(0, 0),
    
    -- Sequence Builder
    CurrentSequence = {},      -- Array of {ComponentId, NodeData} (max 5)
    SequenceSlots = {},        -- UI slot frames
    DraggedComponent = nil,    -- Currently being dragged
    
    -- Rolling State
    IsRolling = false,
    RollTarget = nil,
    CurrentHighlight = nil,
    RollStartTime = 0,
    
    -- UI Elements
    MainFrame = nil,
    GraphCanvas = nil,
    SequencePanel = nil,
    InfoPanel = nil,
    RollButton = nil,

    GraphScale = nil,
    ZoomLevel = 1,
    
    -- Camera/Panning
    IsPanning = false,
    PanStartPos = nil,
    CanvasStartPos = nil,
}

-- ========================================
-- INITIALIZATION
-- ========================================

function InitializeAstralWeb()
    print("🌟 Initializing Astral Web Client...")
    
    -- Load all components from database
    LoadAllComponents()
    
    -- Create main UI
    CreateMainUI()
    
    -- Build node graph
    BuildNodeGraph()
    
    -- Create sequence builder
    CreateSequenceBuilder()
    
    -- Create info panel
    CreateInfoPanel()
    
    -- Connect events
    ConnectEvents()
    
    -- Setup panning
    SetupPanning()
    
    -- TODO: Load player's unlocked components from server
    -- For now, unlock a few starter components for testing
    UnlockStarterComponents()
    
    print("✅ Astral Web initialized")
end

function LoadAllComponents()
    AstralWebState.AllComponents = {}
    
    for componentId, component in pairs(SynergyComponentsDB.Components) do
        table.insert(AstralWebState.AllComponents, {
            Id = componentId,
            Component = component
        })
    end
    
    -- Sort by type and rarity for better layout
    table.sort(AstralWebState.AllComponents, function(a, b)
        if a.Component.Type ~= b.Component.Type then
            return a.Component.Type < b.Component.Type
        end
        return a.Component.Rarity < b.Component.Rarity
    end)
    
    print(string.format("📦 Loaded %d components", #AstralWebState.AllComponents))
end

function UnlockStarterComponents()
    -- Temporary: Unlock some starter components for testing
    AstralWebState.UnlockedComponents = {
        ["ember_core"] = true,
        ["frost_core"] = true,
        ["amplifier"] = true,
        ["power_conduit"] = true,
    }
    
    -- Update visuals
    UpdateNodeVisuals()
end

-- ========================================
-- UI CREATION
-- ========================================

function CreateMainUI()
    -- Main ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AstralWebUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main container frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "AstralWebMain"
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.Position = UDim2.new(0, 0, 0, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Graph viewport (not scrollable - we'll pan manually)
    local graphViewport = Instance.new("Frame")
    graphViewport.Name = "GraphViewport"
    graphViewport.Size = UDim2.new(1, -CONFIG.INFO_PANEL_WIDTH, 1, -CONFIG.SEQUENCE_PANEL_HEIGHT)
    graphViewport.Position = UDim2.new(0, 0, 0, 0)
    graphViewport.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
    graphViewport.BorderSizePixel = 0
    graphViewport.ClipsDescendants = true
    graphViewport.Parent = mainFrame
    
    -- Graph canvas (moveable container inside viewport)
    local graphCanvas = Instance.new("Frame")
    graphCanvas.Name = "GraphCanvas"
    graphCanvas.Size = UDim2.new(0, CONFIG.GRAPH_RADIUS * 6, 0, CONFIG.GRAPH_RADIUS * 6)
    graphCanvas.Position = UDim2.new(0.5, -CONFIG.GRAPH_RADIUS * 3, 0.5, -CONFIG.GRAPH_RADIUS * 3)
    graphCanvas.BackgroundTransparency = 1
    graphCanvas.Parent = graphViewport

    local graphScale = Instance.new("UIScale")
    graphScale.Name = "GraphScale"
    graphScale.Parent = graphCanvas
    
    -- Add starfield background to viewport
    CreateStarfieldBackground(graphViewport)
    
    -- Connections layer (behind nodes)
    local connectionsLayer = Instance.new("Frame")
    connectionsLayer.Name = "ConnectionsLayer"
    connectionsLayer.Size = UDim2.new(1, 0, 1, 0)
    connectionsLayer.BackgroundTransparency = 1
    connectionsLayer.Parent = graphCanvas
    
    -- Nodes layer
    local nodesLayer = Instance.new("Frame")
    nodesLayer.Name = "NodesLayer"
    nodesLayer.Size = UDim2.new(1, 0, 1, 0)
    nodesLayer.BackgroundTransparency = 1
    nodesLayer.ZIndex = 2
    nodesLayer.Parent = graphCanvas
    
    -- Store references
    AstralWebState.MainFrame = mainFrame
    AstralWebState.GraphViewport = graphViewport
    AstralWebState.GraphCanvas = graphCanvas
    AstralWebState.GraphScale = graphScale
    AstralWebState.ConnectionsLayer = connectionsLayer
    AstralWebState.NodesLayer = nodesLayer
    AstralWebState.GraphCenter = Vector2.new(CONFIG.GRAPH_RADIUS * 3, CONFIG.GRAPH_RADIUS * 3)
end

function CreateStarfieldBackground(parent)
    -- Create animated starfield effect
    for i = 1, 50 do
        local star = Instance.new("Frame")
        star.Name = "Star" .. i
        star.Size = UDim2.new(0, math.random(1, 3), 0, math.random(1, 3))
        star.Position = UDim2.new(math.random(), 0, math.random(), 0)
        star.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        star.BackgroundTransparency = math.random() * 0.5 + 0.5
        star.BorderSizePixel = 0
        star.Parent = parent
        
        -- Twinkling animation
        spawn(function()
            while star.Parent do
                local tweenInfo = TweenInfo.new(
                    math.random() * 2 + 1,
                    Enum.EasingStyle.Sine,
                    Enum.EasingDirection.InOut
                )
                local tween = TweenService:Create(star, tweenInfo, {
                    BackgroundTransparency = math.random() * 0.5 + 0.5
                })
                tween:Play()
                tween.Completed:Wait()
            end
        end)
    end
end

-- ========================================
-- NODE GRAPH BUILDING
-- ========================================

function BuildNodeGraph()
    print("🔨 Building node graph...")
    
    local nodeCount = #AstralWebState.AllComponents
    local nodesPerType = {}
    
    -- Group components by type
    for _, componentData in pairs(AstralWebState.AllComponents) do
        local componentType = componentData.Component.Type
        if not nodesPerType[componentType] then
            nodesPerType[componentType] = {}
        end
        table.insert(nodesPerType[componentType], componentData)
    end
    
    -- Layout nodes in concentric circles by type
    local typeOrder = {
        SynergyComponentsDB.ComponentTypes.CORE,
        SynergyComponentsDB.ComponentTypes.MODIFIER,
        SynergyComponentsDB.ComponentTypes.CHAIN,
        SynergyComponentsDB.ComponentTypes.ARTIFACT
    }
    
    local currentRadius = CONFIG.GRAPH_RADIUS * 0.8
    
    for typeIndex, componentType in pairs(typeOrder) do
        local componentsOfType = nodesPerType[componentType] or {}
        local count = #componentsOfType
        
        if count > 0 then
            -- Place nodes in a circle with some randomization
            for i, componentData in pairs(componentsOfType) do
                local angle = (i - 1) * (2 * math.pi / count) + (typeIndex * 0.3)
                local radiusVariation = (math.random() - 0.5) * 50
                local r = currentRadius + radiusVariation
                
                local x = AstralWebState.GraphCenter.X + math.cos(angle) * r
                local y = AstralWebState.GraphCenter.Y + math.sin(angle) * r
                
                local position = Vector2.new(x, y)
                AstralWebState.NodePositions[componentData.Id] = position
                CreateNodeFrame(componentData, position)
            end
            
            currentRadius = currentRadius + CONFIG.NODE_SPACING
        end
    end
    
    -- Connections temporarily disabled
end

function CreateNodeFrame(componentData, position)
    local componentId = componentData.Id
    local component = componentData.Component
    
    -- Main node frame
    local nodeFrame = Instance.new("Frame")
    nodeFrame.Name = componentId
    nodeFrame.Size = UDim2.new(0, CONFIG.NODE_SIZE, 0, CONFIG.NODE_SIZE)
    nodeFrame.Position = UDim2.new(0, position.X - CONFIG.NODE_SIZE/2, 0, position.Y - CONFIG.NODE_SIZE/2)
    nodeFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    nodeFrame.BorderSizePixel = 0
    nodeFrame.Parent = AstralWebState.NodesLayer
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = nodeFrame
    
    -- Border gradient based on rarity
    local rarityData = SynergyComponentsDB.Rarities[component.Rarity]
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.Color = rarityData.Color
    stroke.Transparency = 0.3
    stroke.Parent = nodeFrame
    
    -- Inner content frame
    local innerFrame = Instance.new("Frame")
    innerFrame.Size = UDim2.new(1, -4, 1, -4)
    innerFrame.Position = UDim2.new(0, 2, 0, 2)
    innerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    innerFrame.BorderSizePixel = 0
    innerFrame.Parent = nodeFrame
    
    local innerCorner = Instance.new("UICorner")
    innerCorner.CornerRadius = UDim.new(0, 10)
    innerCorner.Parent = innerFrame
    
    -- Component icon/symbol
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(0.8, 0, 0.5, 0)
    iconLabel.Position = UDim2.new(0.1, 0, 0.1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = GetComponentIcon(component)
    iconLabel.TextColor3 = rarityData.Color
    iconLabel.TextScaled = true
    iconLabel.Font = Enum.Font.SourceSansBold
    iconLabel.Parent = innerFrame
    
    -- Component name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ComponentName"
    nameLabel.Size = UDim2.new(1, -10, 0.3, 0)
    nameLabel.Position = UDim2.new(0, 5, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = component.Name
    nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.SourceSans
    nameLabel.Parent = innerFrame
    
    -- Lock overlay (shown when component is locked)
    local lockOverlay = Instance.new("Frame")
    lockOverlay.Name = "LockOverlay"
    lockOverlay.Size = UDim2.new(1, 0, 1, 0)
    lockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    lockOverlay.BackgroundTransparency = CONFIG.LOCKED_TRANSPARENCY
    lockOverlay.BorderSizePixel = 0
    lockOverlay.ZIndex = 3
    lockOverlay.Visible = true -- Start locked
    lockOverlay.Parent = nodeFrame
    
    local lockCorner = Instance.new("UICorner")
    lockCorner.CornerRadius = UDim.new(0, 12)
    lockCorner.Parent = lockOverlay
    
    -- Lock icon
    local lockIcon = Instance.new("TextLabel")
    lockIcon.Size = UDim2.new(0.4, 0, 0.4, 0)
    lockIcon.Position = UDim2.new(0.3, 0, 0.3, 0)
    lockIcon.BackgroundTransparency = 1
    lockIcon.Text = "🔒"
    lockIcon.TextColor3 = Color3.fromRGB(150, 150, 150)
    lockIcon.TextScaled = true
    lockIcon.Font = Enum.Font.SourceSansBold
    lockIcon.ZIndex = 4
    lockIcon.Parent = lockOverlay
    
    -- Selection highlight (hidden by default)
    local highlight = Instance.new("Frame")
    highlight.Name = "Highlight"
    highlight.Size = UDim2.new(1.2, 0, 1.2, 0)
    highlight.Position = UDim2.new(-0.1, 0, -0.1, 0)
    highlight.BackgroundColor3 = rarityData.Color
    highlight.BackgroundTransparency = 0.8
    highlight.BorderSizePixel = 0
    highlight.ZIndex = 0
    highlight.Visible = false
    highlight.Parent = nodeFrame
    
    local highlightCorner = Instance.new("UICorner")
    highlightCorner.CornerRadius = UDim.new(0, 15)
    highlightCorner.Parent = highlight
    
    -- Hover effects
    nodeFrame.MouseEnter:Connect(function()
        if not AstralWebState.IsRolling and not AstralWebState.IsPanning then
            ShowComponentInfo(componentData)
            TweenService:Create(nodeFrame, TweenInfo.new(0.2), {
                Size = UDim2.new(0, CONFIG.NODE_SIZE * 1.1, 0, CONFIG.NODE_SIZE * 1.1),
                Position = UDim2.new(0, position.X - CONFIG.NODE_SIZE * 1.1/2, 0, position.Y - CONFIG.NODE_SIZE * 1.1/2)
            }):Play()
        end
    end)
    
    nodeFrame.MouseLeave:Connect(function()
        if not AstralWebState.IsRolling then
            HideComponentInfo()
            TweenService:Create(nodeFrame, TweenInfo.new(0.2), {
                Size = UDim2.new(0, CONFIG.NODE_SIZE, 0, CONFIG.NODE_SIZE),
                Position = UDim2.new(0, position.X - CONFIG.NODE_SIZE/2, 0, position.Y - CONFIG.NODE_SIZE/2)
            }):Play()
        end
    end)
    
    -- Click to select (if unlocked)
    nodeFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and not AstralWebState.IsRolling and not AstralWebState.IsPanning then
            OnNodeClicked(componentData, nodeFrame)
        end
    end)
    
    -- Store reference
    AstralWebState.NodeFrames[componentId] = nodeFrame
end

function GetComponentIcon(component)
    -- Return appropriate icon based on component type and tags
    local icons = {
        [SynergyComponentsDB.ComponentTypes.CORE] = "⚡",
        [SynergyComponentsDB.ComponentTypes.MODIFIER] = "✨",
        [SynergyComponentsDB.ComponentTypes.CHAIN] = "🔗",
        [SynergyComponentsDB.ComponentTypes.ARTIFACT] = "💎"
    }
    
    -- Override for specific tags
    if table.find(component.Tags, "Fire") then return "🔥" end
    if table.find(component.Tags, "Ice") then return "❄️" end
    if table.find(component.Tags, "Lightning") then return "⚡" end
    if table.find(component.Tags, "Void") then return "🌑" end
    if table.find(component.Tags, "Chaos") then return "🌀" end
    
    return icons[component.Type] or "◆"
end

function CreateNodeConnections()
    -- Only create connections between nodes that have strong synergies
    -- Limit connections to reduce visual clutter
    
    for componentId1, nodeFrame1 in pairs(AstralWebState.NodeFrames) do
        local component1 = SynergyComponentsDB.GetComponent(componentId1)
        local connectionsFromNode = 0
        
        for componentId2, nodeFrame2 in pairs(AstralWebState.NodeFrames) do
            if componentId1 ~= componentId2 and connectionsFromNode < 3 then -- Limit connections per node
                local component2 = SynergyComponentsDB.GetComponent(componentId2)
                
                -- Check for multiple shared tags (stronger synergy)
                local sharedTags = 0
                for _, tag1 in pairs(component1.Tags) do
                    if table.find(component2.Tags, tag1) then
                        sharedTags = sharedTags + 1
                    end
                end
                
                -- Only create connection if 2+ shared tags
                if sharedTags >= 2 and not ConnectionExists(componentId1, componentId2) then
                    CreateConnectionLine(componentId1, componentId2, CONFIG.CONNECTION_TRANSPARENCY)
                    connectionsFromNode = connectionsFromNode + 1
                end
            end
        end
    end
end

function ConnectionExists(id1, id2)
    -- Check if connection already exists (prevent duplicates)
    local key1 = id1 .. "-" .. id2
    local key2 = id2 .. "-" .. id1
    return AstralWebState.NodeConnections[key1] or AstralWebState.NodeConnections[key2]
end

function CreateConnectionLine(nodeId1, nodeId2, transparency)
    local nodeFrame1 = AstralWebState.NodeFrames[nodeId1]
    local nodeFrame2 = AstralWebState.NodeFrames[nodeId2]

    if not nodeFrame1 or not nodeFrame2 then return end

    local canvasAbs = AstralWebState.GraphCanvas.AbsolutePosition

    local center1 = nodeFrame1.AbsolutePosition + (nodeFrame1.AbsoluteSize / 2)
    local center2 = nodeFrame2.AbsolutePosition + (nodeFrame2.AbsoluteSize / 2)

    local x1 = center1.X - canvasAbs.X
    local y1 = center1.Y - canvasAbs.Y
    local x2 = center2.X - canvasAbs.X
    local y2 = center2.Y - canvasAbs.Y
    
    local distance = math.sqrt((x2-x1)^2 + (y2-y1)^2)
    local angle = math.atan2(y2-y1, x2-x1)
    
    local line = Instance.new("Frame")
    line.Name = "Connection"
    line.Size = UDim2.new(0, distance, 0, CONFIG.CONNECTION_THICKNESS)
    line.Position = UDim2.new(0, x1, 0, y1)
    line.AnchorPoint = Vector2.new(0, 0.5)
    line.BackgroundColor3 = Color3.fromRGB(100, 100, 150)
    line.BackgroundTransparency = transparency or 0.5
    line.BorderSizePixel = 0
    line.Rotation = math.deg(angle)
    line.Parent = AstralWebState.ConnectionsLayer
    
    -- Store connection
    local key = nodeId1 .. "-" .. nodeId2
    AstralWebState.NodeConnections[key] = line
end

-- ========================================
-- SEQUENCE BUILDER UI
-- ========================================

function CreateSequenceBuilder()
    -- Bottom panel for sequence configuration
    local sequencePanel = Instance.new("Frame")
    sequencePanel.Name = "SequencePanel"
    sequencePanel.Size = UDim2.new(1, -CONFIG.INFO_PANEL_WIDTH, 0, CONFIG.SEQUENCE_PANEL_HEIGHT)
    sequencePanel.Position = UDim2.new(0, 0, 1, -CONFIG.SEQUENCE_PANEL_HEIGHT)
    sequencePanel.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    sequencePanel.BorderSizePixel = 0
    sequencePanel.Parent = AstralWebState.MainFrame
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.3, 0, 0, 30)
    titleLabel.Position = UDim2.new(0, 20, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "ASTRAL WEB SEQUENCE"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Parent = sequencePanel
    
    -- Sequence slots container
    local slotsContainer = Instance.new("Frame")
    slotsContainer.Name = "SlotsContainer"
    slotsContainer.Size = UDim2.new(0.6, 0, 1, -50)
    slotsContainer.Position = UDim2.new(0.2, 0, 0, 40)
    slotsContainer.BackgroundTransparency = 1
    slotsContainer.Parent = sequencePanel
    
    -- Create 5 sequence slots
    local slotSpacing = 20
    local totalSlotsWidth = CONFIG.SLOT_SIZE * CONFIG.MAX_SEQUENCE_LENGTH + slotSpacing * (CONFIG.MAX_SEQUENCE_LENGTH - 1)
    local startX = (slotsContainer.AbsoluteSize.X - totalSlotsWidth) / 2
    
    for i = 1, CONFIG.MAX_SEQUENCE_LENGTH do
        local slot = CreateSequenceSlot(i, slotsContainer, startX + (i-1) * (CONFIG.SLOT_SIZE + slotSpacing))
        AstralWebState.SequenceSlots[i] = slot
    end

    AstralWebState.SequencePanel = sequencePanel
end

function CreateSequenceSlot(index, parent, xPosition)
    local slot = Instance.new("Frame")
    slot.Name = "Slot" .. index
    slot.Size = UDim2.new(0, CONFIG.SLOT_SIZE, 0, CONFIG.SLOT_SIZE)
    slot.Position = UDim2.new(0, xPosition or (index-1) * 120, 0.5, -CONFIG.SLOT_SIZE/2)
    slot.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    slot.BorderColor3 = Color3.fromRGB(100, 100, 150)
    slot.BorderSizePixel = 2
    slot.Parent = parent
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = slot
    
    -- Position number
    local positionLabel = Instance.new("TextLabel")
    positionLabel.Name = "Position"
    positionLabel.Size = UDim2.new(0, 20, 0, 20)
    positionLabel.Position = UDim2.new(0, 5, 0, 5)
    positionLabel.BackgroundTransparency = 1
    positionLabel.Text = tostring(index)
    positionLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    positionLabel.TextScaled = true
    positionLabel.Font = Enum.Font.SourceSansBold
    positionLabel.Parent = slot
    
    -- Component display (hidden by default)
    local componentDisplay = Instance.new("Frame")
    componentDisplay.Name = "ComponentDisplay"
    componentDisplay.Size = UDim2.new(0.8, 0, 0.8, 0)
    componentDisplay.Position = UDim2.new(0.1, 0, 0.1, 0)
    componentDisplay.BackgroundTransparency = 1
    componentDisplay.Visible = false
    componentDisplay.Parent = slot
    
    -- Drop target detection
    slot.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            OnSlotClicked(index, slot)
        end
    end)
    
    return slot
end

-- ========================================
-- INFO PANEL
-- ========================================

function CreateInfoPanel()
    local infoPanel = Instance.new("Frame")
    infoPanel.Name = "InfoPanel"
    infoPanel.Size = UDim2.new(0, CONFIG.INFO_PANEL_WIDTH, 1, 0)
    infoPanel.Position = UDim2.new(1, -CONFIG.INFO_PANEL_WIDTH, 0, 0)
    infoPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
    infoPanel.BorderSizePixel = 0
    infoPanel.Parent = AstralWebState.MainFrame
    
    -- Component info display
    local componentInfo = Instance.new("ScrollingFrame")
    componentInfo.Name = "ComponentInfo"
    componentInfo.Size = UDim2.new(1, -20, 0.5, -20)
    componentInfo.Position = UDim2.new(0, 10, 0, 10)
    componentInfo.BackgroundTransparency = 1
    componentInfo.ScrollBarThickness = 6
    componentInfo.CanvasSize = UDim2.new(0, 0, 0, 0)
    componentInfo.Visible = false
    componentInfo.Parent = infoPanel
    
    -- Roll button
    local rollButton = Instance.new("TextButton")
    rollButton.Name = "RollButton"
    rollButton.Size = UDim2.new(0.8, 0, 0, 60)
    rollButton.Position = UDim2.new(0.1, 0, 0.7, 0)
    rollButton.BackgroundColor3 = Color3.fromRGB(255, 100, 50)
    rollButton.Text = "ROLL NEW COMPONENT"
    rollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    rollButton.TextScaled = true
    rollButton.Font = Enum.Font.SourceSansBold
    rollButton.Parent = infoPanel
    
    local rollCorner = Instance.new("UICorner")
    rollCorner.CornerRadius = UDim.new(0, 10)
    rollCorner.Parent = rollButton
    
    rollButton.MouseButton1Click:Connect(StartRoll)
    
    -- Currency display
    local currencyLabel = Instance.new("TextLabel")
    currencyLabel.Name = "Currency"
    currencyLabel.Size = UDim2.new(0.8, 0, 0, 40)
    currencyLabel.Position = UDim2.new(0.1, 0, 0.85, 0)
    currencyLabel.BackgroundTransparency = 1
    currencyLabel.Text = "💎 0 Essence"
    currencyLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    currencyLabel.TextScaled = true
    currencyLabel.Font = Enum.Font.SourceSans
    currencyLabel.Parent = infoPanel
    
    AstralWebState.InfoPanel = infoPanel
    AstralWebState.RollButton = rollButton
    AstralWebState.ComponentInfoFrame = componentInfo
end

-- ========================================
-- COMPONENT INFO DISPLAY
-- ========================================

function ShowComponentInfo(componentData)
    if not AstralWebState.ComponentInfoFrame then
        return
    end
    
    local infoFrame = AstralWebState.ComponentInfoFrame
    infoFrame.Visible = true
    
    -- Clear previous info
    for _, child in pairs(infoFrame:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    
    -- Add list layout
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = infoFrame
    
    local component = componentData.Component
    local rarityData = SynergyComponentsDB.Rarities[component.Rarity]
    
    -- Component name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 30)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = component.Name
    nameLabel.TextColor3 = rarityData.Color
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.Parent = infoFrame
    
    -- Type and rarity
    local typeLabel = Instance.new("TextLabel")
    typeLabel.Size = UDim2.new(1, 0, 0, 20)
    typeLabel.BackgroundTransparency = 1
    typeLabel.Text = string.format("%s • %s", rarityData.Name, component.Type)
    typeLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    typeLabel.TextScaled = true
    typeLabel.Font = Enum.Font.SourceSans
    typeLabel.Parent = infoFrame
    
    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, 0, 0, 60)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = component.Description
    descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    descLabel.TextWrapped = true
    descLabel.TextScaled = false
    descLabel.TextSize = 14
    descLabel.Font = Enum.Font.SourceSans
    descLabel.Parent = infoFrame
    
    -- Tags
    local tagsLabel = Instance.new("TextLabel")
    tagsLabel.Size = UDim2.new(1, 0, 0, 20)
    tagsLabel.BackgroundTransparency = 1
    tagsLabel.Text = "Tags: " .. table.concat(component.Tags, ", ")
    tagsLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    tagsLabel.TextWrapped = true
    tagsLabel.TextScaled = false
    tagsLabel.TextSize = 14
    tagsLabel.Font = Enum.Font.SourceSans
    tagsLabel.Parent = infoFrame
    
    -- Stats
    local contentHeight = 130
    for statName, statValue in pairs(component.BaseStats) do
        local statLabel = Instance.new("TextLabel")
        statLabel.Size = UDim2.new(1, 0, 0, 20)
        statLabel.BackgroundTransparency = 1
        statLabel.Text = string.format("%s: %s", statName, tostring(statValue))
        statLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        statLabel.TextScaled = false
        statLabel.TextSize = 14
        statLabel.Font = Enum.Font.SourceSans
        statLabel.Parent = infoFrame
        
        contentHeight = contentHeight + 25
    end
    
    -- Locked/Unlocked status
    local isUnlocked = AstralWebState.UnlockedComponents[componentData.Id]
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 30)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = isUnlocked and "✅ UNLOCKED" or "🔒 LOCKED"
    statusLabel.TextColor3 = isUnlocked and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.SourceSansBold
    statusLabel.Parent = infoFrame
    
    -- Update canvas size
    infoFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 50)
end

function HideComponentInfo()
    if AstralWebState.ComponentInfoFrame then
        AstralWebState.ComponentInfoFrame.Visible = false
    end
end

-- ========================================
-- PANNING FUNCTIONALITY
-- ========================================

function SetupPanning()
    local viewport = AstralWebState.GraphViewport
    local canvas = AstralWebState.GraphCanvas
    local scale = AstralWebState.GraphScale

    viewport.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 or
           (input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)) then
            AstralWebState.IsPanning = true
            AstralWebState.PanStartPos = input.Position
            AstralWebState.CanvasStartPos = canvas.Position
        end
    end)

    viewport.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton1 then
            AstralWebState.IsPanning = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if AstralWebState.IsPanning and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - AstralWebState.PanStartPos
            canvas.Position = UDim2.new(
                AstralWebState.CanvasStartPos.X.Scale,
                AstralWebState.CanvasStartPos.X.Offset + delta.X,
                AstralWebState.CanvasStartPos.Y.Scale,
                AstralWebState.CanvasStartPos.Y.Offset + delta.Y
            )
        elseif input.UserInputType == Enum.UserInputType.MouseWheel then
            local zoomDelta = math.sign(input.Position.Z)
            local newZoom = math.clamp(AstralWebState.ZoomLevel + zoomDelta * CONFIG.ZOOM_STEP,
                CONFIG.MIN_ZOOM, CONFIG.MAX_ZOOM)
            if newZoom ~= AstralWebState.ZoomLevel then
                AstralWebState.ZoomLevel = newZoom
                scale.Scale = newZoom
            end
        end
    end)

    -- Prevent default camera actions while web is open
    ContextActionService:BindAction(
        "AWBlockCamera",
        function() return Enum.ContextActionResult.Sink end,
        false,
        Enum.UserInputType.MouseButton2,
        Enum.UserInputType.MouseWheel
    )
end

-- ========================================
-- NODE INTERACTION
-- ========================================

function OnNodeClicked(componentData, nodeFrame)
    local componentId = componentData.Id
    local isUnlocked = AstralWebState.UnlockedComponents[componentId]
    
    if not isUnlocked then
        -- Show locked message
        ShowNotification("Component is locked! Roll to unlock new components.", Color3.fromRGB(255, 100, 100))
        return
    end
    
    -- Check if component is already in sequence
    local existingIndex = nil
    for i, seqData in pairs(AstralWebState.CurrentSequence) do
        if seqData and seqData.ComponentId == componentId then
            existingIndex = i
            break
        end
    end
    
    if existingIndex then
        -- Remove from sequence
        RemoveFromSequence(existingIndex)
    else
        -- Add to sequence (find first empty slot)
        AddToSequence(componentData)
    end
end

function AddToSequence(componentData)
    -- Find first empty slot
    local emptySlot = nil
    for i = 1, CONFIG.MAX_SEQUENCE_LENGTH do
        if not AstralWebState.CurrentSequence[i] then
            emptySlot = i
            break
        end
    end
    
    if not emptySlot then
        ShowNotification("Sequence is full! Remove a component first.", Color3.fromRGB(255, 150, 50))
        return
    end
    
    -- Add to sequence
    AstralWebState.CurrentSequence[emptySlot] = {
        ComponentId = componentData.Id,
        Component = componentData.Component,
        Position = emptySlot
    }
    
    -- Update slot visual
    UpdateSequenceSlot(emptySlot)
    
    -- Highlight node
    local nodeFrame = AstralWebState.NodeFrames[componentData.Id]
    if nodeFrame then
        local highlight = nodeFrame:FindFirstChild("Highlight")
        if highlight then
            highlight.Visible = true
        end
    end
    
    ShowNotification(string.format("Added %s to position %d", componentData.Component.Name, emptySlot), Color3.fromRGB(100, 255, 100))

    SubmitSequence()
end

function RemoveFromSequence(index)
    local seqData = AstralWebState.CurrentSequence[index]
    if not seqData then return end
    
    -- Remove from sequence
    AstralWebState.CurrentSequence[index] = nil
    
    -- Update slot visual
    UpdateSequenceSlot(index)
    
    -- Remove highlight
    local nodeFrame = AstralWebState.NodeFrames[seqData.ComponentId]
    if nodeFrame then
        local highlight = nodeFrame:FindFirstChild("Highlight")
        if highlight then
            highlight.Visible = false
        end
    end
    
    ShowNotification(string.format("Removed %s from sequence", seqData.Component.Name), Color3.fromRGB(255, 150, 50))

    SubmitSequence()
end

function OnSlotClicked(index, slot)
    -- If slot has component, remove it
    if AstralWebState.CurrentSequence[index] then
        RemoveFromSequence(index)
    end
end

function UpdateSequenceSlot(index)
    local slot = AstralWebState.SequenceSlots[index]
    if not slot then return end
    
    local componentDisplay = slot:FindFirstChild("ComponentDisplay")
    if not componentDisplay then return end
    
    -- Clear previous display
    for _, child in pairs(componentDisplay:GetChildren()) do
        child:Destroy()
    end
    
    local seqData = AstralWebState.CurrentSequence[index]
    
    if seqData then
        componentDisplay.Visible = true
        
        local component = seqData.Component
        local rarityData = SynergyComponentsDB.Rarities[component.Rarity]
        
        -- Icon
        local iconLabel = Instance.new("TextLabel")
        iconLabel.Size = UDim2.new(1, 0, 0.6, 0)
        iconLabel.Position = UDim2.new(0, 0, 0, 0)
        iconLabel.BackgroundTransparency = 1
        iconLabel.Text = GetComponentIcon(component)
        iconLabel.TextColor3 = rarityData.Color
        iconLabel.TextScaled = true
        iconLabel.Font = Enum.Font.SourceSansBold
        iconLabel.Parent = componentDisplay
        
        -- Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
        nameLabel.Position = UDim2.new(0, 0, 0.6, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = component.Name
        nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.SourceSans
        nameLabel.Parent = componentDisplay
    else
        componentDisplay.Visible = false
    end
end

-- ========================================
-- ROLLING SYSTEM
-- ========================================

function StartRoll()
    if AstralWebState.IsRolling then
        return
    end
    
    -- TODO: Check if player has currency to roll
    
    AstralWebState.IsRolling = true
    AstralWebState.RollStartTime = tick()
    AstralWebState.RollButton.Text = "ROLLING..."
    AstralWebState.RollButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    
    -- Get all locked components
    local lockedComponents = {}
    for _, componentData in pairs(AstralWebState.AllComponents) do
        if not AstralWebState.UnlockedComponents[componentData.Id] then
            table.insert(lockedComponents, componentData)
        end
    end
    
    if #lockedComponents == 0 then
        ShowNotification("All components unlocked!", Color3.fromRGB(255, 200, 50))
        EndRoll()
        return
    end
    
    -- Select random target
    AstralWebState.RollTarget = lockedComponents[math.random(1, #lockedComponents)]
    
    -- Start roll animation
    spawn(function()
        AnimateRoll()
    end)
end

function AnimateRoll()
    local startTime = AstralWebState.RollStartTime
    local duration = CONFIG.ROLL_DURATION
    local minHops = CONFIG.ROLL_MIN_HOPS
    
    local hopCount = 0
    local lastHighlightedNode = nil
    
    while AstralWebState.IsRolling do
        local elapsed = tick() - startTime
        local progress = math.min(elapsed / duration, 1)
        
        -- Calculate current speed (slowing down)
        local currentDelay = CONFIG.ROLL_SPEED_START + (CONFIG.ROLL_SPEED_END - CONFIG.ROLL_SPEED_START) * progress
        
        -- Pick random node to highlight
        local randomNode = nil
        if progress < 0.8 or hopCount < minHops then
            -- Still rolling fast - pick any node
            local allNodes = {}
            for id, frame in pairs(AstralWebState.NodeFrames) do
                table.insert(allNodes, {Id = id, Frame = frame})
            end
            randomNode = allNodes[math.random(1, #allNodes)]
        else
            -- Slowing down - bias towards target
            if math.random() < progress then
                randomNode = {
                    Id = AstralWebState.RollTarget.Id,
                    Frame = AstralWebState.NodeFrames[AstralWebState.RollTarget.Id]
                }
            else
                -- Still pick random occasionally
                local allNodes = {}
                for id, frame in pairs(AstralWebState.NodeFrames) do
                    table.insert(allNodes, {Id = id, Frame = frame})
                end
                randomNode = allNodes[math.random(1, #allNodes)]
            end
        end
        
        -- Highlight current node
        if lastHighlightedNode then
            RemoveRollHighlight(lastHighlightedNode)
        end
        
        if randomNode then
            AddRollHighlight(randomNode.Frame)
            lastHighlightedNode = randomNode.Frame
            
            -- Play tick sound
            -- TODO: Add sound effect
        end
        
        hopCount = hopCount + 1
        
        -- Check if we should stop
        if progress >= 1 and hopCount >= minHops and randomNode.Id == AstralWebState.RollTarget.Id then
            -- Landed on target!
            wait(0.5) -- Dramatic pause
            OnRollComplete()
            break
        end
        
        wait(currentDelay)
    end
end

function AddRollHighlight(nodeFrame)
    -- Create special roll highlight
    local rollHighlight = Instance.new("Frame")
    rollHighlight.Name = "RollHighlight"
    rollHighlight.Size = UDim2.new(1.3, 0, 1.3, 0)
    rollHighlight.Position = UDim2.new(-0.15, 0, -0.15, 0)
    rollHighlight.BackgroundColor3 = Color3.fromRGB(255, 255, 100)
    rollHighlight.BackgroundTransparency = 0.5
    rollHighlight.BorderSizePixel = 0
    rollHighlight.ZIndex = 5
    rollHighlight.Parent = nodeFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = rollHighlight
    
    -- Pulse animation
    local pulseTween = TweenService:Create(rollHighlight, 
        TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {BackgroundTransparency = 0.2}
    )
    pulseTween:Play()
end

function RemoveRollHighlight(nodeFrame)
    local highlight = nodeFrame:FindFirstChild("RollHighlight")
    if highlight then
        highlight:Destroy()
    end
end

function OnRollComplete()
    local unlockedComponent = AstralWebState.RollTarget
    
    -- Check if duplicate
    if AstralWebState.UnlockedComponents[unlockedComponent.Id] then
        -- Duplicate - award currency
        ShowNotification(string.format("Duplicate %s! +50 Essence", unlockedComponent.Component.Name), Color3.fromRGB(255, 200, 50))
        -- TODO: Award currency
    else
        -- New unlock!
        AstralWebState.UnlockedComponents[unlockedComponent.Id] = true
        ShowNotification(string.format("UNLOCKED: %s!", unlockedComponent.Component.Name), Color3.fromRGB(100, 255, 100))
        
        -- Update node visual
        local nodeFrame = AstralWebState.NodeFrames[unlockedComponent.Id]
        if nodeFrame then
            local lockOverlay = nodeFrame:FindFirstChild("LockOverlay")
            if lockOverlay then
                -- Fade out lock
                TweenService:Create(lockOverlay, TweenInfo.new(1, Enum.EasingStyle.Quad), {
                    BackgroundTransparency = 1
                }):Play()
                
                wait(1)
                lockOverlay.Visible = false
            end
        end
    end
    
    -- TODO: Send unlock to server
    
    EndRoll()
end

function EndRoll()
    AstralWebState.IsRolling = false
    AstralWebState.RollTarget = nil
    AstralWebState.RollButton.Text = "ROLL NEW COMPONENT"
    AstralWebState.RollButton.BackgroundColor3 = Color3.fromRGB(255, 100, 50)
    
    -- Clean up any remaining highlights
    for _, nodeFrame in pairs(AstralWebState.NodeFrames) do
        RemoveRollHighlight(nodeFrame)
    end
end

-- ========================================
-- SEQUENCE SUBMISSION
-- ========================================

function SubmitSequence()
    -- Validate sequence
    local sequenceData = {}
    local hasAnyComponent = false
    
    for i = 1, CONFIG.MAX_SEQUENCE_LENGTH do
        local seqData = AstralWebState.CurrentSequence[i]
        if seqData then
            hasAnyComponent = true
            sequenceData[i] = {
                ComponentId = seqData.ComponentId,
                Position = i,
                Rarity = seqData.Component.Rarity,
                EvolutionLevel = 0 -- TODO: Track evolution
            }
        else
            sequenceData[i] = nil -- Empty slot
        end
    end
    
    if not hasAnyComponent then
        ShowNotification("Add at least one component to your sequence!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    -- Prepare submission data
    local configurationData = {
        SequenceConfiguration = sequenceData,
        ConfigurationHash = GenerateConfigHash(sequenceData),
        Timestamp = tick()
    }
    
    -- Send to server
    print("📤 Submitting astral web configuration...")
    Remotes.SubmitAstralWebConfiguration:FireServer(configurationData)
    
    ShowNotification("Astral Web submitted!", Color3.fromRGB(100, 255, 100))
end

function GenerateConfigHash(sequenceData)
    -- Simple hash for detecting changes
    local hash = ""
    for i = 1, CONFIG.MAX_SEQUENCE_LENGTH do
        if sequenceData[i] then
            hash = hash .. sequenceData[i].ComponentId .. "-"
        else
            hash = hash .. "empty-"
        end
    end
    return hash
end

-- ========================================
-- VISUAL UPDATES
-- ========================================

function UpdateNodeVisuals()
    for componentId, nodeFrame in pairs(AstralWebState.NodeFrames) do
        local isUnlocked = AstralWebState.UnlockedComponents[componentId]
        local lockOverlay = nodeFrame:FindFirstChild("LockOverlay")
        
        if lockOverlay then
            lockOverlay.Visible = not isUnlocked
            lockOverlay.BackgroundTransparency = isUnlocked and 1 or CONFIG.LOCKED_TRANSPARENCY
        end
    end
end

-- ========================================
-- NOTIFICATIONS
-- ========================================

function ShowNotification(text, color)
    -- Create temporary notification
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(0, 400, 0, 60)
    notification.Position = UDim2.new(0.5, -200, 0, -100)
    notification.BackgroundColor3 = color or Color3.fromRGB(50, 50, 50)
    notification.BorderSizePixel = 0
    notification.ZIndex = 10
    notification.Parent = AstralWebState.MainFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = notification
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = notification
    
    -- Slide in
    TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, -200, 0, 20)
    }):Play()
    
    -- Fade out after delay
    spawn(function()
        wait(3)
        TweenService:Create(notification, TweenInfo.new(0.5), {
            Position = UDim2.new(0.5, -200, 0, -100),
            BackgroundTransparency = 1
        }):Play()
        
        TweenService:Create(label, TweenInfo.new(0.5), {
            TextTransparency = 1
        }):Play()
        
        wait(0.5)
        notification:Destroy()
    end)
end

-- ========================================
-- EVENT CONNECTIONS
-- ========================================

function ConnectEvents()
    -- Server responses
    if Remotes.AwardComponentEvent then
        Remotes.AwardComponentEvent.OnClientEvent:Connect(function(componentId)
            AstralWebState.UnlockedComponents[componentId] = true
            UpdateNodeVisuals()
            
            local component = SynergyComponentsDB.GetComponent(componentId)
            if component then
                ShowNotification(string.format("Received: %s!", component.Name), Color3.fromRGB(100, 255, 100))
            end
        end)
    end
    
    -- Keyboard shortcuts
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.R then
            -- R to roll
            StartRoll()
        elseif input.KeyCode == Enum.KeyCode.C then
            -- C to clear sequence
            for i = 1, CONFIG.MAX_SEQUENCE_LENGTH do
                RemoveFromSequence(i)
            end
        end
    end)
end

-- ========================================
-- INITIALIZATION
-- ========================================

-- Wait for character to load
player.CharacterAdded:Wait()
wait(1)

-- Initialize the astral web
InitializeAstralWeb()

print("✅ AstralWebClient loaded")