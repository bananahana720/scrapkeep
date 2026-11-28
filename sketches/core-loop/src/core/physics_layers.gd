extends RefCounted

const NONE := 0
const WORLD_LAYER := 1
const BALL_LAYER := 2
const ENEMY_LAYER := 3
const STAKE_LAYER := 8

const WORLD_MASK := 1 << (WORLD_LAYER - 1)
const BALL_MASK := 1 << (BALL_LAYER - 1)
const ENEMY_MASK := 1 << (ENEMY_LAYER - 1)
const STAKE_MASK := 1 << (STAKE_LAYER - 1)
const WORLD_AND_ENEMIES_MASK := WORLD_MASK | ENEMY_MASK
