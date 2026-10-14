
AddCSLuaFile()

local ExoPBRTextures = {}
local ExoPBRBlacklist = {}

file.CreateDir("exopbr_auto_replacer")

if !file.Exists("exopbr_auto_replacer/ExoPBRTextures.txt", "DATA") then
	file.Write("exopbr_auto_replacer/ExoPBRTextures.txt", util.TableToJSON(ExoPBRTextures) )
else
	ExoPBRTextures = util.JSONToTable( file.Read("exopbr_auto_replacer/ExoPBRTextures.txt", "DATA") )
end

if !file.Exists("exopbr_auto_replacer/ExoPBRBlacklist.txt", "DATA") then
	file.Write("exopbr_auto_replacer/ExoPBRBlacklist.txt", util.TableToJSON(ExoPBRBlacklist) )
else
	ExoPBRBlacklist = util.JSONToTable( file.Read("exopbr_auto_replacer/ExoPBRBlacklist.txt", "DATA") )
end

function ExoPBR_Replacer_GetTextures()
	return ExoPBRTextures
end

function ExoPBR_Replacer_GetBlacklist()
	return ExoPBRBlacklist
end

function ExoPBR_Replacer_AddTexture(texture,skip)
	if skip then
		ExoPBRTextures[texture] = false
	else
		ExoPBRTextures[texture] = true
	end
	file.Write("exopbr_auto_replacer/ExoPBRTextures.txt", util.TableToJSON(ExoPBRTextures) )
end

function ExoPBR_Replacer_ClearTextures()
	ExoPBRTextures = {}
	file.Write("exopbr_auto_replacer/ExoPBRTextures.txt", util.TableToJSON(ExoPBRTextures) )
end

function ExoPBR_Replacer_AddBlacklist(model)
	ExoPBRBlacklist[model] = true
	file.Write("exopbr_auto_replacer/ExoPBRBlacklist.txt", util.TableToJSON(ExoPBRBlacklist) )
end

function ExoPBR_Replacer_RemoveBlacklist(model)
	ExoPBRBlacklist[model] = nil
	file.Write("exopbr_auto_replacer/ExoPBRBlacklist.txt", util.TableToJSON(ExoPBRBlacklist) )
end

function ExoPBR_Replacer_ClearBlacklist()
	ExoPBRBlacklist = {}
	file.Write("exopbr_auto_replacer/ExoPBRBlacklist.txt", util.TableToJSON(ExoPBRBlacklist) )
end

local function ResetSkin(ent)
	local materials = ent:GetMaterials()
	if !materials or #materials == 0 then return end

	for id, matPath in ipairs(materials) do
		ent:SetSubMaterial( id - 1,nil )
	end
end

local function ReplaceSkin(ent,properties)
	if !IsValid(ent) or ent:GetModel() == nil or string.sub(ent:GetModel(), 1, 6) != "models" then return end
	if !(properties or GetConVar("exopbr_auto_replacement"):GetBool()) then return end
	
	local materials = ent:GetMaterials()
	if !materials or #materials == 0 then return end
	ResetSkin(ent)
	local AddToBlacklist = true
	
	for id, matPath in ipairs(materials) do
		local Texture = matPath.."_exopbr"
		local HasPBRTexture = false
		local Index = id - 1
		local CheckTextureList = ExoPBRTextures[Texture]
		
		if !properties and ExoPBRBlacklist[ent:GetModel()] then return end
		
		if CheckTextureList then
			HasPBRTexture = true
			AddToBlacklist = false
		elseif CheckTextureList == false then
			if properties then
				if file.Exists( "materials/"..Texture..".vmt", "GAME" ) then
					HasPBRTexture = true
					AddToBlacklist = false
				end
			end
		else
			if file.Exists( "materials/"..Texture..".vmt", "GAME" ) then
				HasPBRTexture = true
				AddToBlacklist = false
			end
		end
		
		if HasPBRTexture then
			ExoPBR_Replacer_AddTexture( Texture )
			if GetConVar("developer"):GetBool() then print("Found ExoPBR texture, replacing... (Index "..id..". Texture "..Texture..")") end
			ent:SetSubMaterial( Index, Texture )
		else
			ExoPBR_Replacer_AddTexture( Texture, true )
		end
	end
	if AddToBlacklist then ExoPBR_Replacer_AddBlacklist(ent:GetModel()) else ExoPBR_Replacer_RemoveBlacklist(ent:GetModel()) end
