local UI = {}
local FILES = {
    ["favorites"] = "/aps_data/favorites.txt",
}

local VPVars = {
    ["curAnim"] = 0,
    ["lastAnim"] = 0,
    ["bindpose"] = false 
}

-- CVars
local welconvr = GetConVar("aps_playermodel_selector_welcome")
if CLIENT then
    CreateClientConVar("cl_playerskin", "0", true, true, "The skin to use, if the model has any")
    CreateClientConVar("cl_playerbodygroups", "0", true, true, "The bodygroups to use, if the model has any")
    CreateClientConVar("cl_playerflexes", "0", true, true, "The flexes to use, if the model has any")
    CreateClientConVar("cl_playerhands", "", true, true, "The hands to use, if the model has any")
    CreateClientConVar("cl_playerhandsbodygroups", "0", true, true, "The bodygroups on the hands to use, if the model has any")
    CreateClientConVar("cl_playerhandsskin", "0", true, true, "The skin on the hands to use, if the model has any")
    CreateClientConVar("cl_playercolor", "0.24 0.34 0.41", true, true, "The player color")
    CreateClientConVar("cl_weaponcolor", "0.30 1.80 2.10", true, true, "The weapon color")
end

-- vars
UI["enabled"] = false 

-- funcs
local function chatWelcome()
    print("[APS]: if you need to disable this change the convar 'aps_playermodel_selector_welcome' to 0")

    chat.AddText(
        Color(255, 100, 100),
        "======================================================",
        "\n",
        "      Adurite's Player Model Selector",
        "\n",
        "      This server uses APS",
        "\n",
        "      If you are the server owner follow the instructions in the RCON or",
        "\n",
        "      set aps_playermodel_selector_welcome to 0.",
        "\n",
        "======================================================"
    )
end

if welconvr:GetBool() then
chatWelcome()
end

local function SaveFavorites()
    file.CreateDir("aps")
    file.Write("aps/favorites.txt", util.TableToJSON(UI.Favorites or {}, true))
end

