-- AZS Cache Arrow: points at the nearest cache from AZS_CHESTS, turning with the hero's facing.

local ARROW = "Interface\\Minimap\\MinimapArrow";
local SIZE = 56;

local f = CreateFrame("Frame", "AZSCacheArrowFrame", UIParent);
f:SetWidth(SIZE);
f:SetHeight(SIZE);
f:SetMovable(true);
f:EnableMouse(true);
f:RegisterForDrag("LeftButton");
f:SetScript("OnDragStart", function(self) self:StartMoving(); end);
f:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing();
	AZSCacheArrowDB.point = { self:GetCenter() };
end);
f:Hide();

local arrow = f:CreateTexture(nil, "ARTWORK");
arrow:SetAllPoints(f);
arrow:SetTexture(ARROW);

local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
label:SetPoint("TOP", f, "BOTTOM", 0, -2);

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffff7d0aAZS Cache Arrow|r: " .. msg);
end

-- Turns the texture counterclockwise by a radians on screen.
local function Rotate(tex, a)
	local c, s = math.cos(a), math.sin(a);
	local function T(x, y)
		return 0.5 + x * c + y * s, 0.5 - (-x * s + y * c);
	end
	local ulx, uly = T(-0.5, 0.5);
	local llx, lly = T(-0.5, -0.5);
	local urx, ury = T(0.5, 0.5);
	local lrx, lry = T(0.5, -0.5);
	tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry);
end

local function Place()
	f:ClearAllPoints();
	local p = AZSCacheArrowDB.point;
	if ( p and p[1] ) then
		f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p[1], p[2]);
	else
		f:SetPoint("TOP", UIParent, "TOP", 0, -140);
	end
end

-- The nearest cache in the hero's coordinate space: dx north, dy west, distance.
local function Nearest(p)
	local best, bx, by, bd;
	if ( not AZS_CHESTS ) then
		return nil;
	end
	for i = 1, table.getn(AZS_CHESTS) do
		local c = AZS_CHESTS[i];
		if ( c.spaceId == p.spaceId ) then
			local dx, dy = c.x - p.x, c.y - p.y;
			local d = math.sqrt(dx * dx + dy * dy);
			if ( not bd or d < bd ) then
				best, bx, by, bd = c, dx, dy, d;
			end
		end
	end
	return best, bx, by, bd;
end

local updater = CreateFrame("Frame");
updater:SetScript("OnUpdate", function(self, e)
	if ( not AZSCacheArrowDB or AZSCacheArrowDB.off or AZS_GetPhase() ~= "playing" ) then
		f:Hide();
		return;
	end
	local p = AZS_GetPlayerPosition();
	if ( not p ) then
		f:Hide();
		return;
	end
	local cache, dx, dy, d = Nearest(p);
	if ( not cache ) then
		f:Hide();
		return;
	end
	-- angles run counterclockwise from north toward west, as the hero's facing does
	Rotate(arrow, math.atan2(dy, dx) - p.facing);
	-- green and pulsing when the gold for it is there, grey when not
	local run = AZS_RUN or {};
	local affordable = run.chest and run.gold and run.gold >= run.chest;
	if ( affordable ) then
		arrow:SetVertexColor(0.3, 1, 0.3);
		arrow:SetAlpha(0.65 + 0.35 * math.abs(math.sin(GetTime() * 3)));
	else
		arrow:SetVertexColor(0.7, 0.7, 0.7);
		arrow:SetAlpha(1);
	end
	local text = string.format("Cache  %d yd", d);
	if ( run.chest and run.chest > 0 ) then
		text = text .. string.format("  (%d/%dg)", run.gold or 0, run.chest);
	end
	if ( affordable ) then
		text = "|cff4dff4dCAN OPEN|r  " .. text;
	end
	label:SetText(text);
	f:Show();
end);

-- A coin over every cache while you have the gold to open one.
local COIN, COIN_SIZE = "Interface\\Icons\\INV_Misc_Coin_01", 30;
local markers, freeMarkers = {}, {}; -- anchorId -> frame
local nextScan = 0;

local function Affordable()
	local run = AZS_RUN;
	return run and run.chest and run.gold and run.chest > 0 and run.gold >= run.chest;
