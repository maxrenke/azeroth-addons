-- AZS Lairs: a label over every lair in the world (its guardian, or the time until it fills)
-- and an arrow to the lair the minimap's red flag points at.

local ARROW, ARROW_SIZE = "Interface\\Minimap\\MinimapArrow", 44;

-- ---------------------------------------------------------------- labels over lairs
local labels, freeLabels = {}, {}; -- anchorId -> frame (with .lairIndex)
local nextScan = 0;

local function NewLabel()
	local m = table.remove(freeLabels);
	if ( not m ) then
		m = CreateFrame("Frame", nil, WorldFrame);
		m:SetFrameStrata("LOW");
		m:SetWidth(200);
		m:SetHeight(16);
		m.text = m:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		m.text:SetPoint("BOTTOM", m, "BOTTOM", 0, 0);
	end
	m:Hide();
	return m;
end

-- whole catalog in one frame; false if not now (NOT_READY, CATALOG_CHANGED)
local function Scan()
	local found, cursor, page = {}, nil, nil;
	repeat
		page = AZS_GetWorldAnchors({ kinds = { "guardianLair" } }, cursor);
		if ( not page ) then
			return false;
		end
		for i = 1, table.getn(page.entries) do
			local e = page.entries[i];
			found[e.anchorId] = true;
			if ( not labels[e.anchorId] ) then
				labels[e.anchorId] = NewLabel();
			end
			labels[e.anchorId].lairIndex = e.lairIndex;
		end
		cursor = page.nextCursor;
	until not page.hasMore;
	for id, m in pairs(labels) do
		if ( not found[id] ) then
			m:Hide();
			table.insert(freeLabels, m);
			labels[id] = nil;
		end
	end
	return true;
end

local function LabelText(l)
	local flag = (l.flag == 1) and "|cffff3333>|r " or "";
	if ( l.state == "empty" ) then
		if ( l.left and l.left > 0 ) then
			return flag .. string.format("|cffaaaaaaLair %d fills in %d:%02d|r", l.index, math.floor(l.left / 60), math.mod(l.left, 60));
		end
		return flag .. string.format("|cffaaaaaaLair %d|r", l.index);
	elseif ( l.state == "awake" ) then
		return flag .. "|cffff5555" .. (l.name or "Guardian") .. " (awake)|r";
	end
	return flag .. "|cffffd100" .. (l.name or "Guardian") .. " (asleep)|r";
end

local function PlaceLabels()
	if ( not AZSLairsDB or AZSLairsDB.noMarkers ) then
		for _, m in pairs(labels) do
			m:Hide();
		end
		return;
	end
	local now = GetTime();
	if ( now >= nextScan and Scan() ) then
		nextScan = now + 1;
	end
	local byIndex = {};
	local lairs = AZS_GetLairs and AZS_GetLairs() or {};
	for i = 1, table.getn(lairs) do
		byIndex[lairs[i].index] = lairs[i];
	end
	local requests, list = {}, {};
	for id, m in pairs(labels) do
		table.insert(requests, { anchorId = id, attachment = "position", offset = { z = 3 } });
		table.insert(list, m);
	end
	if ( table.getn(requests) == 0 ) then
		return;
	end
	local projection = AZS_ProjectWorldAnchors(requests);
	if ( not projection ) then
		return;
	end
	for i = 1, table.getn(projection.entries) do
		local e, m = projection.entries[i], list[i];
		local l = byIndex[m.lairIndex];
		if ( l and projection.frameCurrent and e.state == "onScreen" ) then
			local scale = 1;
			if ( e.playerDistance and e.playerDistance > 25 ) then
				scale = math.max(0.6, 25 / e.playerDistance);
			end
			m.text:SetText(LabelText(l));
			m:SetScale(scale);
			m:ClearAllPoints();
			m:SetPoint("BOTTOM", WorldFrame, "BOTTOMLEFT", e.x / scale, e.y / scale);
			m:Show();
		else
			m:Hide();
		end
	end
end

-- ---------------------------------------------------------------- arrow to the flagged lair
local f = CreateFrame("Frame", "AZSLairArrowFrame", UIParent);
f:SetWidth(ARROW_SIZE);
f:SetHeight(ARROW_SIZE);
f:SetMovable(true);
f:EnableMouse(true);
f:RegisterForDrag("LeftButton");
f:SetScript("OnDragStart", function(self) self:StartMoving(); end);
f:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing();
	AZSLairsDB.arrowPoint = { self:GetCenter() };
end);
f:Hide();

local arrow = f:CreateTexture(nil, "ARTWORK");
arrow:SetAllPoints(f);
arrow:SetTexture(ARROW);
arrow:SetVertexColor(1, 0.3, 0.3);

local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
label:SetPoint("TOP", f, "BOTTOM", 0, -2);

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

function AZSLairs_PlaceArrow()
	f:ClearAllPoints();
	local p = AZSLairsDB.arrowPoint;
	if ( p and p[1] ) then
		f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p[1], p[2]);
	else
		f:SetPoint("TOP", UIParent, "TOP", -90, -140);
	end
end

f:SetScript("OnUpdate", function(self, e)
	local p = AZS_GetPlayerPosition();
	local l = AZS_GetFlaggedLair();
	if ( not p or not l or l.spaceId ~= p.spaceId ) then
		arrow:Hide();
		label:SetText("");
		return;
	end
	local dx, dy = l.x - p.x, l.y - p.y;
	-- angles run counterclockwise from north toward west, as the hero's facing does
	Rotate(arrow, math.atan2(dy, dx) - p.facing);
	arrow:Show();
	local what = (l.state == "empty") and string.format("Lair %d", l.index) or (l.name or "Lair");
	label:SetText(string.format("%s  %d yd", what, math.sqrt(dx * dx + dy * dy)));
end);

-- shows the arrow during a run, unless turned off
local watcher = CreateFrame("Frame");
local elapsed = 0;
watcher:SetScript("OnUpdate", function(self, e)
	elapsed = elapsed + (e or arg1);
	if ( elapsed < 0.5 ) then return; end
	elapsed = 0;
	if ( not AZSLairsDB or not AZS_GetPlayerPosition or not AZS_GetFlaggedLair ) then return; end
	if ( not AZSLairsDB.noArrow and AZS_GetPhase() == "playing" ) then
		f:Show();
	else
		f:Hide();
	end
end);

local loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:SetScript("OnEvent", function()
	if ( AZSLairsDB ) then
		AZSLairs_PlaceArrow();
	end
	if ( AZS_GetWorldAnchorCapabilities ) then
		AZS_RegisterWorldAnchorFrameHandler(PlaceLabels);
	end
end);
