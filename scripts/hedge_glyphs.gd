class_name HedgeGlyph
extends RefCounted

# HedgeInk's private-use codepoints are addresses for drawing gestures, not text.
const LEAF_SIMPLE_CODEPOINT := 0xE000
const LEAF_NARROW_CODEPOINT := 0xE001
const LEAF_ROUND_CODEPOINT := 0xE002
const LEAF_POINTED_CODEPOINT := 0xE003
const LEAF_BENT_CODEPOINT := 0xE004
const LEAF_PAIR_CODEPOINT := 0xE005
const LEAF_PAIR_ALTERNATING_CODEPOINT := 0xE006
const THREE_LEAF_CLUSTER_CODEPOINT := 0xE007
const STEM_SEGMENT_CODEPOINT := 0xE008
const CURVED_STEM_CODEPOINT := 0xE009
const BRANCH_FORK_CODEPOINT := 0xE00A
const TENDRIL_CODEPOINT := 0xE00B
const BUD_CODEPOINT := 0xE00C
const SIMPLE_FLOWER_CODEPOINT := 0xE00D
const BERRY_CLUSTER_CODEPOINT := 0xE00E
const SEED_POD_CODEPOINT := 0xE00F

const CODEPOINTS := [
	LEAF_SIMPLE_CODEPOINT,
	LEAF_NARROW_CODEPOINT,
	LEAF_ROUND_CODEPOINT,
	LEAF_POINTED_CODEPOINT,
	LEAF_BENT_CODEPOINT,
	LEAF_PAIR_CODEPOINT,
	LEAF_PAIR_ALTERNATING_CODEPOINT,
	THREE_LEAF_CLUSTER_CODEPOINT,
	STEM_SEGMENT_CODEPOINT,
	CURVED_STEM_CODEPOINT,
	BRANCH_FORK_CODEPOINT,
	TENDRIL_CODEPOINT,
	BUD_CODEPOINT,
	SIMPLE_FLOWER_CODEPOINT,
	BERRY_CLUSTER_CODEPOINT,
	SEED_POD_CODEPOINT,
]

const NAMES := [
	"leaf_simple",
	"leaf_narrow",
	"leaf_round",
	"leaf_pointed",
	"leaf_bent",
	"leaf_pair",
	"leaf_pair_alternating",
	"three_leaf_cluster",
	"stem_segment",
	"curved_stem",
	"branch_fork",
	"tendril",
	"bud",
	"simple_flower",
	"berry_cluster",
	"seed_pod",
]


static func codepoint_for_index(index: int) -> int:
	return CODEPOINTS[posmod(index, CODEPOINTS.size())]


static func glyph_for_index(index: int) -> String:
	return String.chr(codepoint_for_index(index))


static func name_for_index(index: int) -> String:
	return NAMES[posmod(index, NAMES.size())]
