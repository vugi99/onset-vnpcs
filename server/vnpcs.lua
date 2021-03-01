
local vnpcs = {}

local function IsNPCStreamed(npc, no_ply)
    for i, v in ipairs(GetAllPlayers()) do
        if (v ~= no_ply and IsNPCStreamedIn(v, npc)) then
            return true
        end
    end
    return false
end

local function GetVnpcIndex(npc)
    for i, v in ipairs(vnpcs) do
        if v.npc == npc then
            return i
        end
    end
    return false
end

local function CheckToCreateVNPC(npc)
    local i = GetVnpcIndex(npc)
    if not i then
        Init_VNPC(npc)
    end
end

local function UpdateTargetLocationForFollow()
    for i, v in ipairs(vnpcs) do
        if (v.move.target_type == "vehicle") then
            local x, y, z = GetVehicleLocation(v.move.target[1])
            for i2, ply in ipairs(GetAllPlayers()) do
                if (IsNPCStreamedIn(ply, v.npc) and not IsVehicleStreamedIn(ply, v.move.target[1])) then
                    CallRemoteEvent(ply, "UpdateFakeTarget", v.npc, x, y, z)
                end
            end
        elseif (v.move.target_type == "player") then
            local x, y, z = GetPlayerLocation(v.move.target[1])
            for i2, ply in ipairs(GetAllPlayers()) do
                if (IsNPCStreamedIn(ply, v.npc) and not IsPlayerStreamedIn(ply, v.move.target[1])) then
                    CallRemoteEvent(ply, "UpdateFakeTarget", v.npc, x, y, z)
                end
            end
        end
    end
end

local function check_pathfinding_to_default(i, npc)
    if vnpcs[i].move.type then
        if vnpcs[i].move.type == "pathfinding" then
            for i2, v in ipairs(GetAllPlayers()) do
                if IsNPCStreamedIn(v, npc) then
                    CallRemoteEvent(v, "StopVNPC", npc)
                end
            end
        end
    end
end

local function ResetVNPCPathfindingPropertyValues(npc)
    SetNPCPropertyValue(npc, "vnpc_pathfinding_move_data", nil, true)
    SetNPCPropertyValue(npc, "vnpc_sync_player", nil, true)
end

local function ResetVNPCDefaultPropertyValue(npc)
    SetNPCPropertyValue(npc, "vnpc_moving_default", nil, true)
end

local function VNPCTargetLocation_pathfinding(npc, x, y, z, acceptance_radius, i)
    local tbl = {type = "pathfinding", target_type = "location", target = {x, y, z, acceptance_radius}}
    local nx, ny, nz = GetNPCLocation(npc)
    if vnpcs[i].move.type then
        if vnpcs[i].move.type == "default" then
            vnpcs[i].move = tbl
            SetNPCTargetLocation(npc, nx, ny, nz, 400.0)
        else
            vnpcs[i].move = tbl
        end
    else
        vnpcs[i].move = tbl
    end
    vnpcs[i].sync_player = GetNearestPlayer2D(nx, ny)
    ResetVNPCDefaultPropertyValue(npc)
    SetNPCPropertyValue(npc, "vnpc_pathfinding_move_data", vnpcs[i].move, true)
    SetNPCPropertyValue(npc, "vnpc_sync_player", vnpcs[i].sync_player, true)
end

local function VNPCTargetLocation_default(npc, x, y, z, acceptance_radius, i, no_pathfinding_check)
    if not no_pathfinding_check then
        check_pathfinding_to_default(i, npc)
    end
    vnpcs[i].move = {type = "default", target_type = "location", target = {x, y, z, acceptance_radius}}
    vnpcs[i].sync_player = 0
    ResetVNPCPathfindingPropertyValues(npc)
    SetNPCPropertyValue(npc, "vnpc_moving_default", true, true)
    SetNPCTargetLocation(npc, x, y, z, 400.0)
end

