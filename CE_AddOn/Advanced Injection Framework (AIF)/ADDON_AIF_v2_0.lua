-- ============================================================================
-- MBRKiNG Advanced Injection Framework (AIF) v2.0 Pro - BOOTSTRAPPER
-- ============================================================================
-- MIT License
-- Copyright (c) 2026 MBRKiNG
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
-- ============================================================================

_G.AIF = _G.AIF or {}

AIF.Config = {
  File = (os.getenv("APPDATA") or os.getenv("HOME") or "") .. "/MBRKiNG_CE_Settings.txt",
  Author = "MBRKiNG",
  Github = "https://github.com/MBRKiNG/CE-Tables",
  Forum  = "https://opencheattables.com/",
  Debug = true,
  PushAll = false,
  UseWildcards = true,
  UseComments = true,
  IncludeHeader = true,
  IncludeOriginalCode = true,
  UseModuleNamesInContext = true,
  AobSpaces = true,
  SmartAob = true,
  AobMinScan = 8,
  AobMaxScan = 48,
  LinesBefore = 50,
  LinesAfter = 50
}

function AIF.DebugLog(msg)
  if AIF.Config.Debug then print("[AIF-PRO] " .. tostring(msg)) end
end

function AIF.LoadSettings()
  local f = io.open(AIF.Config.File, "r")
  if f then
    for line in f:lines() do
      local k, v = line:match("^([^=]+)=(.*)$")
      if k and v then
        if k == "AUTHOR" then AIF.Config.Author = v
        elseif k == "GITHUB" then AIF.Config.Github = v
        elseif k == "FORUM" then AIF.Config.Forum = v
        elseif k == "DEBUG" then AIF.Config.Debug = (v == "true")
        elseif k == "PUSHALL" then AIF.Config.PushAll = (v == "true")
        elseif k == "USE_WILDCARDS" then AIF.Config.UseWildcards = (v == "true")
        elseif k == "USE_COMMENTS" then AIF.Config.UseComments = (v == "true")
        elseif k == "INCLUDE_HEADER" then AIF.Config.IncludeHeader = (v == "true")
        elseif k == "INCLUDE_ORIGINAL_CODE" then AIF.Config.IncludeOriginalCode = (v == "true")
        elseif k == "USE_MODULE_NAMES" then AIF.Config.UseModuleNamesInContext = (v == "true")
        elseif k == "AOB_SPACES" then AIF.Config.AobSpaces = (v == "true")
        elseif k == "SMART_AOB" then AIF.Config.SmartAob = (v == "true")
        elseif k == "AOB_MIN_SCAN" then AIF.Config.AobMinScan = tonumber(v) or 8
        elseif k == "AOB_MAX_SCAN" then AIF.Config.AobMaxScan = tonumber(v) or 48
        elseif k == "LINES_BEFORE" then AIF.Config.LinesBefore = tonumber(v) or 50
        elseif k == "LINES_AFTER" then AIF.Config.LinesAfter = tonumber(v) or 50
        end
      end
    end
    f:close()
  end
end

function AIF.SaveSettings(cfg)
  local f = io.open(AIF.Config.File, "w")
  if f then
    f:write("AUTHOR=" .. tostring(cfg.Author) .. "\nGITHUB=" .. tostring(cfg.Github) .. "\nFORUM=" .. tostring(cfg.Forum) .. "\n")
    f:write("DEBUG=" .. tostring(cfg.Debug) .. "\nPUSHALL=" .. tostring(cfg.PushAll) .. "\nUSE_WILDCARDS=" .. tostring(cfg.UseWildcards) .. "\n")
    f:write("USE_COMMENTS=" .. tostring(cfg.UseComments) .. "\nINCLUDE_HEADER=" .. tostring(cfg.IncludeHeader) .. "\nINCLUDE_ORIGINAL_CODE=" .. tostring(cfg.IncludeOriginalCode) .. "\n")
    f:write("USE_MODULE_NAMES=" .. tostring(cfg.UseModuleNamesInContext) .. "\n")
    f:write("AOB_SPACES=" .. tostring(cfg.AobSpaces) .. "\nSMART_AOB=" .. tostring(cfg.SmartAob) .. "\n")
    f:write("AOB_MIN_SCAN=" .. tostring(cfg.AobMinScan) .. "\nAOB_MAX_SCAN=" .. tostring(cfg.AobMaxScan) .. "\n")
    f:write("LINES_BEFORE=" .. tostring(cfg.LinesBefore) .. "\nLINES_AFTER=" .. tostring(cfg.LinesAfter) .. "\n")
    f:close()
    for k, v in pairs(cfg) do AIF.Config[k] = v end
  end
