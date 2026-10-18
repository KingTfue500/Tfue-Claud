package com.tfue.onepiece.entity;

public enum VfxType {
	/** Rubber arm stretching from the owner's shoulder to a point and snapping back. */
	STRETCH_ARM,
	/** Rubber leg stretching out (stamps, whips). */
	STRETCH_LEG,
	/** Huge flying fist (Gear 3, Gear 4, Gear 5). */
	GIANT_FIST,
	/** Crescent sword slash that flies forward. */
	SLASH,
	/** Spinning wind tornado. */
	TORNADO,
	/** Expanding ground ring. */
	SHOCKWAVE,
	/** Fire explosion (Diable/Ifrit Jambe). */
	FIRE_BURST,
	/** Conqueror's Haki black-red lightning burst. */
	CONQUEROR,
	/** Lightning bolt (Gear 5 grabs lightning). */
	LIGHTNING,
	/** Cartoon impact star. */
	IMPACT,
	/** Cloud puff burst (Gear 5, Sky Walk). */
	CLOUD,
	/** Fire dragon slash (King of Hell). */
	DRAGON,
	/** Afterimage trail for dashes. */
	DASH_TRAIL,
	/** Ring of nine sword arcs (Asura). */
	SLASH_RING,
	/** Katakuri's mochi trident thrust. */
	SPEAR,
	/** Claw marks (Lucci). */
	CLAW,
	/** Cracked ground left behind by huge slams. */
	CRATER,
	/** Wobbling mochi dome that follows its owner (Mochi Wall). */
	MOCHI_DOME;

	public static VfxType byId(int id) {
		VfxType[] values = values();
		return id >= 0 && id < values.length ? values[id] : IMPACT;
	}
}
