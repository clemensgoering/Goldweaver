std = "lua51"
max_line_length = 240  -- data tables are kept on one line per entry
self = false
ignore = { "212/_.*", "213", "211/ADDON" }  -- unused args starting with _, unused loop vars, unused ADDON name from `local ADDON, ns = ...`

exclude_files = { "tools/tests/**" }

globals = {
  "Goldweaver", "GoldweaverDB", "GoldweaverCharDB", "GoldweaverBackupDB",
  "SLASH_GOLDWEAVER1", "SLASH_GOLDWEAVER2", "SlashCmdList",
}

read_globals = {
  -- Lua / WoW basics
  "DEFAULT_CHAT_FRAME", "CreateFrame", "C_Timer", "C_AddOns", "GetLocale", "GetBuildInfo", "GetTime", "time", "date",
  "issecretvalue", "InCombatLockdown", "hooksecurefunc", "UIParent", "GameTooltip", "WOW_PROJECT_ID",
  "UnitName", "UnitFullName", "UnitFactionGroup", "UnitClassBase", "UnitLevel", "GetNormalizedRealmName", "GetRealmName", "GetAutoCompleteRealms",
  "GetProfessions", "GetProfessionInfo", "GetMoney", "C_RestrictedActions", "C_ChatInfo",
  -- Namespaces
  "C_Item", "C_Spell", "C_Container", "C_TradeSkillUI", "C_AuctionHouse", "C_TooltipInfo", "C_Mail",
  "TooltipDataProcessor", "Enum", "Item",
  -- Legacy tradeskill / craft fallbacks (see Professions/Adapter.lua)
  "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillReagentInfo", "GetTradeSkillNumReagents",
  "GetTradeSkillItemLink", "GetTradeSkillRecipeLink", "GetTradeSkillLine", "GetTradeSkillTools", "DoTradeSkill",
  "GetNumCrafts", "GetCraftInfo", "GetCraftReagentInfo", "GetCraftNumReagents", "GetCraftItemLink", "DoCraft",
  -- Mail
  "SendMail", "GetInboxNumItems", "GetInboxHeaderInfo", "GetInboxInvoiceInfo", "TakeInboxItem", "AutoLootMailItem",
  "SendMailNameEditBox", "SendMailFrame", "MailFrame", "InboxFrame",
  -- Optional addons
  "Auctionator", "TSM_API", "Syndicator", "GatherMate2",
  -- Misc UI
  "BackdropTemplateMixin", "UISpecialFrames", "StaticPopup_Show", "StaticPopupDialogs",
  "Minimap", "GetCursorPosition", "tinsert", "CreateFrame", "GetMoney", "AuctionHouseFrame",
  "IsShiftKeyDown", "ItemRefTooltip", "BankFrame", "MailFrameTab2", "SendMailSubjectEditBox", "GetSendMailItem",
  "ATTACHMENTS_MAX_SEND", "GetNumLootItems", "GetLootSlotInfo", "GetLootSlotLink", "C_Map",
  "GetMerchantNumItems", "GetMerchantItemInfo", "GetMerchantItemLink", "UnitName", "unpack",
  "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceSkillReq", "GetTrainerServiceLevelReq",
  "GetTrainerServiceCost", "ERR_MAIL_TARGET_NOT_FOUND", "debugstack",
}
