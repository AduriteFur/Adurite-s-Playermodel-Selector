print("[APS] Loaded!")

local flag = FCVAR_REPLICATED

if SERVER then
    flag = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)
end

local convars = {}

convars["aps_playermodel_selector_force"] = 1
convars["aps_playermodel_selector_gamemodes"] = 1
convars["aps_playermodel_selector_instantly"] = 1
convars["aps_playermodel_selector_flexes"] = 1
convars["aps_playermodel_selector_limit"] = 1
convars["aps_playermodel_selector_debug"] = 0
convars["aps_playermodel_selector_welcome"] = 1

for cvar, def in pairs(convars) do
    CreateConVar(cvar, tostring(def), flag)
end

local CVarFlexes = GetConVar("aps_playermodel_selector_flexes")
local CVarDebug = GetConVar("aps_playermodel_selector_debug")

local function APSDebug(text)
    if CVarDebug and CVarDebug:GetBool() then
        print("[APS] " .. tostring(text))
    end
end

-- plr functs
local function ApplyBodygroups(ply, groups)
    groups = groups or ""

    if groups == "" then
        for i = 0, ply:GetNumBodyGroups() - 1 do
            ply:SetBodygroup(i, 0)
        end

        return
    end

    local values = string.Explode(" ", groups)

    for i = 0, ply:GetNumBodyGroups() - 1 do
        local value = tonumber(values[i + 1]) or 0

        ply:SetBodygroup(i, value)

        APSDebug(
            "Set bodygroup no. "
            .. tostring(i)
            .. " to: "
            .. tostring(value)
        )
    end
end

local function ApplyFlexes(ply)
--[[
    if not CVarFlexes or not CVarFlexes:GetBool() then
        return
    end

    if ply:GetInfoNum("cl_playermodel_selector_unlockflexes", 0) == 0 then
        return
    end

    local flexes = ply:GetInfo("cl_playerflexes")

    if not flexes or flexes == "" or flexes == "0" then
        return
    end

    local values = string.Explode(" ", flexes)

    for i = 0, ply:GetFlexNum() - 1 do
        local weight = tonumber(values[i + 1]) or 0

        ply:SetFlexWeight(i, weight)
    end
    --]]
end

local function ApplyColors(ply)
    local playerColor = ply:GetInfo("cl_playercolor")
    local weaponColor = ply:GetInfo("cl_weaponcolor")

    APSDebug("Restoring colors for " .. ply:Nick())
    APSDebug("Player color received: " .. tostring(playerColor))
    APSDebug("Weapon color received: " .. tostring(weaponColor))

    if playerColor and playerColor ~= "" then
        ply:SetPlayerColor(Vector(playerColor))
        APSDebug("Applied player color: " .. playerColor)
    else
        APSDebug("WARNING: Player color is empty!")
    end

    if weaponColor and weaponColor ~= "" then
        ply:SetWeaponColor(Vector(weaponColor))
        APSDebug("Applied weapon color: " .. weaponColor)
    else
        APSDebug("WARNING: Weapon color is empty!")
    end
end

local function SetupPlayerHands(ply, mdlname)
    timer.Simple(0, function()
        if not IsValid(ply) then return end

        if isfunction(ply.SetupHands) then
            ply:SetupHands()
        end

        if not mdlname or mdlname == "" then return end

        timer.Simple(0.1, function()
            if not IsValid(ply) then return end

            local hands = ply:GetHands()
            if not IsValid(hands) then return end

            hands:SetModel(mdlname)
        end)
    end)
end

