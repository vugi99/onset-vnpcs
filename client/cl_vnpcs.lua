
local loaded
local vnpcs_actors = {}
local vehicles_targets = {}
local players_targets = {}
local fake_targets = {}

local sync_timers = {}

local function IsStreamedNPC(npc)
    for i, v in ipairs(GetStreamedNPC()) do
        if v == npc then
            return true
        end
    end
    return false
end

local function GetVNPC_tbl_From_npc(npc)
    for i, v in ipairs(vnpcs_actors) do
        if v.npc == npc then
            return i
        end
    end
end

local function GetVehTarget_From_veh(veh)
    for i, v in ipairs(vehicles_targets) do
        if v.veh == veh then
            return i
        end
    end
end

local function GetFakeTarget_From_npc(npc)
    for i, v in ipairs(fake_targets) do
        if v.npc == npc then
            return i
        end
    end
end

local function GetFakeTarget_From_veh(veh)
    for i, v in ipairs(fake_targets) do
        local pathfinding_property = GetNPCPropertyValue(v.npc, "vnpc_pathfinding_move_data")
        if pathfinding_property then
            if pathfinding_property.target_type == "vehicle" then
                if pathfinding_property.target[1] == veh then
                    return i, pathfinding_property
                end
            end
        end
    end
end

local function GetFakeTarget_From_ply(ply)
    for i, v in ipairs(fake_targets) do
        local pathfinding_property = GetNPCPropertyValue(v.npc, "vnpc_pathfinding_move_data")
        if pathfinding_property then
            if pathfinding_property.target_type == "player" then
                if pathfinding_property.target[1] == ply then
                    return i, pathfinding_property
                end
            end
        end
    end
end

local function GetPlyTarget_From_ply(ply)
    for i, v in ipairs(players_targets) do
        if v.ply == ply then
            return i
        end
    end
end

local function GetTimer_Sync_tbl_From_npc(npc)
    for i, v in ipairs(sync_timers) do
        if v.npc == npc then
            return i
        end
    end
end

local function DestroySyncTimer(npc)
    local index = GetTimer_Sync_tbl_From_npc(npc)
    if index then
        DestroyTimer(sync_timers[index].timer)
        table.remove(sync_timers, index)
        return true
    end
    return false
end

local function PlayerFollowedByNPC(ply, npc)
    local pathfinding_property = GetNPCPropertyValue(npc, "vnpc_pathfinding_move_data")
    if pathfinding_property then
        if pathfinding_property.target_type == "player" then
            if pathfinding_property.target[1] == ply then
                return pathfinding_property
            end
        end
    end
    return false
end

local function CreatePlyTarget(ply)
    local vnpc_target_actor = GetWorld():SpawnActor(UClass.LoadFromAsset("/vnpcs/vnpc_target"), FVector(0, 0, 0), FRotator(0, 0, 0))
    local ply_actor = GetPlayerActor(ply)
    local atr = FAttachmentTransformRules(EAttachmentRule.SnapToTarget)
    vnpc_target_actor:AttachToActor(ply_actor, atr, "")
    ply_actor:ActorAddTag("npc_target_player")
    local success = vnpc_target_actor:ProcessEvent("InitPlayerTarget", ply)
    --AddPlayerChat("InitPlayerTarget " .. tostring(success))
    local tbl = {
        ply = ply,
        vnpc_target_actor = vnpc_target_actor
    }
    table.insert(players_targets, tbl)
end

local function InitVNPCForNPC(npc)
    local vnpc_actor = GetWorld():SpawnActor(UClass.LoadFromAsset("/vnpcs/vnpc"), FVector(0, 0, 0), FRotator(0, 0, 0))
    local npc_actor = GetNPCActor(npc)
    local atr = FAttachmentTransformRules(EAttachmentRule.SnapToTarget)
    vnpc_actor:AttachToActor(npc_actor, atr, "")
    local success = vnpc_actor:ProcessEvent("InitVNPC", npc)
    if vnpcs_debug then
        AddPlayerChat("InitVNPC " .. tostring(success))
    end
    local tbl = {
        npc = npc,
        vnpc_actor = vnpc_actor,
    }
    table.insert(vnpcs_actors, tbl)
end