local function VNPCFollowVehicle_pathfinding(npc, veh, acceptance_radius, i)
    local x, y, z = GetVehicleLocation(veh)
    local tbl = {type = "pathfinding", target_type = "vehicle", target = {veh, acceptance_radius}, target_start_loc = {x, y, z}}
    local nx, ny, nz = GetNPCLocation(npc)
    if vnpcs[i].move.type then
        if vnpcs[i].move.type == "default" then
            vnpcs[i].move = tbl
            SetNPCTargetLocation(npc, nx, ny, nz, 400.0)
        else
            vnpcs[i].move = tbl
        end
    else
        vnpcs[i].move = tbl
    end
    vnpcs[i].sync_player = GetNearestPlayer2D(nx, ny)
    ResetVNPCDefaultPropertyValue(npc)
    SetNPCPropertyValue(npc, "vnpc_pathfinding_move_data", vnpcs[i].move, true)
    SetNPCPropertyValue(npc, "vnpc_sync_player", vnpcs[i].sync_player, true)
end

local function VNPCFollowVehicle_default(npc, veh, acceptance_radius, i, no_pathfinding_check)
    if not no_pathfinding_check then
        check_pathfinding_to_default(i, npc)
    end
    vnpcs[i].move = {type = "default", target_type = "vehicle", target = {veh, acceptance_radius}}
    vnpcs[i].sync_player = 0
    ResetVNPCPathfindingPropertyValues(npc)
    SetNPCPropertyValue(npc, "vnpc_moving_default", true, true)
    SetNPCFollowVehicle(npc, veh, 400.0)
end

local function VNPCFollowPlayer_pathfinding(npc, ply, acceptance_radius, i)
    local nx, ny, nz = GetNPCLocation(npc)
    local x, y, z = GetPlayerLocation(ply)
    local tbl = {type = "pathfinding", target_type = "player", target = {ply, acceptance_radius}, target_start_loc = {x, y, z}}
    if vnpcs[i].move.type then
        if vnpcs[i].move.type == "default" then
            vnpcs[i].move = tbl
            SetNPCTargetLocation(npc, nx, ny, nz, 400.0)
        else
            vnpcs[i].move = tbl
        end
    else
        vnpcs[i].move = tbl
    end
    vnpcs[i].sync_player = GetNearestPlayer2D(nx, ny)
    ResetVNPCDefaultPropertyValue(npc)
    SetNPCPropertyValue(npc, "vnpc_pathfinding_move_data", vnpcs[i].move, true)
    SetNPCPropertyValue(npc, "vnpc_sync_player", vnpcs[i].sync_player, true)
end

local function VNPCFollowPlayer_default(npc, ply, acceptance_radius, i, no_pathfinding_check)
    if not no_pathfinding_check then
        check_pathfinding_to_default(i, npc)
    end
    vnpcs[i].move = {type = "default", target_type = "player", target = {ply, acceptance_radius}}
    vnpcs[i].sync_player = 0
    ResetVNPCPathfindingPropertyValues(npc)
    SetNPCPropertyValue(npc, "vnpc_moving_default", true, true)
    SetNPCFollowPlayer(npc, ply, 400.0)
end

function StopVNPC(npc)
    if npc then
        local index = GetVnpcIndex(npc)
        if index then
            if vnpcs[index].move.type then
                if vnpcs[index].move.type == "pathfinding" then
                    for i, v in ipairs(GetAllPlayers()) do
                        if IsNPCStreamedIn(v, npc) then
                            CallRemoteEvent(v, "StopVNPC", npc)
                        end
                    end
                    vnpcs[index].last_sync_player = vnpcs[index].sync_player
                    vnpcs[index].sync_player = 0
                    ResetVNPCPathfindingPropertyValues(npc)
                    vnpcs[index].move = {}
                elseif vnpcs[index].move.type == "default" then
                    ResetVNPCDefaultPropertyValue(npc)
                    vnpcs[index].move = {}
                    local x, y, z = GetNPCLocation(npc)
                    SetNPCTargetLocation(npc, x, y, z, 400.0)
                end
            end
            return true
        end
    end
    return false
end
AddFunctionExport("StopVNPC", StopVNPC)

