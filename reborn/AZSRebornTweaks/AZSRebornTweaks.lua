-- AZS Reborn Tweaks: hides AzerothSurvivorsUI's player, target and target-of-target frames and its
-- boss bar (BlackwellUI has its own unit frames), and draws the boss bar again in BlackwellUI's style:
-- each boss's health while bosses are up, else "<boss> approaches  N%" toward the next one.

local HIDE = {
	"AzerothSurvivorsUnitFramePlayer",
	"AzerothSurvivorsUnitFrameTarget",
	"AzerothSurvivorsUnitFrameToT",
	"AzerothSurvivorsSurvivorsBossBar",
	"AzerothSurvivorsSurvivorsResources",
	"AzerothSurvivorsActionBar1",
	"AzerothSurvivorsActionBar2",
};
local WIDTH, HEIGHT = 300, 18;
local DEFAULT_ACCENT = { 0, 229/255, 1 };
local BOSS_COLOR = { 1, 0, 85/255 };

local hidden = CreateFrame("Frame");
hidden:Hide();

local function HideStock()
	if ( InCombatLockdown() ) then
		return false;
	end
	local done = true;
	for _, name in ipairs(HIDE) do
		local f = _G[name];
		if ( f ) then
			if ( f.GetAttribute and f:GetAttribute("unit") ) then
				UnregisterUnitWatch(f);
			end
			f:SetParent(hidden);
			f:Hide();
		else
			done = false;
		end
	end
	return done;
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffff7d0aAZS Reborn Tweaks|r: " .. msg);
end

local function Accent()
	local B = BlackwellUI;
	local t = B and B.db and B.THEMES and B.THEMES[B.db.theme];
	if ( t and t.r ) then
		return t.r, t.g, t.b;
	end
	return DEFAULT_ACCENT[1], DEFAULT_ACCENT[2], DEFAULT_ACCENT[3];
end

local function FormatHealth(v)
	if ( v >= 1e6 ) then return string.format("%.1fm", v / 1e6); end
	if ( v >= 1e4 ) then return string.format("%.1fk", v / 1e3); end
	return tostring(v);
end

-- the bar
local f = CreateFrame("Frame", "AZSRebornBossBar", UIParent);
f:SetSize(WIDTH, HEIGHT);
f:SetFrameStrata("LOW");
f:SetMovable(true);
f:EnableMouse(true);
f:RegisterForDrag("LeftButton");
f:SetScript("OnDragStart", function(self) if ( IsShiftKeyDown() ) then self:StartMoving(); end end);
f:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing();
	AZSRebornTweaksDB.point = { self:GetCenter() };
end);
f:Hide();

local bar = CreateFrame("StatusBar", nil, f);
bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1);
bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1);
bar:SetMinMaxValues(0, 1);
bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8");

local label, styled;

local function Style()
	local B = BlackwellUI;
	if ( B and B.db and B.Backdrop and B.Font ) then
		B:Backdrop(f);
		local tex = B.BAR_TEXTURES and B.BAR_TEXTURES[B.db.barTexture];
		if ( tex ) then bar:SetStatusBarTexture(tex); end
		label = B:Font(bar, 11, "CENTER");
		f:SetScale(B.db.scale or 1);
	else
		local bg = f:CreateTexture(nil, "BACKGROUND");
		bg:SetAllPoints(f);
		bg:SetTexture(0, 0, 0, 0.85);
		label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	end
	label:SetPoint("CENTER", bar, "CENTER", 0, 0);
	styled = true;
end

local function Place()
	f:ClearAllPoints();
	local p = AZSRebornTweaksDB.point;
	if ( p and p[1] ) then
		f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p[1], p[2]);
	else
		f:SetPoint("TOP", UIParent, "TOP", 0, -60);
	end
end

-- the boss with the most health share up (the final boss first), else the way to the next boss
local function Progress()
	local best;
	for _, u in ipairs(AZS_UNITS or {}) do
		if ( u.hpm and u.hpm > 0 and (u.hp or 0) > 0 ) then
			if ( not best or (u.kind == "final" and best.kind ~= "final") ) then
				best = u;
			end
		end
	end
	if ( best ) then
		return best.hp / best.hpm, string.format("%s   %s", best.name or "?", FormatHealth(best.hp)), true;
	end
	if ( AZS_NextBossProgress ) then
		local share, text = AZS_NextBossProgress();
		if ( share ) then
			return share, text, false;
		end
	end
end

