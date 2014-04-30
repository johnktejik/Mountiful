﻿-- pointless edit change to demonstrate subversion

local VersionString = "@project-version@"
local L = MountifulLocalization
local MountifulLoaded = false
local InvalidNames = {"hide","remove","add","smart","mounts","safeflying","options","rebuild","debug", "dismiss", "help", "reset", "pet"} -- Don't let people use these as category names
local PetSummoned = false
local LastPetSummoned = 0
Mountiful_Mounts = {}
local Mountiful_Defaults
local RTCF
local MountifulSelectedNum = 1
local MountifulPageNum
local MountifulFlyableSubZones = {"Krasus' Landing",}
local MountifulTooltip
local MOusefuturemount = false
local MOpastflyable = false
local MOsecurebuttonclicked = false
local MOmacroclicked = false
local MOcompanionupdate = false
local MOdruidfailmessage = "*Mountiful:  Alas, flight forms cannot be cast by mods.  Use the mountiful macro, or use '/click Mountiful' in your own macro."
local MOtimer,MOelapsed
local MOoverflowcount = 0
MOelapsed= 0


--MOdebug = true

local SPELLTIMEOUT = 2 --2 seconds
local TESTEVENT = "UNIT_SPELLCAST_SENT"

local MACROTEXT = "/click [button:1] Mountiful; [button:2] MOrightclickbutton"
local MOUNTIFUL_ERRORS = {
	[SPELL_FAILED_NOT_MOUNTED] = true,
	[SPELL_FAILED_NOT_SHAPESHIFT] = true,
	[ERR_ATTACK_MOUNTED] = true,
}

function ErrorWithStack(msg)
   msg = msg.."\n"..debugstack()
   --_ERRORMESSAGE(msg)
   MOprint("|c00ff0000"..msg)
   --Mountiful_InitializeSelections()
   Mountiful_RebuildSelections()
end



local MOUNTIFUL_CASTDETECTION = {
	["UNIT_SPELLCAST_SUCCEEDED"] = true,
	["UNIT_SPELLCAST_FAILED"] = true,
	["UNIT_SPELLCAST_INTERRUPTED"] = true,
	["UNIT_SPELLCAST_FAILED_QUIET"] = true,
}

if (not L) then  --apparently this only bugs out on devs.  curse somehow changes variables when i upload it to make things work.  Thats cool and all, but not very helpful to me.  So i had to throw this in.
	
	--other localization stuff here?
	L = {}
	setmetatable(L, {__index = function(self, key)
		--if MOdebug then ChatFrame3:AddMessage('Please localize: '..tostring(key)) end
		rawset(self, key, key)  --sets the index to be the key
		return key
	end })
else
	MountifulFlyableSubZones = {
		L["Krasus' Landing"],
	}
end

tinsert(UISpecialFrames, "MountifulFrame") -- Insert the menu frame into UISpecialFrames to it will close when hitting ESC

local MOprintstack = -1
local MessageString = ""
function MOprint(message)

	--MOdebug = true   --for severe errors

   if(MOdebug) then
		if(MOprintstack == -1) then
			MessageString=""
		end
      local stack, filler
      if not message then
	  	 print(MessageString..tostring(message))
		 return false 
      end
      MOprintstack=MOprintstack+1
      
	  filler=string.rep(". . ",MOprintstack)
      
      if (type(message) == "table") then
	  	-- DEFAULT_CHAT_FRAME:AddMessage("its a table.  length="..MO_tcount(message))
	 	
		DEFAULT_CHAT_FRAME:AddMessage(MessageString.."{table} --> ")
		
	 	for k,v in pairs(message) do
			MessageString = filler.."["..k.."] = "
	    	MOprint(v)
	 	end
      elseif (type(message) == "userdata") then

      elseif (type(message) == "function") then
        DEFAULT_CHAT_FRAME:AddMessage(MessageString.." A Function()")
      elseif (type(message) == "boolean") then
            DEFAULT_CHAT_FRAME:AddMessage(MessageString..tostring(message))
      else
	  	 	DEFAULT_CHAT_FRAME:AddMessage(MessageString..tostring(message))
      end
      MOprintstack=MOprintstack-1
   end
end


-- Checks if value e is in array t

local function in_array(e, t) 
	if(type(t) ~= "table") then 
		MOprint("ERROR!   passed in a nonexistant table!")
		return false
	end;
 	for _,v in pairs(t) do
		if (v==e) then return true end
	end
	return false
end

function Mountiful_OnLoad()
	print("|c00ffff00Mountiful |rloading.  '/mount help' for details")
	MountifulFrame:RegisterEvent("COMPANION_LEARNED");
	MountifulFrame:RegisterEvent("PLAYER_LOGIN");
	MountifulFrame:RegisterEvent("TAXIMAP_OPENED");
	--MountifulFrame:RegisterEvent("UI_ERROR_MESSAGE");
	MountifulFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN");
	MountifulFrame:RegisterEvent("UPDATE_STEALTH");
	MountifulFrame:RegisterEvent("COMPANION_UPDATE");
	
	--Register Slash Commands
	SLASH_MOUNT1 = "/mountiful"
	SLASH_MOUNT2 = "/mount" -- A shortcut or alias
	SLASH_MOUNT3 = "/mo" -- A shortcut or alias
	SlashCmdList["MOUNT"] = function(arg) Mountiful_Command(arg); end;

	--SLASH_PET1 = "/pet"  --i dont want to override the default /pet command
	--SlashCmdList["PET"] = function(arg) Mountiful_Command(arg, true); end;
	


	-- Binding Variables
	BINDING_HEADER_MOUNTIFULHDR = "Mountiful Bindings"
	--BINDING_NAME_MOUNTIFULBIND1 = "Smart Mounting"
	_G["BINDING_NAME_CLICK Mountiful:LeftButton"] = "Smart Mounting"
	BINDING_NAME_MOUNTIFULBIND2 = "Pre-Selected Smart Mounting"
	BINDING_NAME_MOUNTIFULBIND3 = "FastGround"
	BINDING_NAME_MOUNTIFULBIND4 = "FastFlying"
	BINDING_NAME_MOUNTIFULBIND5 = "Pet"
	
	
	MountifulFrame:EnableMouse()
	MountifulFrame:SetScript("OnMouseDown", function()  
		MountifulFrame:StartMoving()
	end)
	MountifulFrame:SetScript("OnMouseUp", function()  
		MountifulFrame:StopMovingOrSizing()
	end)
	
	mountiful = Mountiful  --an alias incase someone makes a '/click mountiful' (lcase)
				
	--patch into the blizzard mount screen
	
	local tabbutton = CreateFrame("Button","MountifulTab", SpellBookFrame,"TabButtonTemplate")
	--tabbutton:SetID(4)  --needed?  not sure
	tabbutton:SetPoint("top",_G["SpellBookFrameTabButton3"],"bottom",0,10)
	tabbutton:SetText("Mountiful")
	getglobal(tabbutton:GetName().."HighlightTexture"):SetWidth(tabbutton:GetTextWidth() + 31);
	PanelTemplates_TabResize(tabbutton, 0);
--	tabbutton:SetFrameLevel(PetPaperDollFrameCompanionFrame:GetFrameLevel()+1);
	tabbutton:SetScript("OnClick", function()
		Mountiful_Command("")
	end)
--	tabbutton:SetNormalTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotLeft");
--	tabbutton:SetNormalTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-Bot");
--	tabbutton:SetNormalTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotRight");
	
	MOrightclickbutton = CreateFrame("Button","MOrightclickbutton",UIParent)
	MOrightclickbutton:SetScript("OnClick",MOrightclick)
	MOprint("|c00ffff00Mountiful |ronload finished")
end

function Mountiful_OnEvent(self,event,...)
	MOprint("EVENT: |c00ff33ff"..tostring(event))
	--MOprint({...})
	local arg1,arg2,arg3,arg4,arg5 = select(1,...)
	if event == "PLAYER_LOGIN" then
		Mountiful_Loaded()
	elseif event == "COMPANION_LEARNED" then -- Rebuild selections array when user learns a new mount/pet
	
		Mountiful_Options.learningmode.value = true
	
		Mountiful_RebuildSelections()
		
	elseif event == "TAXIMAP_OPENED" then
		Dismount()
	
	elseif event == "UI_ERROR_MESSAGE" then
		
	elseif event == TESTEVENT then
		MountifulFrame:UnregisterEvent(TESTEVENT)
		
	elseif event == "ADDON_ACTION_FORBIDDEN" then
		if (arg1 == "Mountiful") then
			print(MOdruidfailmessage)
		end
	elseif MOUNTIFUL_CASTDETECTION[event] then --see postclick func at bottom
		if arg1=="player" then  --ignore others casts
			MOstopcastdetection()
			
			if(MOcompanionupdate) then
				MOcompanionupdate=false
				MOseenmountprocessing()
			end
			--update the macro to the new future mount
			if (MOmacroclicked) then
				MOmacroclicked = false
				
				local mountname
				if (MOpastmount and type(MOpastmount)=="number") then
					_,mountname = GetCompanionInfo("MOUNT",MOpastmount)
					mountname = MOfbgdbm(mountname)
				end
				
				Mountiful_UpdateMacro()		
			end
		end
		
		if(difftime(MOtimer,time()) > SPELLTIMEOUT) then  --2 seconds have passed
			MOstopcastdetection()
		end
		
		
		--Check if player stealth status changed
	elseif (event == "UPDATE_STEALTH") then
    
		--Check if stealthed
		if IsStealthed() then
		
			  --Dismiss companion when going stealth
			if Mountiful_Options.dismissonstealth.value then
				DismissCompanion( "CRITTER" );
			end
		end
	elseif (event == "COMPANION_UPDATE") then
		if(arg1=="MOUNT") then
			MOcompanionupdate=true
			MOstartcastdetection()  --catch the next spell cast
		end
	end
