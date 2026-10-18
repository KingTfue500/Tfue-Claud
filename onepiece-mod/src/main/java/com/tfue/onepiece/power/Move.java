package com.tfue.onepiece.power;

import net.minecraft.world.entity.LivingEntity;

/**
 * A single attack or skill. {@code form} decides which wheel it shows up in.
 */
public record Move(String id, Form form, int cost, int cooldown, Anim anim, Icon icon, Action action) {
	public interface Action {
		void run(LivingEntity user);
	}

	/** Icon drawn in the move wheel and HUD. Each has its own texture, tinted by the form color. */
	public enum Icon {
		FIST, GATLING, GIANT_FIST, PALMS, ROCKET, WHIP, BALLOON, DASH, STOMP, FIRE_FIST, LIGHTNING, CLOUD, GIANT,
		SNAKE, SLASH, SLASH_WAVE, TORNADO, X_SLASH, DRAGON, SPIN_BLADES, KICK, KICK_SPIN, KICK_DOWN, FIRE_KICK, SKY_WALK, STEALTH, SHIELD,
		CLUB, BREATH, ROAR, MOCHI, TRIDENT, CLAW, FINGER, POUNCE;

		public String texture() {
			return name().toLowerCase(java.util.Locale.ROOT);
		}
	}

	public String translationKey() {
		return "move.onepiece." + id;
	}
}