-- Resources strip: holiday currency, gold, next cache price, in BlackwellUI tiles above its meter.
local TILE, TILE_W = 22, 74;
local res = CreateFrame("Frame", "AZSRebornResources", UIParent);
res:SetHeight(TILE + 6);
res:SetFrameStrata("LOW");
res:Hide();
local tiles = {};
local function Tile(i, icon)
	local t = CreateFrame("Frame", nil, res);
	t:SetSize(TILE_W, TILE);
	t:SetPoint("RIGHT", res, "RIGHT", -3 - (i - 1) * (TILE_W + 4), 0);
	t.icon = t:CreateTexture(nil, "ARTWORK");
	t.icon:SetSize(TILE, TILE);
	t.icon:SetPoint("LEFT", t, "LEFT", 0, 0);
	t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
	if ( icon ) then t.icon:SetTexture(icon); end
	tiles[i] = t;
	return t;
end
local cacheTile = Tile(1, "Interface\\Icons\\INV_Box_02");
local goldTile = Tile(2, "Interface\\Icons\\INV_Misc_Bag_10");
local eventTile = Tile(3, nil);
local resStyled;

local function StyleRes()
	local B = BlackwellUI;
	for i = 1, 3 do
		local t = tiles[i];
		if ( B and B.Backdrop and B.Font ) then
			B:Backdrop(t);
			t.text = B:Font(t, 12, "RIGHT");
		else
			local bg = t:CreateTexture(nil, "BACKGROUND");
			bg:SetAllPoints(t);
			bg:SetTexture(0, 0, 0, 0.85);
			t.text = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		end
		t.text:SetPoint("RIGHT", t, "RIGHT", -4, 0);
	end
	if ( B and B.db ) then res:SetScale(B.db.scale or 1); end
	resStyled = true;
end

local function PlaceRes()
	res:ClearAllPoints();
	local meter = BUI_MeterFrame;
	if ( meter and meter:IsShown() ) then
		res:SetPoint("BOTTOMRIGHT", meter, "TOPRIGHT", 0, 4);
	else
		res:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -12, 40);
	end
	res:SetWidth(3 * (TILE_W + 4) + 2);
end

local function UpdateRes()
	local run = AZS_RUN;
	if ( AZSRebornTweaksDB.resOff or not run or not run.ph ) then
		res:Hide();
		return;
	end
	if ( not resStyled ) then StyleRes(); end
	PlaceRes();
	local gold, price = tonumber(run.gold) or 0, tonumber(run.cache) or 0;
	goldTile.text:SetText(gold .. "g");
	cacheTile.text:SetText(price .. "g");
	if ( gold >= price ) then
		cacheTile.text:SetTextColor(Accent());
		cacheTile.icon:SetVertexColor(1, 1, 1);
	else
		cacheTile.text:SetTextColor(0.5, 0.5, 0.5);
		cacheTile.icon:SetVertexColor(0.5, 0.5, 0.5);
	end
	local ev, name, icon = AZS_EVENT;
	if ( ev and AZS_EventCurrency ) then
		name, icon = AZS_EventCurrency(ev.key);
	end
	if ( name ) then
		eventTile.icon:SetTexture(icon);
		eventTile.text:SetText(tostring(ev.n or 0));
		eventTile:Show();
	else
		eventTile:Hide();
	end
	res:Show();
end

-- Spell bar: the hero's spells from AZS_SPELLS (icon, rank, cooldown) as BlackwellUI tiles above its chat.
local SPELL, SPELL_GAP, MAX_SPELLS = 34, 4, 8;
local spellBar = CreateFrame("Frame", "AZSRebornSpellBar", UIParent);
spellBar:SetSize(SPELL, SPELL);
spellBar:SetFrameStrata("LOW");
spellBar:Hide();
local spellSlots = {};

local function SpellSlot(i)
	if ( spellSlots[i] ) then return spellSlots[i]; end
	local B = BlackwellUI;
	local s = CreateFrame("Frame", nil, spellBar);
	s:SetSize(SPELL, SPELL);
	s:SetPoint("LEFT", spellBar, "LEFT", (i - 1) * (SPELL + SPELL_GAP), 0);
	s:EnableMouse(true);
	s.icon = s:CreateTexture(nil, "ARTWORK");
	s.icon:SetPoint("TOPLEFT", s, "TOPLEFT", 2, -2);
	s.icon:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -2, 2);
	s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
	s.shade = s:CreateTexture(nil, "OVERLAY");
	s.shade:SetAllPoints(s.icon);
	s.shade:SetTexture(0, 0, 0, 0.6);
	s.shade:Hide();
	if ( B and B.Backdrop and B.Font ) then
		B:Backdrop(s);
		s.rank = B:Font(s, 10, "RIGHT");
		s.cd = B:Font(s, 14, "CENTER");
	else
		local bg = s:CreateTexture(nil, "BACKGROUND");
		bg:SetAllPoints(s);
		bg:SetTexture(0, 0, 0, 0.85);
		s.rank = s:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall");
		s.cd = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge");
	end
	s.rank:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -2, 2);
	s.cd:SetPoint("CENTER", s, "CENTER", 0, 0);
	s:SetScript("OnEnter", function(self)
		if ( self.spell ) then
			GameTooltip:SetOwner(self, "ANCHOR_TOP");
			GameTooltip:SetHyperlink("spell:" .. self.spell);
			GameTooltip:Show();
		end
	end);
	s:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	spellSlots[i] = s;
	return s;
