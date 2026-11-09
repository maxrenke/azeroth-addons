-- HoA Blackwell Skin: walks Hordes of Azeroth's hero bar (VanillaBonkHeroBar) and swaps its Blizzard art
-- for BlackwellUI's look: the stone plate and quickslot frames become flat dark panels with a black
-- border, the gryphons and slot recesses go, the bars take BlackwellUI's bar texture, the text its font.
-- Hordes' own code keeps running the bar; this only changes how it looks. Walks again every half second,
-- since the bar builds slots as a run goes on.

local HIDE_ART = {
	"ui%-mainmenubar%-endcap",
	"ui%-quickslot2", -- slot frames: hidden, no panel, so the icons aren't shaded
	"slotrecess",
	-- the hover highlight (HIGHLIGHT layer, additive): this engine draws it all the time, washing the icons
	"buttonhilight%-square",
};
local PANEL_ART = {
	"ui%-mainmenubar%-dwarf",
	"levelplate",
};
local FLAT = "Interface\\Buttons\\WHITE8X8";

local paneled = {};

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffff7d0aHoA Blackwell Skin|r: " .. msg);
end

local function Matches(path, list)
	for i = 1, table.getn(list) do
		if ( string.find(path, list[i]) ) then
			return true;
		end
	end
	return false;
end

local function Panel(f)
	if ( paneled[f] ) then return; end
	-- never under a slot's icon: this engine can draw a backdrop added later over the icon
	if ( f:GetObjectType() == "Button" ) then return; end
	paneled[f] = true;
	-- This engine draws a frame's textures in the order they were made, whatever their layer, so a
	-- backdrop added to the frame itself covers its text, bars and art. Put it on its own frame behind.
	local back = CreateFrame("Frame", nil, f:GetParent() or UIParent);
	back:SetAllPoints(f);
	back:SetFrameStrata(f:GetFrameStrata());
	local level = f:GetFrameLevel() - 1;
	if ( level < 0 ) then level = 0; end
	back:SetFrameLevel(level);
	local B = BlackwellUI;
	if ( B and B.Backdrop ) then
		B:Backdrop(back);
	else
		local bg = back:CreateTexture(nil, "BACKGROUND");
		bg:SetAllPoints(back);
		bg:SetTexture(0.05, 0.05, 0.07, 0.85);
	end
	-- follow the frame's visibility (the run and camp plates swap)
	local onShow, onHide = f:GetScript("OnShow"), f:GetScript("OnHide");
	f:SetScript("OnShow", function() back:Show(); if ( onShow ) then onShow(); end end);
	f:SetScript("OnHide", function() back:Hide(); if ( onHide ) then onHide(); end end);
	if ( not f:IsVisible() ) then back:Hide(); end
end

