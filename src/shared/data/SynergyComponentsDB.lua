-- SynergyComponentsDB.lua
-- Master database for all synergy components in SynRNG
-- Defines Cores, Modifiers, Chains, and Artifacts with their properties and synergy rules

local SynergyComponentsDB = {}

-- ========================================
-- COMPONENT TYPE DEFINITIONS
-- ========================================

SynergyComponentsDB.ComponentTypes = {
    CORE = "Core",           -- Primary damage dealers, the heart of any web
    MODIFIER = "Modifier",   -- Enhance/alter other components' effects
    CHAIN = "Chain",         -- Connect and amplify between distant nodes
    ARTIFACT = "Artifact"    -- Special effects and unique mechanics
}

-- ========================================
-- RARITY SYSTEM
-- ========================================

SynergyComponentsDB.Rarities = {
    COMMON = {
        Name = "Common",
        Color = Color3.fromRGB(155, 155, 155),
        Multiplier = 1.0,
        DropWeight = 60
    },
    UNCOMMON = {
        Name = "Uncommon", 
        Color = Color3.fromRGB(30, 255, 30),
        Multiplier = 1.2,
        DropWeight = 25
    },
    RARE = {
        Name = "Rare",
        Color = Color3.fromRGB(0, 112, 255),
        Multiplier = 1.5,
        DropWeight = 10
    },
    EPIC = {
        Name = "Epic",
        Color = Color3.fromRGB(163, 53, 238),
        Multiplier = 2.0,
        DropWeight = 4
    },
    LEGENDARY = {
        Name = "Legendary",
        Color = Color3.fromRGB(255, 128, 0),
        Multiplier = 3.0,
        DropWeight = 1
    },
    MYTHICAL = {
        Name = "Mythical",
        Color = Color3.fromRGB(255, 20, 147),  -- Deep pink/magenta
        Multiplier = 5.0,
        DropWeight = 0.1  -- Extremely rare
    }
}

-- ========================================
-- SEQUENTIAL POSITION SYSTEM
-- ========================================

SynergyComponentsDB.SequencePositions = {
    FIRST = "First",               -- Position 1 in the chain
    SECOND = "Second",             -- Position 2 in the chain  
    MIDDLE = "Middle",             -- Positions 2-4 (between first and last)
    FOURTH = "Fourth",             -- Position 4 in the chain
    LAST = "Last",                 -- Position 5 in the chain
    ANY = "Any"                    -- Any position (default)
}

SynergyComponentsDB.RequirementTypes = {
    SEQUENCE_POSITION = "SequencePosition",     -- Must be in specific position (1-5)
    ADJACENT_TAG = "AdjacentTag",               -- Next/previous component must have tag
    ADJACENT_TYPE = "AdjacentType",             -- Next/previous component must be type
    SANDWICH = "Sandwich",                      -- Between two components with specific criteria
    SEQUENCE_COUNT = "SequenceCount",           -- Must have X components of type Y in sequence
    TAG_DIVERSITY = "TagDiversity",             -- Requires X different tags in sequence
    GLOBAL_PRESENCE = "GlobalPresence",         -- Requires specific component anywhere in sequence
    EVOLUTION_STAGE = "EvolutionStage",         -- Component must have evolved X times
    CUSTOM = "Custom"                           -- Custom function evaluation
}

-- ========================================
-- SYNERGY TAGS SYSTEM
-- ========================================
-- Tags enable flexible synergy combinations without hardcoding every interaction

SynergyComponentsDB.SynergyTags = {
    -- Elemental
    "Fire", "Ice", "Lightning", "Earth", "Void",
    -- Mechanical  
    "Crit", "Speed", "Burst", "DoT", "Heal",
    -- Conceptual
    "Chaos", "Order", "Growth", "Decay", "Resonance"
}

-- ========================================
-- COMPONENT DATABASE
-- ========================================

