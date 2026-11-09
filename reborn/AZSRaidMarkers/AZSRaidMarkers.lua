-- AZS Raid Markers: draws raid target icons, with a small nameplate, over special enemies through the world anchors API.

-- raid target icon per kind: 1 star, 2 circle, 3 diamond, 4 triangle, 5 moon, 6 square, 7 cross, 8 skull
local MARK = { finalBoss = 8, boss = 7, guardian = 3, elite = 4 };
-- health bar colour per kind
local COLOR = {
	finalBoss = { 0.8, 0, 0 },
	boss = { 1, 0.25, 0.25 },
	guardian = { 1, 0.8, 0 },
	elite = { 0.3, 0.6, 1 },
};
local TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons";
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar";
local ICON, BAR_W, BAR_H = 28, 100, 8;

local anchors = {}; -- anchorId -> { holder, kind, unitId, name }
local pool = {};
local nextRefresh = 0;

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffff7d0aAZS Raid Markers|r: " .. msg);
end

local function SetKind(f, kind)
	local i = MARK[kind] - 1;
	local c, r = math.mod(i, 4) * 0.25, math.floor(i / 4) * 0.25;
	f.icon:SetTexCoord(c, c + 0.25, r, r + 0.25);
	local col = COLOR[kind];
	f.bar:SetStatusBarColor(col[1], col[2], col[3]);
end

-- holder: the plate (health bar, name above it) at the bottom and the icon on top
local function NewHolder()
	local f = table.remove(pool);
	if ( not f ) then
		f = CreateFrame("Frame", nil, WorldFrame);
		f:SetFrameStrata("LOW");
		f:SetWidth(BAR_W + 4);
		f:SetHeight(BAR_H + 14 + ICON + 6);

		f.bar = CreateFrame("StatusBar", nil, f);
		f.bar:SetWidth(BAR_W);
		f.bar:SetHeight(BAR_H);
		f.bar:SetPoint("BOTTOM", f, "BOTTOM", 0, 2);
		f.bar:SetStatusBarTexture(BAR_TEXTURE);
		f.bar:SetMinMaxValues(0, 1);
		local bg = f.bar:CreateTexture(nil, "BACKGROUND");
		bg:SetTexture(0, 0, 0, 0.7);
		bg:SetPoint("TOPLEFT", f.bar, "TOPLEFT", -1, 1);
		bg:SetPoint("BOTTOMRIGHT", f.bar, "BOTTOMRIGHT", 1, -1);

		f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		f.name:SetPoint("BOTTOM", f.bar, "TOP", 0, 2);
		f.name:SetWidth(BAR_W + 40);

		f.icon = f:CreateTexture(nil, "ARTWORK");
		f.icon:SetWidth(ICON);
		f.icon:SetHeight(ICON);
		f.icon:SetPoint("BOTTOM", f.name, "TOP", 0, 2);
		f.icon:SetTexture(TEXTURE);
	end
	f:Hide();
	return f;
end

local function Free(id)
	local a = anchors[id];
	a.holder:Hide();
	a.holder:ClearAllPoints();
	table.insert(pool, a.holder);
	anchors[id] = nil;
end

local function FreeAll()
	for id in pairs(anchors) do
		Free(id);
	end
end

-- Reads the whole catalog in one go; false if it couldn't (NOT_READY, CATALOG_CHANGED): try next frame.
local function Refresh()
	local kinds = { "finalBoss", "boss", "guardian" };
	if ( AZSRaidMarkersDB.elites ) then
		table.insert(kinds, "elite");
	end
	local seen, cursor, page = {}, nil, nil;
	repeat
		page = AZS_GetWorldAnchors({ kinds = kinds, states = { "alive" } }, cursor);
		if ( not page ) then
			return false;
		end
		for i = 1, table.getn(page.entries) do
			local e = page.entries[i];
			if ( MARK[e.kind] ) then
				seen[e.anchorId] = true;
				local a = anchors[e.anchorId];
				if ( not a ) then
					a = { holder = NewHolder() };
					anchors[e.anchorId] = a;
				end
				if ( a.kind ~= e.kind ) then
					a.kind = e.kind;
					SetKind(a.holder, e.kind);
				end
				a.unitId = e.unitId;
				a.name = e.name;
			end
		end
		cursor = page.nextCursor;
	until not page.hasMore;
	-- dead, gone or no longer a marked kind
	for id in pairs(anchors) do
		if ( not seen[id] ) then
			Free(id);
		end
	end
	return true;
