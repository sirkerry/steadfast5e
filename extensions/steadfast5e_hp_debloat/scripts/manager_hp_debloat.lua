--
-- Steadfast5e - HP Debloat
-- Compresses PC/NPC hit points: level 1 = max hit die + CON mod;
-- each subsequent level = max hit die / 2, no CON.
-- Multiclass: the class with the largest hit die is used for the level 1 slot.
--

local OPT_PCS      = "SSHPP";   -- Apply formula to PCs (default: on)
local OPT_NPCS     = "SSHNP";   -- Apply formula to GM-controlled charsheet NPCs (default: on)
local OPT_MONSTERS = "SSHPM";   -- Apply formula to npc-record monsters (default: off)
local OPT_LEVELUP  = "SSHLM";   -- Level-up application mode (default: auto)

-- Saved reference to the original helperAddClassHP so we can fall through
-- to standard 5E behaviour when a charsheet is excluded by option.
local _fnOrigAddClassHP;

function onInit()
	OptionsManager.registerOptionData({
		sKey = OPT_PCS, sGroupRes = "option_header_houserule",
		tCustom = { default = "on" },
	});
	OptionsManager.registerOptionData({
		sKey = OPT_NPCS, sGroupRes = "option_header_houserule",
		tCustom = { default = "on" },
	});
	OptionsManager.registerOptionData({
		sKey = OPT_MONSTERS, sGroupRes = "option_header_houserule",
	});
	OptionsManager.registerOptionData({
		sKey      = OPT_LEVELUP,
		sGroupRes = "option_header_houserule",
		tCustom   = {
			labelsres    = "option_val_SSHLM_prompt",
			values       = "prompt",
			baselabelres = "option_val_SSHLM_auto",
			baseval      = "",
			default      = "",
		},
	});

	-- Save original, then replace with our debloated version.
	_fnOrigAddClassHP = CharClassManager.helperAddClassHP;
	CharClassManager.helperAddClassHP = HPDebloatManager.debloatClassHP;

	-- Recalculate HP for all existing charsheet records so that characters
	-- created or levelled before this extension was installed are normalised.
	-- Runs at every campaign load; the calculation is idempotent.
	HPDebloatManager.recalcAll();

	-- Mid-session option callbacks: recalc when an option is turned on.
	OptionsManager.registerCallback(OPT_PCS,      HPDebloatManager.onPCOptionChanged);
	OptionsManager.registerCallback(OPT_NPCS,     HPDebloatManager.onNPCOptionChanged);
	OptionsManager.registerCallback(OPT_MONSTERS, HPDebloatManager.onMonsterOptionChanged);
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────

-- Returns true if the charsheet node is owned by a player (PC),
-- false if it is GM-controlled (companion / hireling / sidekick NPC).
local function isCharPC(nodeChar)
	return (DB.getOwner(nodeChar) ~= "");
end

-- Returns true if the debloat formula should be applied to this charsheet.
local function shouldDebloatChar(nodeChar)
	if isCharPC(nodeChar) then
		return OptionsManager.getOption(OPT_PCS) == "on";
	else
		return OptionsManager.getOption(OPT_NPCS) == "on";
	end
end

-- ─── Level-up intercept ──────────────────────────────────────────────────────