SynergyComponentsDB.Components = {
    
    -- ========================================
    -- CORES - Primary damage dealers
    -- ========================================
    
    ["ember_core"] = {
        Name = "Ember Core",
        Type = SynergyComponentsDB.ComponentTypes.CORE,
        Rarity = "COMMON",
        Description = "A flickering core of primal fire energy",
        
        BaseStats = {
            Damage = 10,
            CritChance = 0.05,
            CritMultiplier = 1.5
        },
        
        Tags = {"Fire"},
        
        -- Core ability - triggered every evaluation tick
        Ability = {
            Name = "Ember Burst",
            Description = "Deals fire damage with small crit chance",
            
            -- Function called during synergy evaluation
            Execute = function(nodeData, webContext, connections)
                local baseDamage = nodeData.BaseStats.Damage
                local finalDamage = baseDamage
                
                -- Apply rarity multiplier
                local rarity = SynergyComponentsDB.Rarities[nodeData.Rarity]
                finalDamage = finalDamage * rarity.Multiplier
                
                -- Check for crit
                local isCrit = math.random() < nodeData.BaseStats.CritChance
                if isCrit then
                    finalDamage = finalDamage * nodeData.BaseStats.CritMultiplier
                end
                
                return {
                    Damage = finalDamage,
                    DamageType = "Fire",
                    IsCritical = isCrit,
                    Effects = {}
                }
            end
        }
    },
    
    -- ========================================
    -- SEQUENTIAL SYNERGY EXAMPLES
    -- ========================================
    
    ["vanguard_core"] = {
        Name = "Vanguard Core",
        Type = SynergyComponentsDB.ComponentTypes.CORE,
        Rarity = "UNCOMMON",
        Description = "Leads from the front - massive damage bonus when first in sequence",
        
        BaseStats = {
            BaseDamage = 12,
            FirstPositionBonus = 2.5,  -- 2.5x damage when first
            LeadershipBonus = 0.3      -- 30% bonus to next component
        },
        
        Tags = {"Order", "Fire"},
        
        -- Requirement: Must be first in sequence
        Requirements = {
            {
                Type = SynergyComponentsDB.RequirementTypes.SEQUENCE_POSITION,
                Position = SynergyComponentsDB.SequencePositions.FIRST,
                Description = "Must be first in the sequence"
            }
        },
        
        Ability = {
            Name = "Lead the Charge",
            Description = "Devastating damage when leading, empowers the component that follows",
            
            Execute = function(nodeData, webContext)
                local baseDamage = nodeData.BaseStats.BaseDamage
                
                -- Massive bonus for being first
                local finalDamage = baseDamage * nodeData.BaseStats.FirstPositionBonus
                finalDamage = finalDamage * SynergyComponentsDB.Rarities[nodeData.Rarity].Multiplier
                
                -- Empower next component if it exists
                local adjacent = SynergyComponentsDB.SequenceAnalysis.GetAdjacentNodes(nodeData, webContext)
                if adjacent.Next then
                    adjacent.Next.LeadershipBonus = (adjacent.Next.LeadershipBonus or 1) + nodeData.BaseStats.LeadershipBonus
                end
                
                return {
                    Damage = finalDamage,
                    DamageType = "Fire",
                    IsCritical = false,
                    Effects = {},
                    EmpoweredNext = adjacent.Next ~= nil
                }
            end
        }
    },
    
    ["chain_link"] = {
        Name = "Chain Link",
        Type = SynergyComponentsDB.ComponentTypes.MODIFIER,
        Rarity = "COMMON",
        Description = "Gets stronger when sandwiched between matching component types",
        
        BaseStats = {
            BasePower = 8,
            SameTypeBonus = 1.5,  -- 1.5x when between same types
            ChainMultiplier = 0.4  -- 40% bonus to adjacent components
        },
        
        Tags = {"Growth", "Resonance"},
        
        -- Requirement: Must be between two components of the same type
        Requirements = {
            {
                Type = SynergyComponentsDB.RequirementTypes.SANDWICH,
                Criteria = {
                    Previous = { Type = nil }, -- Will be checked dynamically
                    Next = { Type = nil }      -- Will be checked dynamically
                },
                Description = "Must be between two components of the same type"
            }
        },
        
        Ability = {
            Name = "Missing Link",
            Description = "Forms the connection that completes the chain",
            
            ModifyWeb = function(nodeData, webContext)
                local adjacent = SynergyComponentsDB.SequenceAnalysis.GetAdjacentNodes(nodeData, webContext)
                
                -- Check if sandwiched between same types
                local isSandwiched = false
                if adjacent.Previous and adjacent.Next then
                    isSandwiched = adjacent.Previous.Type == adjacent.Next.Type
                end
                
                if not isSandwiched then
                    return {
                        ModificationsApplied = 0,
                        RequirementsMet = false,
                        SandwichedBetween = "None"
                    }
                end
                
                local modifications = 0
                local chainBonus = nodeData.BaseStats.ChainMultiplier
                
                if isSandwiched then
                    chainBonus = chainBonus * nodeData.BaseStats.SameTypeBonus
                end
                
                -- Boost adjacent components
                if adjacent.Previous then
                    adjacent.Previous.ChainLinkBonus = (adjacent.Previous.ChainLinkBonus or 1) + chainBonus
                    modifications = modifications + 1
                end
                
                if adjacent.Next then
                    adjacent.Next.ChainLinkBonus = (adjacent.Next.ChainLinkBonus or 1) + chainBonus
                    modifications = modifications + 1
                end
                
                return {
                    ModificationsApplied = modifications,
                    RequirementsMet = isSandwiched,
                    SandwichedBetween = adjacent.Previous.Type,
                    ChainBonus = chainBonus
                }
            end
        }
    },
    
    ["elemental_conductor"] = {
        Name = "Elemental Conductor",
        Type = SynergyComponentsDB.ComponentTypes.CHAIN,
        Rarity = "RARE",
        Description = "Amplifies elemental synergies when next to different elements",
        
        BaseStats = {
            ElementalAmplification = 2.0,  -- 2x elemental effects
            DiversityBonus = 0.5          -- 50% per unique adjacent element
        },
        
        Tags = {"Lightning", "Resonance"},
        
        -- Requirement: Must be adjacent to at least one elemental component
        Requirements = {
            {
                Type = SynergyComponentsDB.RequirementTypes.CUSTOM,
                CustomFunction = function(nodeData, webContext)
                    local adjacent = SynergyComponentsDB.SequenceAnalysis.GetAdjacentNodes(nodeData, webContext)
                    local elementalTags = {"Fire", "Ice", "Lightning", "Earth", "Void"}
                    
                    local hasElementalNeighbor = false
                    
                    if adjacent.Previous then
                        for _, tag in pairs(adjacent.Previous.Tags) do
                            if table.find(elementalTags, tag) then
                                hasElementalNeighbor = true
                                break
                            end
                        end
                    end
                    
                    if adjacent.Next and not hasElementalNeighbor then
                        for _, tag in pairs(adjacent.Next.Tags) do
                            if table.find(elementalTags, tag) then
                                hasElementalNeighbor = true
                                break
                            end
                        end
                    end
                    
                    return hasElementalNeighbor
                end,
                Description = "Must be adjacent to at least one elemental component"
            }
        },
        
        Ability = {
            Name = "Elemental Bridge",
            Description = "Conducts and amplifies elemental energies between components",
            
            ModifyWeb = function(nodeData, webContext)
                local adjacent = SynergyComponentsDB.SequenceAnalysis.GetAdjacentNodes(nodeData, webContext)
                local elementalTags = {"Fire", "Ice", "Lightning", "Earth", "Void"}
                
                local adjacentElements = {}
                local modifications = 0
                
                -- Collect adjacent elemental tags
                if adjacent.Previous then
                    for _, tag in pairs(adjacent.Previous.Tags) do
                        if table.find(elementalTags, tag) then
                            adjacentElements[tag] = true
                        end
                    end
                end
                
                if adjacent.Next then
                    for _, tag in pairs(adjacent.Next.Tags) do
                        if table.find(elementalTags, tag) then
                            adjacentElements[tag] = true
                        end
                    end
                end
                
                local uniqueElements = 0
                for _ in pairs(adjacentElements) do
                    uniqueElements = uniqueElements + 1
                end
                
                if uniqueElements == 0 then
                    return {
                        ModificationsApplied = 0,
                        RequirementsMet = false
                    }
                end
                
                -- Calculate amplification based on diversity
                local amplification = nodeData.BaseStats.ElementalAmplification + (uniqueElements * nodeData.BaseStats.DiversityBonus)
                
                -- Apply to adjacent elemental components
                if adjacent.Previous then
                    for _, tag in pairs(adjacent.Previous.Tags) do
                        if table.find(elementalTags, tag) then
                            adjacent.Previous.ElementalAmplification = (adjacent.Previous.ElementalAmplification or 1) * amplification
                            modifications = modifications + 1
                            break
                        end
                    end
                end
                
                if adjacent.Next then
                    for _, tag in pairs(adjacent.Next.Tags) do
                        if table.find(elementalTags, tag) then
                            adjacent.Next.ElementalAmplification = (adjacent.Next.ElementalAmplification or 1) * amplification
                            modifications = modifications + 1
                            break
                        end
                    end
                end
                
                return {
                    ModificationsApplied = modifications,
                    RequirementsMet = true,
                    UniqueElements = uniqueElements,
                    Amplification = amplification
                }
            end
        }
    },
    
    ["finale_artifact"] = {
        Name = "Grand Finale",
        Type = SynergyComponentsDB.ComponentTypes.ARTIFACT,
        Rarity = "EPIC",
        Description = "The dramatic conclusion - power scales with entire sequence complexity",
        
        BaseStats = {
            BasePower = 25,
            SequenceMultiplier = 0.8,  -- 80% bonus per component before it
            TypeDiversityBonus = 1.0   -- 100% per unique type in sequence
        },
        
        Tags = {"Chaos", "Growth"},
        
        -- Requirement: Must be last in sequence
        Requirements = {
            {
                Type = SynergyComponentsDB.RequirementTypes.SEQUENCE_POSITION,
                Position = SynergyComponentsDB.SequencePositions.LAST,
                Description = "Must be the final component in the sequence"
            }
        },
        
        Ability = {
            Name = "Crescendo",
            Description = "Explosive finale that builds on everything that came before",
            
            Execute = function(nodeData, webContext)
                local basePower = nodeData.BaseStats.BasePower
                local sequenceLength = #webContext.OrderedNodes
                
                -- Power scales with sequence length
                local sequenceBonus = (sequenceLength - 1) * nodeData.BaseStats.SequenceMultiplier
                
                -- Count unique component types in sequence
                local uniqueTypes = {}
                for _, node in pairs(webContext.OrderedNodes) do
                    uniqueTypes[node.Type] = true
                end
                
                local typeCount = 0
                for _ in pairs(uniqueTypes) do
                    typeCount = typeCount + 1
                end
                
                local diversityBonus = (typeCount - 1) * nodeData.BaseStats.TypeDiversityBonus
                
                local finalDamage = basePower * (1 + sequenceBonus + diversityBonus)
                finalDamage = finalDamage * SynergyComponentsDB.Rarities[nodeData.Rarity].Multiplier
                
                -- Special finale effects based on sequence composition
                local effects = {}
                
                -- Different effects based on what types are in the sequence
                if uniqueTypes[SynergyComponentsDB.ComponentTypes.CORE] then
                    table.insert(effects, {
                        Type = "PowerSurge",
                        Power = finalDamage * 0.2,
                        Duration = 10,
                        Description = "Cores in sequence create power surge"
                    })
                end
                
                if uniqueTypes[SynergyComponentsDB.ComponentTypes.MODIFIER] then
                    table.insert(effects, {
                        Type = "Enhancement",
                        Power = finalDamage * 0.15,
                        Duration = 8,
                        Description = "Modifiers create lasting enhancement"
                    })
                end
                
                return {
                    Damage = finalDamage,
                    DamageType = "Finale",
                    IsCritical = typeCount >= 3,  -- Crit with 3+ different types
                    Effects = effects,
                    SequenceLength = sequenceLength,
                    TypeDiversity = typeCount,
                    SequenceBonus = sequenceBonus,
                    DiversityBonus = diversityBonus
                }
            end
        }
    },
    
    ["echo_chamber"] = {
        Name = "Echo Chamber",
        Type = SynergyComponentsDB.ComponentTypes.ARTIFACT,
        Rarity = "RARE",
        Description = "Repeats the effect of the component that came before it",
        
        BaseStats = {
            EchoStrength = 0.75,  -- 75% of previous component's power
            ResonanceBonus = 0.25  -- 25% bonus if matching tags
        },
        
        Tags = {"Resonance", "Void"},
        
        -- Requirement: Cannot be first (needs something to echo)
        Requirements = {
            {
                Type = SynergyComponentsDB.RequirementTypes.CUSTOM,
                CustomFunction = function(nodeData, webContext)
                    local index = webContext.NodeIndex[nodeData]
                    return index > 1  -- Not first
                end,
                Description = "Cannot be first in sequence (needs something to echo)"
            }
        },
        
        Ability = {
            Name = "Perfect Echo",
            Description = "Mirrors and amplifies the previous component's ability",
            
            Execute = function(nodeData, webContext)
                local adjacent = SynergyComponentsDB.SequenceAnalysis.GetAdjacentNodes(nodeData, webContext)
                
                if not adjacent.Previous then
                    return {
                        Damage = 0,
                        DamageType = "None",
                        IsCritical = false,
                        Effects = {},
                        EchoTarget = "None"
                    }
                end
                
                local previousNode = adjacent.Previous
                local echoStrength = nodeData.BaseStats.EchoStrength
                
                -- Check for resonance (shared tags)
                local sharedTags = 0
                for _, tag in pairs(nodeData.Tags) do
                    if table.find(previousNode.Tags, tag) then
                        sharedTags = sharedTags + 1
                    end
                end
                
                if sharedTags > 0 then
                    echoStrength = echoStrength + (sharedTags * nodeData.BaseStats.ResonanceBonus)
                end
                
                -- Echo the previous component's base power (simplified)
                local echoDamage = 0
                if previousNode.BaseStats.Damage then
                    echoDamage = previousNode.BaseStats.Damage * echoStrength
                elseif previousNode.BaseStats.BaseDamage then
                    echoDamage = previousNode.BaseStats.BaseDamage * echoStrength
                elseif previousNode.BaseStats.BasePower then
                    echoDamage = previousNode.BaseStats.BasePower * echoStrength
                end
                
                echoDamage = echoDamage * SynergyComponentsDB.Rarities[nodeData.Rarity].Multiplier
                
                return {
                    Damage = echoDamage,
                    DamageType = "Echo",
                    IsCritical = false,
                    Effects = {
                        {
                            Type = "EchoResonance",
                            Power = echoDamage * 0.1,
                            Duration = 5,
                            Description = "Echoed energy resonates through sequence"
                        }
                    },
                    EchoTarget = previousNode.Name or previousNode.ComponentId,
                    EchoStrength = echoStrength,
                    SharedTags = sharedTags
                }
            end
        }
    },
    
    -- ========================================
    -- MYTHICAL TIER COMPONENTS
    -- ========================================
    
    ["astral_nexus"] = {
        Name = "Astral Nexus",
        Type = SynergyComponentsDB.ComponentTypes.CORE,
        Rarity = "MYTHICAL",
        Description = "A transcendent core that grows exponentially stronger with web complexity",
        
        BaseStats = {
            BaseDamage = 50,
            WebScaling = 2.0,    -- Damage multiplies by 2 for each connected component
            CritChance = 0.25,
            CritMultiplier = 3.0,
            AstralPower = 100    -- Special resource for mythical effects
        },
        
        Tags = {"Void", "Growth", "Resonance", "Chaos"},
        
        Ability = {
            Name = "Nexus Convergence",
            Description = "Damage scales exponentially with total web connections",
            
            Execute = function(nodeData, webContext, connections)
                local totalConnections = 0
                local uniqueTypes = {}
                
                -- Count all connections in the entire web and track component diversity
                for _, node in pairs(webContext.AllNodes) do
                    totalConnections = totalConnections + #node.Connections
                    uniqueTypes[node.Type] = true
                end
                
                local typeBonus = 0
                for _ in pairs(uniqueTypes) do
                    typeBonus = typeBonus + 1
                end
                
                -- Exponential scaling based on web complexity
                local complexityMultiplier = math.pow(nodeData.BaseStats.WebScaling, math.min(totalConnections / 4, 6)) -- Cap at 2^6 = 64x
                local diversityMultiplier = 1 + (typeBonus * 0.5) -- 50% per unique component type
                
                local finalDamage = nodeData.BaseStats.BaseDamage * complexityMultiplier * diversityMultiplier
                finalDamage = finalDamage * SynergyComponentsDB.Rarities[nodeData.Rarity].Multiplier
                
                local isCrit = math.random() < nodeData.BaseStats.CritChance
                if isCrit then
                    finalDamage = finalDamage * nodeData.BaseStats.CritMultiplier
                end
                
                -- Special mythical effect: Astral Cascade
                local cascadeEffects = {}
                if totalConnections >= 8 then  -- Trigger special effect with complex webs
                    table.insert(cascadeEffects, {
                        Type = "AstralCascade",
                        Power = nodeData.BaseStats.AstralPower,
                        Duration = 10,
                        Description = "Reality tears, dealing void damage over time"
                    })
                end
                
                return {
                    Damage = finalDamage,
                    DamageType = "Astral",
                    IsCritical = isCrit,
                    Effects = cascadeEffects,
                    ComplexityMultiplier = complexityMultiplier,
                    TotalConnections = totalConnections
                }
            end
        }
    },
    
    ["reality_anchor"] = {
        Name = "Reality Anchor",
        Type = SynergyComponentsDB.ComponentTypes.MODIFIER,
        Rarity = "MYTHICAL", 
        Description = "Warps the fundamental laws of synergy, enabling impossible combinations",
        
        BaseStats = {
            SynergyAmplification = 2.0,  -- Doubles all synergy bonuses
            Range = 999,                 -- Affects entire web
            RealityBreak = 0.15         -- 15% chance to ignore component type restrictions
        },
        
        Tags = {"Order", "Chaos", "Void", "Resonance"},
        
        Ability = {
            Name = "Dimensional Rift",
            Description = "Breaks the rules of reality, allowing any component to synergize with any other",
            
            ModifyWeb = function(nodeData, webContext, connections)
                local totalModifications = 0
                
                -- Phase 1: Amplify ALL existing synergies in the web
                for _, node in pairs(webContext.AllNodes) do
                    if node ~= nodeData then  -- Don't modify self
                        -- Double any existing synergy bonuses
                        node.SynergyAmplifier = (node.SynergyAmplifier or 1) * nodeData.BaseStats.SynergyAmplification
                        totalModifications = totalModifications + 1
                    end
                end
                
                -- Phase 2: Create impossible synergies (Reality Break)
                local impossibleSynergies = 0
                for _, node1 in pairs(webContext.AllNodes) do
                    for _, node2 in pairs(webContext.AllNodes) do
                        if node1 ~= node2 and math.random() < nodeData.BaseStats.RealityBreak then
                            -- Force synergy between any two components regardless of tags
                            node1.RealityBrokenSynergy = (node1.RealityBrokenSynergy or 1) + 0.25
                            impossibleSynergies = impossibleSynergies + 1
                        end
                    end
                end
                
                -- Phase 3: Grant temporary mythical properties to nearby components
                for _, connection in pairs(connections) do
                    local targetNode = connection.TargetNode
                    if targetNode.Rarity ~= "MYTHICAL" then
                        targetNode.TemporaryMythicalBonus = 1.5  -- 50% damage bonus
                        totalModifications = totalModifications + 1
                    end
                end
                
                return {
                    ModificationsApplied = totalModifications,
                    ImpossibleSynergies = impossibleSynergies,
                    RealityState = "Fractured"
                }
            end
        }
    },
    
    ["infinity_conduit"] = {
        Name = "Infinity Conduit", 
        Type = SynergyComponentsDB.ComponentTypes.CHAIN,
        Rarity = "MYTHICAL",
        Description = "A chain that exists across infinite dimensions, connecting all things",
        
        BaseStats = {
            MaxDistance = 999,           -- Connects everything
            InfinityBonus = 0.05,       -- 5% bonus per connection in entire web
            DimensionalResonance = 3.0,  -- Triples chain efficiency
            QuantumEntanglement = true   -- Special property
        },
        
        Tags = {"Void", "Resonance", "Growth", "Order"},
        
        Ability = {
            Name = "Quantum Entanglement Web",
            Description = "Creates a web where every component is connected to every other component",
            
            ModifyWeb = function(nodeData, webContext, connections)
                local totalNodes = #webContext.AllNodes
                local totalPossibleConnections = totalNodes * (totalNodes - 1) / 2  -- n(n-1)/2 formula
                
                -- Apply infinity bonus based on theoretical maximum connections
                local infinityMultiplier = 1 + (totalPossibleConnections * nodeData.BaseStats.InfinityBonus)
                
                -- Every component in the web gets the infinity bonus
                for _, node in pairs(webContext.AllNodes) do
                    if node.Type == SynergyComponentsDB.ComponentTypes.CORE then
                        node.InfinityChainBonus = infinityMultiplier
                    end
                    
                    -- Special quantum effect: components gain properties from ALL other components
                    node.QuantumEntangled = true
                    
                    -- Grant small bonuses from every other component's tags
                    for _, otherNode in pairs(webContext.AllNodes) do
                        if otherNode ~= node then
                            for _, tag in pairs(otherNode.Tags) do
                                node.QuantumTagBonus = (node.QuantumTagBonus or 1) + 0.02  -- 2% per unique tag in web
                            end
                        end
                    end
                end
                
                return {
                    QuantumConnections = totalPossibleConnections,
                    InfinityMultiplier = infinityMultiplier,
                    EntangledNodes = totalNodes,
                    DimensionalState = "Infinite"
                }
            end
        }
    },
    
    ["genesis_engine"] = {
        Name = "Genesis Engine",
        Type = SynergyComponentsDB.ComponentTypes.ARTIFACT,
        Rarity = "MYTHICAL",
        Description = "The primordial force that created the first synergies. Evolves and improves over time.",
        
        BaseStats = {
            CreationPower = 200,
            EvolutionRate = 0.1,        -- Grows 10% stronger each evaluation
            MaxEvolution = 10.0,        -- Caps at 10x original power
            GenesisCharge = 0           -- Tracks evolution progress
        },
        
        Tags = {"Order", "Growth", "Void", "Resonance"},
        
        Ability = {
            Name = "Primordial Genesis",
            Description = "Creates new synergies from nothing and evolves stronger each tick",
            
            Execute = function(nodeData, webContext, connections)
                -- Evolution mechanic: Genesis Engine gets stronger over time
                nodeData.BaseStats.GenesisCharge = (nodeData.BaseStats.GenesisCharge or 0) + nodeData.BaseStats.EvolutionRate
                local evolutionMultiplier = math.min(1 + nodeData.BaseStats.GenesisCharge, nodeData.BaseStats.MaxEvolution)
                
                local currentPower = nodeData.BaseStats.CreationPower * evolutionMultiplier
                currentPower = currentPower * SynergyComponentsDB.Rarities[nodeData.Rarity].Multiplier
                
                -- Special Genesis Effects based on evolution level
                local genesisEffects = {}
                local evolutionTier = math.floor(nodeData.BaseStats.GenesisCharge)
                
                if evolutionTier >= 1 then
                    table.insert(genesisEffects, {
                        Type = "CreativeForce",
                        Power = currentPower * 0.1,
                        Duration = 15,
                        Description = "Spawns beneficial effects randomly"
                    })
                end
                
                if evolutionTier >= 3 then
                    table.insert(genesisEffects, {
                        Type = "RealityRewrite", 
                        Power = currentPower * 0.2,
                        Duration = 20,
                        Description = "Temporarily enhances all components in web"
                    })
                end
                
                if evolutionTier >= 5 then
                    table.insert(genesisEffects, {
                        Type = "UniversalHarmony",
                        Power = currentPower * 0.3,
                        Duration = 30,
                        Description = "All components gain maximum possible synergies"
                    })
                end
                
                -- Bonus damage for each unique component type (Genesis rewards diversity)
                local uniqueTypes = {}
                for _, node in pairs(webContext.AllNodes) do
                    uniqueTypes[node.Type] = true
                end
                
                local diversityBonus = 0
                for _ in pairs(uniqueTypes) do
                    diversityBonus = diversityBonus + 50  -- 50 base damage per type
                end
                
                local totalDamage = currentPower + (diversityBonus * evolutionMultiplier)
                
                return {
                    Damage = totalDamage,
                    DamageType = "Genesis",
                    IsCritical = evolutionTier >= 2,  -- Always crit after evolution tier 2
                    Effects = genesisEffects,
                    EvolutionTier = evolutionTier,
                    EvolutionMultiplier = evolutionMultiplier,
                    GenesisCharge = nodeData.BaseStats.GenesisCharge
                }
            end
        }
    },
    
    ["frost_core"] = {
        Name = "Frost Core", 
        Type = SynergyComponentsDB.ComponentTypes.CORE,
        Rarity = "COMMON",
        Description = "Crystalline ice core with slowing properties",
        
        BaseStats = {
            Damage = 8,
            CritChance = 0.03,
            CritMultiplier = 1.8,
            SlowPower = 0.15
        },
        
        Tags = {"Ice"},
        
        Ability = {
            Name = "Frost Shard",
            Description = "Ice damage that applies slow effect",
            
            Execute = function(nodeData, webContext, connections)
                local baseDamage = nodeData.BaseStats.Damage
                local finalDamage = baseDamage * SynergyComponentsDB.Rarities[nodeData.Rarity].Multiplier
                
                local isCrit = math.random() < nodeData.BaseStats.CritChance
                if isCrit then
                    finalDamage = finalDamage * nodeData.BaseStats.CritMultiplier
                end
                
                return {
                    Damage = finalDamage,
                    DamageType = "Ice",
                    IsCritical = isCrit,
                    Effects = {
                        {
                            Type = "Slow",
                            Power = nodeData.BaseStats.SlowPower,
                            Duration = 3
                        }
                    }
                }
            end
        }
    },
    
    -- ========================================
    -- MODIFIERS - Enhance other components
    -- ========================================
    
    ["amplifier"] = {
        Name = "Damage Amplifier",
        Type = SynergyComponentsDB.ComponentTypes.MODIFIER,
        Rarity = "COMMON", 
        Description = "Boosts damage of connected components",
        
        BaseStats = {
            DamageBonus = 0.25,  -- 25% damage increase
            Range = 1            -- Affects nodes within 1 connection
        },
        
        Tags = {"Growth"},
        
        Ability = {
            Name = "Power Boost",
            Description = "Increases damage of nearby components",
            
            -- Modifiers work differently - they affect the web evaluation process
            ModifyWeb = function(nodeData, webContext, connections)
                -- Find all connected nodes within range
                local affectedNodes = {}
                
                for _, connection in pairs(connections) do
                    if connection.Distance <= nodeData.BaseStats.Range then
                        table.insert(affectedNodes, connection.TargetNode)
                    end
                end
                
                -- Apply damage bonus to affected nodes
                for _, targetNode in pairs(affectedNodes) do
                    if targetNode.Type == SynergyComponentsDB.ComponentTypes.CORE then
                        targetNode.DamageMultiplier = (targetNode.DamageMultiplier or 1) + nodeData.BaseStats.DamageBonus
                    end
                end
                
                return {
                    ModificationsApplied = #affectedNodes,
                    AffectedNodes = affectedNodes
                }
            end
        }
    },
    
    ["resonator"] = {
        Name = "Elemental Resonator",
        Type = SynergyComponentsDB.ComponentTypes.MODIFIER,
        Rarity = "UNCOMMON",
        Description = "Amplifies matching elemental effects",
        
        BaseStats = {
            ElementalBonus = 0.5,  -- 50% bonus for matching elements
            Range = 2
        },
        
        Tags = {"Resonance"},
        
        Ability = {
            Name = "Elemental Harmony", 
            Description = "Massively boosts matching elemental types",
            
            ModifyWeb = function(nodeData, webContext, connections)
                local modifications = 0
                
                -- Look for elemental tags in connected nodes
                for _, connection in pairs(connections) do
                    if connection.Distance <= nodeData.BaseStats.Range then
                        local targetNode = connection.TargetNode
                        
                        -- Check for shared elemental tags
                        for _, tag in pairs(nodeData.Tags) do
                            if table.find(targetNode.Tags, tag) and 
                               (tag == "Fire" or tag == "Ice" or tag == "Lightning" or tag == "Earth" or tag == "Void") then
                                
                                targetNode.ElementalMultiplier = (targetNode.ElementalMultiplier or 1) + nodeData.BaseStats.ElementalBonus
                                modifications = modifications + 1
                            end
                        end
                    end
                end
                
                return {
                    ModificationsApplied = modifications
                }
            end
        }
    },
    
    -- ========================================
    -- CHAINS - Connection and amplification
    -- ========================================
    
    ["power_conduit"] = {
        Name = "Power Conduit",
        Type = SynergyComponentsDB.ComponentTypes.CHAIN,
        Rarity = "COMMON",
        Description = "Channels energy between distant nodes",
        
        BaseStats = {
            MaxDistance = 3,     -- Can bridge up to 3 nodes apart
            EfficiencyBonus = 0.1 -- 10% bonus for each node in the chain
        },
        
        Tags = {"Growth", "Resonance"},
        
        Ability = {
            Name = "Energy Bridge",
            Description = "Creates efficient pathways for power transfer",
            
            ModifyWeb = function(nodeData, webContext, connections)
                -- Chains create new logical connections beyond adjacent nodes
                local bridgedConnections = 0
                local totalNodes = #webContext.AllNodes
                
                -- Apply efficiency bonus based on web complexity
                local complexityBonus = math.min(totalNodes * nodeData.BaseStats.EfficiencyBonus, 1.0)
                
                -- Boost all connected cores
                for _, connection in pairs(connections) do
                    if connection.TargetNode.Type == SynergyComponentsDB.ComponentTypes.CORE then
                        connection.TargetNode.ChainBonus = (connection.TargetNode.ChainBonus or 1) + complexityBonus
                        bridgedConnections = bridgedConnections + 1
                    end
                end
                
                return {
                    BridgedConnections = bridgedConnections,
                    ComplexityBonus = complexityBonus
                }
            end
        }
    },
    
    -- ========================================  
    -- ARTIFACTS - Special mechanics
    -- ========================================
    
    ["chaos_orb"] = {
        Name = "Chaos Orb",
        Type = SynergyComponentsDB.ComponentTypes.ARTIFACT,
        Rarity = "RARE",
        Description = "Unpredictable effects that grow stronger with chaos",
        
        BaseStats = {
            BaseChaosPower = 5,
            ChaosMultiplier = 0.1,  -- 10% per different component type
            MaxChaosStacks = 10
        },
        
        Tags = {"Chaos", "Growth"},
        
        Ability = {
            Name = "Chaotic Resonance",
            Description = "Power increases with web diversity",
            
            Execute = function(nodeData, webContext, connections)
                -- Count unique component types in the web
                local componentTypes = {}
                for _, node in pairs(webContext.AllNodes) do
                    componentTypes[node.Type] = true
                end
                
                local typeCount = 0
                for _ in pairs(componentTypes) do
                    typeCount = typeCount + 1
                end
                
                -- Calculate chaos damage
                local chaosStacks = math.min(typeCount, nodeData.BaseStats.MaxChaosStacks)
                local chaosPower = nodeData.BaseStats.BaseChaosPower + (chaosStacks * nodeData.BaseStats.ChaosMultiplier * 100)
                
                -- Random effect
                local effects = {}
                local randomEffect = math.random(1, 3)
                
                if randomEffect == 1 then
                    table.insert(effects, {Type = "Burn", Power = chaosPower * 0.2, Duration = 5})
                elseif randomEffect == 2 then
                    table.insert(effects, {Type = "Weaken", Power = chaosPower * 0.15, Duration = 4})
                else
                    table.insert(effects, {Type = "Confuse", Power = chaosPower * 0.1, Duration = 3})
                end
                
                return {
                    Damage = chaosPower,
                    DamageType = "Chaos",
                    IsCritical = false,
                    Effects = effects,
                    ChaosStacks = chaosStacks
                }
            end
        }
    }
}