local function TryDefaultToPathfinding(npc)
    if (GetWorld():GetMapName() == "Island" and vnpcs_default_to_pathfinding) then
        local npc_actor = GetNPCActor(npc)
        local loc = npc_actor:GetActorLocation()
        local x, y, z = loc.X, loc.Y, loc.Z
        local bResult, HitsResult = UKismetSystemLibrary.LineTraceMulti(npc_actor, FVector(x, y, z), FVector(x, y, -100), UEngineTypes.ConvertToTraceType(ECollisionChannel.ECC_GameTraceChannel3), true, {}, EDrawDebugTrace.ForDuration, true, FLinearColor(1.0, 0.0, 0.0, 1.0), FLinearColor(0.0, 1.0, 0.0, 1.0), 10.0)
        local found_ground = false
        for i, v in ipairs(HitsResult) do
            local comp_name = v:GetComponent():GetName()
            if (comp_name ~= "PostProcessShape" and comp_name ~= "InteractionShape" and comp_name ~= "BrushComponent0" and comp_name ~= "TriggerCollision") then
                found_ground = true
                CallRemoteEvent("VNPC_Default_To_Pathfinding", npc, v.Location.X, v.Location.Y, v.Location.Z)
                break
            end
        end
        if not found_ground then
            local nearest_dist
            local nearest_loc
            local bResult, HitsResult = UKismetSystemLibrary.LineTraceMulti(npc_actor, FVector(x, y, z + 25000), FVector(x, y, z), UEngineTypes.ConvertToTraceType(ECollisionChannel.ECC_GameTraceChannel3), true, {}, EDrawDebugTrace.ForDuration, true, FLinearColor(1.0, 0.0, 0.0, 1.0), FLinearColor(0.0, 1.0, 0.0, 1.0), 10.0)
            for i, v in ipairs(HitsResult) do
                local comp_name = v:GetComponent():GetName()
                if (comp_name ~= "PostProcessShape" and comp_name ~= "InteractionShape" and comp_name ~= "BrushComponent0" and comp_name ~= "TriggerCollision") then
                    found_ground = true
                    local dist = v.Location.Z - z
                    if dist > 0 then
                        if not nearest_dist then
                            nearest_dist = dist
                            nearest_loc = v.Location
                        elseif dist < nearest_dist then
                            nearest_dist = dist
                            nearest_loc = v.Location
                        end
                    end
                end
            end
            if found_ground then
                CallRemoteEvent("VNPC_Default_To_Pathfinding", npc, nearest_loc.X, nearest_loc.Y, nearest_loc.Z)
            end
        end
    end
end
--[[local function TryDefaultToPathfinding_test()
    if (GetWorld():GetMapName() == "Island" and vnpcs_default_to_pathfinding) then
        local npc_actor = GetPlayerActor(GetPlayerId())
        local loc = npc_actor:GetActorLocation()
        local x, y, z = loc.X, loc.Y, loc.Z
        local bResult, HitsResult = UKismetSystemLibrary.LineTraceMulti(npc_actor, FVector(x, y, z), FVector(x, y, -100), UEngineTypes.ConvertToTraceType(ECollisionChannel.ECC_GameTraceChannel3), true, {}, EDrawDebugTrace.ForDuration, true, FLinearColor(1.0, 0.0, 0.0, 1.0), FLinearColor(0.0, 1.0, 0.0, 1.0), 10.0)
        local found_ground = false
        for i, v in ipairs(HitsResult) do
            local comp_name = v:GetComponent():GetName()
            AddPlayerChat(comp_name)
            if (comp_name ~= "PostProcessShape" and comp_name ~= "InteractionShape" and comp_name ~= "BrushComponent0" and comp_name ~= "TriggerCollision") then
                found_ground = true
                GetPlayerActor(GetPlayerId()):SetActorLocation(v.Location + FVector(0, 0, 100))
                break
            end
        end
        if not found_ground then
            local nearest_dist
            local nearest_loc
            local bResult, HitsResult = UKismetSystemLibrary.LineTraceMulti(npc_actor, FVector(x, y, z + 25000), FVector(x, y, z), UEngineTypes.ConvertToTraceType(ECollisionChannel.ECC_GameTraceChannel3), true, {}, EDrawDebugTrace.ForDuration, true, FLinearColor(1.0, 0.0, 0.0, 1.0), FLinearColor(0.0, 1.0, 0.0, 1.0), 10.0)
            for i, v in ipairs(HitsResult) do
                local comp_name = v:GetComponent():GetName()
                AddPlayerChat(comp_name .. " 2")
                if (comp_name ~= "PostProcessShape" and comp_name ~= "InteractionShape" and comp_name ~= "BrushComponent0" and comp_name ~= "TriggerCollision") then
                    found_ground = true
                    local dist = v.Location.Z - z
                    if dist > 0 then
                        if not nearest_dist then
                            nearest_dist = dist
                            nearest_loc = v.Location
                        elseif dist < nearest_dist then
                            nearest_dist = dist
                            nearest_loc = v.Location
                        end
                    end
                end
            end
            if found_ground then
                GetPlayerActor(GetPlayerId()):SetActorLocation(nearest_loc + FVector(0, 0, 100))
            end
        end
        AddPlayerChat("done")
    end
end

AddCommand("try", function()
    TryDefaultToPathfinding_test()
end)]]--

