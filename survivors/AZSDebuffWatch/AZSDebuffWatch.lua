-- AZS Debuff Watch: the debuffs on the boss or guardian you fight, from AZS_GetDebuffs.
-- With a watch list (/azdw add <name>) only those show, greyed with "MISSING" when absent,
-- flashing under EXPIRE seconds, and a warning sound when one drops off. With none, every debuff shows.

local ICONS, ICON, GAP, EXPIRE = 8, 36, 4, 3;
local UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark";

local knownIcons = {}; -- debuff name (lower case) -> icon, remembered from when it was seen
local wasUp = {};      -- watched name -> true while it was on the focus
local focusId;

local f = CreateFrame("Frame", "AZSDebuffWatchFrame", UIParent);
f:SetWidth(ICONS * (ICON + GAP));
f:SetHeight(ICON + 30);
f:SetMovable(true);
f:EnableMouse(true);
f:RegisterForDrag("LeftButton");
f:SetScript("OnDragStart", function() this:StartMoving(); end);
f:SetScript("OnDragStop", function()
	this:StopMovingOrSizing();
	AZSDebuffWatchDB.point = { this:GetLeft(), this:GetTop() };
end);
f:Hide();

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);

local slots = {};
for i = 1, ICONS do
	local s = CreateFrame("Frame", nil, f);
	s:SetWidth(ICON);
	s:SetHeight(ICON);
	s:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * (ICON + GAP), -14);
	s.tex = s:CreateTexture(nil, "ARTWORK");
	s.tex:SetAllPoints(s);
	s.time = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	s.time:SetPoint("CENTER", s, "CENTER", 0, 0);
	s.stacks = s:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall");
	s.stacks:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 1);
	s.note = s:CreateFontString(nil, "OVERLAY", "GameFontRedSmall");
	s.note:SetPoint("TOP", s, "BOTTOM", 0, -1);
	slots[i] = s;
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffff7d0aAZS Debuff Watch|r: " .. msg);
end

local function Place()
	f:ClearAllPoints();
	local p = AZSDebuffWatchDB.point;
	if ( p and p[1] ) then
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2]);
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, -170);
	end
end

-- The enemy to watch: your target when it is a boss or an awake guardian, else the first boss up,
-- else the first awake guardian.
local function Focus()
	local t = AZS_TARGET;
	if ( t and t.id and (t.kind == "final" or t.kind == "boss" or (t.kind == "guardian" and t.state == 1)) ) then
		return t.id, t.name;
	end
	local bosses = AZS_GetBosses();
	if ( bosses[1] ) then
		return bosses[1].id, bosses[1].name;
	end
	local guardians = AZS_GetGuardians();
	for i = 1, table.getn(guardians) do
		if ( guardians[i].awake ) then
			return guardians[i].id, guardians[i].name;
		end
	end
	return nil;
end

local function ShowSlot(s, icon, remaining, stacks, missing, now)
	s.tex:SetTexture(icon or UNKNOWN);
	s.tex:SetVertexColor(1, 1, 1);
	s:SetAlpha(1);
	s.time:SetText("");
	s.stacks:SetText("");
	s.note:SetText("");
	if ( missing ) then
		s.tex:SetVertexColor(1, 0.25, 0.25);
		s:SetAlpha(0.6 + 0.4 * math.abs(math.sin(now * 4)));
		s.note:SetText("MISSING");
	else
		if ( remaining ) then
			s.time:SetText(string.format("%d", math.ceil(remaining)));
			if ( remaining < EXPIRE ) then
				s:SetAlpha(0.5 + 0.5 * math.abs(math.sin(now * 8)));
			end
		end
		if ( stacks and stacks > 1 ) then
			s.stacks:SetText(stacks);
		end
	end
	s:Show();
end