-- ========================================
-- SEQUENTIAL ANALYSIS FUNCTIONS
-- ========================================
SynergyComponentsDB.SequenceAnalysis = {}

-- Get a node's position type in the sequence
function SynergyComponentsDB.SequenceAnalysis.GetSequencePosition(nodeData, webContext)
    local index = webContext.NodeIndex[nodeData]
    local totalNodes = #webContext.OrderedNodes
    
    if index == 1 then
        return SynergyComponentsDB.SequencePositions.FIRST
    elseif index == totalNodes then
        return SynergyComponentsDB.SequencePositions.LAST
    elseif index == 2 then
        return SynergyComponentsDB.SequencePositions.SECOND
    elseif index == totalNodes - 1 then
        return SynergyComponentsDB.SequencePositions.FOURTH
    else
        return SynergyComponentsDB.SequencePositions.MIDDLE
    end
end

-- Get adjacent nodes (previous and next in sequence)
function SynergyComponentsDB.SequenceAnalysis.GetAdjacentNodes(nodeData, webContext)
    local index = webContext.NodeIndex[nodeData]
    local totalNodes = #webContext.OrderedNodes
    
    local previousNode = nil
    local nextNode = nil
    
    if index > 1 then
        previousNode = webContext.OrderedNodes[index - 1]
    end
    
    if index < totalNodes then
        nextNode = webContext.OrderedNodes[index + 1]
    end
    
    return {
        Previous = previousNode,
        Next = nextNode,
        Index = index
    }