function SetVNPCTargetLocation(npc, x, y, z, acceptance_radius)
    if (npc and x and y and z) then
        acceptance_radius = acceptance_radius or 5.0
        if IsValidNPC(npc) then
            if (type(x) == "number" and type(y) == "number" and type(z) == "number" and type(acceptance_radius) == "number") then
                if not IsVNPCRagdoll(npc) then
                    CheckToCreateVNPC(npc)
                    local i = GetVnpcIndex(npc)
                    if i then
                        if IsNPCStreamed(npc) then
                            VNPCTargetLocation_pathfinding(npc, x, y, z, acceptance_radius, i)
                        else
                            VNPCTargetLocation_default(npc, x, y, z, acceptance_radius, i)
                        end
                        return true
                    end
                end
            end
        end
    end
    return false
end
AddFunctionExport("SetVNPCTargetLocation", SetVNPCTargetLocation)

function SetVNPCFollowVehicle(npc, veh, acceptance_radius)
    if (npc and veh) then
        acceptance_radius = acceptance_radius or 5.0
        if IsValidNPC(npc) then
            if IsValidVehicle(veh) then
                if not IsVNPCRagdoll(npc) then
                    CheckToCreateVNPC(npc)
                    local i = GetVnpcIndex(npc)
                    if i then
                        if IsNPCStreamed(npc) then
                            VNPCFollowVehicle_pathfinding(npc, veh, acceptance_radius, i)
                        else
                            VNPCFollowVehicle_default(npc, veh, acceptance_radius, i)
                        end
                        return true
                    end
                end
            end
        end
    end
    return false
end
AddFunctionExport("SetVNPCFollowVehicle", SetVNPCFollowVehicle)

function SetVNPCFollowPlayer(npc, ply, acceptance_radius)
    if (npc and ply) then
        acceptance_radius = acceptance_radius or 5.0
        if IsValidNPC(npc) then
            if IsValidPlayer(ply) then
                if not IsVNPCRagdoll(npc) then
                    CheckToCreateVNPC(npc)
                    local i = GetVnpcIndex(npc)
                    if i then
                        if IsNPCStreamed(npc) then
                            VNPCFollowPlayer_pathfinding(npc, ply, acceptance_radius, i)
                        else
                            VNPCFollowPlayer_default(npc, ply, acceptance_radius, i)
                        end
                        return true
                    end
                end
            end
        end
    end
    return false
end
AddFunctionExport("SetVNPCFollowPlayer", SetVNPCFollowPlayer)

function IsVNPCMoving(npc)
    if npc then
        if IsValidNPC(npc) then
            local i = GetVnpcIndex(npc)
            if i then
                if vnpcs[i].move.type then
                    return true
                end
            end
        end
    end
    return false
end
AddFunctionExport("IsVNPCMoving", IsVNPCMoving)

function GetVNPCMoveType(npc)
    if npc then
        if IsValidNPC(npc) then
            local i = GetVnpcIndex(npc)
            if i then
                if vnpcs[i].move.type then
                    return vnpcs[i].move.type
                end
            end
        end
    end
    return false
end
AddFunctionExport("GetVNPCMoveType", GetVNPCMoveType)

function GetVNPCTargetType(npc)
    if npc then
        if IsValidNPC(npc) then
            local i = GetVnpcIndex(npc)
            if i then
                if vnpcs[i].move.target_type then
                    return vnpcs[i].move.target_type
                end
            end
        end
    end
    return false
end
AddFunctionExport("GetVNPCTargetType", GetVNPCTargetType)

function GetVNPCTarget(npc)
    if npc then
        if IsValidNPC(npc) then
            local i = GetVnpcIndex(npc)
            if i then
                if vnpcs[i].move.type then
                    if vnpcs[i].move.target_type == "location" then
                        return vnpcs[i].move.target[1], vnpcs[i].move.target[2], vnpcs[i].move.target[3]
                    elseif (vnpcs[i].move.target_type == "vehicle" or vnpcs[i].move.target_type == "player") then
                        return vnpcs[i].move.target[1]
                    end
                end
            end
        end
    end
    return false
end
AddFunctionExport("GetVNPCTarget", GetVNPCTarget)

