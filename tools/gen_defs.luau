-- Génère un fichier de types Roblox pour luau-lsp à partir de la base de réflexion de Lune
-- (classes, propriétés, enums), complété à la main avec les méthodes/événements utilisés.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local db = roblox.getReflectionDatabase()

local out = {}
local function emit(s)
	table.insert(out, s)
end

local KEYWORDS = {
	["and"]=1,["break"]=1,["do"]=1,["else"]=1,["elseif"]=1,["end"]=1,["false"]=1,["for"]=1,["function"]=1,
	["if"]=1,["in"]=1,["local"]=1,["nil"]=1,["not"]=1,["or"]=1,["repeat"]=1,["return"]=1,["then"]=1,
	["true"]=1,["until"]=1,["while"]=1,["continue"]=1,["type"]=1,["export"]=1,
}
local function ident(s)
	return string.match(s, "^[%a_][%w_]*$") ~= nil and not KEYWORDS[s]
end

---------------------------------------------------------------- datatypes & globals (à la main)
emit([[
type RBXScriptConnection = { Connected: boolean, Disconnect: (self: any) -> () }
type RBXScriptSignal<T...> = {
	Connect: (self: any, callback: (T...) -> ()) -> RBXScriptConnection,
	Once: (self: any, callback: (T...) -> ()) -> RBXScriptConnection,
	Wait: (self: any) -> T...,
}

declare class EnumItem
	Name: string
	Value: number
end
declare class Enum
	function GetEnumItems(self): { EnumItem }
end

declare class Vector3
	X: number
	Y: number
	Z: number
	Magnitude: number
	Unit: Vector3
	function __add(self, other: Vector3): Vector3
	function __sub(self, other: Vector3): Vector3
	function __mul(self, other: Vector3 | number): Vector3
	function __div(self, other: Vector3 | number): Vector3
	function __unm(self): Vector3
	function Dot(self, other: Vector3): number
	function Cross(self, other: Vector3): Vector3
	function Lerp(self, goal: Vector3, alpha: number): Vector3
end
declare Vector3: {
	new: (x: number?, y: number?, z: number?) -> Vector3,
	zero: Vector3,
	one: Vector3,
	xAxis: Vector3,
	yAxis: Vector3,
	zAxis: Vector3,
}

declare class Vector2
	X: number
	Y: number
	Magnitude: number
	Unit: Vector2
	function __add(self, other: Vector2): Vector2
	function __sub(self, other: Vector2): Vector2
	function __mul(self, other: Vector2 | number): Vector2
	function __div(self, other: Vector2 | number): Vector2
end
declare Vector2: { new: (x: number?, y: number?) -> Vector2, zero: Vector2, one: Vector2 }

declare class CFrame
	Position: Vector3
	X: number
	Y: number
	Z: number
	LookVector: Vector3
	RightVector: Vector3
	UpVector: Vector3
	function __mul(self, other: CFrame): CFrame
	function __mul(self, other: Vector3): Vector3
	function __add(self, other: Vector3): CFrame
	function __sub(self, other: Vector3): CFrame
	function Inverse(self): CFrame
	function Lerp(self, goal: CFrame, alpha: number): CFrame
	function ToWorldSpace(self, cf: CFrame): CFrame
	function ToObjectSpace(self, cf: CFrame): CFrame
	function PointToWorldSpace(self, v: Vector3): Vector3
	function PointToObjectSpace(self, v: Vector3): Vector3
	function VectorToWorldSpace(self, v: Vector3): Vector3
	function VectorToObjectSpace(self, v: Vector3): Vector3
end
declare CFrame: {
	new: ((x: number?, y: number?, z: number?) -> CFrame) & ((pos: Vector3) -> CFrame) & ((pos: Vector3, lookAt: Vector3) -> CFrame),
	Angles: (rx: number, ry: number, rz: number) -> CFrame,
	fromEulerAnglesXYZ: (rx: number, ry: number, rz: number) -> CFrame,
	lookAt: (at: Vector3, lookAt: Vector3, up: Vector3?) -> CFrame,
	identity: CFrame,
}

declare class Color3
	R: number
	G: number
	B: number
	function Lerp(self, goal: Color3, alpha: number): Color3
	function ToHSV(self): (number, number, number)
end
declare Color3: {
	new: (r: number?, g: number?, b: number?) -> Color3,
	fromRGB: (r: number?, g: number?, b: number?) -> Color3,
	fromHSV: (h: number, s: number, v: number) -> Color3,
	fromHex: (hex: string) -> Color3,
}

declare class BrickColor
	Name: string
	Color: Color3
end
declare BrickColor: { new: (name: string) -> BrickColor }

declare class UDim
	Scale: number
	Offset: number
end
declare UDim: { new: (scale: number?, offset: number?) -> UDim }

declare class UDim2
	X: UDim
	Y: UDim
	Width: UDim
	Height: UDim
	function __add(self, other: UDim2): UDim2
	function __sub(self, other: UDim2): UDim2
	function Lerp(self, goal: UDim2, alpha: number): UDim2
end
declare UDim2: {
	new: (xs: number?, xo: number?, ys: number?, yo: number?) -> UDim2,
	fromScale: (x: number?, y: number?) -> UDim2,
	fromOffset: (x: number?, y: number?) -> UDim2,
}

declare class NumberRange
	Min: number
	Max: number
end
declare NumberRange: { new: (min: number, max: number?) -> NumberRange }

declare class NumberSequenceKeypoint
	Time: number
	Value: number
	Envelope: number
end
declare NumberSequenceKeypoint: { new: (time: number, value: number, envelope: number?) -> NumberSequenceKeypoint }
declare class NumberSequence
	Keypoints: { NumberSequenceKeypoint }
end
declare NumberSequence: {
	new: ((n: number) -> NumberSequence) & ((n0: number, n1: number) -> NumberSequence) & ((keypoints: { NumberSequenceKeypoint }) -> NumberSequence),
}

declare class ColorSequenceKeypoint
	Time: number
	Value: Color3
end
declare ColorSequenceKeypoint: { new: (time: number, color: Color3) -> ColorSequenceKeypoint }
declare class ColorSequence
	Keypoints: { ColorSequenceKeypoint }
end
declare ColorSequence: {
	new: ((c: Color3) -> ColorSequence) & ((c0: Color3, c1: Color3) -> ColorSequence) & ((keypoints: { ColorSequenceKeypoint }) -> ColorSequence),
}

declare class Ray
	Origin: Vector3
	Direction: Vector3
	Unit: Ray
end
declare Ray: { new: (origin: Vector3, direction: Vector3) -> Ray }

declare class TweenInfo
	Time: number
end
declare TweenInfo: {
	new: (time: number?, style: EnumEasingStyle?, direction: EnumEasingDirection?, repeatCount: number?, reverses: boolean?, delay: number?) -> TweenInfo,
}

declare class Random
	function NextNumber(self, min: number?, max: number?): number
	function NextInteger(self, min: number, max: number): number
end
declare Random: { new: (seed: number?) -> Random }

declare class Rect
	Width: number
	Height: number
end
declare class Font
	Family: string
end
declare class PhysicalProperties
	Density: number
end
declare class Faces
	Top: boolean
end
declare class Axes
	X: boolean
end
declare class Region3int16
	Min: any
end
declare class Vector3int16
	X: number
end
]])