end

if CLIENT then
	CreateClientConVar( "exopbr_auto_replacement", 1 , true, false )

	hook.Add("OnEntityCreated", "ExoPBR_Auto_Replacer", function(ent)
		timer.Simple(0, function()
			ReplaceSkin(ent)
		end)
	end)
	hook.Add("AddToolMenuTabs", "EXOPBR_REPLACER_ADDMENU", function()
		spawnmenu.AddToolCategory("Options", "ExoPBR Replacer Settings", "#ExoPBR_Replacer.Title")
	end)

	hook.Add("PopulateToolMenu","EXOPBR_REPLACER_MENU",function()
		spawnmenu.AddToolMenuOption("Options", "ExoPBR Replacer Settings", "ExoPBR Replacer", "#ExoPBR_Replacer.Settings","","",function(pnl)
			pnl:CheckBox("#ExoPBR_Replacer.Enable", "exopbr_auto_replacement")
			
			local Button = vgui.Create( "DButton", pnl )
			Button:SetText( "#ExoPBR_Replacer.ClearTextures" )
			Button:SetSize( 100, 25 )	
			pnl:AddItem(Button)
			Button.DoClick = function()
				ExoPBR_Replacer_ClearTextures()
			end
		end)
	end)
end

if SERVER then
	hook.Add("PlayerSetHandsModel", "ExoPBR_Auto_Replacer_Player", function(ent)
		timer.Simple(0, function()
			ReplaceSkin(ent)
		end)
	end)
end

properties.Add( "ExoPBR_Auto_Replacer_ToPBR", {
	MenuLabel = "#ExoPBR_Auto_Replacer.ToPBR", -- Name to display on the context menu
	Order = 5887, -- The order to display this property relative to other properties
	MenuIcon = "icon16/add.png", -- The icon to display next to the property
	PrependSpacer = true,
	
	Filter = function( self, ent, ply ) -- A function that determines whether an entity is valid for this property
		if ( !IsValid( ent ) ) then return false end
		return true
	end,
	Action = function( self, ent ) -- The action to perform upon using the property ( Clientside )
		self:MsgStart()
			net.WriteEntity( ent )
		self:MsgEnd()

		ReplaceSkin(ent,true)
	end,
	Receive = function( self, length, ply ) -- The action to perform upon using the property ( Serverside )
		local ent = net.ReadEntity()

		if ( !properties.CanBeTargeted( ent, ply ) ) then return end
		if ( !self:Filter( ent, ply ) ) then return end

		ReplaceSkin(ent,true)
	end 
} )

properties.Add( "ExoPBR_Auto_Replacer_Reset", {
	MenuLabel = "#ExoPBR_Auto_Replacer.Reset", -- Name to display on the context menu
	Order = 5888, -- The order to display this property relative to other properties
	MenuIcon = "icon16/delete.png", -- The icon to display next to the property
	
	Filter = function( self, ent, ply ) -- A function that determines whether an entity is valid for this property
		if ( !IsValid( ent ) ) then return false end
		return true
	end,
	Action = function( self, ent ) -- The action to perform upon using the property ( Clientside )
		self:MsgStart()
			net.WriteEntity( ent )
		self:MsgEnd()
	end,
	Receive = function( self, length, ply ) -- The action to perform upon using the property ( Serverside )
		local ent = net.ReadEntity()

		if ( !properties.CanBeTargeted( ent, ply ) ) then return end
		if ( !self:Filter( ent, ply ) ) then return end

		ResetSkin(ent)
	end 
} )
