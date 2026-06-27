--
-- Steadfast5e - Gritty Realism Rest
-- Registered as global "GrittyRealismRest" via loader.xml.
--
-- Overrides rest duration, long-rest HP recovery, and long-rest HD recovery.
-- Optional CON/Endurance check gates how many HD are recovered after a long rest.
-- Integrates with Steadfast5e - Location System when installed.
--

-- ── Constants ────────────────────────────────────────────────────────────────

-- FGU rest duration is in rounds (10 rounds/min × 60 min = 600 rounds/hour).
local ROUND_HOUR = 600;
local ROUND_DAY  = ROUND_HOUR * 24;

local SHORT_DUR = {
	["raw"]      = ROUND_HOUR,      -- 1 hour  (RAW)
	["extended"] = ROUND_HOUR * 4,  -- 4 hours
	["overnight"]= ROUND_HOUR * 8,  -- 8 hours
};
local LONG_DUR = {
	["raw"]    = ROUND_HOUR * 8,    -- 8 hours (RAW)
	["gritty1"]= ROUND_DAY,        -- 1 day
	["gritty3"]= ROUND_DAY * 3,    -- 3 days
	["gritty7"]= ROUND_DAY * 7,    -- 7 days
};

local HD_PASS_DEFAULT = "half";
local HD_FAIL_DEFAULT = "quarter";
local HD_DC_DEFAULT   = "dc15";

-- ── Option keys ──────────────────────────────────────────────────────────────

local OPT_SHORT_DUR  = "GRR_SHORT_DUR";
local OPT_LONG_DUR   = "GRR_LONG_DUR";
local OPT_HD_CHECK   = "GRR_HD_CHECK";
local OPT_HD_DC      = "GRR_HD_DC";
local OPT_HD_PASS    = "GRR_HD_PASS";
local OPT_HD_FAIL    = "GRR_HD_FAIL";
local OPT_HP_REC     = "GRR_HP_REC";
local OPT_SCOPE_PC   = "GRR_SCOPE_PC";
local OPT_SCOPE_NPC  = "GRR_SCOPE_NPC";
local OPT_SCOPE_MON  = "GRR_SCOPE_MON";

-- ── State ────────────────────────────────────────────────────────────────────

local _fnOrigOnActorRest;

-- ── Init ─────────────────────────────────────────────────────────────────────

function onInit()
	registerOptions();
	applyDurations();

	_fnOrigOnActorRest = GameManager.getFunction("onActorRest");
	GameManager.setFunction("onActorRest", GrittyRealismRest.onActorRest);

	OptionsManager.registerCallback(OPT_SHORT_DUR, GrittyRealismRest.applyDurations);
	OptionsManager.registerCallback(OPT_LONG_DUR,  GrittyRealismRest.applyDurations);
end

-- ── Option registration ──────────────────────────────────────────────────────