-- The spell slots' rarity glow (UI-ActionButton-Border, additive) washes over the icon on this
-- engine: hide it and draw a 2px edge in its color instead, following whether it is shown.
local rims = {};
local function Rim(glow)
	local f = glow:GetParent();
	local rim = rims[glow];
	if ( not rim ) then
		rim = {};
		local edges = {
			{ "TOPLEFT", "TOPRIGHT", nil, 2 },
			{ "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
			{ "TOPLEFT", "BOTTOMLEFT", 2, nil },
			{ "TOPRIGHT", "BOTTOMRIGHT", 2, nil },
		};
		for i = 1, 4 do
			local e = f:CreateTexture(nil, "OVERLAY");
			e:SetTexture(FLAT);
			e:SetPoint(edges[i][1], f, edges[i][1], 0, 0);
			e:SetPoint(edges[i][2], f, edges[i][2], 0, 0);
			if ( edges[i][3] ) then e:SetWidth(2); end
			if ( edges[i][4] ) then e:SetHeight(2); end
			rim[i] = e;
		end
		rims[glow] = rim;
	end
	-- this engine ignores alpha on additive textures, so make it a normal blend first
	glow:SetBlendMode("BLEND");
	glow:SetAlpha(0);
	local r, g, b = glow:GetVertexColor();
	local shown = glow:IsShown();
	for i = 1, 4 do
		rim[i]:SetVertexColor(r or 1, g or 1, b or 1, 1);
		if ( shown ) then rim[i]:Show(); else rim[i]:Hide(); end
	end
end

local function SkinTexture(tex)
	local path = tex:GetTexture();
	if ( type(path) ~= "string" ) then return; end
	path = string.lower(path);
	if ( string.find(path, "ui%-actionbutton%-border") ) then
		Rim(tex);
	elseif ( string.find(path, "buttonhilight%-square") ) then
		-- this engine ignores alpha on the HIGHLIGHT layer: drop the texture outright
		tex:SetTexture(nil);
		tex:Hide();
	elseif ( Matches(path, HIDE_ART) ) then
		tex:SetAlpha(0);
	elseif ( Matches(path, PANEL_ART) ) then
		tex:SetAlpha(0);
		-- the level badge sits centered on the plate's top edge, over the XP rail: lift it clear
		if ( string.find(path, "levelplate") ) then
			local level = tex:GetParent();
			local plate = level:GetParent();
			if ( plate and not level.hoaLifted ) then
				level:ClearAllPoints();
				level:SetPoint("BOTTOM", plate, "TOP", 0, 2);
				level.hoaLifted = true;
			end
		end
		Panel(tex:GetParent());
	end
end

local function SkinFont(fs)
	local B = BlackwellUI;
	if ( not (B and B.GetFontPath) ) then return; end
	local font, size, flags = fs:GetFont();
	local path = B:GetFontPath();
	if ( font and path and font ~= path ) then
		fs:SetFont(path, size or 11, flags or "OUTLINE");
	end
end

local function SkinBar(sb)
	local B = BlackwellUI;
	local tex = B and B.db and B.BAR_TEXTURES and B.BAR_TEXTURES[B.db.barTexture];
	if ( tex ) then
		local cur = sb:GetStatusBarTexture();
		if ( not cur or cur:GetTexture() ~= tex ) then
			local r, g, b = sb:GetStatusBarColor();
			sb:SetStatusBarTexture(tex);
			sb:SetStatusBarColor(r, g, b);
		end
	end
end

local function Walk(f)
	local regions = { f:GetRegions() };
	for i = 1, table.getn(regions) do
		local r = regions[i];
		local kind = r:GetObjectType();
		if ( kind == "Texture" ) then
			SkinTexture(r);
		elseif ( kind == "FontString" ) then
			SkinFont(r);
		end
	end
	if ( f:GetObjectType() == "StatusBar" ) then
		SkinBar(f);
	end
	-- the spell slots' cooldown sweep (a Model) draws as a grey wash over the whole icon on this engine
	if ( f:GetObjectType() == "Model" and not HoABlackwellSkinDB.keepSweep ) then
		f:SetAlpha(0);
	end
	local children = { f:GetChildren() };
	for i = 1, table.getn(children) do
		Walk(children[i]);
	end
end

local function Accent()
	local B = BlackwellUI;
	local t = B and B.db and B.THEMES and B.THEMES[B.db.theme];
	if ( t and t.r ) then return t.r, t.g, t.b; end
	return 0, 0.9, 1;
end

-- Hordes' damage meter: its tooltip-bordered backdrops (the meter, its mode menu, the party list)
-- become sharp flat panels with a 1px theme-colored edge, the gold header gradient a dark bar,
-- the gold rule under it the theme color. The rows keep their damage-type colors.
local meterDone = {};
local function SharpBackdrop(f)
	if ( not f or meterDone[f] or not f.SetBackdrop ) then return; end
	meterDone[f] = true;
	f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } });
	f:SetBackdropColor(0.04, 0.04, 0.05, 0.85);
	local r, g, b = Accent();
	f:SetBackdropBorderColor(r, g, b, 0.5);
end

local function SkinMeter()
	local m = VanillaBonkMeter;
	if ( not m ) then return; end
	SharpBackdrop(m);
	local children = { m:GetChildren() };
	for i = 1, table.getn(children) do
		local c = children[i];
		if ( c.GetBackdrop and c:GetBackdrop() ) then SharpBackdrop(c); end
	end
	if ( m.header and not m.header.hoaDone ) then
		m.header:SetGradientAlpha("VERTICAL", 0.06, 0.06, 0.07, 0.9, 0.1, 0.1, 0.12, 0.9);
		m.header.hoaDone = true;
	end
	if ( m.rule ) then
		local r, g, b = Accent();
		m.rule:SetVertexColor(r, g, b, 0.8);
	end
	-- fonts only: the rows' fills are FLAT textures already, coloured by damage type
	local function Fonts(f)
		local regions = { f:GetRegions() };
		for i = 1, table.getn(regions) do
			if ( regions[i]:GetObjectType() == "FontString" ) then SkinFont(regions[i]); end
		end
		local kids = { f:GetChildren() };
		for i = 1, table.getn(kids) do Fonts(kids[i]); end
	end
	Fonts(m);
end

-- Chat: Hordes speaks to its addon through system lines, which still arrive with the frames hidden.
-- Something shows them again every frame, so hiding flashes: move them under a hidden parent instead.
local CHAT_FRAMES = { "BUI_ChatModule", "ChatFrame1", "ChatFrameMenuButton", "ChatFrame1UpButton",
	"ChatFrame1DownButton", "ChatFrame1BottomButton" };