end

function AIF.ShowSettingsMenu()
  -- SINGLETON CHECK: Wenn das Fenster schon offen ist, anzeigen und in den Vordergrund bringen!
  if AIF.SettingsForm then
    AIF.SettingsForm.show()
    AIF.SettingsForm.bringToFront()
    return
  end

  local frm = createForm(true)
  AIF.SettingsForm = frm
  
  -- ECHTER SINGLETON: 1 = caHide. Fenster bleibt sicher im RAM und wird nur versteckt!
  frm.OnClose = function(sender)
    return 1 -- caHide
  end

  frm.Caption = "AIF v2.0 Pro - Configuration"; frm.Width = 450; frm.Height = 680; frm.Position = poScreenCenter; frm.BorderStyle = bsSingle
  local yPos = 20

  local lblAuth = createLabel(frm); lblAuth.Caption = "Author:"; lblAuth.Left = 20; lblAuth.Top = yPos
  local edtAuth = createEdit(frm); edtAuth.Text = AIF.Config.Author; edtAuth.Left = 150; edtAuth.Top = yPos; edtAuth.Width = 250
  yPos = yPos + 35

  local lblGit = createLabel(frm); lblGit.Caption = "GitHub:"; lblGit.Left = 20; lblGit.Top = yPos
  local edtGit = createEdit(frm); edtGit.Text = AIF.Config.Github; edtGit.Left = 150; edtGit.Top = yPos; edtGit.Width = 250
  yPos = yPos + 35

  local lblForum = createLabel(frm); lblForum.Caption = "Forum:"; lblForum.Left = 20; lblForum.Top = yPos
  local edtForum = createEdit(frm); edtForum.Text = AIF.Config.Forum; edtForum.Left = 150; edtForum.Top = yPos; edtForum.Width = 250
  yPos = yPos + 40

  local chkDebug = createCheckBox(frm); chkDebug.Caption = "Enable Debug Logs"; chkDebug.Checked = AIF.Config.Debug; chkDebug.Left = 20; chkDebug.Top = yPos; chkDebug.Width = 300; yPos = yPos + 30
  local chkPush = createCheckBox(frm); chkPush.Caption = "Push/Pop ALL Registers"; chkPush.Checked = AIF.Config.PushAll; chkPush.Left = 20; chkPush.Top = yPos; chkPush.Width = 300; yPos = yPos + 30
  local chkWildcard = createCheckBox(frm); chkWildcard.Caption = "Use Wildcards (*) for unregister/dealloc"; chkWildcard.Checked = AIF.Config.UseWildcards; chkWildcard.Left = 20; chkWildcard.Top = yPos; chkWildcard.Width = 350; yPos = yPos + 30
  local chkComments = createCheckBox(frm); chkComments.Caption = "Enable Script Comments"; chkComments.Checked = AIF.Config.UseComments; chkComments.Left = 20; chkComments.Top = yPos; chkComments.Width = 300; yPos = yPos + 30
  local chkHeader = createCheckBox(frm); chkHeader.Caption = "Include Script Header"; chkHeader.Checked = AIF.Config.IncludeHeader; chkHeader.Left = 20; chkHeader.Top = yPos; chkHeader.Width = 300; yPos = yPos + 30
  local chkOrigCode = createCheckBox(frm); chkOrigCode.Caption = "Include Original Code at bottom"; chkOrigCode.Checked = AIF.Config.IncludeOriginalCode; chkOrigCode.Left = 20; chkOrigCode.Top = yPos; chkOrigCode.Width = 300; yPos = yPos + 30
  local chkModNames = createCheckBox(frm); chkModNames.Caption = "Use Module Names in Original Code context"; chkModNames.Checked = AIF.Config.UseModuleNamesInContext; chkModNames.Left = 20; chkModNames.Top = yPos; chkModNames.Width = 380; yPos = yPos + 30
  local chkSpaces = createCheckBox(frm); chkSpaces.Caption = "Keep Spaces in generated AOB string"; chkSpaces.Checked = AIF.Config.AobSpaces; chkSpaces.Left = 20; chkSpaces.Top = yPos; chkSpaces.Width = 300; yPos = yPos + 30
  local chkSmartAOB = createCheckBox(frm); chkSmartAOB.Caption = "Use Smart AOB Scanner"; chkSmartAOB.Checked = AIF.Config.SmartAob; chkSmartAOB.Left = 20; chkSmartAOB.Top = yPos; chkSmartAOB.Width = 350; yPos = yPos + 35

  local lblMinAOB = createLabel(frm); lblMinAOB.Caption = "AOB Min Scan:"; lblMinAOB.Left = 20; lblMinAOB.Top = yPos
  local edtMinAOB = createEdit(frm); edtMinAOB.Text = tostring(AIF.Config.AobMinScan); edtMinAOB.Left = 110; edtMinAOB.Top = yPos; edtMinAOB.Width = 40
  local lblMaxAOB = createLabel(frm); lblMaxAOB.Caption = "AOB Max Scan:"; lblMaxAOB.Left = 170; lblMaxAOB.Top = yPos
  local edtMaxAOB = createEdit(frm); edtMaxAOB.Text = tostring(AIF.Config.AobMaxScan); edtMaxAOB.Left = 260; edtMaxAOB.Top = yPos; edtMaxAOB.Width = 40; yPos = yPos + 35

  local lblBefore = createLabel(frm); lblBefore.Caption = "Context Lines Before:"; lblBefore.Left = 20; lblBefore.Top = yPos; lblBefore.Width = 150
  local edtBefore = createEdit(frm); edtBefore.Text = tostring(AIF.Config.LinesBefore); edtBefore.Left = 180; edtBefore.Top = yPos; edtBefore.Width = 50; yPos = yPos + 30
  local lblAfter = createLabel(frm); lblAfter.Caption = "Context Lines After:"; lblAfter.Left = 20; lblAfter.Top = yPos; lblAfter.Width = 150
  local edtAfter = createEdit(frm); edtAfter.Text = tostring(AIF.Config.LinesAfter); edtAfter.Left = 180; edtAfter.Top = yPos; edtAfter.Width = 50; yPos = yPos + 40

  local btnSave = createButton(frm); btnSave.Caption = "Save Settings"; btnSave.Left = 130; btnSave.Top = yPos; btnSave.Width = 180
  btnSave.OnClick = function()
    local newCfg = {
      Author = edtAuth.Text, Github = edtGit.Text, Forum = edtForum.Text,
      Debug = chkDebug.Checked, PushAll = chkPush.Checked, UseWildcards = chkWildcard.Checked,
      UseComments = chkComments.Checked, IncludeHeader = chkHeader.Checked, IncludeOriginalCode = chkOrigCode.Checked,
      UseModuleNamesInContext = chkModNames.Checked,
      AobSpaces = chkSpaces.Checked, SmartAob = chkSmartAOB.Checked,
      AobMinScan = tonumber(edtMinAOB.Text) or 8, AobMaxScan = tonumber(edtMaxAOB.Text) or 48,
      LinesBefore = tonumber(edtBefore.Text) or 50, LinesAfter = tonumber(edtAfter.Text) or 50
    }
    AIF.SaveSettings(newCfg)
    frm.hide() -- SICHER: Fenster nur verstecken, niemals zerstören!
    showMessage("Configuration saved successfully.")
  end