local function CreateGUI()

    if IsValid(UI.Frame) then

        UI.Frame:Hide()
        UI.Frame:MakePopup()

        return

    end

    UI.Favorites = {}

    -- functions

    local function GetPlayerModelName(model)

        if player_manager and player_manager.TranslatePlayerModelName then

            local name = player_manager.TranslatePlayerModelName(model)

            if name and name ~= "" then

                return name

            end

        end

        return model

    end

    local function IsModelFavorite(model)

        return UI.Favorites[model] == true

    end

    local function SetModelFavorite(model, state)

        UI.Favorites[model] = state

    end

    local function SelectModel(model)

        if not IsValid(UI.Viewer.MdlViewport) then

            return

        end

        UI.Viewer.MdlViewport:SetModel(model)

        UI.Viewer.MdlViewport.ModelYaw = 0
        UI.Viewer.MdlViewport.ModelPitch = 0
        UI.Viewer.MdlViewport.LookAtPos = Vector(0, 0, 40)
        UI.Viewer.MdlViewport.Yaw = 180
        UI.Viewer.MdlViewport.Pitch = 0
        UI.Viewer.MdlViewport.Distance = 100

        local ent = UI.Viewer.MdlViewport.Entity

        if IsValid(ent) then

            ent:SetPos(vector_origin)
            ent:SetAngles(Angle(0, 0, 0))

        end

        UI.SelectedModel = model

    end

    local function CreateModelIcon(parent, modelData)

        local icon = parent:Add("SpawnIcon")

        icon:SetModel(modelData.Model)
        icon:SetSize(56, 56)
        icon:SetTooltip(modelData.Name .. "\n" .. modelData.Model)

        icon.ModelPath = modelData.Model
        icon.ModelName = modelData.Name

        icon.DoClick = function()

            SelectModel(modelData.Model)

        end

        icon.DoRightClick = function()

            local menu = DermaMenu()

            menu:AddOption("Select Model", function()

                SelectModel(modelData.Model)

            end)

            menu:AddOption("Copy Model Path", function()

                SetClipboardText(modelData.Model)

            end)

            menu:AddOption("Copy Model Name", function()

                SetClipboardText(modelData.Name)

            end)

            menu:AddSpacer()

            if IsModelFavorite(modelData.Model) then

                menu:AddOption("Remove from Favorites", function()

                    SetModelFavorite(modelData.Model, false)

                    if IsValid(UI.ModelsFavorites) then

                        UI.ModelsFavorites:Refresh()

                    end

                    if IsValid(UI.ArmsCModelsFavorites) then

                        UI.ArmsCModelsFavorites:Refresh()

                    end

                end)

            else

                menu:AddOption("Add to Favorites", function()

                    SetModelFavorite(modelData.Model, true)

                    if IsValid(UI.ModelsFavorites) then

                        UI.ModelsFavorites:Refresh()

                    end

                    if IsValid(UI.ArmsCModelsFavorites) then

                        UI.ArmsCModelsFavorites:Refresh()

                    end

                end)

            end

            menu:Open()

        end

        return icon

    end

    local function CreateModelBrowser(panel, models, favoritesOnly)

        panel:Clear()

        panel.Search = vgui.Create("DTextEntry", panel)
        panel.Search:Dock(TOP)
        panel.Search:DockMargin(5, 5, 5, 5)
        panel.Search:SetTall(20)
        panel.Search:SetPlaceholderText("Search player models...")

        panel.Scroll = vgui.Create("DScrollPanel", panel)
        panel.Scroll:Dock(FILL)
        panel.Scroll:DockMargin(5, 0, 5, 5)

        panel.Grid = vgui.Create("DIconLayout", panel.Scroll)
        panel.Grid:Dock(TOP)
        panel.Grid:SetSpaceX(5)
        panel.Grid:SetSpaceY(5)

        panel.Models = models
        panel.FavoritesOnly = favoritesOnly

        function panel:Refresh()

            if not IsValid(self.Grid) then

                return

            end

            local search = string.Trim(self.Search:GetValue() or "")

            search = string.lower(search)

            self.Grid:Clear()

            for _, modelData in ipairs(self.Models) do

                timer.Simple(0.1, function()
                local name = string.lower(modelData.Name or "")
                local path = string.lower(modelData.Model or "")

                local matchesSearch = search == ""
                    or string.find(name, search, 1, true)
                    or string.find(path, search, 1, true)

                local matchesFavorite = not self.FavoritesOnly
                    or IsModelFavorite(modelData.Model)

                if matchesSearch and matchesFavorite then

                    CreateModelIcon(self.Grid, modelData)

                end
                end)

            end

        end

        panel.Search.OnChange = function()

            panel:Refresh()

        end

        panel:Refresh()

    end

    local function PopulatePlayerModels()

        if not IsValid(UI.ModelsAll) then

            return

        end

        UI.ModelEntries = {}

        local models = player_manager.AllValidModels()

        for _, model in pairs(models) do

            if isstring(model) then

                UI.ModelEntries[#UI.ModelEntries + 1] = {

                    Model = model,
                    Name = GetPlayerModelName(model)

                }

            end

        end

        table.sort(UI.ModelEntries, function(a, b)

            return string.lower(a.Name) < string.lower(b.Name)

        end)

        CreateModelBrowser(UI.ModelsAll, UI.ModelEntries, false)
        CreateModelBrowser(UI.ModelsFavorites, UI.ModelEntries, true)

    end

    local function PopulateArmsModels()

        if not IsValid(UI.ArmsCModelsAll) then

            return

        end

        UI.ArmsModelEntries = {}

        local hands = player_manager.AllValidModels() -- gotta get the hand from what the model is binded to

        for _, hand in pairs(hands) do

            if isstring(hand) then

                UI.ArmsModelEntries[#UI.ArmsModelEntries + 1] = {

                    Model = hand,
                    Name = GetPlayerModelName(hand)

                }

            end

        end

        table.sort(UI.ArmsModelEntries, function(a, b)

            return string.lower(a.Name) < string.lower(b.Name)

        end)

        CreateModelBrowser(UI.ArmsCModelsAll, UI.ArmsModelEntries, false)
        CreateModelBrowser(UI.ArmsCModelsFavorites, UI.ArmsModelEntries, true)

    end

    -- Main viewer
    UI.Frame = vgui.Create("DFrame")
    UI.Frame:SetSize(900, 500)
    UI.Frame:Center()
    UI.Frame:SetTitle("Adurite's PM Selector")

    UI.Viewer = vgui.Create("DPanel", UI.Frame)
    UI.Viewer:Dock(FILL)

    UI.Viewer.MdlViewport = vgui.Create("DModelPanel", UI.Viewer)
    UI.Viewer.MdlViewport:Dock(FILL)
    UI.Viewer.MdlViewport:SetModel(LocalPlayer():GetModel())
    UI.Viewer.MdlViewport:SetFOV(45)
    UI.Viewer.MdlViewport.LookAtPos = Vector(0, 0, 40)
    UI.Viewer.MdlViewport.Yaw = 180
    UI.Viewer.MdlViewport.Pitch = 0
    UI.Viewer.MdlViewport.Distance = 100
    UI.Viewer.MdlViewport.PanSpeed = 0.15
    UI.Viewer.MdlViewport.ModelYaw = 0
    UI.Viewer.MdlViewport.ModelPitch = 0

    UI.Viewer.BTNHolder = vgui.Create("DPanel", UI.Viewer)
    UI.Viewer.BTNHolder:Dock(BOTTOM)
    UI.Viewer.BTNHolder:DockMargin(5, 5, 5, 5)
    UI.Viewer.BTNHolder:DockPadding(5, 5, 5, 5)

    UI.Viewer.BTNHolder.CamReset = vgui.Create("DButton", UI.Viewer.BTNHolder)
    UI.Viewer.BTNHolder.CamReset:SetText("Reset Camera")
    UI.Viewer.BTNHolder.CamReset:Dock(LEFT)
    UI.Viewer.BTNHolder.CamReset:SetWide(120)

    UI.Viewer.BTNHolder.Apply = vgui.Create("DButton", UI.Viewer.BTNHolder)
    UI.Viewer.BTNHolder.Apply:SetText("Apply Model")
    UI.Viewer.BTNHolder.Apply:Dock(RIGHT)
    UI.Viewer.BTNHolder.Apply:SetWide(120)

    -- Model Features

    UI.ModelFeatures = vgui.Create("DPropertySheet", UI.Frame)
    UI.ModelFeatures:SetWide(300)
    UI.ModelFeatures:Dock(LEFT)

    -- Main Models / Arms property sheet

    UI.ModelSelector = vgui.Create("DPropertySheet", UI.Frame)
    UI.ModelSelector:SetWide(300)
    UI.ModelSelector:Dock(LEFT)

    -- Models panel

    UI.ModelsPanel = vgui.Create("DPropertySheet", UI.ModelSelector)
    UI.ModelsAll = vgui.Create("DPanel", UI.ModelsPanel)
    UI.ModelsFavorites = vgui.Create("DPanel", UI.ModelsPanel)

    -- Arms / C-Models panel

    UI.ArmsCModelsPanel = vgui.Create("DPropertySheet", UI.ModelSelector)
    UI.ArmsCModelsAll = vgui.Create("DPanel", UI.ArmsCModelsPanel)
    UI.ArmsCModelsFavorites = vgui.Create("DPanel", UI.ArmsCModelsPanel)

    -- Body Groups

    UI.BodyGroups = vgui.Create("DPanel", UI.ModelFeatures)

    -- Hand Groups

    UI.HandGroups = vgui.Create("DPanel", UI.ModelFeatures)

    -- Flexes

    UI.Flex = vgui.Create("DPanel", UI.ModelFeatures)

    -- Colors

    UI.Colors = vgui.Create("DPanel", UI.ModelFeatures)

    UI.Colors.plrlabel = vgui.Create("DLabel", UI.Colors)
    UI.Colors.plrlabel:SetText("Player Color")
    UI.Colors.plrlabel:Dock(TOP)
    UI.Colors.plrlabel:DockMargin(5, 5, 5, 5)

    UI.Colors.plrcol = vgui.Create("DColorMixer", UI.Colors)
    UI.Colors.plrcol:SetAlphaBar(false)
    UI.Colors.plrcol:SetPalette(false)
    UI.Colors.plrcol:Dock(TOP)
    UI.Colors.plrcol:SetTall(175)
    UI.Colors.plrcol:DockMargin(5, 5, 5, 5)

    UI.Colors.weaponlabel = vgui.Create("DLabel", UI.Colors)
    UI.Colors.weaponlabel:SetText("Weapon Color")
    UI.Colors.weaponlabel:Dock(TOP)
    UI.Colors.weaponlabel:DockMargin(5, 5, 5, 5)

    UI.Colors.weaponcol = vgui.Create("DColorMixer", UI.Colors)
    UI.Colors.weaponcol:SetAlphaBar(false)
    UI.Colors.weaponcol:SetPalette(false)
    UI.Colors.weaponcol:Dock(TOP)
    UI.Colors.weaponcol:SetTall(150)
    UI.Colors.weaponcol:DockMargin(5, 5, 5, 0)

    UI.Colors.apply = vgui.Create("DButton", UI.Colors)
    UI.Colors.apply:SetText("Apply Colors")
    UI.Colors.apply:Dock(TOP)
    UI.Colors.apply:DockMargin(5, 5, 5, 0)

    -- Misc

    UI.Misc = vgui.Create("DPanel", UI.ModelFeatures)

    UI.Misc.Content = vgui.Create("DScrollPanel", UI.Misc)
    UI.Misc.Content:Dock(FILL)

    UI.Misc.EnforcePM = vgui.Create("DCheckBoxLabel", UI.Misc.Content)
    UI.Misc.EnforcePM:SetText(" Enforce Your Player Model")
    UI.Misc.EnforcePM:Dock(TOP)
    UI.Misc.EnforcePM:DockMargin(5, 5, 5, 0)

    UI.Misc.EnforcePMLabel = vgui.Create("DLabel", UI.Misc.Content)
    UI.Misc.EnforcePMLabel:SetText("If selected your model will be protected \n which means no other player model function could change it")
    UI.Misc.EnforcePMLabel:Dock(TOP)
    UI.Misc.EnforcePMLabel:DockMargin(5, 5, 5, 5)
    UI.Misc.EnforcePMLabel:SetWrap(true)
    UI.Misc.EnforcePMLabel:SetAutoStretchVertical(true)

    UI.Misc.ReloadRenders = vgui.Create("DButton", UI.Misc.Content)
    UI.Misc.ReloadRenders:SetText("Reload Renders")
    UI.Misc.ReloadRenders:Dock(TOP)
    UI.Misc.ReloadRenders:DockMargin(5, 5, 5, 0)

    -- add panels to sheets

    -- Models

    UI.ModelsPanel:AddSheet(
        "All",
        UI.ModelsAll,
        "icon16/group.png"
    )

    UI.ModelsPanel:AddSheet(
        "Favorites",
        UI.ModelsFavorites,
        "icon16/heart.png"
    )

    -- Arms / C-Models

    UI.ArmsCModelsPanel:AddSheet(
        "All",
        UI.ArmsCModelsAll,
        "icon16/group.png"
    )

    UI.ArmsCModelsPanel:AddSheet(
        "Favorites",
        UI.ArmsCModelsFavorites,
        "icon16/heart.png"
    )

    -- Main Model Selector

    UI.ModelSelector:AddSheet(
        "Models",
        UI.ModelsPanel,
        "icon16/group.png"
    )

    UI.ModelSelector:AddSheet(
        "Arms",
        UI.ArmsCModelsPanel,
        "icon16/user.png"
    )

    -- Model Features

    UI.ModelFeatures:AddSheet(
        "Body Groups",
        UI.BodyGroups,
        "icon16/user_edit.png"
    )

    UI.ModelFeatures:AddSheet(
        "Hand Groups",
        UI.HandGroups,
        "icon16/user_edit.png"
    )

    UI.ModelFeatures:AddSheet(
        "Flexes",
        UI.Flex,
        "icon16/emoticon_tongue.png"
    )

    UI.ModelFeatures:AddSheet(
        "Colors",
        UI.Colors,
        "icon16/rainbow.png"
    )

    UI.ModelFeatures:AddSheet(
        "Misc",
        UI.Misc,
        "icon16/cog.png"
    )

    -- Main Viewer

    -- UI.Viewer:Whatever()

    -- Models > All

    -- UI.ModelsAll:Whatever()

    -- Models > Favorites

    -- UI.ModelsFavorites:Whatever()

    -- Arms > All

    -- UI.ArmsCModelsAll:Whatever()

    -- Arms > Favorites

    -- UI.ArmsCModelsFavorites:Whatever()

    -- Body Groups

    -- UI.BodyGroups:Whatever()

    -- Hand Groups

    -- UI.HandGroups:Whatever()

    -- Flexes

    -- UI.Flex:Whatever()

    -- Colors

    -- UI.Colors:Whatever()

    -- Misc

    -- UI.Misc:Whatever()

    -- scripting

    -- mdlviewer

    function UI.Viewer.MdlViewport:LayoutEntity(ent)

        self:SetLookAt(self.LookAtPos)

        local ang = Angle(self.Pitch, self.Yaw, 0)

        self:SetCamPos(self.LookAtPos - ang:Forward() * self.Distance)

        ent:SetAngles(Angle(self.ModelPitch, self.ModelYaw, 0))

    end

    function UI.Viewer.MdlViewport:OnMousePressed(key)

        if key == MOUSE_LEFT or key == MOUSE_MIDDLE then

            self.Dragging = true
            self.DragButton = key
            self.LastMouseX, self.LastMouseY = gui.MousePos()
            self:MouseCapture(true)

            return true

        end

    end

    function UI.Viewer.MdlViewport:OnMouseReleased(key)

        if key == self.DragButton then

            self.Dragging = false
            self.DragButton = nil
            self:MouseCapture(false)

            return true

        end

    end

    function UI.Viewer.MdlViewport:Think()

        if not self.Dragging then

            return

        end

        local x, y = gui.MousePos()

        local dx = x - self.LastMouseX
        local dy = y - self.LastMouseY

        self.LastMouseX = x
        self.LastMouseY = y

        local ent = self.Entity

        if not IsValid(ent) then

            return

        end

        if self.DragButton == MOUSE_LEFT then

            self.ModelYaw = self.ModelYaw + dx * 0.5
            self.ModelPitch = math.Clamp(self.ModelPitch + dy * 0.5, -90, 90)

        elseif self.DragButton == MOUSE_MIDDLE then

            local camAng = Angle(self.Pitch, -self.Yaw, 0)
            local pos = ent:GetPos()

            pos = pos + camAng:Right() * dx * 0.2
            pos = pos - camAng:Up() * dy * 0.2

            ent:SetPos(pos)

        end

    end

    function UI.Viewer.MdlViewport:OnMouseWheeled(delta)

        self.Distance = math.Clamp(self.Distance - delta * 5, 20, 500)

        return true

    end

    UI.Viewer.BTNHolder.CamReset.DoClick = function()

        local viewport = UI.Viewer.MdlViewport

        viewport.LookAtPos = Vector(0, 0, 40)
        viewport.Yaw = 180
        viewport.Pitch = 0
        viewport.Distance = 100
        viewport.ModelYaw = 0
        viewport.ModelPitch = 0

        local ent = viewport.Entity

        if IsValid(ent) then

            ent:SetPos(vector_origin)
            ent:SetAngles(Angle(0, 0, 0))

        end

    end



    UI.Viewer.BTNHolder.Apply.DoClick = function()
    if not UI.SelectedModel or UI.SelectedModel == "" then
        return
    end

    RunConsoleCommand("cl_playermodel", UI.SelectedModel)

    net.Start("aps_playermodel_update")
    net.WriteString(UI.SelectedModel)
    net.SendToServer()