end

local function OnFrame()
	if ( not AZSRaidMarkersDB or AZSRaidMarkersDB.off ) then
		return;
	end
	local now = GetTime();
	if ( now >= nextRefresh and Refresh() ) then
		nextRefresh = now + 0.25;
	end

	local requests, list = {}, {};
	for id, a in pairs(anchors) do
		table.insert(requests, { anchorId = id, attachment = "overhead" });
		table.insert(list, a);
	end
	if ( table.getn(requests) == 0 ) then
		return;
	end
	local projection = AZS_ProjectWorldAnchors(requests);
	if ( not projection ) then
		return;
	end

	-- health by spawn id (AZS_UNITS holds at most 40)
	local units = {};
	if ( AZS_UNITS ) then
		for i = 1, table.getn(AZS_UNITS) do
			units[AZS_UNITS[i].id] = AZS_UNITS[i];
		end
	end
	local plates = AZSRaidMarkersDB.plates;

	for i = 1, table.getn(projection.entries) do
		local entry, a = projection.entries[i], list[i];
		local f = a.holder;
		if ( projection.frameCurrent and entry.state == "onScreen" ) then
			local scale = 1;
			local d = entry.playerDistance;
			if ( d and d > 20 ) then
				scale = math.max(0.55, 20 / d);
			end
			local u = a.unitId and units[a.unitId];
			if ( plates ) then
				f.name:SetText(a.name or (u and u.name) or "");
				if ( u and u.hpm and u.hpm > 0 ) then
					f.bar:SetValue(u.hp / u.hpm);
				end
				f.bar:Show();
				f.name:Show();
			else
				f.bar:Hide();
				f.name:Hide();
			end
			-- offsets are in the frame's own scale, so divide them by it
			f:SetScale(scale);
			f:ClearAllPoints();
			f:SetPoint("BOTTOM", WorldFrame, "BOTTOMLEFT", entry.x / scale, (entry.y + 4) / scale);
			f:Show();
		else
			f:Hide();
		end
	end
end

local loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:SetScript("OnEvent", function()
	if ( not AZSRaidMarkersDB ) then
		AZSRaidMarkersDB = { elites = false, off = false };
	end
	if ( AZSRaidMarkersDB.plates == nil ) then
		AZSRaidMarkersDB.plates = true;
	end
	if ( not AZS_GetWorldAnchorCapabilities ) then
		Print("this game version has no world anchors API; markers are off.");
		return;
	end
	AZS_RegisterWorldAnchorFrameHandler(OnFrame);
end);

SLASH_AZSRAIDMARKERS1 = "/azrm";
SlashCmdList["AZSRAIDMARKERS"] = function(msg)
	msg = string.lower(msg or "");
	if ( msg == "elites" ) then
		AZSRaidMarkersDB.elites = not AZSRaidMarkersDB.elites;
		nextRefresh = 0;
		Print("elites (triangle) " .. (AZSRaidMarkersDB.elites and "on" or "off") .. ".");
	elseif ( msg == "plates" ) then
		AZSRaidMarkersDB.plates = not AZSRaidMarkersDB.plates;
		Print("nameplates under the markers " .. (AZSRaidMarkersDB.plates and "on" or "off") .. ".");
	elseif ( msg == "off" or msg == "on" ) then
		AZSRaidMarkersDB.off = (msg == "off");
		if ( AZSRaidMarkersDB.off ) then
			FreeAll();
		end
		nextRefresh = 0;
		Print("markers " .. msg .. ".");
	else
		Print("skull = final boss, cross = boss, diamond = guardian" .. (AZSRaidMarkersDB.elites and ", triangle = elite" or "") .. ".");
		Print("/azrm on | off - show or hide all markers; /azrm elites - toggle triangles on ordinary elites; /azrm plates - toggle the name and health bar.");
	end
end;