-- Replacement for CharClassManager.helperAddClassHP.
-- Called once per class-level-up via helperAddClassMain.
function debloatClassHP(rAdd)
	-- If this character type is excluded by option, fall through to vanilla 5E.
	if not shouldDebloatChar(rAdd.nodeChar) then
		_fnOrigAddClassHP(rAdd);
		return;
	end

	-- Translate hit die from the reference class record (same as original).
	local nHDMult  = 1;
	local nHDSides = 6;
	local sHD = DB.getText(rAdd.nodeSource, "hp.hitdice.text", "");
	local sMult, sSides = sHD:match("(%d?)[dD](%d+)");
	if sMult and sSides then
		nHDMult  = tonumber(sMult)  or 1;
		nHDSides = tonumber(sSides) or 6;
	else
		ChatManager.SystemMessageResource("char_error_addclasshd");
	end

	-- Persist the die type on the class record (same as original; used by
	-- the hit-die recovery roll and other systems).
	if rAdd.bNewCharClass then
		DB.setValue(rAdd.nodeCharClass, "hddie", "dice",
			string.format("%sd%s", nHDMult, nHDSides));
	end

	local nCurMax   = DB.getValue(rAdd.nodeChar, "hp.total", 0);
	local nConBonus = DB.getValue(rAdd.nodeChar, "abilities.constitution.bonus", 0);

	if rAdd.nCharLevel == 1 then
		-- First character level: full hit die maximum + CON modifier.
		local nAddHP = math.max(nHDMult * nHDSides + nConBonus, 1);
		ChatManager.SystemMessageResource(
			"char_abilities_message_hpaddmax",
			rAdd.sSourceName, rAdd.sCharName, nAddHP);
		DB.setValue(rAdd.nodeChar, "hp.total", "number", nCurMax + nAddHP);
	else
		-- Every level beyond 1st: hit die maximum / 2, no CON modifier.
		local nAddHP = math.max(math.floor(nHDMult * nHDSides / 2), 1);

		if OptionsManager.getOption(OPT_LEVELUP) == "prompt" then
			-- Prompt mode: post the gain to chat; do NOT apply automatically.
			ChatManager.SystemMessage(
				string.format(
					Interface.getString("hpd_msg_levelup_prompt"),
					rAdd.sCharName, nAddHP));
		else
			-- Auto apply.
			ChatManager.SystemMessageResource(
				"char_abilities_message_hpaddavg",
				rAdd.sSourceName, rAdd.sCharName, nAddHP);
			DB.setValue(rAdd.nodeChar, "hp.total", "number", nCurMax + nAddHP);
		end
	end

	-- Feat / trait / feature HP bonuses — always applied automatically,
	-- identical to the original helperAddClassHP.
	if CharManager.hasTrait(rAdd.nodeChar, CharManager.TRAIT_DWARVEN_TOUGHNESS) then
		CharSpeciesManager.applyDwarvenToughness(rAdd.nodeChar);
	end
	if CharManager.hasFeature(rAdd.nodeChar, CharManager.FEATURE_DRACONIC_RESILIENCE) then
		local sClassLower = StringManager.simplify(
			DB.getValue(rAdd.nodeCharClass, "name", ""));
		if sClassLower == CharManager.CLASS_SORCERER then
			CharClassManager.applyDraconicResilience(rAdd.nodeChar);
		end
	end
	if CharManager.hasFeat(rAdd.nodeChar, CharManager.FEAT_TOUGH) then
		CharFeatManager.applyTough(rAdd.nodeChar);
	end
end

-- ─── Class-data helpers ───────────────────────────────────────────────────────

-- Returns the number of sides for the hit die stored in a "hddie" dice field,
-- or 0 if absent / unreadable.
-- Each element of aDice is a string like "d8", "d10", "d12".
local function sidesFromDiceTable(aDice)
	if not aDice or #aDice == 0 then return 0; end
	local sSides = aDice[1]:match("[dD](%d+)");
	return tonumber(sSides) or 0;
end