function registerOptions()
	-- Short rest duration (3-way)
	OptionsManager.registerOptionData({
		sKey = OPT_SHORT_DUR, sGroupRes = "option_header_grr",
		tCustom = {
			baselabelres = "option_val_GRR_SHORT_DUR_raw",    baseval = "raw",
			labelsres    = "option_val_GRR_SHORT_DUR_extended,option_val_GRR_SHORT_DUR_overnight",
			values       = "extended,overnight",
			default      = "raw",
		},
	});

	-- Long rest duration (4-way)
	OptionsManager.registerOptionData({
		sKey = OPT_LONG_DUR, sGroupRes = "option_header_grr",
		tCustom = {
			baselabelres = "option_val_GRR_LONG_DUR_raw",    baseval = "raw",
			labelsres    = "option_val_GRR_LONG_DUR_gritty1,option_val_GRR_LONG_DUR_gritty3,option_val_GRR_LONG_DUR_gritty7",
			values       = "gritty1,gritty3,gritty7",
			default      = "raw",
		},
	});

	-- HD recovery check toggle
	OptionsManager.registerOptionData({
		sKey = OPT_HD_CHECK, sGroupRes = "option_header_grr",
		tCustom = { default = "on" },
	});

	-- HD recovery check DC (4-way)
	OptionsManager.registerOptionData({
		sKey = OPT_HD_DC, sGroupRes = "option_header_grr",
		tCustom = {
			baselabelres = "option_val_GRR_HD_DC_dc15",    baseval = "dc15",
			labelsres    = "option_val_GRR_HD_DC_dc10,option_val_GRR_HD_DC_dc20,option_val_GRR_HD_DC_manual",
			values       = "dc10,dc20,manual",
			default      = "dc15",
		},
	});

	-- HD recovery check pass result (3-way)
	OptionsManager.registerOptionData({
		sKey = OPT_HD_PASS, sGroupRes = "option_header_grr",
		tCustom = {
			baselabelres = "option_val_GRR_HD_PASS_half",    baseval = "half",
			labelsres    = "option_val_GRR_HD_PASS_full,option_val_GRR_HD_PASS_quarter",
			values       = "full,quarter",
			default      = "half",
		},
	});

	-- HD recovery check fail result (3-way)
	OptionsManager.registerOptionData({
		sKey = OPT_HD_FAIL, sGroupRes = "option_header_grr",
		tCustom = {
			baselabelres = "option_val_GRR_HD_FAIL_quarter",  baseval = "quarter",
			labelsres    = "option_val_GRR_HD_FAIL_half,option_val_GRR_HD_FAIL_zero",
			values       = "half,zero",
			default      = "quarter",
		},
	});

	-- Long rest HP recovery (4-way)
	OptionsManager.registerOptionData({
		sKey = OPT_HP_REC, sGroupRes = "option_header_grr",
		tCustom = {
			baselabelres = "option_val_GRR_HP_REC_full",    baseval = "full",
			labelsres    = "option_val_GRR_HP_REC_threequarters,option_val_GRR_HP_REC_half,option_val_GRR_HP_REC_quarter",
			values       = "threequarters,half,quarter",
			default      = "full",
		},
	});

	-- Scope toggles
	OptionsManager.registerOptionData({
		sKey = OPT_SCOPE_PC, sGroupRes = "option_header_grr",
		tCustom = { default = "on" },
	});
	OptionsManager.registerOptionData({
		sKey = OPT_SCOPE_NPC, sGroupRes = "option_header_grr",
		tCustom = { default = "on" },
	});
	OptionsManager.registerOptionData({
		sKey = OPT_SCOPE_MON, sGroupRes = "option_header_grr",
		tCustom = { default = "on" },
	});
end

-- ── Duration ─────────────────────────────────────────────────────────────────

function applyDurations()
	local sShort = OptionsManager.getOption(OPT_SHORT_DUR) or "raw";
	local sLong  = OptionsManager.getOption(OPT_LONG_DUR)  or "raw";
	CombatManager.setRestDuration("short", SHORT_DUR[sShort] or SHORT_DUR["raw"]);
	CombatManager.setRestDuration("long",  LONG_DUR[sLong]   or LONG_DUR["raw"]);
end

-- ── Scope check ──────────────────────────────────────────────────────────────

local function isInScope(rActor)
	if ActorManager.isPC(rActor) then
		return OptionsManager.isOption(OPT_SCOPE_PC, "on");
	end
	-- NPC or Monster: distinguish by whether it has a charsheet (companion/hireling) or is a CT monster
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if nodeActor and DB.getPath(nodeActor):find("^charsheet%.") then
		return OptionsManager.isOption(OPT_SCOPE_NPC, "on");
	end
	return OptionsManager.isOption(OPT_SCOPE_MON, "on");
end

-- ── Location System integration ───────────────────────────────────────────────

local function getLocationOverride(sKey)
	local LS = _G["S5E_LocationSystem"];
	if LS and LS.isActive and LS.isActive() and LS.getOverride then
		return LS.getOverride(sKey);
	end
	return nil;
end

-- ── HD state helpers ─────────────────────────────────────────────────────────

