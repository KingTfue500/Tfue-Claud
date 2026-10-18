package com.tfue.onepiece.power;

/** Body animations played on the player model while a move runs. Synced through {@link PowerData}. */
public enum Anim {
	NONE(0),
	PUNCH_RIGHT(10),
	PUNCH_LEFT(10),
	GATLING(40),
	BAZOOKA(14),
	ROCKET(16),
	WHIP(14),
	STOMP(18),
	BALLOON(100),
	CHARGE_PUNCH(24),
	GRAB_SKY(24),
	SWORD_SLASH(12),
	SWORD_CROSS(12),
	SWORD_SPIN(30),
	SWORD_DASH(12),
	SWORD_RAISE(20),
	KICK_HIGH(10),
	KICK_SPIN(40),
	KICK_DOWN(20),
	KICK_RAPID(40),
	KICK_LAUNCH(12),
	ROAR(30),
	FORM_SHIFT(20),
	DASH(10),
	CLUB_SMASH(22),
	BREATH(34),
	CLAW(12),
	POUNCE(18),
	GUARD(50),
	FINGER(10);

	public final int duration;

	Anim(int duration) {
		this.duration = duration;
	}

	public static Anim byId(int id) {
		Anim[] values = values();
		return id >= 0 && id < values.length ? values[id] : NONE;
	}
}
