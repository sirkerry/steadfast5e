--
-- Backward-compatibility shims for Steadfast5e - Expanded Skills.
-- Registered as global table "ExpandedSkillsManager" via loader.xml.
--
-- Overrides ActionSkill / ActionCheck functions so that:
--   1. SKILL effects using old names still apply to renamed skills.
--   2. Programmatic skill requests by old name route to the new skill.
--   3. Party-sheet rolls by old name route to the new skill.
--

-- Maps simplified old names → new flat skill names.
local SKILL_DEFAULTS = {
	-- Standard 5E renames and removals
	["animalhandling"]  = "Beastcraft",
	["history"]         = "Academics",
	["intimidation"]    = "Deception",
	["medicine"]        = "Healing",
	["nature"]          = "Wildcraft",
	["performance"]     = "Perform",
	["sleightofhand"]   = "Trickery",
	-- Standard 5E unchanged (explicit compat for wizard parsing)
	["acrobatics"]      = "Acrobatics",
	["arcana"]          = "Arcana",
	["athletics"]       = "Athletics",
	["deception"]       = "Deception",
	["insight"]         = "Insight",
	["investigation"]   = "Investigation",
	["perception"]      = "Perception",
	["persuasion"]      = "Persuasion",
	["religion"]        = "Religion",
	["stealth"]         = "Stealth",
	["survival"]        = "Survival",
	-- New skill names (pass-through)
	["academics"]   = "Academics",
	["beastcraft"]  = "Beastcraft",
	["cooking"]     = "Cooking",
	["crafting"]    = "Crafting",
	["endurance"]   = "Endurance",
	["healing"]     = "Healing",
	["herblore"]    = "Herblore",
	["occult"]      = "Occult",
	["perform"]     = "Perform",
	["science"]     = "Science",
	["streetwise"]  = "Streetwise",
	["tracking"]    = "Tracking",
	["trickery"]    = "Trickery",
	["wildcraft"]   = "Wildcraft",
};

-- Maps simplified new skill name → simplified old 5E name(s).
-- Used to add old names to tSkillFilter so SKILL effects still match.
local SKILL_OLD_SIMPLIFIED = {
	["academics"]  = {"history"},
	["beastcraft"] = {"animalhandling"},
	["deception"]  = {"intimidation"},
	["healing"]    = {"medicine"},
	["perform"]    = {"performance"},
	["trickery"]   = {"sleightofhand"},
	["wildcraft"]  = {"nature"},
};

local function findSkillNode(nodeActor, sTarget)
	for _, v in ipairs(DB.getChildList(nodeActor, "skilllist")) do
		if DB.getValue(v, "name", "") == sTarget then return v; end
	end
	return nil;
end