if SERVER then
    AddCSLuaFile("autorun/client/aps_playermodel_selector_gui.lua")

    print("[APS] Server side loaded.")

    util.AddNetworkString("aps_playermodel_cvar_change")
    util.AddNetworkString("aps_playermodel_blacklist")
  --util.AddNetworkString("aps_playermodel_voxlist")
    util.AddNetworkString("aps_playermodel_update")
    util.AddNetworkString("aps_playermodel_colors")


    local SetMDL = FindMetaTable("Entity").SetModel
    local addon_legs = false
    local Blacklist = {}

    local function Allowed(ply)
        if not IsValid(ply) or not ply:IsPlayer() then
            return false
        end

        local gamemode = GAMEMODE_NAME

        if not gamemode or gamemode == "" then
            gamemode = engine.ActiveGamemode()
        end

        if gamemode == "sandbox" then
            return true
        end

        if Blacklist[gamemode] then
            return false
        end

        local cvar = GetConVar("aps_playermodel_selector_gamemodes")

        if not cvar then
            return false
        end

        return ply:IsAdmin() or cvar:GetBool()
    end

    local function ChangeCharacter(ply, modelOverride)
        if not IsValid(ply) or not ply:IsPlayer() then
            return false
        end

        if not Allowed(ply) then
            return false
        end

        ply.aps_playermodel_spawned = true

        local mdlpath = modelOverride or ply:GetInfo("cl_playermodel")

        if not mdlpath or mdlpath == "" then
            APSDebug("ERROR - No playermodel was provided.")
            return false
        end

        mdlpath = string.Trim(mdlpath)

        if not string.EndsWith(string.lower(mdlpath), ".mdl") then
            APSDebug("ERROR - Invalid model path: " .. tostring(mdlpath))
            return false
        end

        if not file.Exists(mdlpath, "GAME") then
            APSDebug("ERROR - Model does not exist: " .. tostring(mdlpath))
            return false
        end

        print("[APS] Setting model: " .. mdlpath)

        SetMDL(ply, mdlpath)

        APSDebug("Set model directly to: " .. mdlpath)

        local skin = ply:GetInfoNum("cl_playerskin", 0)

        ply:SetSkin(skin)

        APSDebug("Set model skin to no.: " .. tostring(skin))

        ApplyBodygroups(
            ply,
            ply:GetInfo("cl_playerbodygroups")
        )

        ApplyFlexes(ply)
        ApplyColors(ply)
        SetupPlayerHands(ply)

        if addon_legs then
            hook.Run("SetModel", ply, mdlpath)
        end

        return true
    end

    APS = APS or {}
    APS.ChangeCharacter = ChangeCharacter

    net.Receive("aps_playermodel_cvar_change", function(len, ply)
        if not IsValid(ply) or not ply:IsPlayer() then
            return
        end

        if not Allowed(ply) then
            return
        end

        if not ply:IsAdmin() then
            return
        end

        local cvar = net.ReadString()

        if not convars[cvar] then
            ply:Kick("Illegal convar change")
            return
        end

        local value = net.ReadString()

        if value ~= "0" and value ~= "1" then
            return
        end

        RunConsoleCommand(cvar, value)
    end)

    net.Receive("aps_playermodel_update", function(len, ply)
        if not IsValid(ply) or not ply:IsPlayer() then
            return
        end

        local instantly = GetConVar("aps_playermodel_selector_instantly")

        if not instantly then
            return
        end

        if not (ply:IsAdmin() or instantly:GetBool()) then
            return
        end

        local mdlpath = net.ReadString()

        if not mdlpath or mdlpath == "" then
            return
        end

        APSDebug("Received model path: " .. mdlpath)

        APS.ChangeCharacter(ply, mdlpath)
    end)
    
    net.Receive("aps_playermodel_colors", function(_, ply)
        if not IsValid(ply) or not ply:IsPlayer() then
            return
        end

        if not Allowed(ply) then
            return
        end

        local playerColor = net.ReadVector()
        local weaponColor = net.ReadVector()

        playerColor = Vector(
            math.Clamp(playerColor.x, 0, 1),
            math.Clamp(playerColor.y, 0, 1),
            math.Clamp(playerColor.z, 0, 1)
        )

        weaponColor = Vector(
            math.Clamp(weaponColor.x, 0, 1),
            math.Clamp(weaponColor.y, 0, 1),
            math.Clamp(weaponColor.z, 0, 1)
        )

        ply:SetPlayerColor(playerColor)
        ply:SetWeaponColor(weaponColor)

        APSDebug("Updated player and weapon colors for " .. ply:Nick())
        
    end)

--    if file.Exists("autorun/sh_legs.lua", "LUA") then
--        addon_legs = true
--    end

	hook.Add( "PostGamemodeLoaded", "aps_load_pm_vals", function()
		CreateConVar( "cl_playercolor", "0.24 0.34 0.41", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" )
		CreateConVar( "cl_weaponcolor", "0.30 1.80 2.10", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" )
		CreateConVar( "cl_playerskin", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The skin to use, if the model has any" )
		CreateConVar( "cl_playerbodygroups", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The bodygroups to use, if the model has any" )
		CreateConVar( "cl_playerflexes", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The flexes to use, if the model has any" )
		CreateConVar( "cl_playerhands", "", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The hands to use, if the model has any" )
		CreateConVar( "cl_playerhandsbodygroups", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The bodygroups on the hands to use, if the model has any" )
		CreateConVar( "cl_playerhandsskin", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The skin on the hands to use, if the model has any" )
	end )

hook.Add("PlayerSpawn", "APS_RestorePlayerModel", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) then
            return
        end

        local model = ply:GetInfo("cl_playermodel")

        if not model or model == "" then
            return
        end

        APS.ChangeCharacter(ply, model)
    end)
end)

end