local function SetVNPCTargetLocation(npc, x, y, z, acceptance_radius)
    local index = GetVNPC_tbl_From_npc(npc)
    if (index and x and y and z) then
        local tbl = vnpcs_actors[index]
        local vnpc_actor = tbl.vnpc_actor
        if vnpc_actor:IsValid() then
            local success = vnpc_actor:ProcessEvent("MoveToLoc", x, y, z, acceptance_radius)
            if vnpcs_debug then
                AddPlayerChat("SetVNPCTargetLocation, success : " .. tostring(success))
            end
            return success
        end
    end
end

local function CreateFakeTarget(npc, x, y, z, acceptance_radius)
    local tbl = {
        npc = npc,
        fake_target_location = {x, y, z},
    }
    table.insert(fake_targets, tbl)
    SetVNPCTargetLocation(npc, x, y, z, acceptance_radius)
end

local function DestroyPlyTarget(ply, streamout)
    local index = GetPlyTarget_From_ply(ply)
    if index then
        local tbl = players_targets[index]
        local vnpc_target_actor = tbl.vnpc_target_actor
        if vnpc_target_actor:IsValid() then
            if streamout then
                local loc = vnpc_target_actor:GetActorLocation()
                local x, y, z = loc.X, loc.Y, loc.Z
                for i, v in ipairs(GetStreamedNPC()) do
                    local pathfinding_property = GetNPCPropertyValue(v, "vnpc_pathfinding_move_data")
                    if pathfinding_property then
                        if pathfinding_property.target_type == "player" then
                            if pathfinding_property.target[1] == ply then
                                CreateFakeTarget(v, x, y, z, pathfinding_property.target[2])
                            end
                        end
                    end
                end
            end
            vnpc_target_actor:Destroy()
        end
        table.remove(players_targets, index)
    end
end

local function SetVNPCFollowVehicle(npc, veh, acceptance_radius)
    local index = GetVNPC_tbl_From_npc(npc)
    if (index and veh) then
        local tbl = vnpcs_actors[index]
        local vnpc_actor = tbl.vnpc_actor
        if vnpc_actor:IsValid() then
            local success = vnpc_actor:ProcessEvent("FollowVehicle", veh, acceptance_radius)
            if vnpcs_debug then
                AddPlayerChat("SetVNPCFollowVehicle, success : " .. tostring(success))
            end
            return success
        end
    end
end

local function SetVNPCFollowPlayer(npc, ply, acceptance_radius)
    local index = GetVNPC_tbl_From_npc(npc)
    if (index and ply) then
        local tbl = vnpcs_actors[index]
        local vnpc_actor = tbl.vnpc_actor
        if vnpc_actor:IsValid() then
            local success = vnpc_actor:ProcessEvent("FollowPlayer", ply, acceptance_radius)
            if vnpcs_debug then
                AddPlayerChat("SetVNPCFollowPlayer, success : " .. tostring(success))
            end
            return success
        end
    end
end

local function StopVNPC(npc)
    local index = GetVNPC_tbl_From_npc(npc)
    if index then
        local tbl = vnpcs_actors[index]
        local vnpc_actor = tbl.vnpc_actor
        if vnpc_actor:IsValid() then
            local success = vnpc_actor:ProcessEvent("Stop")
            if vnpcs_debug then
                AddPlayerChat("StopVNPC, success : " .. tostring(success))
            end
            return success
        end
    end
end

local function Sync_NPC(npc)
    local npc_actor = GetNPCActor(npc)
    local loc = npc_actor:GetActorLocation()
    local x, y, z = loc.X, loc.Y, loc.Z
    local rot = npc_actor:GetActorRotation()
    local h = rot.Yaw
    CallRemoteEvent("VNPCS_SyncNPC", npc, x, y, z, h)
end