end

local function UpdateSpells()
	local spells = AZS_SPELLS;
	local run = AZS_RUN;
	if ( AZSRebornTweaksDB.spellsOff or not spells or not run or not run.ph ) then
		spellBar:Hide();
		return;
	end
	local n = math.min(table.getn(spells), MAX_SPELLS);
	local since = GetTime() - (AZS_SPELLS_AT or GetTime());
	local r, g, b = Accent();
	for i = 1, n do
		local sp = spells[i];
		local s = SpellSlot(i);
		local _, _, icon = GetSpellInfo(tonumber(sp.spell) or 0);
		s.spell = tonumber(sp.spell);
		s.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark");
		s.rank:SetText(sp.rank or "");
		s.rank:SetTextColor(r, g, b);
		local left = (tonumber(sp.cd) or 0) - since;
		if ( left >= 0.5 ) then
			s.shade:Show();
			s.cd:SetText(string.format("%d", math.ceil(left)));
		else
			s.shade:Hide();
			s.cd:SetText("");
		end
		s:Show();
	end
	for i = n + 1, table.getn(spellSlots) do
		spellSlots[i]:Hide();
	end
	spellBar:SetWidth(math.max(1, n) * (SPELL + SPELL_GAP));
	spellBar:ClearAllPoints();
	local chat = BUI_ChatPanel;
	if ( chat and chat:IsVisible() ) then
		spellBar:SetPoint("BOTTOMLEFT", chat, "TOPLEFT", 0, 6);
	else
		spellBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 12, 200);
	end
	local B = BlackwellUI;
	if ( B and B.db ) then spellBar:SetScale(B.db.scale or 1); end
	spellBar:Show();
end

local elapsed, stockHidden = 0, false;
f:SetScript("OnUpdate", nil);
local ticker = CreateFrame("Frame");
ticker:SetScript("OnUpdate", function(self, e)
	elapsed = elapsed + e;
	if ( elapsed < 0.1 ) then return; end
	elapsed = 0;
	if ( not AZSRebornTweaksDB ) then return; end
	if ( not stockHidden and AZSRebornTweaksDB.hideStock ) then
		stockHidden = HideStock();
	end
	UpdateRes();
	UpdateSpells();
	local share, text, boss;
	local ph = AZS_RUN and AZS_RUN.ph;
	if ( ph and ph ~= "ready" and not AZSRebornTweaksDB.off ) then
		share, text, boss = Progress();
	end
	if ( not share ) then
		f:Hide();
		return;
	end
	if ( not styled ) then Style(); end
	if ( boss ) then
		bar:SetStatusBarColor(BOSS_COLOR[1], BOSS_COLOR[2], BOSS_COLOR[3]);
	else
		bar:SetStatusBarColor(Accent());
	end
	bar:SetValue(share);
	label:SetText(text);
	f:Show();
end);

local loader = CreateFrame("Frame");
loader:RegisterEvent("VARIABLES_LOADED");
loader:SetScript("OnEvent", function()
	if ( not AZSRebornTweaksDB ) then
		AZSRebornTweaksDB = { off = false, hideStock = true };
	end
	Place();
end);

SLASH_AZSREBORNTWEAKS1 = "/azbar";
SlashCmdList["AZSREBORNTWEAKS"] = function(msg)
	msg = string.lower(msg or "");
	if ( msg == "on" or msg == "off" ) then
		AZSRebornTweaksDB.off = (msg == "off");
		Print("boss bar " .. msg .. ".");
	elseif ( msg == "stock" ) then
		AZSRebornTweaksDB.hideStock = not AZSRebornTweaksDB.hideStock;
		Print("Reborn's own player/target frames and boss bar " .. (AZSRebornTweaksDB.hideStock and "hidden" or "shown") .. " after /reload.");
	elseif ( msg == "spells" ) then
		AZSRebornTweaksDB.spellsOff = not AZSRebornTweaksDB.spellsOff;
		Print("spell bar " .. (AZSRebornTweaksDB.spellsOff and "off" or "on") .. ".");
	elseif ( msg == "res" ) then
		AZSRebornTweaksDB.resOff = not AZSRebornTweaksDB.resOff;
		Print("resources strip " .. (AZSRebornTweaksDB.resOff and "off" or "on") .. ".");
	elseif ( msg == "reset" ) then
		AZSRebornTweaksDB.point = nil;
		Place();
		Print("bar moved back.");
	else
		Print("/azbar on | off - the boss bar; /azbar stock - toggle hiding Reborn's own frames; /azbar reset - move it back. Shift-drag to move.");
	end
end;