end

local function DropMarker(id)
	markers[id]:Hide();
	table.insert(freeMarkers, markers[id]);
	markers[id] = nil;
end

-- whole catalog in one frame; false if not now (NOT_READY, CATALOG_CHANGED)
local function ScanCaches()
	local found, cursor, page = {}, nil, nil;
	repeat
		page = AZS_GetWorldAnchors({ kinds = { "cache" } }, cursor);
		if ( not page ) then
			return false;
		end
		for i = 1, table.getn(page.entries) do
			local id = page.entries[i].anchorId;
			found[id] = true;
			if ( not markers[id] ) then
				local m = table.remove(freeMarkers);
				if ( not m ) then
					m = CreateFrame("Frame", nil, WorldFrame);
					m:SetFrameStrata("LOW");
					m.tex = m:CreateTexture(nil, "ARTWORK");
					m.tex:SetAllPoints(m);
					m.tex:SetTexture(COIN);
				end
				m:Hide();
				markers[id] = m;
			end
		end
		cursor = page.nextCursor;
	until not page.hasMore;
	for id in pairs(markers) do
		if ( not found[id] ) then
			DropMarker(id);
		end
	end
	return true;
end

local function PlaceMarkers()
	if ( AZSCacheArrowDB.off or AZSCacheArrowDB.noCoins or not Affordable() ) then
		for _, m in pairs(markers) do
			m:Hide();
		end
		return;
	end
	local now = GetTime();
	if ( now >= nextScan and ScanCaches() ) then
		nextScan = now + 0.5;
	end
	local requests, list = {}, {};
	for id, m in pairs(markers) do
		table.insert(requests, { anchorId = id, attachment = "position", offset = { z = 2 } });
		table.insert(list, m);
	end
	if ( table.getn(requests) == 0 ) then
		return;
	end
	local projection = AZS_ProjectWorldAnchors(requests);
	if ( not projection ) then
		return;
	end
	local pulse = 0.7 + 0.3 * math.abs(math.sin(now * 3));
	for i = 1, table.getn(projection.entries) do
		local e, m = projection.entries[i], list[i];
		if ( projection.frameCurrent and e.state == "onScreen" ) then
			local size = COIN_SIZE;
			if ( e.playerDistance and e.playerDistance > 20 ) then
				size = COIN_SIZE * math.max(0.55, 20 / e.playerDistance);
			end
			m:SetWidth(size);
			m:SetHeight(size);
			m:SetAlpha(pulse);
			m:ClearAllPoints();
			m:SetPoint("BOTTOM", WorldFrame, "BOTTOMLEFT", e.x, e.y);
			m:Show();
		else
			m:Hide();
		end
	end
end

local loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:SetScript("OnEvent", function()
	if ( not AZSCacheArrowDB ) then
		AZSCacheArrowDB = { off = false };
	end
	Place();
	if ( not AZS_GetPlayerPosition ) then
		Print("this game version has no AZS_GetPlayerPosition; the arrow is off.");
		updater:SetScript("OnUpdate", nil);
	end
	if ( AZS_GetWorldAnchorCapabilities ) then
		AZS_RegisterWorldAnchorFrameHandler(PlaceMarkers);
	end
end);

SLASH_AZSCACHEARROW1 = "/azca";
SlashCmdList["AZSCACHEARROW"] = function(msg)
	msg = string.lower(msg or "");
	if ( msg == "off" or msg == "on" ) then
		AZSCacheArrowDB.off = (msg == "off");
		Print("arrow " .. msg .. ".");
	elseif ( msg == "coins" ) then
		AZSCacheArrowDB.noCoins = not AZSCacheArrowDB.noCoins;
		Print("coins over openable caches " .. (AZSCacheArrowDB.noCoins and "off" or "on") .. ".");
	elseif ( msg == "reset" ) then
		AZSCacheArrowDB.point = nil;
		Place();
		Print("arrow moved back to the top of the screen.");
	else
		Print("points at the nearest cache; green when you have the gold. Drag it to move.");
		Print("/azca on | off - show or hide; /azca coins - toggle the coin over caches you can open; /azca reset - put it back at the top.");
	end
end;