-- Builds a list of {sides, level, name} for every class on nodeChar that has
-- both a positive level and a stored hddie.  Returns nil if none found.
local function buildClassList(nodeChar)
	local tClasses = {};
	for _, nodeClass in ipairs(DB.getChildList(nodeChar, "classes")) do
		local nLevel = DB.getValue(nodeClass, "level", 0);
		if nLevel > 0 then
			local aDice  = DB.getValue(nodeClass, "hddie", {});
			local nSides = sidesFromDiceTable(aDice);
			if nSides > 0 then
				table.insert(tClasses, {
					sides = nSides,
					level = nLevel,
					name  = StringManager.simplify(
						DB.getValue(nodeClass, "name", "")),
				});
			end
		end
	end
	return (#tClasses > 0) and tClasses or nil;
end

-- ─── PC / NPC recalculation ──────────────────────────────────────────────────

-- Calculates the debloated max HP a character should have from current class
-- data, CON modifier, and the three known HP-granting feats / traits / features.
-- Returns 0 if no valid class data exists (e.g. character sheet stub).
function calcCharHP(nodeChar)
	local tClasses = buildClassList(nodeChar);
	if not tClasses then return 0; end

	local nConBonus   = DB.getValue(nodeChar, "abilities.constitution.bonus", 0);
	local nTotalLevel = 0;
	local nBestSides  = 0;
	local nBaseHP     = 0;
	local nSorcLevel  = 0;

	for _, c in ipairs(tClasses) do
		nTotalLevel = nTotalLevel + c.level;
		-- Each class contributes (sides/2) per level as the baseline; the
		-- level-1 class adds an extra (sides/2) on top (see below).
		nBaseHP = nBaseHP + c.level * math.floor(c.sides / 2);
		if c.sides > nBestSides then
			nBestSides = c.sides;
		end
		if c.name == CharManager.CLASS_SORCERER then
			nSorcLevel = c.level;
		end
	end

	-- The level-1 class uses the full die max instead of half-max.
	-- Choosing the class with the biggest die maximises HP per spec.
	-- The baseline already counted (nBestSides/2) for one of that class's
	-- levels; the extra half brings that one level up to the full die value.
	local nNewMax = nBaseHP + math.floor(nBestSides / 2) + nConBonus;

	-- Known HP-granting feats / traits — stack on top per spec.
	if CharManager.hasFeat(nodeChar, CharManager.FEAT_TOUGH) then
		nNewMax = nNewMax + nTotalLevel * 2;
	end
	if CharManager.hasTrait(nodeChar, CharManager.TRAIT_DWARVEN_TOUGHNESS) then
		nNewMax = nNewMax + nTotalLevel;
	end
	if nSorcLevel > 0 and
	   CharManager.hasFeature(nodeChar, CharManager.FEATURE_DRACONIC_RESILIENCE) then
		nNewMax = nNewMax + nSorcLevel;
	end

	return math.max(nNewMax, 1);
end

-- Applies the debloated HP formula to a single charsheet node, preserving the
-- ratio of current HP to max HP so no character is suddenly left at zero.
-- Returns without changing anything if the relevant PC/NPC option is off.
function recalcOneChar(nodeChar)
	if not shouldDebloatChar(nodeChar) then return; end

	local nOldMax    = DB.getValue(nodeChar, "hp.total",  0);
	local nOldWounds = DB.getValue(nodeChar, "hp.wounds", 0);
	local nOldCurrent = nOldMax - nOldWounds;

	local nNewMax = HPDebloatManager.calcCharHP(nodeChar);
	if nNewMax <= 0 then return; end  -- no valid class data; skip

	-- Preserve current / max ratio (spec recommendation: floor the result).
	local nNewCurrent;
	if nOldMax > 0 then
		nNewCurrent = math.floor(nOldCurrent / nOldMax * nNewMax);
	else
		nNewCurrent = nNewMax;
	end
	nNewCurrent = math.max(nNewCurrent, 0);

	local nNewWounds = math.max(nNewMax - nNewCurrent, 0);

	if nNewMax ~= nOldMax then
		DB.setValue(nodeChar, "hp.total",  "number", nNewMax);
		DB.setValue(nodeChar, "hp.wounds", "number", nNewWounds);
		local sName = DB.getValue(nodeChar, "name", "?");
		ChatManager.SystemMessage(
			string.format(
				Interface.getString("hpd_msg_recalc"),
				sName, nOldMax, nNewMax, nOldCurrent, nNewCurrent));
	end
end

-- ─── Monster recalculation ───────────────────────────────────────────────────

-- Parses a 5E hit dice string such as "10d8+20", "5d10", "12d12-3".
-- Returns numDice, sides, modifier (all numbers), or nil on failure.
local function parseHDString(sHD)
	if not sHD or sHD == "" then return nil; end
	local sNum, sSides, sMod = sHD:match("(%d+)[dD](%d+)([+-]?%d*)");
	if not sNum or not sSides then return nil; end
	local nMod = 0;
	if sMod and sMod ~= "" then
		nMod = tonumber(sMod) or 0;
	end
	return tonumber(sNum), tonumber(sSides), nMod;
end

-- Applies the debloated formula to a single npc node.
-- Monster HP = numDice × (sides / 2) + modifier.
function recalcOneMonster(nodeNPC)
	local sHD    = DB.getValue(nodeNPC, "hd", "");
	local nOldHP = DB.getValue(nodeNPC, "hp", 0);

	local nNum, nSides, nMod = parseHDString(sHD);
	if not nNum then return; end

	local nNewHP = math.max(math.floor(nNum * (nSides / 2)) + nMod, 1);

	if nNewHP ~= nOldHP then
		DB.setValue(nodeNPC, "hp", "number", nNewHP);
		local sName = DB.getValue(nodeNPC, "name", "?");
		ChatManager.SystemMessage(
			string.format(
				Interface.getString("hpd_msg_monster_recalc"),
				sName, nOldHP, nNewHP));
	end
end

function recalcAllMonsters()
	for _, nodeNPC in ipairs(DB.getChildList("npc")) do
		HPDebloatManager.recalcOneMonster(nodeNPC);
	end
end

-- ─── Batch recalculation ─────────────────────────────────────────────────────

function recalcAll()
	for _, nodeChar in ipairs(DB.getChildList("charsheet")) do
		HPDebloatManager.recalcOneChar(nodeChar);
	end
	if OptionsManager.getOption(OPT_MONSTERS) == "on" then
		HPDebloatManager.recalcAllMonsters();
	end
end

-- ─── Event handlers ──────────────────────────────────────────────────────────

-- Called when a PC/NPC option changes during the session.
-- Triggers recalculation for the affected charsheet type if turned on.
function onPCOptionChanged()
	if OptionsManager.getOption(OPT_PCS) == "on" then
		for _, nodeChar in ipairs(DB.getChildList("charsheet")) do
			if isCharPC(nodeChar) then
				HPDebloatManager.recalcOneChar(nodeChar);
			end
		end
	end
end
function onNPCOptionChanged()
	if OptionsManager.getOption(OPT_NPCS) == "on" then
		for _, nodeChar in ipairs(DB.getChildList("charsheet")) do
			if not isCharPC(nodeChar) then
				HPDebloatManager.recalcOneChar(nodeChar);
			end
		end
	end
end

-- Called when the "Apply to Monsters" option changes during the session.
function onMonsterOptionChanged()
	if OptionsManager.getOption(OPT_MONSTERS) == "on" then
		HPDebloatManager.recalcAllMonsters();
	end
end
