-- AZS Lairs: one line per guardian lair. A held lair shows its guardian's health and its power
-- (max health against the first guardian seen in that lair this run); an empty one counts down to filling.

local ROWS, ROW_H, WIDTH = 12, 14, 300;

-- per run: lair index -> max health of the first guardian seen there, and guardians seen
local first, seen, seenId, runId = {}, {}, {}, nil;

local f = CreateFrame("Frame", "AZSLairsFrame", UIParent);
f:SetWidth(WIDTH);
f:SetHeight(24 + ROW_H);
f:SetMovable(true);
f:EnableMouse(true);
f:RegisterForDrag("LeftButton");
f:SetScript("OnDragStart", function() this:StartMoving(); end);
f:SetScript("OnDragStop", function()
	this:StopMovingOrSizing();
	AZSLairsDB.point = { this:GetLeft(), this:GetTop() };
end);
f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 } });
f:SetBackdropColor(0, 0, 0, 0.7);
f:Hide();

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7);
title:SetText("Lairs");

local rows = {};
for i = 1, ROWS do
	local r = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	r:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8 - i * ROW_H);
	r:SetWidth(WIDTH - 16);
	r:SetJustifyH("LEFT");
	rows[i] = r;
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffff7d0aAZS Lairs|r: " .. msg);
end

local function Place()
	f:ClearAllPoints();
	local p = AZSLairsDB.point;
	if ( p and p[1] ) then
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2]);
	else
		f:SetPoint("RIGHT", UIParent, "RIGHT", -20, 80);
	end
end

local function Short(n)
	if ( n >= 1000000 ) then
		return string.format("%.1fm", n / 1000000);
	elseif ( n >= 1000 ) then
		return string.format("%.1fk", n / 1000);
	end
	return string.format("%d", n);
end

local function Line(l, units)
	local head = string.format("%d. %s", l.index, l.name or "?");
	if ( l.state == "empty" ) then
		if ( l.left and l.left > 0 ) then
			return head .. string.format("  |cff888888fills in %d:%02d|r", math.floor(l.left / 60), math.mod(l.left, 60));
		end
		return head .. "  |cff888888empty|r";
	end
	local u = units[l.id];
	if ( not u or not u.hpm or u.hpm <= 0 ) then
		return head .. "  " .. l.state;
	end
	-- a new guardian in this lair: count it, and keep the first one's max health as the base
	if ( seenId[l.index] ~= l.id .. ":" .. u.hpm ) then
		seenId[l.index] = l.id .. ":" .. u.hpm;
		seen[l.index] = (seen[l.index] or 0) + 1;
		first[l.index] = first[l.index] or u.hpm;
	end
	local color = (l.state == "awake") and "|cffff5555" or "|cffffd100";
	local text = string.format("%s  %s%s|r  %d%% of %s", head, color, l.state, math.floor(100 * u.hp / u.hpm), Short(u.hpm));
	if ( first[l.index] and seen[l.index] > 1 ) then
		text = text .. string.format("  |cffff9933x%.2f|r", u.hpm / first[l.index]);
	end
	return text;
end

local elapsed = 0;
f:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1;
	if ( elapsed < 0.25 ) then return; end
	elapsed = 0;
	local lairs = AZS_GetLairs and AZS_GetLairs() or {};
	local units = {};
	if ( AZS_UNITS ) then
		for i = 1, table.getn(AZS_UNITS) do
			units[AZS_UNITS[i].id] = AZS_UNITS[i];
		end
	end
	local n = math.min(table.getn(lairs), ROWS);
	for i = 1, ROWS do
		if ( i <= n ) then
			rows[i]:SetText(Line(lairs[i], units));
			rows[i]:Show();
		else
			rows[i]:Hide();
		end
	end
	f:SetHeight(24 + math.max(n, 1) * ROW_H);
end);

-- shows the window during a run that has lairs, unless turned off
local watcher = CreateFrame("Frame");
local wElapsed = 0;
watcher:SetScript("OnUpdate", function()
	wElapsed = wElapsed + arg1;
	if ( wElapsed < 0.5 ) then return; end
	wElapsed = 0;
	if ( not AZSLairsDB ) then return; end
	local run = AZS_ZONE and AZS_ZONE.run;
	if ( run ~= runId ) then
		runId = run;
		first, seen, seenId = {}, {}, {};
	end
	local ph = AZS_GetPhase and AZS_GetPhase();
	local live = ph == "playing" or ph == "choosing" or ph == "paused";
	if ( not AZSLairsDB.off and live and AZS_LAIRS and table.getn(AZS_LAIRS) > 0 ) then
		f:Show();
	else
		f:Hide();
	end
end);

local loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:SetScript("OnEvent", function()
	if ( not AZSLairsDB ) then
		AZSLairsDB = { off = false };
	end
	Place();
end);

SLASH_AZSLAIRS1 = "/azlair";
SlashCmdList["AZSLAIRS"] = function(msg)
	msg = string.lower(msg or "");
	if ( msg == "off" or msg == "on" ) then
		AZSLairsDB.off = (msg == "off");
		Print("window " .. msg .. ".");
	elseif ( msg == "markers" ) then
		AZSLairsDB.noMarkers = not AZSLairsDB.noMarkers;
		Print("labels over lairs " .. (AZSLairsDB.noMarkers and "off" or "on") .. ".");
	elseif ( msg == "arrow" ) then
		AZSLairsDB.noArrow = not AZSLairsDB.noArrow;
		Print("arrow to the flagged lair " .. (AZSLairsDB.noArrow and "off" or "on") .. ".");
	elseif ( msg == "reset" ) then
		AZSLairsDB.point = nil;
		AZSLairsDB.arrowPoint = nil;
		Place();
		AZSLairs_PlaceArrow();
		Print("window and arrow moved back.");
	else
		Print("one line per lair: the guardian's state, health and max health; xN is its power against the first guardian of that lair this run.");
		Print("/azlair on | off - show or hide the window; /azlair markers - labels over lairs; /azlair arrow - arrow to the flagged lair; /azlair reset - move them back. Drag to move.");
	end
end;