---------------------------------------------------------------- enums
local enumNames = db:GetEnumNames()
table.sort(enumNames)
for _, en in enumNames do
	emit(("declare class Enum%s extends EnumItem end"):format(en))
end
for _, en in enumNames do
	emit(("declare class Enum%s_INTERNAL extends Enum"):format(en))
	local items = db:GetEnum(en).Items
	local names = {}
	for item in items do
		table.insert(names, item)
	end
	table.sort(names)
	for _, item in names do
		if ident(item) then
			emit(("\t%s: Enum%s"):format(item, en))
		end
	end
	emit("end")
end
emit("declare Enum: {")
for _, en in enumNames do
	emit(("\t%s: Enum%s_INTERNAL,"):format(en, en))
end
emit("}")

---------------------------------------------------------------- classes
local DT = {
	Bool = "boolean", Float32 = "number", Float64 = "number", Int32 = "number", Int64 = "number",
	String = "string", Content = "string", BinaryString = "string", Color3uint8 = "Color3",
	OptionalCFrame = "CFrame?", Ref = "Instance?",
	Vector3 = "Vector3", Vector2 = "Vector2", CFrame = "CFrame", Color3 = "Color3", UDim = "UDim", UDim2 = "UDim2",
	NumberRange = "NumberRange", NumberSequence = "NumberSequence", ColorSequence = "ColorSequence",
	BrickColor = "BrickColor", Ray = "Ray", Rect = "Rect", Font = "Font", PhysicalProperties = "PhysicalProperties",
	Faces = "Faces", Axes = "Axes", Region3int16 = "Region3int16", Vector3int16 = "Vector3int16",
}