local function captureHDState(nodeChar)
	local tState = {};
	for _, vClass in ipairs(DB.getChildList(nodeChar, "classes")) do
		tState[DB.getPath(vClass)] = DB.getValue(vClass, "hdused", 0);
	end
	return tState;
end

local function restoreHDState(nodeChar, tState)
	for _, vClass in ipairs(DB.getChildList(nodeChar, "classes")) do
		local sPath = DB.getPath(vClass);
		if tState[sPath] ~= nil then
			DB.setValue(vClass, "hdused", "number", tState[sPath]);
		end
	end
end

local function recoverHD(nodeChar, nRecover)
	if nRecover <= 0 then return; end

	local nHDUsed = 0;
	for _, vClass in ipairs(DB.getChildList(nodeChar, "classes")) do
		nHDUsed = nHDUsed + DB.getValue(vClass, "hdused", 0);
	end

	if nRecover >= nHDUsed then
		for _, vClass in ipairs(DB.getChildList(nodeChar, "classes")) do
			DB.setValue(vClass, "hdused", "number", 0);
		end
		return;
	end

	-- Recover from the largest die first (matches FGU default behaviour)
	while nRecover > 0 do
		local nodeMax, nMaxSides, nMaxUsed = nil, 0, 0;
		for _, vClass in ipairs(DB.getChildList(nodeChar, "classes")) do
			local nUsed = DB.getValue(vClass, "hdused", 0);
			if nUsed > 0 then
				local aDice = DB.getValue(vClass, "hddie", {});
				if #aDice > 0 then
					local nSides = tonumber(aDice[1]:sub(2)) or 0;
					if nSides > nMaxSides then
						nodeMax, nMaxSides, nMaxUsed = vClass, nSides, nUsed;
					end
				end
			end
		end
		if not nodeMax then break; end

		if nRecover >= nMaxUsed then
			DB.setValue(nodeMax, "hdused", "number", 0);
			nRecover = nRecover - nMaxUsed;
		else
			DB.setValue(nodeMax, "hdused", "number", nMaxUsed - nRecover);
			nRecover = 0;
		end
	end
end

local function hdFractionAmount(nTotal, sFraction)
	if sFraction == "full"    then return nTotal; end
	if sFraction == "half"    then return math.max(math.floor(nTotal / 2), 1); end
	if sFraction == "quarter" then return math.max(math.floor(nTotal / 4), 1); end
	if sFraction == "zero"    then return 0; end
	return math.max(math.floor(nTotal / 2), 1);
end

local function getCheckDC()
	local sDC = OptionsManager.getOption(OPT_HD_DC) or HD_DC_DEFAULT;
	if sDC == "dc10" then return 10; end
	if sDC == "dc20" then return 20; end
	if sDC == "manual" then
		-- Read from campaign DB if GM has set a manual value
		return DB.getValue("campaign.grr_manual_dc", 15);
	end
	return 15; -- dc15 default
end

-- ── CON / Endurance check modifier ───────────────────────────────────────────

local function getCheckMod(rActor)
	local nodeActor = ActorManager.getCreatureNode(rActor);
	local nConScore = DB.getValue(nodeActor, "abilities.constitution.score", 10);
	local nMod = math.floor((nConScore - 10) / 2);

	-- If Expanded Skills is loaded, add Endurance proficiency bonus if proficient
	if _G["ExpandedSkillsManager"] then
		for _, nodeSkill in ipairs(DB.getChildList(nodeActor, "skilllist")) do
			if DB.getValue(nodeSkill, "name", "") == "Endurance" then
				local nProf     = DB.getValue(nodeSkill, "prof", 0);
				local nProfBonus = DB.getValue(nodeActor, "profbonus", 2);
				nMod = nMod + math.floor(nProf * nProfBonus);
				break;
			end
		end
	end

	return nMod;
end

-- ── Long rest HP recovery ────────────────────────────────────────────────────

