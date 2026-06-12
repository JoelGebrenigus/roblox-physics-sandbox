--!strict

export type GrabAction = {
	kind: "Grab",
	target: Instance,
}

export type DropAction = {
	kind: "Drop",
}

export type ChargeStartAction = {
	kind: "ChargeStart",
}

export type ChargeReleaseAction = {
	kind: "ChargeRelease",
}

export type TelekinesisAction = GrabAction | DropAction | ChargeStartAction | ChargeReleaseAction

export type HoldUpdate = {
	cameraCFrame: CFrame,
	targetCFrame: CFrame,
	holdDistance: number,
	sequence: number,
}

export type GrabbedFeedback = {
	kind: "Grabbed",
	root: BasePart,
	mass: number,
	holdDistance: number,
	rotation: CFrame,
}

export type ReleasedFeedback = {
	kind: "Released",
	reason: string,
	thrown: boolean,
}

export type RejectedFeedback = {
	kind: "Rejected",
	code: string,
	message: string,
}

export type ChargeFeedback = {
	kind: "Charge",
	active: boolean,
}

export type TelekinesisFeedback =
	GrabbedFeedback
	| ReleasedFeedback
	| RejectedFeedback
	| ChargeFeedback

export type RemoteSet = {
	Action: RemoteEvent,
	Update: RemoteEvent,
	Feedback: RemoteEvent,
}

export type Candidate = {
	root: BasePart,
	parts: { BasePart },
	mass: number,
	bounds: Vector3,
	container: Instance,
}

return {}