-- Membres ajoutés/remplacés à la main (méthodes, événements, types plus précis)
local EXTRA = {
	Instance = [[
	Parent: Instance?
	function FindFirstChild(self, name: string, recursive: boolean?): Instance?
	function FindFirstChildOfClass(self, className: string): Instance?
	function FindFirstChildWhichIsA(self, className: string, recursive: boolean?): Instance?
	function FindFirstAncestor(self, name: string): Instance?
	function WaitForChild(self, name: string, timeout: number?): Instance
	function GetChildren(self): { Instance }
	function GetDescendants(self): { Instance }
	function IsA(self, className: string): boolean
	function IsDescendantOf(self, ancestor: Instance): boolean
	function Destroy(self): ()
	function ClearAllChildren(self): ()
	function Clone(self): Instance
	function GetFullName(self): string
	function SetAttribute(self, name: string, value: any): ()
	function GetAttribute(self, name: string): any
	function GetAttributes(self): { [string]: any }
	function GetAttributeChangedSignal(self, name: string): RBXScriptSignal<>
	function GetPropertyChangedSignal(self, property: string): RBXScriptSignal<>
	ChildAdded: RBXScriptSignal<Instance>
	DescendantAdded: RBXScriptSignal<Instance>
	DescendantRemoving: RBXScriptSignal<Instance>
	ChildRemoved: RBXScriptSignal<Instance>
	AncestryChanged: RBXScriptSignal<Instance, Instance?>
	Destroying: RBXScriptSignal<>
]],
	DataModel = [[
	JobId: string
	PlaceId: number
	function BindToClose(self, callback: () -> ()): ()
]],
	Workspace = [[
	CurrentCamera: Camera
	function Raycast(self, origin: Vector3, direction: Vector3, params: RaycastParams?): RaycastResult?
	function GetServerTimeNow(self): number
]],
	Camera = [[
	function ScreenPointToRay(self, x: number, y: number, depth: number?): Ray
	function ViewportPointToRay(self, x: number, y: number, depth: number?): Ray
	function WorldToScreenPoint(self, point: Vector3): (Vector3, boolean)
	function WorldToViewportPoint(self, point: Vector3): (Vector3, boolean)
]],
	Players = [[
	LocalPlayer: Player
	PlayerAdded: RBXScriptSignal<Player>
	PlayerRemoving: RBXScriptSignal<Player>
	function GetPlayers(self): { Player }
	function GetPlayerByUserId(self, userId: number): Player?
]],
	Player = [[
	Character: Model?
	CharacterAdded: RBXScriptSignal<Model>
	CharacterRemoving: RBXScriptSignal<Model>
	function Kick(self, message: string?): ()
]],
	RunService = [[
	RenderStepped: RBXScriptSignal<number>
	Heartbeat: RBXScriptSignal<number>
	Stepped: RBXScriptSignal<number, number>
	function IsServer(self): boolean
	function IsClient(self): boolean
	function IsStudio(self): boolean
]],
	UserInputService = [[
	TouchEnabled: boolean
	KeyboardEnabled: boolean
	GamepadEnabled: boolean
	MouseEnabled: boolean
	InputBegan: RBXScriptSignal<InputObject, boolean>
	InputEnded: RBXScriptSignal<InputObject, boolean>
	TouchTapInWorld: RBXScriptSignal<Vector2, boolean>
	function GetMouseLocation(self): Vector2
]],
	TweenService = [[
	function Create(self, instance: Instance, info: TweenInfo, goals: { [string]: any }): Tween
]],
	TweenBase = [[
	Completed: RBXScriptSignal<EnumPlaybackState>
	function Play(self): ()
	function Pause(self): ()
	function Cancel(self): ()
]],
	Debris = [[
	function AddItem(self, item: Instance, lifetime: number?): ()
]],
	Sound = [[
	function Play(self): ()
	function Stop(self): ()
	Ended: RBXScriptSignal<string>
]],
	ParticleEmitter = [[
	function Emit(self, count: number?): ()
	function Clear(self): ()
]],
	RemoteEvent = [[
	OnServerEvent: RBXScriptSignal<Player, ...any>
	OnClientEvent: RBXScriptSignal<...any>
	function FireServer(self, ...: any): ()
	function FireClient(self, player: Player, ...: any): ()
	function FireAllClients(self, ...: any): ()
]],
	DataStoreService = [[
	function GetDataStore(self, name: string, scope: string?): DataStore
	function GetOrderedDataStore(self, name: string, scope: string?): OrderedDataStore
]],
	GlobalDataStore = [[
	function GetAsync(self, key: string): any
	function SetAsync(self, key: string, value: any): any
	function UpdateAsync(self, key: string, transform: (any) -> any): any
	function RemoveAsync(self, key: string): any
]],
	Model = [[
	PrimaryPart: BasePart?
	WorldPivot: CFrame
	function GetPivot(self): CFrame
	function PivotTo(self, cf: CFrame): ()
]],
	BasePart = [[
	Touched: RBXScriptSignal<BasePart>
]],
	InputObject = [[
	Position: Vector3
	Delta: Vector3
]],
	Terrain = [[
	function FillBall(self, center: Vector3, radius: number, material: EnumMaterial): ()
	function FillBlock(self, cframe: CFrame, size: Vector3, material: EnumMaterial): ()
	function SetMaterialColor(self, material: EnumMaterial, color: Color3): ()
]],
	Humanoid = [[
	StateChanged: RBXScriptSignal<EnumHumanoidStateType, EnumHumanoidStateType>
	Died: RBXScriptSignal<>
	function Move(self, direction: Vector3, relativeToCamera: boolean?): ()
	function ChangeState(self, state: EnumHumanoidStateType): ()
]],
	ProximityPrompt = [[
	Triggered: RBXScriptSignal<Player>
	TriggerEnded: RBXScriptSignal<Player>
	PromptShown: RBXScriptSignal<EnumProximityPromptInputType>
]],
	GuiButton = [[
	Activated: RBXScriptSignal<InputObject, number>
	MouseButton1Click: RBXScriptSignal<>
]],
}