local function Handle_vnpc_pathfinding_move_data(npc, pval)
    if vnpcs_debug then
        AddPlayerChat("OnNPCNetworkUpdatePropertyValue, vnpc_pathfinding_move_data")
    end
    if pval then
        if pval.target_type == "location" then
            SetVNPCTargetLocation(npc, pval.target[1], pval.target[2], pval.target[3], pval.target[4])
        elseif pval.target_type == "vehicle" then
            if IsValidVehicle(pval.target[1]) then
                SetVNPCFollowVehicle(npc, pval.target[1], pval.target[2])
            else
                CreateFakeTarget(npc, pval.target_start_loc[1], pval.target_start_loc[2], pval.target_start_loc[3], pval.target[2])
            end
        elseif pval.target_type == "player" then
            if IsValidPlayer(pval.target[1]) then
                SetVNPCFollowPlayer(npc, pval.target[1], pval.target[2])
            else
                CreateFakeTarget(npc, pval.target_start_loc[1], pval.target_start_loc[2], pval.target_start_loc[3], pval.target[2])
            end
        end
        return true
    end
end

AddEvent("OnPackageStart", function()
    loaded = LoadPak("vnpcs", "/vnpcs/", "../../../OnsetModding/Plugins/vnpcs/Content")
    if not loaded then
        print("[VNPCS] : pak loading failed")
    else
        print("[VNPCS] : pak loaded")
    end
    for i, v in ipairs(GetStreamedNPC()) do
        InitVNPCForNPC(v)
    end
end)

AddEvent("OnNPCStreamIn", function(npc)
    InitVNPCForNPC(npc)
    local has_data = Handle_vnpc_pathfinding_move_data(npc, GetNPCPropertyValue(npc, "vnpc_pathfinding_move_data"))
    if not has_data then
        if GetNPCPropertyValue(npc, "vnpc_moving_default") then
            TryDefaultToPathfinding(npc)
        end
    end
end)

AddEvent("OnNPCStreamOut", function(npc)
    local index = GetVNPC_tbl_From_npc(npc)
    if index then
        local tbl = vnpcs_actors[index]
        local vnpc_actor = tbl.vnpc_actor
        if vnpc_actor:IsValid() then
            local loc = vnpc_actor:GetActorLocation()
            local x, y, z = loc.X, loc.Y, loc.Z
            local rot = vnpc_actor:GetActorRotation()
            local h = rot.Yaw
            local destroyed = DestroySyncTimer(npc)
            if (destroyed and x and y and z) then
                if vnpcs_debug then
                    AddPlayerChat("VNPCS_SyncStop in OnNPCStreamOut, h : " .. tostring(h))
                end
                CallRemoteEvent("VNPCS_SyncStop", npc, x, y, z, h)
            end
            vnpc_actor:Destroy()
        end
        table.remove(vnpcs_actors, index)
    end
end)

AddEvent("OnVehicleStreamIn", function(veh)
    local vnpc_target_actor = GetWorld():SpawnActor(UClass.LoadFromAsset("/vnpcs/vnpc_target"), FVector(0, 0, 0), FRotator(0, 0, 0))
    local veh_actor = GetVehicleActor(veh)
    local atr = FAttachmentTransformRules(EAttachmentRule.SnapToTarget)
    vnpc_target_actor:AttachToActor(veh_actor, atr, "")
    veh_actor:ActorAddTag("npc_target_vehicle")
    local success = vnpc_target_actor:ProcessEvent("InitVehTarget", veh)
    --AddPlayerChat("InitVehTarget " .. tostring(success))
    local tbl = {
        veh = veh,
        vnpc_target_actor = vnpc_target_actor
    }
    table.insert(vehicles_targets, tbl)
    local i, pathfinding_property = GetFakeTarget_From_veh(veh)
    if i then
        SetVNPCFollowVehicle(fake_targets[i].npc, pathfinding_property.target[1], pathfinding_property.target[2])
        table.remove(fake_targets, i)
    end
end)

AddEvent("OnVehicleStreamOut", function(veh)
    local index = GetVehTarget_From_veh(veh)
    if index then
        local tbl = vehicles_targets[index]
        local vnpc_target_actor = tbl.vnpc_target_actor
        if vnpc_target_actor:IsValid() then
            local loc = vnpc_target_actor:GetActorLocation()
            local x, y, z = loc.X, loc.Y, loc.Z
            for i, v in ipairs(GetStreamedNPC()) do
                local pathfinding_property = GetNPCPropertyValue(v, "vnpc_pathfinding_move_data")
                if pathfinding_property then
                    if pathfinding_property.target_type == "vehicle" then
                        if pathfinding_property.target[1] == veh then
                            CreateFakeTarget(v, x, y, z, pathfinding_property.target[2])
                        end
                    end
                end
            end
            vnpc_target_actor:Destroy()
        end
        table.remove(vehicles_targets, index)
    end
end)