end

--[[
function Mountiful_OnUpdate(self,elapsed)
	--if no cast happened in 1.5 seconds, the length of a mount cast, then stop watching for mount casts
	MOelapsed = MOelapsed + elapsed
	if(MOelapsed > 1) then  --throttle
		MOelapsed = 0
		if (difftime(MOtimer,time()) > 2) then  --account for some lag
			MOstopcastdetection()
		end
	end
end
]]  --not needed.  we can just do this in the event handlers
function MOseenmountprocessing()
	MOprint("|c00ffaaff Seen Mount Processing")

	local tt,i,j,name, rank, iconTexture, count, duration, timeLeft,mountname, mountspellID, icon, issummoned ,index,buffIndex
	local groundspeed,flightspeed
	groundspeed, flightspeed = nil

	--loop through our mounts, see if it matches
	mountname, mountspellID, icon, issummoned = MOgetsummonedmount()
	if (not mountname) then return end
	mountname = MOfbgdbm(mountname)
	--check to see if we have seen this mount arelady
	groundspeed = MOgetspeedfromseen(mountname)
	if (groundspeed) then return end
	--maybe double check that it's right>?

	
	--if(castspellid == mountspellID) then   --this should always be true at this point, since a cast spell is a summoned one, but just in case

	--check that the buff/aura actually exists
	buffIndex = MOgetbuffindex(mountname)
	if (not buffIndex) then return end;
	groundspeed,flightspeed = MOgetspeedfrombuff(buffIndex)
	if (not groundspeed) then return end
	--weve seen it.  store it.
	MOprint("|c00ffff00 ADDING "..tostring(mountname).." to Seen Mounts.  Ground="..tostring(groundspeed).."  flight="..tostring(flightspeed))
	table.insert(Mountiful_Vars.seenmounts, {["name"]=mountname,["groundspeed"]=tonumber(groundspeed),["flightspeed"]=tonumber(flightspeed)})
	Mountiful_RebuildSelections()
	--end
	
end


function MOgetsummonedmount()
	MOprint("|c00ffaaff Get summoned mount")
	local mountname, mountspellID, icon, issummoned
	local mountnum = GetNumCompanions("MOUNT")
	for i=1, mountnum do
		_, mountname, mountspellID, icon, issummoned = GetCompanionInfo("MOUNT", i)
		if(issummoned) then --we are mounted
		--	MOprint("|c00ffaaff returning "..mountname)
			return mountname, mountspellID, icon, issummoned
		end
	end
	MOprint("|c00ff3366   Mo Mount is Summoned")
	return nil
end

function MOgetbuffindex(spellname)
	local name, buffIndex
	MOprint("|c00ffaaff  Find matching BUFF "..spellname)
	buffIndex = 1
	while(UnitBuff("player", buffIndex)) do
		name = UnitBuff("player", buffIndex)
		 
		if (name == spellname) then  --not sure if they will be the same  -- and (icon==iconTexture)
			MOprint("|c00ffaaff returning "..buffIndex)
			return buffIndex
		end
			 
		buffIndex = buffIndex+1
	end
	return nil
end

function MOgetspeedfrombuff(buffIndex)
--	MOprint("|c00ffaaff Get speed from buff "..buffIndex)
	local text,indexstart,indexend,indexpercent,groundspeed,flightspeed
	--set the tooltip of that buff
	
	if(not MountifulTooltip) then
		MountifulTooltip = CreateFrame("GameTooltip", "MountifulTooltip", nil, "GameTooltipTemplate") 
		
		--MountifulTooltip:AddFontStrings(MountifulTooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"),MountifulTooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText"))
	end
	MountifulTooltip:SetOwner(WorldFrame)
	MountifulTooltip:SetUnitBuff("player",buffIndex)
	MountifulTooltip:Show()
	text = _G["MountifulTooltipTextLeft2"]:GetText()
	MOprint("TT Text 2 = "..tostring(text))
	if(text) then
		
		groundspeed = nil
		indexstart,indexend = strfind(text, L["ground speed by"])
		if(indexend) then
			indexpercent = strfind(text,"%",indexend,true)
			groundspeed = strsub(text,indexend+1,indexpercent-1)
			MOprint("GSpeed = "..groundspeed)
		end
		
		flightspeed = nil
		indexstart,indexend = strfind(text, L["flight speed by"])
		if(indexend) then
			indexpercent = strfind(text,"%",indexend,true)
			flightspeed = strsub(text,indexend+1,indexpercent-1)
			MOprint("FSpeed = "..flightspeed)
		end
		MountifulTooltip:Hide()
		return groundspeed,flightspeed
	else
		MOprint("|c00ff0000  Error.   SetUnitBuff() didn't get a tooltip.  Index="..buffIndex)
	
	end
	return nil
end


function MOgetspeedfromseen(name)
	--MOprint("|c00ffaaff Get speed from seen "..name)
	for j = 1,#Mountiful_Vars.seenmounts do
		if(Mountiful_Vars.seenmounts[j].name == name) then
			--maybe double check that it's right>?
	--		MOprint("|c00ffaaff returning "..tonumber(Mountiful_Vars.seenmounts[j].groundspeed))
			return tonumber(Mountiful_Vars.seenmounts[j].groundspeed),tonumber(Mountiful_Vars.seenmounts[j].flightspeed)
		end
	end
--	MOprint("|c00ffaaff name not seen")
	return nil
end


-- Load Saved Variables / Check Defaults / Initialize UI
-- This should only run ONCE per game 
function Mountiful_Loaded()

	-- If Mountiful is loaded do nothing and exit function
	if MountifulLoaded then
		return
	end

	MOprint("|c00aaffccMountiful_loaded() |rcalled.  MountifulLoaded="..tostring(MountifulLoaded))

	Mountiful_CreateDefaults()
	Mountiful_LoadSavedVars()
	Mountiful_CreateMountTables()
	Mountiful_InitializeSelections()
	Mountiful_CreateMainFrame()
	
	MOcreateoptions()

	MOcreatemacro()
	
	--generate future mount num
	MOfuturemount =	MOgeneratemountname(false)
	
	MountifulLoaded = true
	MOprint("|c0000ff00 Loaded() successfully completed")
	if (Mountiful_Options.learningmode.value) then
		print("|c00ffff00Mountiful |rLearning Mode is ON - only mounts not yet seen by mountiful will be cast.")
	end
end

function MOrightclick()
	--MOfuturemount = MOgeneratemountname(Mountiful_Options.preselecteddefault.value)  --it makes a stupid local copy here that doesnt get transfered to the updatemacro, and i dont know why.	
	--Mountiful_UpdateMacro(MOfuturemount)
	
	Mountiful_Command("SlowGround")
	
end


function MOcreatemacro() 	--create a macro - the only way to cast 'spell' mounts like druid flight forms
	--check if mountiful macro already exists
	if (GetMacroIndexByName("Mountiful") > 0) then
		MOprint("Mountiful macro already exists.  id# "..GetMacroIndexByName("Mountiful"))
	else
		--check if we are over the limit.  if we are, print error message.
		local numglobal,numperchar = GetNumMacros()
		if (numglobal >= 36 and numperchar >=18) then
			print("No Macro slots free.  Cannot create the Mountiful Macro (/click Mountiful).  You're on your own.")
		elseif (numglobal >= 36) then  --make it local
			CreateMacro("Mountiful",1,MACROTEXT,1,true)
			
		else
			
			local macroid = CreateMacro("Mountiful",1,MACROTEXT,nil,true)  --global
			MOprint("Creating global macro.  Id="..macroid)
			--MOprint("macroid = "..tostring(macroid))
		end
	end