end

-- ============================================================================
-- 4. Main Menu Injection
-- ============================================================================
local function InjectMainMenu()
  local mf = getMainForm()
  if not mf or not mf.Menu then return end
  
  for i = mf.Menu.Items.Count - 1, 0, -1 do
    local item = mf.Menu.Items[i]
    if item and item.Caption == "AIF Pro" then
      item.destroy()
    end
  end
  
  local topMenu = createMenuItem(mf.Menu)
  topMenu.Caption = "AIF Pro"
  
  local settingsItem = createMenuItem(topMenu)
  settingsItem.Caption = "Configuration Settings"
  settingsItem.OnClick = AIF.ShowSettingsMenu
  topMenu.add(settingsItem)
  
  local patcherItem = createMenuItem(topMenu)
  patcherItem.Caption = "PE Cave Injector"
  patcherItem.OnClick = function()
    if _G.AIF and _G.AIF.FilePatcher then
      _G.AIF.FilePatcher.ShowGUI()
    else
      showMessage("PE Cave Injector module not loaded!")
    end
  end
  topMenu.add(patcherItem)
  
  local reloadItem = createMenuItem(topMenu)
  reloadItem.Caption = "Reload AIF Framework"
  reloadItem.OnClick = function()
    if _G.reload_aif then _G.reload_aif() end
  end
  topMenu.add(reloadItem)
  
  mf.Menu.Items.add(topMenu)
