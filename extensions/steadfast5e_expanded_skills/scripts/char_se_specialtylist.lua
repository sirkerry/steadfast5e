--
-- Skill list manager for Steadfast5e - Expanded Skills.
-- Replaces char_skilllist.lua on the "list" control inside
-- charsheet_skills_contents. Populates 26 flat skills and migrates
-- standard 5E skill entries (renamed/removed skills) on first open.
--

local SKILLS = {
	-- STR
	{ name = "Athletics",     stat = "strength",     legacy = {} },
	-- DEX
	{ name = "Acrobatics",    stat = "dexterity",    legacy = {} },
	{ name = "Stealth",       stat = "dexterity",    legacy = {} },
	{ name = "Trickery",      stat = "dexterity",    legacy = { "Sleight of Hand" } },
	-- INT
	{ name = "Academics",     stat = "intelligence", legacy = { "History" } },
	{ name = "Arcana",        stat = "intelligence", legacy = {} },
	{ name = "Crafting",      stat = "intelligence", legacy = {} },
	{ name = "Investigation", stat = "intelligence", legacy = {} },
	{ name = "Nature",        stat = "intelligence", legacy = {} },
	{ name = "Religion",      stat = "intelligence", legacy = {} },
	{ name = "Science",       stat = "intelligence", legacy = {} },
	-- WIS
	{ name = "Beastcraft",    stat = "wisdom",       legacy = { "Animal Handling" } },
	{ name = "Cooking",       stat = "wisdom",       legacy = {} },
	{ name = "Healing",       stat = "wisdom",       legacy = { "Medicine" } },
	{ name = "Herblore",      stat = "wisdom",       legacy = {} },
	{ name = "Insight",       stat = "wisdom",       legacy = {} },
	{ name = "Occult",        stat = "wisdom",       legacy = {} },
	{ name = "Survival",      stat = "wisdom",       legacy = {} },
	{ name = "Tracking",      stat = "wisdom",       legacy = {} },
	{ name = "Wildcraft",     stat = "wisdom",       legacy = {} },
	-- CON
	{ name = "Endurance",     stat = "constitution", legacy = {} },
	{ name = "Perception",    stat = "constitution", legacy = {} },
	-- CHA
	{ name = "Deception",     stat = "charisma",     legacy = { "Intimidation" } },
	{ name = "Perform",       stat = "charisma",     legacy = { "Performance" } },
	{ name = "Persuasion",    stat = "charisma",     legacy = {} },
	{ name = "Streetwise",    stat = "charisma",     legacy = {} },
};

local _bInitialized = false;

function onInit()
	self.constructDefaultSkills();
	_bInitialized = true;
end

function onChildWindowCreated(w)
	if _bInitialized then
		w.setCustom(true);
	end
end

function constructDefaultSkills()
	local SKILL_NAMES  = {};  -- name → stat (marks recognised new names)
	local LEGACY_TO_NEW = {}; -- legacy name → new skill name

	for _, t in ipairs(SKILLS) do
		SKILL_NAMES[t.name] = t.stat;
		for _, sLeg in ipairs(t.legacy) do
			LEGACY_TO_NEW[sLeg] = t.name;
		end
	end

	-- Survey existing windows.
	local entrymap  = {};  -- new skill name → window
	local legacymap = {};  -- new skill name → { nodes={}, maxprof=0 }

	for _, w in pairs(getWindows()) do
		local sLabel = w.name.getValue();
		if SKILL_NAMES[sLabel] then
			entrymap[sLabel] = w;
		elseif LEGACY_TO_NEW[sLabel] then
			local sNew  = LEGACY_TO_NEW[sLabel];
			local nProf = DB.getValue(w.getDatabaseNode(), "prof", 0);
			if not legacymap[sNew] then legacymap[sNew] = { nodes = {}, maxprof = 0 }; end
			table.insert(legacymap[sNew].nodes, w.getDatabaseNode());
			if nProf > legacymap[sNew].maxprof then legacymap[sNew].maxprof = nProf; end
		else
			w.setCustom(true);
		end
	end

	-- Create or update all 26 standard skills.
	for _, tSkill in ipairs(SKILLS) do
		local tLeg = legacymap[tSkill.name];
		local nMigratedProf = tLeg and tLeg.maxprof or 0;

		local w = entrymap[tSkill.name];
		if not w then
			w = createWindow();
			if w then
				w.name.setValue(tSkill.name);
				w.stat.setValue(tSkill.stat);
				if nMigratedProf > 0 then
					DB.setValue(w.getDatabaseNode(), "prof", "number", nMigratedProf);
				end
			end
		else
			if w.stat.getValue() ~= tSkill.stat then
				w.stat.setValue(tSkill.stat);
			end
			if nMigratedProf > 0 then
				local nCur = DB.getValue(w.getDatabaseNode(), "prof", 0);
				if nMigratedProf > nCur then
					DB.setValue(w.getDatabaseNode(), "prof", "number", nMigratedProf);
				end
			end
		end
		if w then w.setCustom(false); end
	end

	-- Delete legacy nodes now that migration is complete.
	for _, tLeg in pairs(legacymap) do
		for _, nodeOld in ipairs(tLeg.nodes) do
			DB.deleteNode(nodeOld);
		end
	end
end