end

-- Check if node is "sandwiched" between components matching criteria
function SynergyComponentsDB.SequenceAnalysis.IsSandwichedBetween(nodeData, webContext, criteria)
    local adjacent = SynergyComponentsDB.SequenceAnalysis.GetAdjacentNodes(nodeData, webContext)
    
    if not adjacent.Previous or not adjacent.Next then
        return false -- Can't be sandwiched without both neighbors
    end
    
    local prevMatch = SynergyComponentsDB.SequenceAnalysis.MatchesCriteria(adjacent.Previous, criteria.Previous)
    local nextMatch = SynergyComponentsDB.SequenceAnalysis.MatchesCriteria(adjacent.Next, criteria.Next)
    
    return prevMatch and nextMatch
end

-- Check if a node matches given criteria (tag, type, rarity, etc.)
function SynergyComponentsDB.SequenceAnalysis.MatchesCriteria(node, criteria)
    if criteria.Type and node.Type ~= criteria.Type then
        return false
    end
    
    if criteria.Tag and not table.find(node.Tags, criteria.Tag) then
        return false
    end
    
    if criteria.Rarity and node.Rarity ~= criteria.Rarity then
        return false
    end
    
    if criteria.ComponentId and node.ComponentId ~= criteria.ComponentId then
        return false
    end
    
    return true