end

    PopulatePlayerModels()
    PopulateArmsModels()

    --  --

    UI.Frame:MakePopup()

end

local function toggleUI()
    UI["enabled"] = not UI["enabled"]

    if UI["Enabled"] == true then
        UI.Frame:Show()
    else
        UI.Frame:Hide()
    end
end

hook.Add("PopulateToolMenu", "APS_ReplacePlayerModelSelector", function()
    local menu = spawnmenu.GetToolMenu("Utilities", "User")

    if not menu then
        return
    end

    for k = #menu, 1, -1 do
        if menu[k].ItemName == "PlayerModelSelector" then
            table.remove(menu, k)
        end
    end

    spawnmenu.AddToolMenuOption(
        "Utilities",
        "User",
        "PlayerModelSelector",
        "#smwidget.playermodel_title",
        "",
        "",
        function()
            RunConsoleCommand("aps_selector_gui")
        end
    )
end)

concommand.Add("aps_selector_gui", function()
    CreateGUI()
end)

hook.Add("PostGamemodeLoaded", "APS_ReplacePlayerModelDesktop", function()
    if GAMEMODE_NAME == "sandbox" then
        local desktop = list.GetForEdit("DesktopWindows").PlayerEditor

        if desktop then
            desktop.init = function(icon, window)
                window:Remove()
                RunConsoleCommand("aps_selector_gui")
            end
        end
    else
        list.Set("DesktopWindows", "PlayerEditor", {
            title = "Player Model",
            icon = "icon64/playermodel.png",

            init = function(icon, window)
                window:Remove()
                RunConsoleCommand("aps_selector_gui")
            end
        })
    end
end)

hook.Add("InitPostEntity", "APS_InitializeGUI", function()
    timer.Simple(1, function()
        if not IsValid(LocalPlayer()) then
            return
        end

        CreateGUI()
    end)
end)