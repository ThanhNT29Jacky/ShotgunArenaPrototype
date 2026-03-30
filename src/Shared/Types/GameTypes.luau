export type PelletData = {
	origin: Vector3,
	direction: Vector3,
}

export type HitData = {
	pellets: { PelletData },
}

export type PlayerState = {
	character: Model,
	humanoid: Humanoid,
	health: number,
	isAlive: boolean,
}

export type WeaponData = {
	ammo: number,
	lastFireTime: number,
	isReloading: boolean,
}

return {}
