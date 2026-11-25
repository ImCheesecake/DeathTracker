local _, ns = ...
local UI, R = ns.UI, ns.Recap

local system

local function fillToast(frame, alert)
    PlaySound(SOUNDKIT.UI_PROFESSIONS_NEW_RECIPE_LEARNED_TOAST)
    frame.Icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    frame.Icon:SetTexture(UI.ICON)
    frame.Title:SetText(alert.title)
    frame.Name:SetText(alert.label)
    frame.playRecap = alert.play
    if not frame.playsRecap then
        frame.playsRecap = true
        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        -- Blizzard's own click opens the professions window at the toast's recipe.
        frame:SetScript("OnClick", function(self, button, down)
            if AlertFrame_OnClick(self, button, down) then return end
            self:Hide()
            self.playRecap()
        end)
    end
    return true
end

function R.Alert(title, label, play)
    system = system or AlertFrame:AddQueuedAlertFrameSubSystem("NewRecipeLearnedAlertFrameTemplate", fillToast, 2, 6)
    system:AddAlert({ title = title, label = label, play = play })
end

function R.Toast(key) R.Alert("Monthly recap ready", R.PlayLabel(key), function() R.Play(key) end) end