end

-- Count components matching criteria in the sequence
function SynergyComponentsDB.SequenceAnalysis.CountInSequence(webContext, criteria)
    local count = 0
    
    for _, node in pairs(webContext.OrderedNodes) do
        if SynergyComponentsDB.SequenceAnalysis.MatchesCriteria(node, criteria) then
            count = count + 1
        end
    end
    
    return count
end

-- Check if specific component exists anywhere in sequence
function SynergyComponentsDB.SequenceAnalysis.ExistsInSequence(webContext, criteria)
    for _, node in pairs(webContext.OrderedNodes) do
        if SynergyComponentsDB.SequenceAnalysis.MatchesCriteria(node, criteria) then
            return true
        end
    end
    return false
end

-- Evaluate if a component meets its activation requirements
function SynergyComponentsDB.EvaluateRequirements(component, nodeData, webContext)
    if not component.Requirements then
        return true -- No requirements, always activate
    end
    
    for _, requirement in pairs(component.Requirements) do
        if not SynergyComponentsDB.CheckRequirement(requirement, nodeData, webContext) then
            return false -- Failed requirement
        end
    end
    
    return true -- All requirements met
end

-- Check individual requirement for sequential logic
function SynergyComponentsDB.CheckRequirement(requirement, nodeData, webContext)
    local reqType = requirement.Type
    
    if reqType == SynergyComponentsDB.RequirementTypes.SEQUENCE_POSITION then
        local currentPosition = SynergyComponentsDB.SequenceAnalysis.GetSequencePosition(nodeData, webContext)
        return currentPosition == requirement.Position or requirement.Position == SynergyComponentsDB.SequencePositions.ANY
        
    elseif reqType == SynergyComponentsDB.RequirementTypes.ADJACENT_TAG then
        local adjacent = SynergyComponentsDB.SequenceAnalysis.GetAdjacentNodes(nodeData, webContext)
        local targetTag = requirement.Tag
        
        if requirement.Direction == "Next" and adjacent.Next then
            return table.find(adjacent.Next.Tags, targetTag)
        elseif requirement.Direction == "Previous" and adjacent.Previous then
            return table.find(adjacent.Previous.Tags, targetTag)
        elseif requirement.Direction == "Either" then
            local nextHasTag = adjacent.Next and table.find(adjacent.Next.Tags, targetTag)
            local prevHasTag = adjacent.Previous and table.find(adjacent.Previous.Tags, targetTag)
            return nextHasTag or prevHasTag
        end
        
    elseif reqType == SynergyComponentsDB.RequirementTypes.ADJACENT_TYPE then
        local adjacent = SynergyComponentsDB.SequenceAnalysis.GetAdjacentNodes(nodeData, webContext)
        local targetType = requirement.ComponentType
        
        if requirement.Direction == "Next" and adjacent.Next then
            return adjacent.Next.Type == targetType
        elseif requirement.Direction == "Previous" and adjacent.Previous then
            return adjacent.Previous.Type == targetType
        elseif requirement.Direction == "Either" then
            local nextIsType = adjacent.Next and adjacent.Next.Type == targetType
            local prevIsType = adjacent.Previous and adjacent.Previous.Type == targetType
            return nextIsType or prevIsType
        end
        
    elseif reqType == SynergyComponentsDB.RequirementTypes.SANDWICH then
        return SynergyComponentsDB.SequenceAnalysis.IsSandwichedBetween(nodeData, webContext, requirement.Criteria)
        
    elseif reqType == SynergyComponentsDB.RequirementTypes.SEQUENCE_COUNT then
        local count = SynergyComponentsDB.SequenceAnalysis.CountInSequence(webContext, {Type = requirement.ComponentType})
        return count >= requirement.MinCount
        
    elseif reqType == SynergyComponentsDB.RequirementTypes.TAG_DIVERSITY then
        local uniqueTags = {}
        for _, node in pairs(webContext.OrderedNodes) do
            for _, tag in pairs(node.Tags) do
                uniqueTags[tag] = true
            end
        end
        local tagCount = 0
        for _ in pairs(uniqueTags) do tagCount = tagCount + 1 end
        return tagCount >= requirement.MinTags
        
    elseif reqType == SynergyComponentsDB.RequirementTypes.GLOBAL_PRESENCE then
        return SynergyComponentsDB.SequenceAnalysis.ExistsInSequence(webContext, requirement.Criteria)
        
    elseif reqType == SynergyComponentsDB.RequirementTypes.EVOLUTION_STAGE then
        local evolutionLevel = nodeData.EvolutionLevel or 0
        return evolutionLevel >= requirement.MinStage
        
    elseif reqType == SynergyComponentsDB.RequirementTypes.CUSTOM then
        -- Execute custom function
        return requirement.CustomFunction(nodeData, webContext)
    end
    
    return false
