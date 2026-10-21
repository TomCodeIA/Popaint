--!strict
-- Popaint : fenêtre du cadeau quotidien (7 jours).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Ui = require(script.Parent:WaitForChild("Ui")) :: any
local State = require(script.Parent:WaitForChild("State")) :: any
local Hud = require(script.Parent:WaitForChild("Hud")) :: any

local Daily = {}

local t = Ui.t
local window: Frame
local cards: { Frame } = {}
local claimButton: TextButton
local dot: Frame
local autoOpened = false

local ICONS = { Coins = "💰", Boost = "⚡", Egg = "🥚", Companion = "⭐" }

local function rewardText(r: any): string
	if r.Kind == "Coins" then
		return t("D_Coins", { n = r.Amount })
	elseif r.Kind == "Boost" then
		return t("D_Boost", { n = math.floor(r.Seconds / 60) })
	elseif r.Kind == "Egg" then
		return t("D_Egg")
	end
	return t("D_Companion")
end

local function refresh(state: any)
	local daily = state.Daily or {}
	local day = daily.Day or 1
	local can = daily.CanClaim == true
	for i, card in cards do
		local stroke = card:FindFirstChildOfClass("UIStroke")
		local isToday = i == day
		if stroke then
			(stroke :: UIStroke).Thickness = if isToday then 6 else 3
			;(stroke :: UIStroke).Color = if isToday then Ui.Pink else Ui.Ink
		end
		card.BackgroundTransparency = if (i < day) or (i == day and not can) then 0.5 else 0
	end
	claimButton.Text = if can then t("Claim") else t("ComeBack")
	dot.Visible = can
end

function Daily.open()
	Ui.open(window)
	if State.current then
		refresh(State.current)
	end
end

function Daily.start()
	local gui = Hud.gui :: ScreenGui
	local content
	window, content = Ui.window(gui, "🎁 " .. t("DailyTitle"), Ui.Yellow, UDim2.fromOffset(760, 380))
	window.Name = "Daily"
	for i, r in Config.Daily do
		local card = Ui.frame(content, {
			Position = UDim2.new((i - 1) / 7, 4, 0, 0),
			Size = UDim2.new(1 / 7, -8, 0, 190),
			BackgroundColor3 = if i == 7 then Color3.fromRGB(255, 230, 120) else Ui.White,
			ZIndex = 12,
		})
		Ui.corner(card, UDim.new(0, 14))
		Ui.stroke(card, 3)
		Ui.label(card, t("Day", { n = i }), { Size = UDim2.new(1, -6, 0, 26), Position = UDim2.fromOffset(3, 6), ZIndex = 13 })
		Ui.label(card, ICONS[r.Kind] or "🎁", { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 40), ZIndex = 13 })
		Ui.label(card, rewardText(r), {
			Size = UDim2.new(1, -6, 0, 54),
			Position = UDim2.fromOffset(3, 112),
			TextColor3 = Ui.Ink,
			ZIndex = 13,
		})
		table.insert(cards, card)
	end
	claimButton = Ui.button(content, t("Claim"), Ui.Green, function()
		if State.current and State.current.Daily and State.current.Daily.CanClaim then
			State.action("ClaimDaily")
			Ui.close(window)
		end
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(300, 64),
		ZIndex = 12,
	})

	local button = Ui.button(Hud.leftBar, "🎁", Ui.Yellow, function()
		if window.Visible then
			Ui.close(window)
		else
			Daily.open()
		end
	end, { Name = "DailyButton", Size = UDim2.fromOffset(78, 78), LayoutOrder = 1 })
	dot = Ui.frame(button, {
		Position = UDim2.new(1, -18, 0, -6),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Ui.Red,
		Visible = false,
		ZIndex = 5,
	})
	Ui.corner(dot, UDim.new(1, 0))
	Ui.stroke(dot, 2)

	State.onChange(function(state: any)
		refresh(state)
		-- s'ouvre tout seul une fois, si le cadeau est dispo et que le didacticiel est fini
		if not autoOpened and state.Daily and state.Daily.CanClaim and state.Tutorial and state.Tutorial.Step == "Done" then
			autoOpened = true
			task.delay(2, Daily.open)
		end
	end)
end

return Daily