function IsVNPCRagdoll(npc)
    if npc then
        if IsValidNPC(npc) then
            local i = GetVnpcIndex(npc)
            if i then
                return vnpcs[i].ragdoll
            end
        end
    end
end
AddFunctionExport("IsVNPCRagdoll", IsVNPCRagdoll)

function SetVNPCRagdoll(npc, rag)
    if (npc and (rag == true or rag == false)) then
        if IsValidNPC(npc) then
            CheckToCreateVNPC(npc)
            local i = GetVnpcIndex(npc)
            if i then
                if rag then
                    StopVNPC(npc)
                end
                SetNPCRagdoll(npc, rag)
                vnpcs[i].ragdoll = rag
                CallEvent("OnVNPCRagdoll", npc, rag)
                return true
            end
        end
    end
    return false
end
AddFunctionExport("SetVNPCRagdoll", SetVNPCRagdoll)

function Init_VNPC(npc)
    local tbl = {
        npc = npc,
        move = {},
        sync_player = 0,
        last_sync_player = 0,
        sync_stop = nil,
        death_stopped = nil,
        ragdoll = false
    }
    table.insert(vnpcs, tbl)
end

AddEvent("OnPackageStart", function()
    for i, v in ipairs(GetAllNPC()) do
        Init_VNPC(v)
    end
    CreateTimer(UpdateTargetLocationForFollow, vnpcs_target_location_follow_sync_interval_ms)
end)

AddEvent("OnNPCCreated", function(npc)
    CheckToCreateVNPC(npc)
end)

AddEvent("OnNPCDestroyed", function(npc)
    local index = GetVnpcIndex(npc)
    if index then
        table.remove(vnpcs, index)
    end
end)

AddRemoteEvent("VNPCS_SyncNPC", function(ply, npc, x, y, z, h)
    local sync_player_property = GetNPCPropertyValue(npc, "vnpc_sync_player")
    if sync_player_property then
        if sync_player_property == ply then
            if vnpcs_debug then
                print("VNPCS_SyncNPC", npc, x, y, z)
            end
            SetNPCLocation(npc, x, y, z)
            SetNPCHeading(npc, h)
        end
    end
end)

local function Check_end_pathfinding(ply, npc, x, y, z, h, success)
    local sync_player_property = GetNPCPropertyValue(npc, "vnpc_sync_player")
    if sync_player_property then
        if sync_player_property == ply then
            local i = GetVnpcIndex(npc)
            if i then
                vnpcs[i].move = {}
                vnpcs[i].sync_player = 0
            end
            ResetVNPCPathfindingPropertyValues(npc)
            if success then
                CallEvent("OnVNPCReachTarget", npc)
            else
                CallEvent("OnVNPCReachTargetFailed", npc)
            end
            SetNPCLocation(npc, x, y, z)
            SetNPCHeading(npc, h)
        end
    end
end

AddRemoteEvent("VNPCS_Pathfinding_success", function(ply, npc, x, y, z, h)
    Check_end_pathfinding(ply, npc, x, y, z, h, true)
end)

AddRemoteEvent("VNPCS_Pathfinding_failed", function(ply, npc, x, y, z, h)
    Check_end_pathfinding(ply, npc, x, y, z, h, false)
end)

AddEvent("OnNPCStreamOut", function(npc, ply)
    local index = GetVnpcIndex(npc)
    if index then
        if vnpcs[index].move.type then
            if vnpcs[index].move.type == "pathfinding" then
                if ply == vnpcs[index].sync_player then
                    if IsNPCStreamed(npc, ply) then
                        vnpcs[index].sync_player = GetNearestPlayer2D(nx, ny)
                        SetNPCPropertyValue(npc, "vnpc_sync_player", vnpcs[index].sync_player, true)
                    else
                        vnpcs[index].last_sync_player = ply
                        if vnpcs[index].move.target_type == "location" then
                            VNPCTargetLocation_default(npc, vnpcs[index].move.target[1], vnpcs[index].move.target[2], vnpcs[index].move.target[3], vnpcs[index].move.target[4], index, true)
                        elseif vnpcs[index].move.target_type == "vehicle" then
                            VNPCFollowVehicle_default(npc, vnpcs[index].move.target[1], vnpcs[index].move.target[2], index, true)
                        elseif vnpcs[index].move.target_type == "player" then
                            VNPCFollowPlayer_default(npc,vnpcs[index].move.target[1], vnpcs[index].move.target[2], index, true)
                        end
                    end
                end
            end
        end
    end
end)