end

-- ========================================
-- SYNERGY EVALUATION HELPERS
-- ========================================

-- Calculate synergy bonus between two components based on shared tags
function SynergyComponentsDB.CalculateTagSynergy(component1, component2)
    local sharedTags = 0
    local synergyMultiplier = 1.0
    
    for _, tag1 in pairs(component1.Tags) do
        for _, tag2 in pairs(component2.Tags) do
            if tag1 == tag2 then
                sharedTags = sharedTags + 1
                synergyMultiplier = synergyMultiplier + 0.1  -- 10% bonus per shared tag
            end
        end
    end
    
    return {
        SharedTags = sharedTags,
        SynergyMultiplier = synergyMultiplier
    }
end

-- Get component by ID with error handling and requirement evaluation
function SynergyComponentsDB.GetComponent(componentId)
    local component = SynergyComponentsDB.Components[componentId]
    if not component then
        warn("Component not found: " .. tostring(componentId))
        return nil
    end
    return component
end

-- Enhanced component evaluation with sequential requirement checking
function SynergyComponentsDB.EvaluateComponent(component, nodeData, webContext)
    -- Enhanced webContext should include:
    -- webContext = {
    --     AllNodes = {...},        -- Full list of all nodes
    --     OrderedNodes = {...},    -- Ordered sequence of nodes (positions 1-5)
    --     NodeIndex = {[node] = index}  -- Maps each node to its sequence position
    -- }
    
    -- First check if component meets its activation requirements
    local requirementsMet = SynergyComponentsDB.EvaluateRequirements(component, nodeData, webContext)
    
    local result = {
        RequirementsMet = requirementsMet,
        ComponentId = nodeData.ComponentId or "unknown",
        ComponentName = component.Name,
        SequencePosition = webContext.NodeIndex[nodeData] or 0
    }
    
    if not requirementsMet then
        -- Component doesn't activate, return inactive result
        result.Damage = 0
        result.DamageType = "None" 
        result.Effects = {}
        result.Active = false
        result.FailureReason = "Requirements not met"
        return result
    end
    
    -- Requirements met, execute component ability
    result.Active = true
    
    if component.Type == SynergyComponentsDB.ComponentTypes.CORE or 
       component.Type == SynergyComponentsDB.ComponentTypes.ARTIFACT then
        -- Execute damage/effect abilities
        if component.Ability and component.Ability.Execute then
            local abilityResult = component.Ability.Execute(nodeData, webContext)
            
            -- Merge ability result into main result
            for key, value in pairs(abilityResult) do
                result[key] = value
            end
        end
        
    elseif component.Type == SynergyComponentsDB.ComponentTypes.MODIFIER or
           component.Type == SynergyComponentsDB.ComponentTypes.CHAIN then
        -- Execute web modification abilities
        if component.Ability and component.Ability.ModifyWeb then
            local modifyResult = component.Ability.ModifyWeb(nodeData, webContext)
            
            -- Merge modification result
            for key, value in pairs(modifyResult) do
                result[key] = value
            end
        end
    end
    
    return result