local chatHider = CreateFrame("Frame");
chatHider:Hide();
local function HideChat()
	for _, name in ipairs(CHAT_FRAMES) do
		local f = getglobal(name);
		if ( f and f:GetParent() ~= chatHider ) then
			f.hoaParent = f:GetParent();
			f:SetParent(chatHider);
		end
	end
end
local function ShowChat()
	for _, name in ipairs(CHAT_FRAMES) do
		local f = getglobal(name);
		if ( f and f:GetParent() == chatHider ) then
			f:SetParent(f.hoaParent or UIParent);
			f:Show();
		end
	end
end

local elapsed = 0.5;
local ticker = CreateFrame("Frame");
ticker:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1;
	if ( elapsed < 0.5 ) then return; end
	elapsed = 0;
	if ( not HoABlackwellSkinDB or HoABlackwellSkinDB.off ) then return; end
	if ( VanillaBonkHeroBar ) then Walk(VanillaBonkHeroBar); end
	SkinMeter();
	if ( HoABlackwellSkinDB.hideChat ) then HideChat(); end
end);

local loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:SetScript("OnEvent", function()
	if ( not HoABlackwellSkinDB ) then
		HoABlackwellSkinDB = { off = false };
	end
	if ( HoABlackwellSkinDB.hideChat == nil ) then HoABlackwellSkinDB.hideChat = true; end
	if ( not HoABlackwellSkinDB.scale ) then HoABlackwellSkinDB.scale = 0.8; end
	UIParent:SetScale(HoABlackwellSkinDB.scale);
end);

SLASH_HOABLACKWELLSKIN1 = "/hoaskin";
SlashCmdList["HOABLACKWELLSKIN"] = function(msg)
	msg = string.lower(msg or "");
	if ( msg == "dump" ) then
		-- every visible texture on the bar's buttons, saved for inspection after /reload
		local out = {};
		local function Dump(f, depth)
			local regions = { f:GetRegions() };
			for i = 1, table.getn(regions) do
				local r = regions[i];
				if ( r:GetObjectType() == "Texture" and r:IsShown() ) then
					local layer = r.GetDrawLayer and r:GetDrawLayer() or "?";
					local blend = r.GetBlendMode and r:GetBlendMode() or "?";
					local cr, cg, cb, ca = r:GetVertexColor();
					table.insert(out, string.format("%s%s tex=%s layer=%s blend=%s alpha=%.2f color=%.2f,%.2f,%.2f,%.2f w=%d",
						string.rep(" ", depth), f:GetObjectType(), tostring(r:GetTexture()), tostring(layer), tostring(blend),
						r:GetAlpha() or -1, cr or -1, cg or -1, cb or -1, ca or -1, r:GetWidth() or 0));
				end
			end
			local children = { f:GetChildren() };
			for i = 1, table.getn(children) do
				local c = children[i];
				if ( c:IsShown() ) then
					table.insert(out, string.format("%s[%s alpha=%.2f]", string.rep(" ", depth), c:GetObjectType(), c:GetAlpha() or -1));
					Dump(c, depth + 1);
				end
			end
		end
		Dump(VanillaBonkHeroBar, 0);
		HoABlackwellSkinDB.dump = out;
		Print("dumped " .. table.getn(out) .. " lines; /reload to save them.");
	elseif ( msg == "chat" ) then
		HoABlackwellSkinDB.hideChat = not HoABlackwellSkinDB.hideChat;
		if ( not HoABlackwellSkinDB.hideChat ) then
			ShowChat();
		end
		Print("chat " .. (HoABlackwellSkinDB.hideChat and "hidden" or "shown") .. ".");
	elseif ( string.find(msg, "^scale") ) then
		local _, _, v = string.find(msg, "^scale%s*([%d%.]+)");
		v = tonumber(v);
		if ( v and v >= 0.5 and v <= 1.5 ) then
			HoABlackwellSkinDB.scale = v;
			UIParent:SetScale(v);
			Print("UI scale " .. v .. ".");
		else
			Print("/hoaskin scale 0.8 (0.5 to 1.5)");
		end
	elseif ( msg == "sweep" ) then
		HoABlackwellSkinDB.keepSweep = not HoABlackwellSkinDB.keepSweep;
		Print("cooldown sweep " .. (HoABlackwellSkinDB.keepSweep and "shown (restart to bring it back)" or "hidden") .. ".");
	elseif ( msg == "on" or msg == "off" ) then
		HoABlackwellSkinDB.off = (msg == "off");
		Print("skin " .. msg .. (msg == "off" and " (restart the game to bring the old art back)." or "."));
	else
		Print("/hoaskin on | off - the skin; /hoaskin chat - hide or show chat; /hoaskin scale <0.5-1.5> - UI scale; /hoaskin sweep - cooldown sweep.");
	end
end;
