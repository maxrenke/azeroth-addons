-- HoA Arrows: an arrow to the nearest of each kind of objective Hordes of Azeroth pins on its minimap,
-- from the same BONK~objective lines (id, kind, north, west, map, label, seconds, icon, description).
-- Kinds: chest (gold; green and pulsing when it opens for free), shrine, event, boss, miniboss, vendor.
-- The arrows sit in a row, each with its name and yards. Same angle as Hordes' own tutorial arrow:
-- atan2(west, north) less the camera's (or hero's) facing.

local ARROW = "Interface\\AddOns\\HordesOfAzeroth\\Textures\\TutorialArrow";
local SIZE, GAP = 44, 20;
local KINDS = { "chest", "shrine", "event", "miniboss", "boss", "vendor" };
local COLORS = {
	chest = { 1, 0.82, 0.2 },
	shrine = { 0.3, 0.85, 1 },
	event = { 1, 0.5, 0.1 },
	miniboss = { 0.75, 0.4, 1 },
	boss = { 1, 0.2, 0.2 },
	vendor = { 0.9, 0.9, 0.9 },
};
local DEFAULT_ON = { chest = true, shrine = true, event = true, miniboss = true, boss = true, vendor = false };

local objectives = {}; -- id -> { kind, x = north, y = west, mapId, label, free }

local f = CreateFrame("Frame", "HoAChestArrowFrame", UIParent);
f:SetWidth(SIZE);
f:SetHeight(SIZE + 14);
f:SetMovable(true);
f:EnableMouse(true);
f:RegisterForDrag("LeftButton");
f:SetScript("OnDragStart", function() this:StartMoving(); end);
f:SetScript("OnDragStop", function()
	this:StopMovingOrSizing();
	HoAChestArrowDB.point = { this:GetCenter() };
end);
f:Hide();

local arrows = {};
for i = 1, table.getn(KINDS) do
	local a = CreateFrame("Frame", nil, f);
	a:SetWidth(SIZE);
	a:SetHeight(SIZE + 14);
	a.tex = a:CreateTexture(nil, "ARTWORK");
	a.tex:SetWidth(SIZE);
	a.tex:SetHeight(SIZE);
	a.tex:SetPoint("TOP", a, "TOP", 0, 0);
	a.tex:SetTexture(ARROW);
	a.label = a:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	a.label:SetPoint("TOP", a.tex, "BOTTOM", 0, -1);
	a:Hide();
	arrows[i] = a;
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffff7d0aHoA Arrows|r: " .. msg);
end

local function Place()
	f:ClearAllPoints();
	local p = HoAChestArrowDB.point;
	if ( p and p[1] ) then
		f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p[1], p[2]);
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 140);
	end
end

-- Hordes' tutorial arrow rotation
local function Rotate(tex, angle)
	local c, s = math.cos(angle), math.sin(angle);
	local function Corner(x, y)
		return 0.5 + x * c + y * s, 0.5 + x * s - y * c;
	end
	local ulx, uly = Corner(-0.5, 0.5);
	local llx, lly = Corner(-0.5, -0.5);
	local urx, ury = Corner(0.5, 0.5);
	local lrx, lry = Corner(0.5, -0.5);
	tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry);
end

local handlers = {};
handlers["objective"] = function(m)
	local id, kind = m[2], m[3] or "";
	local x, y, mapId = tonumber(m[4] or ""), tonumber(m[5] or ""), tonumber(m[6] or "");
	if ( not COLORS[kind] or not x or not y ) then
		objectives[id] = nil;
		return;
	end
	local desc = string.lower(m[10] or "");
	objectives[id] = { kind = kind, x = x, y = y, mapId = mapId, label = m[7] or kind,
		free = kind == "chest" and string.find(desc, "free") ~= nil };
end;
handlers["objectiveclear"] = function(m)
	if ( m[2] and m[2] ~= "" ) then
		objectives[m[2]] = nil;
	else
		objectives = {};
	end
end;
VanillaBonkUI.Listen(handlers);