AddEvent("OnPlayerStreamIn", function(ply)
    CreatePlyTarget(ply)
    local i, pathfinding_property = GetFakeTarget_From_ply(ply)
    if i then
        SetVNPCFollowPlayer(fake_targets[i].npc, pathfinding_property.target[1], pathfinding_property.target[2])
        table.remove(fake_targets, i)
    end
end)

AddEvent("OnPlayerStreamOut", function(ply)
    DestroyPlyTarget(ply, true)
end)

AddEvent("OnPlayerSpawn", function()
    DestroyPlyTarget(GetPlayerId())
    CreatePlyTarget(GetPlayerId())
    for i, v in ipairs(GetStreamedNPC()) do
        local pathfinding_property = PlayerFollowedByNPC(GetPlayerId(), v)
        if pathfinding_property then
            SetVNPCFollowPlayer(v, GetPlayerId(), pathfinding_property.target[2])
        end
    end
end)

AddEvent("OnNPCNetworkUpdatePropertyValue", function(npc, pname, pval)
    if IsStreamedNPC(npc) then
        if pname == "vnpc_pathfinding_move_data" then
            Handle_vnpc_pathfinding_move_data(npc, pval)
        elseif pname == "vnpc_sync_player" then
            if vnpcs_debug then
                AddPlayerChat("OnNPCNetworkUpdatePropertyValue, vnpc_sync_player")
            end
            if pval then
                if pval == GetPlayerId() then
                    local destroyed = DestroySyncTimer(npc)
                    local tbl = {
                        npc = npc,
                        timer = CreateTimer(Sync_NPC, vnpcs_sync_interval_ms, npc)
                    }
                    table.insert(sync_timers, tbl)
                end
            end
        end
    end
end)

AddEvent("VNPC_MoveTo_Success", function(arg)
    if vnpcs_debug then
        AddPlayerChat("VNPC_MoveTo_Success " .. arg)
    end
    local npc = tonumber(arg)
    local destroyed = DestroySyncTimer(npc)
    if destroyed then
        local npc_actor = GetNPCActor(npc)
        local loc = npc_actor:GetActorLocation()
        local x, y, z = loc.X, loc.Y, loc.Z
        CallRemoteEvent("VNPCS_Pathfinding_success", npc, x, y, z, GetNPCHeading(npc))
    end
end)

AddEvent("VNPC_MoveTo_Failed", function(arg)
    if vnpcs_debug then
        AddPlayerChat("VNPC_MoveTo_Failed " .. arg)
    end
    local npc = tonumber(arg)
    local destroyed = DestroySyncTimer(npc)
    if destroyed then
        local npc_actor = GetNPCActor(npc)
        local loc = npc_actor:GetActorLocation()
        local x, y, z = loc.X, loc.Y, loc.Z
        CallRemoteEvent("VNPCS_Pathfinding_failed", npc, x, y, z, GetNPCHeading(npc))
    end
end)

AddEvent("VNPC_MoveEvent_Called", function(npc)
    --AddPlayerChat("VNPC_MoveEvent_Called " .. npc)
    npc = tonumber(npc)
end)

AddRemoteEvent("StopVNPC", function(npc)
    if IsStreamedNPC(npc) then
        local i = GetFakeTarget_From_npc(npc)
        if i then
            table.remove(fake_targets, i)
        end
        StopVNPC(npc)
        local npc_actor = GetNPCActor(npc)
        local loc = npc_actor:GetActorLocation()
        local x, y, z = loc.X, loc.Y, loc.Z
        local destroyed = DestroySyncTimer(npc)
        if destroyed then
            local rot = npc_actor:GetActorRotation()
            local h = rot.Yaw
            CallRemoteEvent("VNPCS_SyncStop", npc, x, y, z, h)
        end
    end
end)

AddRemoteEvent("UpdateFakeTarget", function(npc, x, y, z)
    if IsStreamedNPC(npc) then
        local i = GetFakeTarget_From_npc(npc)
        local pathfinding_property = GetNPCPropertyValue(npc, "vnpc_pathfinding_move_data")
        if (i and pathfinding_property) then
            if GetDistanceSquared3D(x, y, z, fake_targets[i].fake_target_location[1], fake_targets[i].fake_target_location[2], fake_targets[i].fake_target_location[3]) > 1000000 then
                SetVNPCTargetLocation(npc, x, y, z, pathfinding_property.target[2])
                fake_targets[i].fake_target_location = {x, y, z}
            end
        end
    end
end)