end
function Mountiful_CreateDefaults()
	Mountiful_Defaults = {
		["Options"] = {
			--revision = 129,
			safeflying = {["value"] = true, ["tooltip"] = L["Disallow dismounting in mid-air"],},
			--debugging = {["value"] = false, ["tooltip"] = L["print debugging messages"]},
			autoremount = {["value"] = true, ["tooltip"] = L["Mountiful will dismount and re-mount with one key press"]},
			preselecteddefault = {["value"] = true, ["tooltip"] = L["Sets whether the automated macro uses preselected categories"]},
			--no310 = {["value"] = false, ["tooltip"]= L["Combine 310% mounts with 280% mounts"]},
			autopet = {["value"] = true, ["tooltip"] = L["Summon a companion whenever you mount"]},
			dismissonstealth = {["value"] = true, ["tooltip"] = L["Dismiss your companion when you stealth"]},
			learningmode = {["value"] = true, ["tooltip"] = L["Use mounts Mountiful hasn't figured out the speed of (yet)"]},
		},
			
		["Categories"] = {
			[1] = "FastGround",
			[2] = "FastFlying",
			[3] = "SlowGround",
			[4] = "SlowFlying",
			[5] = "ExtremeFlying",
			[6] = "Swimming",
			[7] = "Qiraj",
			[8] = "Vashjir",
			[9] = "All",
			[10] = "Pet",
			[11] = "notseen",
		},
		["Categories_Selections"] = {
			["Pet"] = {
				ispet = true,
			},
		},
	}
	
	--[=[
	--here is my suggested data structure.  it is the closest possible to how the graphics are.  We woudln't have as many issues as we've been having.  Unfortunately everything would have to change to do this
	Mountiful_vars={
		[options] = {
			safeflying = true,
			debugging = false,
			autoremount = true,
		}
		[categories]={
			[1] = {
				[name] = string
				[companiontype] = "Mount" or "Critter" or "druid"
				[mounts] ={
					[1] = {
						[name] = string
						[checked (or selected as you say)] = boolean
						[id] = number
					}
					[2] = ...
				}
			}
			[2] = .....
		}
	}
	
	]=]
	
	
end
	
function Mountiful_LoadSavedVars()
--basically catch all old versions and formats it to current data structure

	--seterrorhandler(ErrorWithStack)

	-- Start checks for really old versions
	if Mountiful_Vars and Mountiful_Vars.version then
		Mountiful_Vars = nil
	elseif(Mountiful_Vars and Mountiful_Vars.Categories[1] == "Ground") then
		Mountiful_Vars = nil
	end
	
	
	--End checks for really old versions

	if (not Mountiful_Vars) then
		Mountiful_Vars = Mountiful_Defaults
	end
	
	if (not Mountiful_Vars.seenmounts) then  --mount that have already been seen, we should know if they are flying or not by the tooltip
		Mountiful_Vars.seenmounts = {}
	end
	
	Mountiful_Options = Mountiful_Vars["Options"]
	Mountiful_Categories = Mountiful_Vars["Categories"]
	Mountiful_Selections = Mountiful_Vars["Categories_Selections"]
	
	
--	MOprint(Mountiful_Defaults.Categories)
	
		
	local categoryfound = true
	--make sure every category from defaults exist - needed by olllld saved variables which dont have it
	for i,value in pairs(Mountiful_Defaults.Categories) do
		categoryfound = false
		--MOprint("searching for default Category "..value)
		for j = 1,#Mountiful_Categories do
			if(Mountiful_Categories[j] == value) then
				categoryfound = true