end

-- ============================================================================
-- 5. Direct & Bulletproof Auto Assembler Menu Integration
-- ============================================================================
local function InjectTranspilerIntoForm(form)
  if not form or form.ClassName ~= 'TfrmAutoInject' then return end

  local waitTimer = createTimer(form, false)
  waitTimer.Interval = 150

  waitTimer.OnTimer = function(timer)
    if form.Menu and form.Menu.Items.Count > 0 then
      timer.destroy()
      
      -- Index 0 is always the first top-level menu dropdown ("File" / "Datei")
      local fileMenu = form.Menu.Items[0]
      if fileMenu then
        -- Check if already added
        local alreadyInjected = false
        for c = 0, fileMenu.Count - 1 do
          if fileMenu[c].Caption and fileMenu[c].Caption:find("Convert to Lua") then
            alreadyInjected = true
            break
          end
        end

        if not alreadyInjected then
          -- Find position right after "Assign to current cheat table" if present, otherwise append
          local insertIdx = -1
          if form.Assigntocurrentcheattable1 then
            -- Find its index in the fileMenu
            for c = 0, fileMenu.Count - 1 do
              if fileMenu[c] == form.Assigntocurrentcheattable1 then
                insertIdx = c + 1
                break
              end
            end
          end

          local function getAAEditorText()
            if form.Assemblescreen and form.Assemblescreen.Lines then
              return form.Assemblescreen.Lines.Text
            end
            return ""
          end

          local function setAAEditorText(newText)
            if form.Assemblescreen and form.Assemblescreen.Lines then
              form.Assemblescreen.Lines.Text = newText
            end
          end

          local itemConvertOnly = createMenuItem(fileMenu)
          itemConvertOnly.Caption = "Convert current AA Code to Lua"
          itemConvertOnly.OnClick = function()
            local code = getAAEditorText()
            if code ~= "" and _G.AIF and _G.AIF.LuaTranspiler then
              local newCode = _G.AIF.LuaTranspiler.ConvertAAToLua(code, "AA_Script")
              -- Erfolgsmeldung NUR ausgeben, wenn sich der Code auch wirklich verändert hat
              if newCode and newCode ~= code then
                  setAAEditorText(newCode)
                  showMessage("Successfully converted Auto Assembler code to Lua!")
              end
            else
              showMessage("Auto Assembler editor is empty or Transpiler missing.")
            end
          end

          local itemConvertAssign = createMenuItem(fileMenu)
          itemConvertAssign.Caption = "Convert to Lua and assign to cheat table"
          itemConvertAssign.OnClick = function()
            local code = getAAEditorText()
            if code ~= "" and _G.AIF and _G.AIF.LuaTranspiler then
              local luaCode = _G.AIF.LuaTranspiler.ConvertAAToLua(code, "Table_Script")
              -- Erfolgsmeldung und Cheat Table Zuweisung NUR ausführen, wenn Konvertierung stattfand
              if luaCode and luaCode ~= code then
                  local al = getAddressList()
                  if al then
                    local memrec = al.createMemoryRecord()
                    memrec.Description = "Transpiled Lua Script"
                    memrec.Type = vtAutoAssembler
                    memrec.Script = luaCode
                    showMessage("Lua script successfully generated and assigned to cheat table!")
                  else
                    showMessage("Could not access Cheat Table address list.")
                  end
              end
            else
              showMessage("Auto Assembler editor is empty or Transpiler missing.")
            end
          end

          if insertIdx ~= -1 and insertIdx <= fileMenu.Count then
            fileMenu.insert(insertIdx, itemConvertOnly)
            fileMenu.insert(insertIdx + 1, itemConvertAssign)
          else
            fileMenu.add(itemConvertOnly)
            fileMenu.add(itemConvertAssign)
          end
        end
      end
    end
  end

  waitTimer.Enabled = true