function onInit()
	-- Update DataCommon.skilldata: remove old renamed/removed skills, add new ones.
	if DataCommon and DataCommon.skilldata then
		DataCommon.skilldata["Animal Handling"] = nil;
		DataCommon.skilldata["History"]         = nil;
		DataCommon.skilldata["Intimidation"]    = nil;
		DataCommon.skilldata["Medicine"]        = nil;
		DataCommon.skilldata["Performance"]     = nil;
		DataCommon.skilldata["Sleight of Hand"] = nil;

		DataCommon.skilldata["Perception"] = { stat = "constitution" };

		DataCommon.skilldata["Academics"]  = { stat = "intelligence" };
		DataCommon.skilldata["Beastcraft"] = { stat = "wisdom" };
		DataCommon.skilldata["Cooking"]    = { stat = "wisdom" };
		DataCommon.skilldata["Crafting"]   = { stat = "intelligence" };
		DataCommon.skilldata["Endurance"]  = { stat = "constitution" };
		DataCommon.skilldata["Healing"]    = { stat = "wisdom" };
		DataCommon.skilldata["Herblore"]   = { stat = "wisdom" };
		DataCommon.skilldata["Occult"]     = { stat = "wisdom" };
		DataCommon.skilldata["Perform"]    = { stat = "charisma" };
		DataCommon.skilldata["Science"]    = { stat = "intelligence" };
		DataCommon.skilldata["Streetwise"] = { stat = "charisma" };
		DataCommon.skilldata["Tracking"]   = { stat = "wisdom" };
		DataCommon.skilldata["Trickery"]   = { stat = "dexterity" };
		DataCommon.skilldata["Wildcraft"]  = { stat = "wisdom" };
	end

	-- Replace party sheet skill dropdown with all 26 flat skills.
	if DataCommon then
		DataCommon.psskilldata = {
			"Academics",
			"Acrobatics",
			"Arcana",
			"Athletics",
			"Beastcraft",
			"Cooking",
			"Crafting",
			"Deception",
			"Endurance",
			"Healing",
			"Herblore",
			"Insight",
			"Investigation",
			"Nature",
			"Occult",
			"Perception",
			"Perform",
			"Persuasion",
			"Religion",
			"Science",
			"Stealth",
			"Streetwise",
			"Survival",
			"Tracking",
			"Trickery",
			"Wildcraft",
		};
	end

	-- ----------------------------------------------------------------
	-- Override 1: CharBuildManager.parseSkillsField
	-- Translate old skill names to new names in the Character Wizard's
	-- skill choice dropdowns (class, background, species features).
	-- Deduplicates in case two old names map to the same new name
	-- (e.g. both "Deception" and "Intimidation" → "Deception").
	-- ----------------------------------------------------------------
	local _orig_parseSkillsField = CharBuildManager.parseSkillsField;
	CharBuildManager.parseSkillsField = function(s, bSource2024)
		local tBase, tOptions, nPicks = _orig_parseSkillsField(s, bSource2024);
		local function remapUnique(t)
			local seen = {};
			local tOut = {};
			for _, sOpt in ipairs(t) do
				local sNew = SKILL_DEFAULTS[StringManager.simplify(sOpt)] or sOpt;
				if not seen[sNew] then
					seen[sNew] = true;
					table.insert(tOut, sNew);
				end
			end
			return tOut;
		end
		return remapUnique(tBase), remapUnique(tOptions), nPicks;
	end

	-- ----------------------------------------------------------------
	-- Override 2: ActionCheck.setupRollMod
	-- After the base call builds tSkillFilter with the current skill's
	-- simplified name, also inject all simplified old names for that
	-- skill so legacy SKILL effects still match.
	-- ----------------------------------------------------------------
	local _orig_setupRollMod = ActionCheck.setupRollMod;
	ActionCheck.setupRollMod = function(rRoll)
		_orig_setupRollMod(rRoll);
		if rRoll.tSkillFilter then
			local tExtra = {};
			for _, sCurrent in ipairs(rRoll.tSkillFilter) do
				local tOld = SKILL_OLD_SIMPLIFIED[sCurrent];
				if tOld then
					for _, sOld in ipairs(tOld) do
						table.insert(tExtra, sOld);
					end
				end
			end
			for _, sOld in ipairs(tExtra) do
				table.insert(rRoll.tSkillFilter, sOld);
			end
		end
	end

	-- ----------------------------------------------------------------
	-- Override 3: ActionSkill.setupRollBuildFromNamePC
	-- Called when a roll is requested by skill name (spells, features,
	-- effects automation). Redirect old names to new skill nodes.
	-- ----------------------------------------------------------------
	local _orig_setupFromName = ActionSkill.setupRollBuildFromNamePC;
	ActionSkill.setupRollBuildFromNamePC = function(rRoll, rActor, sSkill)
		local sNew = SKILL_DEFAULTS[StringManager.simplify(sSkill)];
		if sNew then
			local nodeActor = ActorManager.getCreatureNode(rActor);
			if nodeActor then
				local nodeSkill = findSkillNode(nodeActor, sNew);
				if nodeSkill then
					ActionSkill.setupRollBuildFromNodePC(rRoll, rActor, nodeSkill);
					return;
				end
			end
		end
		_orig_setupFromName(rRoll, rActor, sSkill);
	end

	-- ----------------------------------------------------------------
	-- Override 4: ActionSkill.performPartySheetRoll
	-- Party sheet requests rolls by the skill name string. Redirect old
	-- names to the matching new skill node.
	-- ----------------------------------------------------------------
	local _orig_partyRoll = ActionSkill.performPartySheetRoll;
	ActionSkill.performPartySheetRoll = function(draginfo, rActor, sSkill)
		local nodeActor = ActorManager.getCreatureNode(rActor);
		if nodeActor then
			if findSkillNode(nodeActor, sSkill) then
				return _orig_partyRoll(draginfo, rActor, sSkill);
			end
			local sNew = SKILL_DEFAULTS[StringManager.simplify(sSkill)];
			if sNew then
				local nodeSkill = findSkillNode(nodeActor, sNew);
				if nodeSkill then
					local rRoll = ActionSkill.getRoll(rActor, nodeSkill);
					local nTargetDC = DB.getValue("partysheet.skilldc", 0);
					if nTargetDC > 0 then rRoll.nTargetDC = nTargetDC; end
					ActionsManager.performAction(draginfo, rActor, rRoll);
					return;
				end
			end
		end
		_orig_partyRoll(draginfo, rActor, sSkill);
	end
end