local elapsed = 0;
f:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1;
	if ( elapsed < 0.03 ) then return; end
	elapsed = 0;
	if ( not UnitPosition ) then return; end
	local west, north, _, mapId = UnitPosition("player");
	local facing = GetCameraFacing and GetCameraFacing() or (GetPlayerFacing and GetPlayerFacing());
	if ( not west or not facing ) then return; end

	-- nearest of each enabled kind
	local best, bestD = {}, {};
	for _, o in pairs(objectives) do
		if ( HoAChestArrowDB.kinds[o.kind] and (not o.mapId or not mapId or o.mapId == mapId) ) then
			local dn, dw = o.x - north, o.y - west;
			local d = math.sqrt(dn * dn + dw * dw);
			if ( not bestD[o.kind] or d < bestD[o.kind] ) then
				best[o.kind], bestD[o.kind] = o, d;
			end
		end
	end

	local shown = 0;
	for i = 1, table.getn(KINDS) do
		local kind, a = KINDS[i], arrows[i];
		local o = best[kind];
		if ( o ) then
			shown = shown + 1;
			a.slot = shown;
			Rotate(a.tex, math.atan2(o.y - west, o.x - north) - facing);
			local c = COLORS[kind];
			local yards = math.floor(bestD[kind] + 0.5);
			if ( o.free ) then
				a.tex:SetVertexColor(0.3, 1, 0.3);
				a.tex:SetAlpha(0.6 + 0.4 * math.abs(math.sin(GetTime() * 4)));
				a.label:SetText(string.format("%s\nFREE %d yd", o.label, yards));
			else
				a.tex:SetVertexColor(c[1], c[2], c[3]);
				a.tex:SetAlpha(1);
				a.label:SetText(string.format("%s\n%d yd", o.label, yards));
			end
			a:Show();
		else
			a.slot = nil;
			a:Hide();
		end
	end
	-- lay the shown arrows out in a row, centered on the frame
	local width = shown * SIZE + (shown - 1) * GAP;
	for i = 1, table.getn(arrows) do
		local a = arrows[i];
		if ( a.slot ) then
			a:ClearAllPoints();
			a:SetPoint("TOPLEFT", f, "TOP", -width / 2 + (a.slot - 1) * (SIZE + GAP), 0);
		end
	end
end);

local loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:SetScript("OnEvent", function()
	if ( not HoAChestArrowDB ) then
		HoAChestArrowDB = { off = false };
	end
	if ( not HoAChestArrowDB.kinds ) then
		HoAChestArrowDB.kinds = {};
		for k, v in pairs(DEFAULT_ON) do HoAChestArrowDB.kinds[k] = v; end
	end
	Place();
	if ( not HoAChestArrowDB.off ) then f:Show(); end
end);

SLASH_HOACHESTARROW1 = "/hoaarrow";
SLASH_HOACHESTARROW2 = "/hoachest";
SlashCmdList["HOACHESTARROW"] = function(msg)
	msg = string.lower(msg or "");
	if ( msg == "on" or msg == "off" ) then
		HoAChestArrowDB.off = (msg == "off");
		if ( HoAChestArrowDB.off ) then f:Hide(); else f:Show(); end
		Print("arrows " .. msg .. ".");
	elseif ( COLORS[msg] ) then
		HoAChestArrowDB.kinds[msg] = not HoAChestArrowDB.kinds[msg];
		Print(msg .. " arrow " .. (HoAChestArrowDB.kinds[msg] and "on" or "off") .. ".");
	elseif ( msg == "reset" ) then
		HoAChestArrowDB.point = nil;
		Place();
		Print("arrows moved back.");
	else
		local list = {};
		for i = 1, table.getn(KINDS) do
			table.insert(list, KINDS[i] .. (HoAChestArrowDB.kinds[KINDS[i]] and " (on)" or " (off)"));
		end
		Print("/hoaarrow on | off | reset; /hoaarrow <kind> toggles one: " .. table.concat(list, ", ") .. ". Drag to move.");
	end
end;
