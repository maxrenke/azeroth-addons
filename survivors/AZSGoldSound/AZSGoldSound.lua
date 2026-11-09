-- AZS Gold Sound: plays a sound of your own (gold.wav in this folder) when AZS_RUN.gold goes up.

local SOUND = "Interface\\AddOns\\AZSGoldSound\\gold.wav";
local MIN_GAP = 0.12; -- seconds between two plays, so a burst of pickups doesn't stack up

local lastGold, lastPlay = nil, 0;

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffff7d0aAZS Gold Sound|r: " .. msg);
end

local f = CreateFrame("Frame");
f:RegisterEvent("CHAT_MSG_ADDON");
f:SetScript("OnEvent", function()
	if ( arg1 ~= "AZSRUN" or not AZSGoldSoundDB or AZSGoldSoundDB.off or not AZS_RUN ) then
		return;
	end
	local gold = AZS_RUN.gold;
	if ( not gold ) then
		return;
	end
	-- a new run starts lower: only rises count
	if ( lastGold and gold > lastGold and AZS_GetPhase() == "playing" ) then
		local now = GetTime();
		if ( now - lastPlay >= MIN_GAP ) then
			lastPlay = now;
			PlaySoundFile(SOUND);
		end
	end
	lastGold = gold;
end);

local loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:SetScript("OnEvent", function()
	if ( not AZSGoldSoundDB ) then
		AZSGoldSoundDB = { off = false };
	end
end);

SLASH_AZSGOLDSOUND1 = "/azgold";
SlashCmdList["AZSGOLDSOUND"] = function(msg)
	msg = string.lower(msg or "");
	if ( msg == "off" or msg == "on" ) then
		AZSGoldSoundDB.off = (msg == "off");
		Print("sound " .. msg .. ".");
	elseif ( msg == "test" ) then
		PlaySoundFile(SOUND);
	else
		Print("plays gold.wav from Interface\\AddOns\\AZSGoldSound when your gold goes up.");
		Print("/azgold on | off; /azgold test - play it now.");
	end
end;