end

-- Helper to create proper webContext for sequential evaluation
function SynergyComponentsDB.CreateWebContext(orderedNodeList)
    local webContext = {
        AllNodes = {},
        OrderedNodes = orderedNodeList,
        NodeIndex = {}
    }
    
    -- Build AllNodes and NodeIndex from ordered list
    for index, node in pairs(orderedNodeList) do
        table.insert(webContext.AllNodes, node)
        webContext.NodeIndex[node] = index
    end
    
    return webContext
end

-- Simulate a full sequence evaluation (useful for testing)
function SynergyComponentsDB.SimulateSequence(orderedComponents)
    -- orderedComponents should be a table like:
    -- {
    --   {ComponentId = "ember_core", Rarity = "COMMON", ...},
    --   {ComponentId = "chain_link", Rarity = "UNCOMMON", ...},
    --   ...
    -- }
    
    local webContext = SynergyComponentsDB.CreateWebContext(orderedComponents)
    local results = {}
    
    -- Phase 1: Evaluate all modifiers first (they affect the web state)
    for index, nodeData in pairs(webContext.OrderedNodes) do
        local component = SynergyComponentsDB.GetComponent(nodeData.ComponentId)
        if component and (component.Type == SynergyComponentsDB.ComponentTypes.MODIFIER or 
                         component.Type == SynergyComponentsDB.ComponentTypes.CHAIN) then
            local result = SynergyComponentsDB.EvaluateComponent(component, nodeData, webContext)
            results[index] = result
        end
    end
    
    -- Phase 2: Evaluate cores and artifacts (they generate damage/effects)
    for index, nodeData in pairs(webContext.OrderedNodes) do
        local component = SynergyComponentsDB.GetComponent(nodeData.ComponentId)
        if component and (component.Type == SynergyComponentsDB.ComponentTypes.CORE or
                         component.Type == SynergyComponentsDB.ComponentTypes.ARTIFACT) then
            local result = SynergyComponentsDB.EvaluateComponent(component, nodeData, webContext)
            results[index] = result
        end
    end
    
    -- Calculate total damage and effects
    local totalDamage = 0
    local allEffects = {}
    local activeComponents = 0
    
    for index, result in pairs(results) do
        if result and result.Active then
            activeComponents = activeComponents + 1
            if result.Damage then
                totalDamage = totalDamage + result.Damage
            end
            if result.Effects then
                for _, effect in pairs(result.Effects) do
                    table.insert(allEffects, effect)
                end
            end
        end
    end
    
    return {
        IndividualResults = results,
        TotalDamage = totalDamage,
        AllEffects = allEffects,
        ActiveComponents = activeComponents,
        SequenceLength = #webContext.OrderedNodes,
        WebContext = webContext
    }