end

registerFormAddNotification(InjectTranspilerIntoForm)

-- ============================================================================
-- 6. Module Bootstrapper & Reload
-- ============================================================================
local function BootstrapModules()
  AIF.DebugLog("Initializing module loading sequence...")
  local ceDir = getCheatEngineDir()
  if ceDir then
      package.path = package.path .. ";" .. ceDir .. "autorun/?.lua;" .. ceDir .. "autorun/?/init.lua"
      package.path = package.path .. ";" .. ceDir .. "autorun\\?.lua;" .. ceDir .. "autorun\\?\\init.lua"
  end

  local modules = {
    "AIF.AIF_Decoder",
    "AIF.AIF_Relocator",
    "AIF.AIF_ABI",
    "AIF.AIF_Memory",
    "AIF.AIF_Scanner",
    "AIF.AIF_ScannerARM",
    "AIF.AIF_Validator",
    "AIF.AIF_MonoIL2CPP",
    "AIF.AIF_LuaTranspiler",
    "AIF.AIF_FilePatcher",
    "AIF.AIF_Utilities", 
    "AIF.AIF_Tests",     
    "AIF.AIF_Templates",
    "AIF.AIF_TemplatesARM"
  }
  
  for _, mod in ipairs(modules) do
    package.loaded[mod] = nil
  end
  
  for _, mod in ipairs(modules) do
    local status, err = pcall(require, mod)
    if status then
      AIF.DebugLog("Module loaded successfully: " .. mod)
    else
      AIF.DebugLog("CRITICAL Module Error [" .. mod .. "]: " .. tostring(err))
    end
  end
end

function _G.reload_aif()
  AIF.DebugLog("--- RELOADING AIF PRO FRAMEWORK ---")
  BootstrapModules()
  InjectMainMenu()
  AIF.DebugLog("--- RELOAD COMPLETE ---")
  showMessage("AIF Pro Framework reloaded successfully!")
end

-- ============================================================================
-- Initialization
-- ============================================================================
AIF.LoadSettings()
InjectMainMenu()
BootstrapModules()

AIF.DebugLog("Bootstrapper initialization complete.")