local function applyLongRestHP(rActor)
	local sRecovery = getLocationOverride("hp_recovery")
	              or OptionsManager.getOption(OPT_HP_REC)
	              or "full";

	if sRecovery == "full" then return; end  -- original already restored full HP

	local nMaxHP = GameManager.getRecordFieldValue(rActor, "hptotal", 0);
	if nMaxHP <= 0 then return; end

	local nFraction;
	if sRecovery == "threequarters" then nFraction = 0.75;
	elseif sRecovery == "half"      then nFraction = 0.5;
	elseif sRecovery == "quarter"   then nFraction = 0.25;
	else return; end

	local nRestore  = math.ceil(nMaxHP * nFraction);
	local nWounds   = math.max(0, nMaxHP - nRestore);
	GameManager.setRecordFieldValue(rActor, "wounds", "number", nWounds);

	local sLabel = sRecovery == "threequarters" and "3/4" or sRecovery;
	ChatManager.Message(
		string.format(Interface.getString("grr_msg_hp_recovery"),
			ActorManager.getDisplayName(rActor), nRestore, nMaxHP, sLabel),
		true, rActor
	);
end

-- ── Long rest HD recovery ────────────────────────────────────────────────────

local function applyLongRestHD(rActor, tHDStateBefore)
	if not OptionsManager.isOption(OPT_HD_CHECK, "on") then
		return;  -- check disabled; keep FGU's default HD recovery
	end

	local nodeChar = ActorManager.getCreatureNode(rActor);
	local nHDUsed, nHDTotal = CharManager.getClassHDUsage(nodeChar);

	if nHDUsed == 0 then
		ChatManager.Message(
			string.format(Interface.getString("grr_msg_hd_check_skip"),
				ActorManager.getDisplayName(rActor)),
			true, rActor
		);
		return;
	end

	-- Restore pre-rest HD state (undo the original recovery) so we control it
	restoreHDState(nodeChar, tHDStateBefore);

	-- Roll CON (or Endurance) check
	local nDC  = getLocationOverride("hd_check_dc") or getCheckDC();
	local nMod = getCheckMod(rActor);
	local nDie = math.random(1, 20);
	local nTotal = nDie + nMod;
	local bPass = (nTotal >= nDC);

	local sPassResult = getLocationOverride("hd_pass_result")
	                 or OptionsManager.getOption(OPT_HD_PASS)
	                 or HD_PASS_DEFAULT;
	local sFailResult = getLocationOverride("hd_fail_result")
	                 or OptionsManager.getOption(OPT_HD_FAIL)
	                 or HD_FAIL_DEFAULT;

	local sResult  = bPass and sPassResult or sFailResult;
	local nRecover = hdFractionAmount(nHDTotal, sResult);

	recoverHD(nodeChar, nRecover);

	local sModStr = (nMod >= 0) and ("+" .. nMod) or tostring(nMod);
	ChatManager.Message(
		string.format(Interface.getString("grr_msg_hd_check"),
			ActorManager.getDisplayName(rActor),
			sModStr, nTotal, nDC,
			bPass and "Pass" or "Fail",
			nRecover, nHDTotal),
		true, rActor
	);
end

-- ── Main hook ────────────────────────────────────────────────────────────────

function onActorRest(rActor, sRestType)
	if not isInScope(rActor) then
		if _fnOrigOnActorRest then return _fnOrigOnActorRest(rActor, sRestType); end
		return false;
	end

	-- Capture HD state before the original runs (for long rest HD override)
	local tHDStateBefore;
	if sRestType == "long" and ActorManager.isPC(rActor) then
		local nodeChar = ActorManager.getCreatureNode(rActor);
		tHDStateBefore = captureHDState(nodeChar);
	end

	-- Run the original (handles powers, exhaustion, conditions, FGU-default HD/HP)
	local bResult = false;
	if _fnOrigOnActorRest then
		bResult = _fnOrigOnActorRest(rActor, sRestType);
	else
		bResult = true;
	end
	if not bResult then return false; end

	-- Apply GRR overrides for long rest
	if sRestType == "long" then
		applyLongRestHP(rActor);
		if ActorManager.isPC(rActor) and tHDStateBefore then
			applyLongRestHD(rActor, tHDStateBefore);
		end
	end

	return true;
end