--				MOprint("Category "..value.." found.")
				break
			end
		end
		if(not categoryfound) then
			MOprint("Category "..value.." NOT found!  adding.")
			Mountiful_Categories[#Mountiful_Categories+1] = value
		end
	end
	
	
--	MOprint(Mountiful_Options)
--	MOprint(Mountiful_Vars.Options)
	
	--make sure every options from defaults exist 
	for option,setting in pairs(Mountiful_Defaults.Options) do
	--	MOprint("Checking "..tostring(option).." in mountiful_options.  default setting is "..tostring(setting.value))
		if not Mountiful_Options[option] or not (type(Mountiful_Options[option]) == "table") then  --if its a table, then that means we alredy fixed it.   booleans and whatever means we need to add the "value" key
			Mountiful_Options[option] = {}
			Mountiful_Options[option].value = setting.value  --put the default in there
			Mountiful_Options[option].tooltip = setting.tooltip
		--	MOprint("Creating "..tostring(option).." in mountiful_options.  setting to "..tostring(setting.value))
		end
	end
	
	--version 181 changed some stuff, took out some values
	for option,setting in pairs(Mountiful_Options) do
		if not Mountiful_Defaults.Options[option] then
			Mountiful_Options[option] = nil
		end
	end
	
	
	--we changed the name of autodismount to autoremount
	if Mountiful_Options.autodismount then
		MOprint("old Mountiful_Options.autodismount found:  "..tostring(Mountiful_Options.autodismount))
		Mountiful_Options.autodismount = nil
		Mountiful_Options.autoremount.value = true
	end
	
end




function Mountiful_InitializeSelections()
	--MOprint("INitializing selections table - starting values are false")   --
--		checkbox:SetChecked(Mountiful_Selections[panelname][mountname]["checked"])   --always errors when i do a line like this,   /cry

	local ispet
	local companionType
	local mounts = {}
	for i,panelname in ipairs(Mountiful_Categories) do  --else the selectall acts wierd
		if (not Mountiful_Selections[panelname]) then
			Mountiful_Selections[panelname] = {}
		end
		
		if (string.lower(panelname)=="pet") then --sometimes ispet for the pet panel is false.  i dont know why.  and I dont care.
			Mountiful_Selections[panelname].ispet = true
		end
		
		if (Mountiful_Selections[panelname].ispet) then  
			ispet = true
			companionType = "CRITTER";
		else
			companionType = "MOUNT";
		end
		
		if(ispet) then
			mounts = Mountiful_Mounts.Pet
		elseif(Mountiful_Mounts[panelname]) then
			mounts = Mountiful_Mounts[panelname]
		else
			MOprint("|c00ffeeee Panelname "..panelname.. " NOT found in  Mountiful_Mounts  initializselections.  useing all!")
			mounts = Mountiful_Mounts.All
		end

		if(mounts and #mounts>0) then
			for j = 1,#mounts do
				_, mountname, spellID, icon, _ = GetCompanionInfo(companionType, mounts[j])
				if(not mountname) then break end;  --catches old data
				mountname = MOfbgdbm(mountname)
				if (Mountiful_Selections[panelname][mountname] and Mountiful_Selections[panelname][mountname].checked == false) then 
					--removes corrupt data
					Mountiful_Selections[panelname][mountname] = nil
				end
				if( not Mountiful_Selections[panelname][mountname]) then
					Mountiful_Selections[panelname][mountname] = {checked=false,id=mounts[j]}
				end

				
				--recheck all id's for mounts
				Mountiful_Selections[panelname][mountname].id = mounts[j]
			end
		end
		
	end
end

function Mountiful_GetCommand(msg)
	if msg then
		local a,b,c=strfind(msg, "(%S+)") --contiguous string of non-space characters
		if a then
			return c, strsub(msg, b+2)
		else	
			return ""
		end
	end
end

function Mountiful_Command(msg) -- Parse the slash commands
	-- If not loaded then load
	
	if (not MountifulLoaded) then  
		Mountiful_Loaded()   --i had the same idea.  
	end
	if not msg then msg = "" end;
	--if not ispet then ispet=false end;

	local rand
	
	local msg = SecureCmdOptionParse(msg)
	local Cmd, SubCmd = Mountiful_GetCommand(msg)
	
	--MOprint("Command = "..tostring(Cmd).."   sub = "..tostring(SubCmd))
	
	local tmpcmd, ismountcmd
		for i, panel in pairs(Mountiful_Categories) do -- Check to see if the cmd matches the name of a category
			if (type(panel) == "string") then
				tmp = strlower(panel)
				Cmd = strlower(Cmd)
				if (Cmd == tmp) then
					ismountcmd = true
					tmpcmd = panel
					break
				end
			end
		end
		if (Cmd == "help") then
			print(L["/mount <Category> - Uses a random mount/pet from that category"])
			print(L["/mount <Category> pre - Uses a random preselected mount/pet from that category"])
			print(L["/mount smart - Uses a random mount that suits your location"])
			print(L["/mount smart pre - Uses a random mount from your Flying/Ground lists depending on your location"])
			print(L["/mount add <Category> - Adds a new category"])
			print(L["/mount remove <Category> - Removes a category"])
			
			for key,setting in pairs(Mountiful_Options) do
				print("/mount "..tostring(key).." - "..tostring(setting.tooltip))
			end

			print(L["/mount settings - See what all your settings are currently at"])
			print(L["/mount reset - Makes Mountiful act like a brand new install.  Destroys all saved settings.  Also causes your ui to reload"])
			
			
		elseif (Cmd == "hide") then
			MountifulFrame:Hide()
		elseif (Cmd == "settings") then
			for option,setting in pairs(Mountiful_Options) do
				print(tostring(option).." = "..tostring(setting.value))
			end			
		elseif (Cmd == "reset") then
			Mountiful_ResetSettings()
		elseif (Cmd == "add") then
			Mountiful_AddPanel(SubCmd)
		elseif (Cmd == "remove") then
			Mountiful_RemovePanel(SubCmd)
		elseif (Cmd == "dismiss") then
			DismissCompanion("CRITTER")
			PetSummoned = false
		elseif (Cmd == "smart") then
			if SubCmd == "pre" or SubCmd == "predefined" then
				Mountiful_SmartMount(true)
			else
				Mountiful_SmartMount()
			end
		elseif (Cmd == "rebuildselections") then
			print(L["Rebuilding mount selections database"])
			Mountiful_RebuildSelections()
		elseif (Cmd == "debug") then
			MOdebug = not MOdebug
			print(tostring(MOdebug))
		elseif Mountiful_Options[Cmd] then
			if type(Mountiful_Options[Cmd]) == "table" then
				
				Mountiful_Options[Cmd].value = not Mountiful_Options[Cmd].value
				print(Cmd.." now: "..tostring(Mountiful_Options[Cmd].value))
				MOfuturemount = nil
				Mountiful_RebuildSelections()
				MOupdateoptions()
			end
			
		
		elseif (Cmd == "test") then
			MOtest()
	
		
		elseif (ismountcmd) then -- If the command matched the name of a category call the mount function
			MOprint("|c000033aaIs Mount command!")
			if SubCmd == "debug" then
				MOdebug = true
				MOprint(Mountiful_Mounts[tmpcmd])
			elseif SubCmd == "pre" or SubCmd == "predefined" then
				Mountiful_Mount(tmpcmd,true)
			else
				Mountiful_Mount(tmpcmd)
			end
		else	
			if(MountifulFrame:IsVisible()) then
				MountifulFrame:Hide()
			else
				MountifulFrame:Show()
			end
		end
end

function MOtest()
	MOprint("|c0000ffff Mo Test")
	MOdebug = true
	
	
	MountifulTooltip:Hide()
	--MountifulTooltip:Show()
	MountifulTooltip:SetOwner(WorldFrame)
	MOprint("IS MOUntiful TOoltip visible? 1  "..tostring(MountifulTooltip:IsVisible()))
	
	MOprint("|c0033ff00  seenmounts:")
	MOprint(Mountiful_Vars.seenmounts)
	MOprint("|c0033ff00  options:")
	MOprint(Mountiful_Options)
	
	MOprint("|c0033ff00  Mounts:")
	MOprint(Mountiful_Mounts)
	Mountiful_RebuildSelections()
	
end

function MOdismount()

	MOprint("Reached MY dismount!! hahahaha")
end

function Mountiful_CreateMainFrame()
	if (not MountifulPageNum) then
		MountifulPageNum = 1
	end
	
	local button,tempbutton
	mountifulcreated = true
	
	local title = _G["Mountiful_Frame_Title"]
	title:SetText(title:GetText()..VersionString)
	
	local parent = _G["MountifulFrame"]
	parent:SetScript("OnShow",Mountiful_Update)
	local leftpanel = getglobal("MountifulFrame_LeftPane")
	local leftpanelheight = leftpanel:GetHeight()
	local rightpanel = CreateFrame("Frame", "mountifulrightpanel", parent, "RightPane_Template")
	local paneltext = getglobal(rightpanel:GetName().."_Name")
	local buttonheight = 20

	RTCF = math.floor(leftpanelheight / buttonheight)  --rows that can fit
	
	MOprint("|c000033dd Rows that can fit in Left panel: "..RTCF)
	
	for i = 1,RTCF do
		button = CreateFrame("Button", "mountifulleftmenubutton"..i, leftpanel)
		button:SetWidth(143)
		button:SetHeight(buttonheight)
		button:SetHighlightTexture("Interface\\Tooltips\\UI-Tooltip-Background")
		--button:SetDisableFontObject(GameFontDisable)
		button:SetNormalFontObject(GameFontNormal)
		button:SetHighlightFontObject(GameFontHighlight)
		
		button.id = i
		if(i == 1) then
			button:SetPoint("top",0,-4)
		else
			button:SetPoint("top",getglobal("mountifulleftmenubutton"..i-1),"bottom")
		end
		button:SetScript("OnClick",function(self)
			Mountiful_PanelSelect(self)  --seems like, in beta, one can't use virtual handlers anymore?
		end);
	end
	
	local rows = 4
	local columns = 6
	
	for i = 1,rows*columns do
		local mounticon = CreateFrame("Frame", "mountifulicon"..i, rightpanel, "MountifulIcon")
		if (i == 1) then
			firstinrow = mounticon
			mounticon:SetPoint("topleft",16,-26)
		elseif (mod(i, columns) == 1) then
			mounticon:SetPoint("TOPLEFT", firstinrow, "BOTTOMLEFT", 0, 0)
			firstinrow = mounticon
		else
			mounticon:SetPoint("TOPLEFT", previcon, "TOPRIGHT", 0, 0)
		end
		
		
		--get the associated check button
		checkbutton = getglobal(mounticon:GetName().."_CheckButton")
		--can't seem to set click handlers in xml anymore
		checkbutton:SetScript("OnClick",function(self)
			MountifulCheckBox_OnClick(self)
		end)
		
		--get the associated button
		button = getglobal(mounticon:GetName().."_MountIcon")
		--can't seem to set click handlers in xml anymore
		button:SetScript("OnEnter",function(self)
			mountifulicon_OnEnter(self)
		end)
		button:SetScript("OnLeave",function(self)
			GameTooltip:Hide()
		end)
		
		previcon = mounticon
	end
	
	getglobal(rightpanel:GetName().."_NextPage"):SetScript("OnClick",Mountiful_NextPage)
	getglobal(rightpanel:GetName().."_PrevPage"):SetScript("OnClick",Mountiful_PrevPage)
	
	
	--add a select all button
	local nextpagebutton = getglobal(rightpanel:GetName().."_PrevPage")
	local selectall = CreateFrame("CheckButton","mountifulselectall",rightpanel,"UICheckButtonTemplate")
	getglobal(selectall:GetName().."Text"):SetText("Select/deselect all")
	selectall:SetPoint("left",nextpagebutton,"right",50,0)
	selectall:SetScript("OnClick",function(self)
		Mountiful_SelectAllClick(self)
	end);
	
	Mountiful_Update()	
end




function Mountiful_SelectAllClick(self)
	local panelname = Mountiful_Categories[MountifulSelectedNum]
	MOprint("Select all clicked.  panelname ="..tostring(panelname))
	local mountname,jvalue,newvalue

	newvalue = self:GetChecked()

	if(Mountiful_Selections[panelname]) then
		for mountname,jvalue in pairs(Mountiful_Selections[panelname]) do
			--get the first check value, and use that to decide what to do with the rest
			if type(jvalue) == "table" then
				Mountiful_Selections[panelname][mountname]["checked"] = newvalue
			end
		end
	end
	Mountiful_Update()
end
	


----all the updating and drawing stuff
function Mountiful_Update()
--graphical stuff
	MOprint("|c00dddd33Mountiful_Update()|r  MountifulSelectedNum="..tostring(MountifulSelectedNum))
	
	MountifulFrame:SetFrameStrata(SpellBookFrame:GetFrameStrata())
	MountifulFrame:Raise()
	
	
	if(not MountifulSelectedNum) then
		MountifulSelectedNum = 1
	end
	
	while (Mountiful_Categories[MountifulSelectedNum]) do  --loop through all categories to find one with something in it
		curselectedcat = Mountiful_Categories[MountifulSelectedNum]
		if(Mountiful_Mounts[curselectedcat] and #Mountiful_Mounts[curselectedcat] > 0) then
			break  --we're good.  exit the loop
		end
		MountifulSelectedNum = MountifulSelectedNum + 1
	end
	
	
	
	Mountiful_UpdateLeftPanel()
	Mountiful_UpdateRightPanel()

	
end
function Mountiful_UpdateMacro(mountname)  -- changes the icon of the macro
  --changing the macro mid-cast is resulting in very strange and hard to reproduce behavior
	local fulltext
	if (not mountname) then mountname = MOfuturemount end
	if (not mountname) then return end

	MOprint(" EDITING MACRO.  icon=|c000044ee"..tostring(mountname).."|r ")
	fulltext = MACROTEXT.."\n#showtooltipicon "..mountname
	EditMacro("Mountiful", nil, nil, fulltext, nil, nil)  --apparently doing this too soon after calling the macro causes strange behavior
	
	
end

function Mountiful_UpdateLeftPanel()
	local buttoni = 1
	local button
	for i, category in ipairs(Mountiful_Categories) do
		
		button = getglobal("mountifulleftmenubutton"..buttoni)
		if(not button) then return end
		button.categorynum = i
		button.name = category
		button.index = buttoni
		--MOprint("UPDate left panel: category="..category.."  mounts[category]=")
		--MOprint(Mountiful_Mounts[category])
		if(Mountiful_Mounts[category] and #Mountiful_Mounts[category] > 0) then
			button:Show()
			button:SetText(category.." ("..#Mountiful_Mounts[category]..")")
			buttoni=buttoni+1
		elseif(Mountiful_Mounts[category] and #Mountiful_Mounts[category] <= 0) then
			--dont show 0 count categories?  --skip.  dont increment buttoni
			
		else  -- its a custom category
			button:Show()
			button:SetText(category)
			buttoni=buttoni+1
		end
		
		if(i == MountifulSelectedNum) then
			button:SetText("|c0000ff55"..tostring(button:GetText()))  --greeny
		end
		

		
	end
	button = getglobal("mountifulleftmenubutton"..buttoni) --hide non used
	while (button) do
		button:Hide()
		buttoni = buttoni + 1
		button = getglobal("mountifulleftmenubutton"..buttoni)
	end
	
end


function Mountiful_UpdateRightPanel()
	
	local ispet=false
	local rightpanel = getglobal("mountifulrightpanel")
	if not rightpanel:IsVisible() then return end
	local paneltext = getglobal(rightpanel:GetName().."_Name")
			
	local endmountnum = MountifulPageNum * 24
	local startmountnum = (MountifulPageNum * 24) - 23
	local mountname, spellID, icon
	local button 
	local mounttexture
	local checkbox
	local iconi=1
	local companionType
	
	if(not MountifulSelectedNum) then
		MountifulSelectedNum = 9 --All panel
	end

	panelname = Mountiful_Categories[MountifulSelectedNum]
	
	if not panelname then panelname = "All" end  --panelnames Do dissappear - the notseen panel for example
	
	if not Mountiful_Selections[panelname] then
		--Mountiful_RebuildSelections()  --bug here, when right-clicking on each item in 'notseen'.  Notseen disappears, triggering this
	end
	
	
--	MOprint("UPDATERight:  Panelname="..tostring(panelname).."   SelectedNum="..tonumber(MountifulSelectedNum))
	
	if (not MountifulPageNum) then
		MountifulPageNum = 1
	end
	paneltext:SetText(tostring(panelname).." Page "..MountifulPageNum)
	if ((Mountiful_Selections[panelname] and Mountiful_Selections[panelname].ispet) or (string.lower(panelname) == "pet")) then
		ispet = true
		companionType = "CRITTER";
	else
		companionType = "MOUNT";
	end
	local mounts = {}
	--[[  --custom pet categories
	if(ispet) then
		mounts = Mountiful_Mounts.Pet
	else
	]]
	
	if(Mountiful_Mounts[panelname]) then
		mounts = Mountiful_Mounts[panelname]
	else
		MOprint("|c00ffeeee Panelname "..panelname.. " NOT found in  Mountiful_Mounts  update().  useing all!")
		mounts = Mountiful_Mounts.All
	end
	
	if #mounts <= (MountifulPageNum * 24) then -- Disable the next page button if there is only one page
		getglobal(rightpanel:GetName().."_NextPage"):Disable()
	else
		getglobal(rightpanel:GetName().."_NextPage"):Enable()
	end
	if(MountifulPageNum == 1 ) then
		getglobal(rightpanel:GetName().."_PrevPage"):Disable()
	else
		getglobal(rightpanel:GetName().."_PrevPage"):Enable()
	end
	
		
	for i = startmountnum,endmountnum do
		if (not mounts[i]) then break end;
		 _, mountname, spellID, icon, _ = GetCompanionInfo(companionType, mounts[i])
		if not mountname then break end;
		mountname = MOfbgdbm(mountname)
		
		mounticon = getglobal("mountifulicon"..iconi)
		mounticon:Show()
		button = getglobal(mounticon:GetName().."_MountIcon")
		mounttexture = getglobal(mounticon:GetName().."_MountIcon_IconTexture")
		checkbox = getglobal(mounticon:GetName().."_CheckButton")
		checkbox.mountname = mountname
		
		mounticon.link = GetSpellLink(spellID)
		button.link = GetSpellLink(spellID)
		mounttexture:SetTexture(icon)
		checkbox:SetID(i)
		
		button:SetAttribute("type","spell")  --daxdax
		button:SetAttribute("spell",mountname)
	
		if not Mountiful_Selections[panelname][mountname] then
			Mountiful_CreateMountTables() 
			Mountiful_InitializeSelections()
			break
		end
	
		checkbox:SetChecked(Mountiful_Selections[panelname][mountname]["checked"] or false)

		iconi=iconi+1
	end
	
	--MOprint("Hiding icons +"..iconi)
	mounticon = getglobal("mountifulicon"..iconi)
	while(mounticon) do
		mounticon:Hide()
		iconi=iconi+1
		mounticon = getglobal("mountifulicon"..iconi)
	end
	--MOprint("Hiding end icon "..iconi)

end



function Mountiful_PanelSelect(self)
	MOprint("panel_selected(): ")
	MOprint(self)

	--sigh.  if the first button is clicked, 'THIS' doesnt work.  why?????!

	if(not self or not self:GetName()) then
--		self = mountifulleftmenubutton1
		MOprint("'This' was nil.  :(")
		MountifulSelectedNum = 9  --9 is 'all'
	else
		MountifulSelectedNum = self.categorynum  --we cant use button ID because they might delete buttons?
	end

	MountifulPageNum = 1
	Mountiful_Update()
end


function mountifulicon_OnEnter(self)
	--MOprint("ON enter breeched.")
	--MOprint(self)
	if (self) and (self.link) then
		GameTooltip:SetOwner(self)
		GameTooltip:SetHyperlink(self.link)
		GameTooltip:Show()

	end
end


function Mountiful_AddPanel(newpanel, ispet) -- Add a new category
	MOprint("NEWpanel() called "..newpanel)
	local exists = false
	if newpanel == nil or newpanel == "" then
		if ispet == true then
			print("Usage: /pet add <panelname>")
		else
			print("Usage: /mount add <panelname>")
		end
	else
		local button = getglobal("mountifulleftmenubutton"..#Mountiful_Categories+1)
		if(not button) then 
			print("Maximum number of categories exceeded.  Please remove some using the '/mountiful remove <name>' command.")
			return
		end
	
		newpanellower = strlower(newpanel)
		if in_array(newpanellower, InvalidNames) then
			print(newpanel.." cannot be used as a Category name")
		else
			MOprint("NEWpanel() cchecking for exists in Mountiful_categories "..newpanel)
			for index, value in pairs(Mountiful_Categories) do
				MOprint("Mountiful category checking exists.   Index = "..index.."   Value="..value)
				if newpanel == value then
					MOprint("|c00ffdd00 panel "..value.. " already exists!")
					exists = true
				end
			end
			if exists then
				print("Cannot add panel \""..newpanel.."\", it already exists")
			else
				Mountiful_Categories[#Mountiful_Categories+1] = newpanel
				Mountiful_Selections[newpanel] = { };
				Mountiful_Selections[newpanel].ispet = ispet
				MOprint("Successfully added "..newpanel)
			end
			
			Mountiful_RebuildSelections()
		end
	end

end

function Mountiful_AddNewPetPanel()
	local panelname,x
	x=0
	repeat
		x=x+1
		panelname = "Pet"..x
	until not Mountiful_Selections[panelname]
	
	Mountiful_AddPanel(panelname, true)
end

function Mountiful_AddNewMountPanel()
	local panelname,x
	x=0
	repeat
		x=x+1
		panelname = "Mount"..x
	until not Mountiful_Selections[panelname]
	
	Mountiful_AddPanel(panelname, false)
end



function Mountiful_RemovePanel(panel) -- Remove a category
	if panel == nil then
		print("Usage: /mount remove <panelname>")
		return
	elseif in_array(panel, Mountiful_Defaults.Categories) then
		print("Cannot remove that panel")
		return
	else
		for index, value in pairs(Mountiful_Categories) do
			if strlower(value) == strlower(panel) then
				table.remove(Mountiful_Categories,index)
				if (Mountiful_Selections[value]) then
					MOprint("removing value : "..value)
					--table.remove(Mountiful_Selections,value)
					Mountiful_Selections[value] = nil
				end
				print(value.." was removed")
				MountifulSelectedNum = 1
				Mountiful_Update()
				return
			end
		end
	end
	print (panel.." was not removed")
end

-- --
function MountifulCheckBox_OnClick(self) -- Runs when user clicks the checkbox for a mount


	local mountname = self.mountname
	local panelname = Mountiful_Categories[MountifulSelectedNum]
	
	MOprint("Cleek.  panelname = "..panelname)

	if (self:GetChecked()) then -- Mount is now checked, set to checked in Selections and update its id
		MOprint(mountname..": Checked = true; id = "..tostring(id).."; panelname = "..panelname.."; mountname = "..mountname)
		Mountiful_Selections[panelname][mountname]["checked"] = true
	else -- Mount is now unchecked, set to unchecked in Selections and update its id
		Mountiful_Selections[panelname][mountname]["checked"] = false
	end
	
	if Mountiful_Selections[panelname].ispet then
		companiontype = "CRITTER"
	else
		companiontype = "MOUNT"
	end

	Mountiful_Selections[panelname][mountname]["id"] = Mountiful_NameToNum(mountname,companiontype)
	
	Mountiful_Update()
end

-- --
function Mountiful_Mount(panel,pre)
	MOprint("|c0000ff00 Mountiful_mount called.  Panel:"..tostring(panel))
	local rand,ispet,summontype,mountnumber,mount

	if Mountiful_Selections[panel] and Mountiful_Selections[panel].ispet then
		ispet = true
		summontype = "CRITTER"
	else
		summontype = "MOUNT"
	end
		
	if (not ispet) and (IsMounted()) then -- If player is already mounted dismount
		if IsFlying() and Mountiful_Options.safeflying.value then -- If player is flying and safeflying is on don't dismount
			MOprint("NO dismount for you!")
			return
		else
			MOprint("dismount!")
			Dismount()
			if(not Mountiful_Options.autoremount.value) then  --dont summon another pet/mount
				MOprint("And dont come back again!")
				return
			end
		end
	end
	if (ispet) and (IsFlying()) and (Mountiful_Options.safeflying.value) then
		MOprint("You tried to summon a pet in mid-air?  doh")
		return --dont cast pets in midair
	end

	
	
	--auto summon a companion
	if(not ispet and Mountiful_Options.autopet.value) then
		Mountiful_Mount("Pet",pre)
	end
	
	
	if not panel then return end;
	
	local summontable = {}
	summontable = MOpaneltotable(panel,pre)
	if (not summontable) then return end;  --just in case
	
	if(not ispet and MOusefuturemount) then
		MOprint("ispet="..tostring(ispet).."  MOusefuturemount="..tostring(MOusefuturemount))
		if not MOfuturemount then
			MOfuturemount = Mountiful_NameToNum(MOgeneratemountname(pre),"MOUNT")
		end
		if type(MOfuturemount) == "string" then  --flight forms
			if(IsUsableSpell(MOfuturemount)) then  --this must be true to get to this poitn but just in case  
				Mountiful:SetAttribute("type", "spell")
				Mountiful:SetAttribute("spell", MOfuturemount)
				return
				--Mountiful_UpdateMacro(mountnumber)  -- problem.  Updating the macro so soon after calling the macro results in weird behavior.  Sometimes its gibberish and I Mistell strange things to chat
			end
			mountnumber = Mountiful_NameToNum(MOfuturemount)
			if not mountnumber then --should never happen?
				MOprint("|c00ff0000 error.  |rMountnumber not found.  futuremount="..tostring(MOfuturemount))
				mountnumber = MOgetrandmountnum(summontable)
			end
		else
			MOprint("using MOfuturemount = "..tostring(MOfuturemount))
			mountnumber = MOfuturemount
		end
		
		--generate new future mount num
		MOfuturemount = MOgeneratemountname(pre)
		
	else
		mountnumber = MOgetrandmountnum(summontable)
		MOprint("Creating a new random number  ("..tostring(mountnumber)..").  MOfuturemount is now "..tostring(MOfuturemount))
	end
	
	
	
	MOusefuturemount = false
	
	MOprint("|c00ffff00Summoning "..tostring(summontype).."  #"..tostring(mountnumber).." "..tostring(MOnumtoname(mountnumber,summontype)))
	
	CallCompanion(summontype, mountnumber)
	
	
	if(ispet) then
		LastPetSummoned = mountnumber
	else
		MOpastmount = mountnumber  --save for checking event
	end
end


function Mountiful_SmartMount(predefined)
	local panelname = Mountiful_GetSmartPanel()--so we can test generating a 'what if' mount without actually summoning it, for the macro
	Mountiful_Mount(panelname,predefined)
end

function Mountiful_GetSmartPanel()  --so we can test generating a 'what if' mount without actually summoning it, for the macro
	local druidcheck = IsUsableSpell("Swift Flight Form")
	--MOprint("|c00ff00ffGetSmartPanel() |rcalled.   IsUsableSpell('Swift Flight Form') == "..tostring(druidcheck))
	local mountnum = GetNumCompanions("MOUNT")
	local flyable
	local zoneName = GetRealZoneText()
	local ridingSkill = Mountiful_GetRidingSkill()
--	local level = UnitLevel("player") -- Get players level
	local tmpnum
	local tablename
	local isvashjir = false
	if(zoneName == L["Vashj'ir"] or zoneName == L["Abyssal Depths"] or  zoneName == L["Kelp'thar Forest"] or zoneName == L["Shimmering Expanse"]) then
		isvashjir = true
	end
	
	--Check if area is flyable and if player is allowed to fly there
	flyable = MOgetisflyable()
	
	-- Pick a mount from the first array that is not empty
	if (zoneName == "Ahn'Qiraj") and (#Mountiful_Mounts.Qiraj > 0) and (IsInInstance()) then
		tablename = "Qiraj"
	elseif (isvashjir) and (#Mountiful_Mounts.Vashjir > 0) and (IsSwimming()) then
		tablename = "Vashjir"
	elseif IsSwimming() and #Mountiful_Mounts.Swimming > 0 then
		tablename = "Swimming"	
	elseif IsSwimming() then
		tablename = "FastGround"
	elseif flyable and Mountiful_Options.learningmode.value and #Mountiful_Mounts.notseen > 0 then
		tablename = "notseen"
	elseif flyable and ridingSkill >= 300 and #Mountiful_Mounts.ExtremeFlying > 0 then
		tablename = "ExtremeFlying"
	elseif flyable and IsUsableSpell("Swift Flight Form") and MOsecurebuttonclicked then
		--CastSpellByName("Swift Flight Form")  --[[  --protected code.  wont work  ??]]
		MOprint("Swift flight form found in GetSmartPanel.  ")
		return "Swift Flight Form"
	elseif flyable and IsUsableSpell("Flight Form")	and MOsecurebuttonclicked then
		return "Flight Form"
	elseif flyable  and ridingSkill >= 300 and #Mountiful_Mounts.FastFlying > 0 then  --just because its a fast mount doesnt mean you need 300 riding skill
		tablename = "FastFlying"
	elseif flyable and ridingSkill >= 175 and #Mountiful_Mounts.SlowFlying > 0 then
		tablename = "SlowFlying"
	elseif #Mountiful_Mounts.FastGround > 0 and ridingSkill >= 150 then
		tablename = "FastGround"
	elseif #Mountiful_Mounts.SlowGround > 0 then
		tablename = "SlowGround"
	else
		if(MountifulLoaded) then  --meaning its not the initial generate future mount call
			print("No mounts available")
		end
		return
	end
	
	return tablename
	
end


function MOpaneltotable(panelname,pre)
	local summontable = {}
	local ispet,summontype,index,value
	
	if(IsUsableSpell(panelname)) then  --catch flight forms and other special 'spell' mounts
		table.insert(summontable,panelname)
		return summontable
	end
	
	if Mountiful_Selections[panelname] and Mountiful_Selections[panelname].ispet then
		ispet = true
	end
	
	if (pre) then --pre, meaning, use only the checked mounts/pets in that category
		if(Mountiful_Selections[panelname]) then
			MOprint("|c00eeddee Generating a table from Pre-selected selections, panelname="..tostring(panelname))
			for mountname, value in pairs(Mountiful_Selections[panelname]) do  --panelname is the mount category, first entry is the mount name, value is checked/id table
				if(mountname ~= "ispet" and value.checked) then
					if(ispet and value.id == LastPetSummoned) then  --dont call the same pet twice ina row.  i hate that.
						--skip
					else
						summontable[#summontable+1] = value.id
					end
				end
			end
		else
			MOprint("Nothing is pre-selected for panelname "..tostring(panelname)..".  Defaulting to non pre-selected.")
			return MOpaneltotable(panelname,false)
		end
	else
		if(ispet and #Mountiful_Mounts.Pet > 0) then
			summontable = Mountiful_Mounts.Pet
		else
			--if(Mountiful_Categories[panelname]) then--dammit its not indexed by string grrr
			if((Mountiful_Mounts[panelname]) and (#Mountiful_Mounts[panelname] > 0)) then
				summontable = Mountiful_Mounts[panelname]  --there was a premade table made in makealltables()
			elseif (#Mountiful_Mounts.All > 0) then--if(Mountiful_Categories[panelname]) then--dammit its not indexed by string grrr
				summontable = Mountiful_Mounts.All
				MOprint("No panelname found for "..tostring(panelname).." in panelToTable.  defaulting to all")
			else
				MOprint("No Mounts found")
				return nil
			end
		end
	end
	
	if (#summontable == 0) then
		return MOpaneltotable(panelname,false)
	end
	
	return summontable
	
end


function MOgetrandmountnum(summontable)
	if not summontable then return 1 end
	if(#summontable == 1) then
		rand = 1
	elseif(#summontable > 1) then
		rand = random(1,#summontable)
	end
	return summontable[rand]
end




function MOgetisflyable()
--Get the continent the player is on
	SetMapToCurrentZone()
	currentContinent = GetCurrentMapContinent()
	local zoneName = GetRealZoneText()
	local subZone = GetSubZoneText()
	local coldweatherflying, _ = IsUsableSpell(L["Cold Weather Flying"]) -- Does the player have Cold Weather Flying?
	
	--wintergrasp you cant fly if a battle is going on
	
	if(GetWintergraspWaitTime) then
		MOprint("Wait time found")
	else
		MOprint ("NO wait time found")
	--	return false
	end
	
	
	if (IsFlyableArea() ) then
		--If in Northrend and level is at least 77 but you don't have coldweather flying; flyable = false;
		if currentContinent == 4 and not coldweatherflying then
			MOprint("No cold weather flying found.")
			return false
		else
			return true
		end
	else
		MOprint("Not a flyable area.")
		return false
	end
end

--Retrieve and return the players riding skill
function Mountiful_GetRidingSkill()
	if(GetNumSkillLines) then  -- in beta there's no skills :(
		for skillIndex = 1, GetNumSkillLines() do
			skillName, _, _, skillRank, _, _, _, _, _, _, _, _, _ = GetSkillLineInfo(skillIndex)
			if skillName == L["Riding"] then
				return skillRank
			end
		end
		return 0 --they didn't learn riding
	end
	return 999
end

-- Goto next page of mounts/pets
function Mountiful_NextPage()
	MountifulPageNum = MountifulPageNum + 1
	Mountiful_Update()
	MOprint("NEXT page.  Now at:"..MountifulPageNum)
end

-- Goto previous page of mounts/pets
function Mountiful_PrevPage()
	MountifulPageNum = MountifulPageNum - 1
	Mountiful_Update()
end

function Mountiful_RebuildSelections() -- Rebuild the selections array because it gets messed up after learning new mounts
	Mountiful_CreateMountTables()  --this is the key one
	Mountiful_InitializeSelections()  --sets the new mount id 
	Mountiful_Update()
end

--Empty Vars and reload the UI
function Mountiful_ResetSettings()
	Mountiful_Vars = nil
	ReloadUI()
end

function Mountiful_CreateMountTables()  --the 'meat' of the code.
	MOprint("Entering |c00ffff00 CreateMountTables")
	local mountnum = GetNumCompanions("MOUNT")
	local petnum = GetNumCompanions("CRITTER")
	local real310 = false
	local text,link,mountname,spellID,icon,groundspeed,flightspeed
	--local ridingSkill = Mountiful_GetRidingSkill()  --Here, i believe, is the culprit on why things arn't loading when they should
	--and now that i think about it, why would we check this here?  They cant learn the mounts if they dont have the riding skill!

	-- Empty the mounts tables
	Mountiful_Mounts = {}

	-- Add the categories to the mounts table
	for key,value in pairs(Mountiful_Categories) do
		Mountiful_Mounts[value] = {}
	end
	
	Mountiful_Mounts.notseen = {}
	Mountiful_Mounts.All = {}
	
	if(not MountifulTooltip) then
		MountifulTooltip = CreateFrame("GameTooltip", "MountifulTooltip", nil, "GameTooltipTemplate") 
		--MountifulTooltip:AddFontStrings(MountifulTooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"),MountifulTooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText"))
	end
	
	MountifulTooltip:SetOwner(WorldFrame,"ANCHOR_NONE")  --fixes the deathcharger bug.  why?  who knows.  it works though.

	-- Loops through all mounts and sorts them into tables depending on speed and if they can fly
	for i=1, mountnum do
		_, mountname, spellID, icon, _ = GetCompanionInfo("MOUNT", i)
		mountname = MOfbgdbm(mountname)
		Mountiful_Mounts.All[#Mountiful_Mounts.All+1] = i
		link = GetSpellLink(spellID)
		MountifulTooltip:SetHyperlink(link) -- Set link for tooltip
		text = _G["MountifulTooltipTextLeft"..3]:GetText() -- Get the description text from the tooltip

		if(text) then
			--specialty mounts
			if(strfind (text, L["swimmer"])) then
				Mountiful_Mounts.Swimming[#Mountiful_Mounts.Swimming + 1] = i
			elseif(strfind (text, L["Qiraj"])) then
				Mountiful_Mounts.Qiraj[#Mountiful_Mounts.Qiraj+ 1] = i
			elseif(strfind (text, L["Vashj'ir"])) then
				Mountiful_Mounts.Vashjir[#Mountiful_Mounts.Vashjir+ 1] = i
				
				--[[
			elseif strfind (text, L["changes"]) and strfind (text, L["location"]) then -- Catches mounts that change depending on location and skill --headless horseman mount
				if (strfind(text, "Celestial Steed",1,true)) then
					if (Mountiful_Options.no310.value) then
						Mountiful_Mounts.FastFlying[#Mountiful_Mounts.FastFlying+1] = i
					else
						Mountiful_Mounts.FastFlying[#Mountiful_Mounts.FastFlying+1] = i
						Mountiful_Mounts.ExtremeFlying[#Mountiful_Mounts.ExtremeFlying+1] = i
					end
				end
				Mountiful_Mounts.SlowFlying[#Mountiful_Mounts.SlowFlying+1] = i
				Mountiful_Mounts.FastGround[#Mountiful_Mounts.FastGround+1] = i
				Mountiful_Mounts.SlowGround[#Mountiful_Mounts.SlowGround+1] = i
				
				
			elseif (strfind(text, L["changes"]) or (strfind(text, L["scales"]))) and not strfind(text, L["Outland"]) then -- Catches mounts that change depending on skill
				Mountiful_Mounts.FastGround[#Mountiful_Mounts.FastGround+1] = i
				Mountiful_Mounts.SlowGround[#Mountiful_Mounts.SlowGround+1] = i
			elseif strfind(text, L["Outland"]) then -- Catches flying mounts
				if (strfind(text, L["extremely"]) or strfind(text, "Violet Proto-Drake",1,true)) then -- Catches 310% mounts
					if (Mountiful_Options.no310.value) then
						Mountiful_Mounts.FastFlying[#Mountiful_Mounts.FastFlying+1] = i
					else
						real310 = true
						Mountiful_Mounts.ExtremeFlying[#Mountiful_Mounts.ExtremeFlying+1] = i
					end
				elseif(strfind(text, L["changes"])) or (strfind(text, L["scales"]))  then -- Catches flying mounts that change depending on skill
					Mountiful_Mounts.FastFlying[#Mountiful_Mounts.FastFlying+1] = i
					Mountiful_Mounts.SlowFlying[#Mountiful_Mounts.SlowFlying+1] = i
				elseif (strfind(text, L["very"]))then -- Catches epic flyers
					Mountiful_Mounts.FastFlying[#Mountiful_Mounts.FastFlying+1] = i
				else
					Mountiful_Mounts.SlowFlying[#Mountiful_Mounts.SlowFlying+1] = i
				end
				]]
			else  --regular mounts
			
				
				groundspeed,flightspeed = MOgetspeedfromseen(mountname)
			--	MOprint("Normal Mount reached. "..text.."   speeds:"..tostring(groundspeed).."  "..tostring(flightspeed))
				if(flightspeed) then
				--	MOprint(tostring(flightspeed))
					if(flightspeed <= 60) then
				--		MOprint("slow flying Mount reached. "..text.."   speeds:"..tostring(groundspeed).."  "..tostring(flightspeed))
						Mountiful_Mounts.SlowFlying[#Mountiful_Mounts.SlowFlying+1] = i
					elseif(flightspeed <= 100) then
				--		MOprint("Normal flying Mount reached. "..text.."   speeds:"..tostring(groundspeed).."  "..tostring(flightspeed))
						Mountiful_Mounts.FastFlying[#Mountiful_Mounts.FastFlying+1] = i
					elseif(flightspeed <= 310) then
				--		MOprint("extreme flying Mount reached. "..text.."   speeds:"..tostring(groundspeed).."  "..tostring(flightspeed))
						Mountiful_Mounts.ExtremeFlying[#Mountiful_Mounts.ExtremeFlying+1] = i
					end
				--	Mountiful_Mounts.FastFlying[#Mountiful_Mounts.FastFlying+1] = i
			
				elseif(groundspeed) then
					
					if strfind(text, L["very"])then
						Mountiful_Mounts.FastGround[#Mountiful_Mounts.FastGround+1] = i  -- isnt catching hogs/choppers?
					else
						Mountiful_Mounts.SlowGround[#Mountiful_Mounts.SlowGround+1] = i
					end
					--[[
					if (strfind(text, "X-53 Touring Rocket",1,true)) then
						if (Mountiful_Options.no310.value) then
							Mountiful_Mounts.FastFlying[#Mountiful_Mounts.FastFlying+1] = i
						else
							Mountiful_Mounts.FastFlying[#Mountiful_Mounts.FastFlying+1] = i
							Mountiful_Mounts.ExtremeFlying[#Mountiful_Mounts.ExtremeFlying+1] = i
						end
					end
					]]
				else
					Mountiful_Mounts.notseen[#Mountiful_Mounts.notseen + 1] = i
				end
			end
		end
	end
	
	if (#Mountiful_Mounts.notseen < 1) then
		Mountiful_Options.learningmode.value = false
	end
	--[[
	if (not real310 and not Mountiful_Options.no310.value) then
		Mountiful_Mounts.ExtremeFlying = {}
	end
	]]
	--now the pets and custom stuff
	Mountiful_Mounts.Pet = {}
	
	local exists
	for key,value in pairs(Mountiful_Mounts) do
		if Mountiful_Selections[key] and Mountiful_Selections[key].ispet then
			for i = 1, petnum do
			--	_, _, spellID, icon, _ = GetCompanionInfo("CRITTER", i)
				Mountiful_Mounts[key][i] = i
			end
		else  --not a pet
			if not in_array(key, Mountiful_Defaults.Categories) then
				for i=1, mountnum do
					Mountiful_Mounts[key][i] = i  --same as 'all'
				end
			end
		end
	end
	
	
	MountifulTooltip:Hide()
	
	
	
	
end

-- Get the number of the named mount
function Mountiful_NameToNum(name, companiontype)  

	if not companiontype then 
		companiontype = "MOUNT" 
	end
	local mountname, spellID, icon
	local mountnum = GetNumCompanions(companiontype)
	for i=1, mountnum do
		_, mountname, spellID, icon, _ = GetCompanionInfo(companiontype, i)
		mountname = MOfbgdbm(mountname)
		if(mountname == name) then
			return i
		end
	end
	return nil
end

function MOnumtoname(num, companiontype)  

	if not companiontype then 
		companiontype = "MOUNT" 
	end
	if(type(num) == "number") then
		_, mountname, _, _, _ = GetCompanionInfo(companiontype, num)
	end
	return mountname
end


function Mountiful_PreClick(self)
	if self then MOprint("PREclick occured for "..tostring(self:GetName())) end
	MOsecurebuttonclicked = true
	if (MOpastflyable == MOgetisflyable()) then  --else it will try to summon a ground mount in flying area and you run off a cliff and die
		MOusefuturemount = true
	else
		MOusefuturemount = false
	end
	MOpastflyable = MOgetisflyable()
	MOmacroclicked = true
	MOstartcastdetection()
	
	--Mountiful_Command("smart",false)  --if its druid, it just updates this button's attribute.  else it summons a mount.  cross fingers
	Mountiful_SmartMount(Mountiful_Options.preselecteddefault.value)
end
function Mountiful_Click(self)  --doesnt happen
	MOprint("|c00ffffaaMainclick. |r  self=")
	MOprint(self)
end
function Mountiful_PostClick(self)  --THIS HAppens too fast after the click 
	if self then MOprint("pOSTclick occured for "..tostring(self:GetName())) end
	MOsecurebuttonclicked = false
	
	--MOstartcastdetection()
	
	--Mountiful_UpdateMacro()  --cant do this here.  lag?
	
	
end

function MOstartcastdetection()
	MOprint("|c000000ff Starting Cast Detection.")
	for key,value in pairs(MOUNTIFUL_CASTDETECTION) do
		if value then MountifulFrame:RegisterEvent(key) end
	end
	
	MOtimer = time()
	
end
function MOstopcastdetection()
	--MountifulFrame:SetScript("OnUpdate",nil)
	for key,value in pairs(MOUNTIFUL_CASTDETECTION) do
		if value then MountifulFrame:UnregisterEvent(key) end
	end
	MOprint("|c006600ff Stopping Cast Detection.")
end


function MOgeneratemountname(pre)
	local panelname
	if not Mountiful_Options.preselecteddefault then
		Mountiful_Options.preselecteddefault = {["value"] = true}
	end;
	
	if not pre then
		MOprint("|c0033ffdd pre type ="..type(Mountiful_Options.preselecteddefault))
		if not (type(Mountiful_Options.preselecteddefault) == "table") then  --WHY is this erroring for some???? garrrhhhh... 
			MOprint("|c0033ccddentering not loop")
			local tempval = Mountiful_Options.preselecteddefault
			Mountiful_Options.preselecteddefault = nil
			Mountiful_Options.preselecteddefault = {["value"] = tempval}
			
		end
		pre = Mountiful_Options.preselecteddefault.value or false
	end
	panelname = Mountiful_GetSmartPanel()  --default to smart mounting
	if not panelname then 
		MOprint("no panelname. |c00ff0000 error in generate mount name")
		return
	end
	if (IsUsableSpell(panelname)) then  --druid crap
		return panelname  --returns a string, not a number.  important
	end
	local summontable = MOpaneltotable(panelname,pre)  -- preselected.  still not sure which i want
	local mountnum = MOgetrandmountnum(summontable)
	local _, mountname, spellID, icon, _ = GetCompanionInfo("MOUNT", mountnum)
	if not mountname then
		MOprint("Error in generatemountname.  Mountnum="..mountnum.."  Panelname="..panelname)
	end
	mountname = MOfbgdbm(mountname)
	MOprint("generating mount name "..tostring(mountname).." from panel "..tostring(panelname)..".   Preselected ="..tostring(pre))
	return mountname
end

function MOfbgdbm(mountname)  --       Fix Blizzards God Damn Broken Mounts
	
	MOprint(mountname)
	 if(strfind(string.lower(tostring(mountname)),"drake mount",-11,true)) then  --STUPID BLIZZARD.  some mounts' names are not the actual spell name
		MOprint("Broken Mount name found in fbgdbm: "..mountname)
		mountname = string.sub(mountname,1,-7)
	end
	 if(strfind(string.lower(tostring(mountname)),"drake mount",-11,true)) then  --STUPID BLIZZARD.  some mounts' names are not the actual spell name
	 
	 end
	
	return mountname
end

function MOcreateoptions()

		local optionnames = {"help","hide","settings","reset","add","remove","dismiss","smart","rebuildselections","debug","autopet"}
		
		local options = {}
		

	local Frame = CreateFrame("Frame", "MOoptions");
	Frame.name = "Mountiful";
	InterfaceOptions_AddCategory(Frame);
	Frame:SetScript("OnShow", MOupdateoptions)
	
	--Frame:SetScript("OnShow",WL.update)
	--Frame:SetScript("OnHide",WL.update)
	local Text = Frame:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
	Text:SetText("Mountiful - Your mount and companion manager.");
	Text:SetJustifyH("center");
	Text:SetJustifyV("TOP");
	Text:SetPoint("TOPLEFT", 20, -20);
	Text:SetPoint("BOTTOMRIGHT", -20, 0);
	
	local Text = Frame:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
	Text:SetText("Version "..tostring(VersionString));
	Text:SetJustifyH("right");
	Text:SetJustifyV("bottom");
	Text:SetPoint("TOPLEFT", 20, -20);
	Text:SetPoint("BOTTOMRIGHT", -20, 20);
		
	local previousbutton
	
	for key,setting in pairs(Mountiful_Options) do
	
		if type(setting) == "table" then  --just in case
			--optionx
			local button,editbox
			button = CreateFrame("Checkbutton", "MOoption"..key, Frame, "OptionsCheckbuttonTemplate");
			if (previousoption) then
				button:SetPoint("TOPLEFT",previousoption,"Bottomleft");
			else
				button:SetPoint("TOPLEFT",30,-50);
			end
			getglobal(button:GetName().."Text"):SetText(tostring(key));
			button.tooltipText = setting.tooltip
			button.key = key
			--button:SetChecked(setting.value)
			button:SetScript("OnClick",function(self)
				if(not self) then 
					MOprint(self)
					return
				end
				local key = self.key
				MOprint("Key = "..tostring(key))
				if key then
					Mountiful_Options[key].value = (self:GetChecked() == 1)
				else
					MOprint("|c00ff0000 error.  no key")
				end
			end);
			
			previousoption = button
		end
	end
	
			
	
end


function MOupdateoptions()

	for key,setting in pairs(Mountiful_Options) do
		if type(setting) == "table" then  --just in case
			--optionx
			local button
			button = getglobal("MOoption"..key)
			button:SetChecked(setting.value)
		end
	end

end

function isflyingmount()
--detect if a mount was cast.
--loop through all our buffs
--compare them to our mounts
--if it's a match then
--check if that match is in our 'known' table
--if it is, do nothing
--if it is not, get the tooltip of that buff
--parse it for 100% or 300
--put it in our known table, as fast or slow

return false
end