-- Classes absentes de la base (types de résultat)
emit([[
declare class RaycastResult
	Instance: BasePart
	Position: Vector3
	Normal: Vector3
	Distance: number
	Material: EnumMaterial
end
declare class RaycastParams
	FilterType: EnumRaycastFilterType
	FilterDescendantsInstances: { Instance }
	IgnoreWater: boolean
	CollisionGroup: string
	RespectCanCollide: boolean
end
declare RaycastParams: { new: () -> RaycastParams }
]])

local classNames = db:GetClassNames()
local classes = {}
for _, cn in classNames do
	classes[cn] = db:GetClass(cn)
end

-- ordre : la classe parente avant ses enfants
local emitted, ordered = {}, {}
local function visit(cn)
	if emitted[cn] or not classes[cn] then
		return
	end
	local sup = classes[cn].Superclass
	if sup and sup ~= "<<<ROOT>>>" then
		visit(sup)
	end
	emitted[cn] = true
	table.insert(ordered, cn)
end
table.sort(classNames)
for _, cn in classNames do
	visit(cn)
end

for _, cn in ordered do
	local c = classes[cn]
	local header = "declare class " .. cn
	if c.Superclass and c.Superclass ~= "<<<ROOT>>>" and classes[c.Superclass] then
		header ..= " extends " .. c.Superclass
	end
	emit(header)
	local extra = EXTRA[cn] or ""
	local overridden = {}
	for name in string.gmatch(extra, "\n%s*([%a_][%w_]*):") do
		overridden[name] = true
	end
	for name in string.gmatch("\n" .. extra, "\n%s*([%a_][%w_]*):") do
		overridden[name] = true
	end
	local props = {}
	for pn, p in c.Properties do
		table.insert(props, pn)
	end
	table.sort(props)
	for _, pn in props do
		local p = c.Properties[pn]
		if ident(pn) and not overridden[pn] and p.Scriptability ~= "None" then
			local dt = p.Datatype
			local t
			if string.sub(dt, 1, 5) == "Enum." then
				t = "Enum" .. string.sub(dt, 6)
			else
				t = DT[dt]
			end
			if t then
				emit(("\t%s: %s"):format(pn, t))
			end
		end
	end
	if extra ~= "" then
		extra = extra:gsub("RBXScriptSignal<([^>]*,[^>]*)>", "RBXScriptSignal<(%1)>")
		emit((extra:gsub("\n$", "")))
	end
	emit("end")