local elapsed = 0;
f:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1;
	if ( elapsed < 0.1 ) then return; end
	elapsed = 0;
	local id, name = Focus();
	if ( id ~= focusId ) then
		focusId = id;
		wasUp = {};
	end
	if ( not id ) then
		for i = 1, ICONS do slots[i]:Hide(); end
		title:SetText("");
		return;
	end
	title:SetText(name or "");

	local now = GetTime();
	local debuffs = AZS_GetDebuffs(id) or {};
	local byName = {};
	for i = 1, table.getn(debuffs) do
		local d = debuffs[i];
		local key = string.lower(d.name or "");
		byName[key] = d;
		if ( d.icon ) then
			knownIcons[key] = d.icon;
		end
	end

	local n = 0;
	local watch = AZSDebuffWatchDB.watch;
	if ( table.getn(watch) > 0 ) then
		for i = 1, table.getn(watch) do
			if ( n >= ICONS ) then break; end
			local key = watch[i];
			local d = byName[key];
			n = n + 1;
			if ( d ) then
				wasUp[key] = true;
				ShowSlot(slots[n], d.icon, d.remaining, d.stacks, false, now);
			else
				-- it fell off: warn once
				if ( wasUp[key] and AZSDebuffWatchDB.sound ) then
					PlaySound("RaidWarning");
					UIErrorsFrame:AddMessage(watch[i] .. " fell off " .. (name or "the target"), 1, 0.3, 0.3);
				end
				wasUp[key] = nil;
				ShowSlot(slots[n], knownIcons[key], nil, nil, true, now);
			end
		end
	else
		for i = 1, table.getn(debuffs) do
			if ( n >= ICONS ) then break; end
			local d = debuffs[i];
			n = n + 1;
			ShowSlot(slots[n], d.icon, d.remaining, d.stacks, false, now);
		end
	end
	for i = n + 1, ICONS do
		slots[i]:Hide();
	end
end);

-- shows the frame during a run, unless turned off
local watcher = CreateFrame("Frame");
local wElapsed = 0;
watcher:SetScript("OnUpdate", function()
	wElapsed = wElapsed + arg1;
	if ( wElapsed < 0.5 ) then return; end
	wElapsed = 0;
	if ( not AZSDebuffWatchDB or not AZS_GetDebuffs ) then return; end
	local ph = AZS_GetPhase();
	if ( not AZSDebuffWatchDB.off and (ph == "playing" or ph == "choosing" or ph == "paused") ) then
		f:Show();
	else
		f:Hide();
	end
end);

local loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:SetScript("OnEvent", function()
	if ( not AZSDebuffWatchDB ) then
		AZSDebuffWatchDB = { off = false, sound = true, watch = {} };
	end
	if ( not AZSDebuffWatchDB.watch ) then
		AZSDebuffWatchDB.watch = {};
	end
	Place();
end);

SLASH_AZSDEBUFFWATCH1 = "/azdw";
SlashCmdList["AZSDEBUFFWATCH"] = function(msg)
	msg = msg or "";
	local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$");
	cmd = string.lower(cmd or "");
	local name = string.lower(rest or "");
	local watch = AZSDebuffWatchDB.watch;
	if ( cmd == "add" and name ~= "" ) then
		for i = 1, table.getn(watch) do
			if ( watch[i] == name ) then
				Print(rest .. " is already watched.");
				return;
			end
		end
		table.insert(watch, name);
		Print("watching " .. rest .. ".");
	elseif ( cmd == "remove" and name ~= "" ) then
		for i = 1, table.getn(watch) do
			if ( watch[i] == name ) then
				table.remove(watch, i);
				Print("stopped watching " .. rest .. ".");
				return;
			end
		end
		Print(rest .. " is not on the list.");
	elseif ( cmd == "list" ) then
		if ( table.getn(watch) == 0 ) then
			Print("no watch list: every debuff on the boss shows.");
		else
			Print("watching: " .. table.concat(watch, ", ") .. ".");
		end
	elseif ( cmd == "clear" ) then
		AZSDebuffWatchDB.watch = {};
		Print("watch list cleared: every debuff on the boss shows.");
	elseif ( cmd == "sound" ) then
		AZSDebuffWatchDB.sound = not AZSDebuffWatchDB.sound;
		Print("warning sound " .. (AZSDebuffWatchDB.sound and "on" or "off") .. ".");
	elseif ( cmd == "off" or cmd == "on" ) then
		AZSDebuffWatchDB.off = (cmd == "off");
		Print("frame " .. cmd .. ".");
	elseif ( cmd == "reset" ) then
		AZSDebuffWatchDB.point = nil;
		Place();
		Print("frame moved back.");
	else
		Print("/azdw add <debuff> | remove <debuff> | list | clear - the watch list (names as the game shows them, e.g. /azdw add Hunter's Mark).");
		Print("/azdw sound - toggle the warning; /azdw on | off - show or hide; /azdw reset - move it back. Drag to move.");
	end
end;