AddRemoteEvent("VNPCS_SyncStop", function(ply, npc, x, y, z, h)
    local index = GetVnpcIndex(npc)
    if index then
        if vnpcs[index].last_sync_player == ply then
            SetNPCLocation(npc, x, y, z)
            SetNPCHeading(npc, h)
            vnpcs[index].last_sync_player = 0
            vnpcs[index].sync_stop = {x, y, z, h}
            if vnpcs_debug then
                print("VNPCS_SyncStop", npc, x, y, z, h)
            end
        end
    end
end)

AddEvent("OnNPCDeath", function(npc, ply)
    local index = GetVnpcIndex(npc)
    if index then
        if vnpcs[index].move.type == "pathfinding" then
            vnpcs[index].sync_stop = nil
            local success = StopVNPC(npc)
            if success then
                vnpcs[index].death_stopped = true
            end
        elseif vnpcs[index].move.type == "default" then
            local x, y, z = GetNPCLocation(npc)
            local h = GetNPCHeading(npc)
            vnpcs[index].sync_stop = {x, y, z, h}
            local success = StopVNPC(npc)
            if success then
                vnpcs[index].death_stopped = true
            end
        end
    end
end)

AddEvent("OnNPCSpawn", function(npc)
    local index = GetVnpcIndex(npc)
    if index then
        if vnpcs[index].sync_stop then
            SetNPCLocation(npc, vnpcs[index].sync_stop[1], vnpcs[index].sync_stop[2], vnpcs[index].sync_stop[3])
            SetNPCHeading(npc, vnpcs[index].sync_stop[4])
        end
        if vnpcs[index].death_stopped then
            CallEvent("OnVNPCReachTargetFailed", npc)
        end
    end
end)

AddEvent("OnNPCReachTarget", function(npc)
    local index = GetVnpcIndex(npc)
    if index then
        if vnpcs[index].move.type == "default" then
            ResetVNPCDefaultPropertyValue(npc)
            CallEvent("OnVNPCReachTarget", npc)
        end
    end
end)

AddEvent("OnVehicleDestroyed", function(veh)
    for i, v in ipairs(vnpcs) do
        if v.move.target_type == "vehicle" then
            if v.move.target[1] == veh then
                StopVNPC(v.npc)
            end
        end
    end
end)

AddEvent("OnPlayerQuit", function(ply)
    for i, v in ipairs(vnpcs) do
        if v.move.target_type == "player" then
            if v.move.target[1] == ply then
                StopVNPC(v.npc)
            end
        end
    end
end)

AddRemoteEvent("VNPC_Default_To_Pathfinding", function(ply, npc, x, y, z)
    if vnpcs_default_to_pathfinding then
        local index = GetVnpcIndex(npc)
        if index then
            if GetNPCHealth(npc) > 0 then
                if IsNPCStreamed(npc) then
                    if vnpcs[index].move.type == "default" then
                        SetNPCLocation(npc, x, y, z + 100)
                        if vnpcs[index].move.target_type == "location" then
                            SetVNPCTargetLocation(npc, vnpcs[index].move.target[1], vnpcs[index].move.target[2], vnpcs[index].move.target[3], vnpcs[index].move.target[4])
                        elseif vnpcs[index].move.target_type == "vehicle" then
                            SetVNPCFollowVehicle(npc, vnpcs[index].move.target[1], vnpcs[index].move.target[2])
                        elseif vnpcs[index].move.target_type == "player" then
                            SetVNPCFollowPlayer(npc, vnpcs[index].move.target[1], vnpcs[index].move.target[2])
                        end
                        if vnpcs_debug then
                            print("VNPC_Default_To_Pathfinding", npc)
                        end
                    end
                end
            end
        end
    end
end)