end

---------------------------------------------------------------- Instance.new / GetService
local creatable, services = {}, {}
for _, cn in ordered do
	local tags = {}
	for _, t in classes[cn].Tags or {} do
		tags[t] = true
	end
	if tags.Service then
		table.insert(services, cn)
	elseif not tags.NotCreatable then
		table.insert(creatable, cn)
	end
end
local newParts = {}
for _, cn in creatable do
	table.insert(newParts, ('((className: "%s", parent: Instance?) -> %s)'):format(cn, cn))
end
emit("declare Instance: { new: " .. table.concat(newParts, " & ") .. " }")

emit("declare class ServiceProvider_Get")
emit("end")
-- GetService sur DataModel
local gs = {}
for _, sn in services do
	table.insert(gs, ('\tfunction GetService(self, service: "%s"): %s'):format(sn, sn))
end
-- On ré-ouvre DataModel via une classe dérivée exposée comme "game"
emit("declare class PopaintDataModel extends DataModel")
emit(table.concat(gs, "\n"))
emit("end")

emit([[
declare game: PopaintDataModel
declare workspace: Workspace
declare script: any
declare plugin: any
declare shared: any
declare function warn(...: any): ()
declare function tick(): number
declare function time(): number
declare function wait(t: number?): (number, number)
declare function delay(t: number, f: () -> ()): ()
declare function spawn(f: () -> ()): ()
declare function typeof(value: any): string
declare function settings(): any
declare function UserSettings(): any
declare task: {
	wait: (t: number?) -> number,
	spawn: (f: ((...any) -> ...any) | thread, ...any) -> thread,
	defer: (f: ((...any) -> ...any) | thread, ...any) -> thread,
	delay: (t: number, f: ((...any) -> ...any) | thread, ...any) -> thread,
	cancel: (thread: thread) -> (),
	synchronize: () -> (),
	desynchronize: () -> (),
}
]])

fs.writeFile("tools/roblox.d.luau", table.concat(out, "\n"))
print("classes", #ordered, "services", #services, "creatable", #creatable)