end

-- Get all components of a specific type
function SynergyComponentsDB.GetComponentsByType(componentType)
    local results = {}
    for id, component in pairs(SynergyComponentsDB.Components) do
        if component.Type == componentType then
            results[id] = component
        end
    end
    return results
end

-- Get all components with a specific tag
function SynergyComponentsDB.GetComponentsByTag(tag)
    local results = {}
    for id, component in pairs(SynergyComponentsDB.Components) do
        if table.find(component.Tags, tag) then
            results[id] = component
        end
    end
    return results
end

-- Validate component data structure (updated to include Requirements)
function SynergyComponentsDB.ValidateComponent(component)
    local required = {"Name", "Type", "Rarity", "Description", "BaseStats", "Tags", "Ability"}
    
    for _, field in pairs(required) do
        if not component[field] then
            return false, "Missing required field: " .. field
        end
    end
    
    -- Validate type
    local validType = false
    for _, validTypeValue in pairs(SynergyComponentsDB.ComponentTypes) do
        if component.Type == validTypeValue then
            validType = true
            break
        end
    end
    
    if not validType then
        return false, "Invalid component type: " .. tostring(component.Type)
    end
    
    -- Validate rarity
    if not SynergyComponentsDB.Rarities[component.Rarity] then
        return false, "Invalid rarity: " .. tostring(component.Rarity)
    end
    
    -- Validate requirements if present
    if component.Requirements then
        for i, requirement in pairs(component.Requirements) do
            if not requirement.Type then
                return false, "Requirement " .. i .. " missing Type field"
            end
            
            -- Validate requirement type
            local validReqType = false
            for _, validType in pairs(SynergyComponentsDB.RequirementTypes) do
                if requirement.Type == validType then
                    validReqType = true
                    break
                end
            end
            
            if not validReqType then
                return false, "Invalid requirement type: " .. tostring(requirement.Type)
            end
            
            -- Validate requirement-specific fields
            if requirement.Type == SynergyComponentsDB.RequirementTypes.CUSTOM and not requirement.CustomFunction then
                return false, "Custom requirement missing CustomFunction"
            end
        end
    end
    
    return true, "Valid"
end

-- Helper function to get components that can activate in a given sequence context
function SynergyComponentsDB.GetActiveComponents(webContext)
    local activeComponents = {}
    local inactiveComponents = {}
    
    for index, nodeData in pairs(webContext.OrderedNodes) do
        local component = SynergyComponentsDB.GetComponent(nodeData.ComponentId)
        if component then
            local requirementsMet = SynergyComponentsDB.EvaluateRequirements(component, nodeData, webContext)
            
            if requirementsMet then
                table.insert(activeComponents, {
                    NodeData = nodeData,
                    Component = component,
                    SequencePosition = index
                })
            else
                table.insert(inactiveComponents, {
                    NodeData = nodeData,
                    Component = component,
                    SequencePosition = index,
                    Reason = "Requirements not met"
                })
            end
        end
    end
    
    return {
        Active = activeComponents,
        Inactive = inactiveComponents
    }
end

-- Example usage and testing helper
function SynergyComponentsDB.CreateExampleSequence()
    -- Creates a sample 5-component sequence for testing
    return {
        {ComponentId = "vanguard_core", Rarity = "UNCOMMON", EvolutionLevel = 0},
        {ComponentId = "chain_link", Rarity = "COMMON", EvolutionLevel = 0},
        {ComponentId = "ember_core", Rarity = "COMMON", EvolutionLevel = 0},
        {ComponentId = "elemental_conductor", Rarity = "RARE", EvolutionLevel = 0},
        {ComponentId = "finale_artifact", Rarity = "EPIC", EvolutionLevel = 0}
    }
end

return SynergyComponentsDB