package com.tfue.onepiece.power;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Every transformation a fighter can enter. Each form has its own skin, body shape,
 * stat bonuses and move list (see {@link Moves}).
 */
public enum Form {
	// fighter, color, damage x, speed bonus, scale, stamina drain per second, activation cost
	BASE_LUFFY(Fighter.LUFFY, 0xFFE8332F, 1.0F, 0.0F, 1.0F, 0.0F, 0),
	GEAR_2(Fighter.LUFFY, 0xFFFF6B8A, 1.4F, 0.6F, 1.0F, 1.0F, 15),
	GEAR_3(Fighter.LUFFY, 0xFFFFA14A, 1.6F, 0.0F, 1.0F, 1.2F, 20),
	GEAR_4_BOUNDMAN(Fighter.LUFFY, 0xFF9E1B32, 2.1F, 0.3F, 1.6F, 2.2F, 35),
	GEAR_4_SNAKEMAN(Fighter.LUFFY, 0xFFB0213D, 2.0F, 0.8F, 1.3F, 2.2F, 35),
	GEAR_4_TANKMAN(Fighter.LUFFY, 0xFF7A1530, 2.2F, -0.3F, 1.9F, 2.4F, 35),
	GEAR_5(Fighter.LUFFY, 0xFFF4F1E8, 2.6F, 0.7F, 1.0F, 2.6F, 50),

	BASE_ZORO(Fighter.ZORO, 0xFF3FBF5A, 1.0F, 0.0F, 1.0F, 0.0F, 0),
	ASURA(Fighter.ZORO, 0xFF6E4AA8, 1.9F, 0.1F, 1.15F, 2.0F, 40),
	KING_OF_HELL(Fighter.ZORO, 0xFF8E2BD6, 2.4F, 0.4F, 1.0F, 2.4F, 50),

	BASE_SANJI(Fighter.SANJI, 0xFFF2C744, 1.0F, 0.1F, 1.0F, 0.0F, 0),
	DIABLE_JAMBE(Fighter.SANJI, 0xFFFF5A1F, 1.6F, 0.4F, 1.0F, 1.2F, 20),
	IFRIT_JAMBE(Fighter.SANJI, 0xFF3FA9FF, 2.4F, 0.7F, 1.0F, 2.4F, 45),
	RAID_SUIT(Fighter.SANJI, 0xFF2E56C9, 1.5F, 0.5F, 1.0F, 1.0F, 20),

	BASE_KAIDO(Fighter.KAIDO, 0xFF7A6BFF, 1.3F, -0.05F, 1.5F, 0.0F, 0),
	KAIDO_HYBRID(Fighter.KAIDO, 0xFF4F8BFF, 2.0F, 0.1F, 1.9F, 1.6F, 30),
	KAIDO_DRAGON(Fighter.KAIDO, 0xFF3FC8FF, 2.4F, 0.2F, 2.2F, 2.4F, 50),

	BASE_KATAKURI(Fighter.KATAKURI, 0xFFE0457E, 1.3F, 0.1F, 1.45F, 0.0F, 0),
	KATAKURI_AWAKENED(Fighter.KATAKURI, 0xFFFFB8D8, 2.2F, 0.3F, 1.6F, 2.2F, 45),

	BASE_LUCCI(Fighter.LUCCI, 0xFFE8B030, 1.2F, 0.25F, 1.0F, 0.0F, 0),
	LUCCI_HYBRID(Fighter.LUCCI, 0xFFF0C040, 1.8F, 0.45F, 1.3F, 1.4F, 25),
	LUCCI_AWAKENED(Fighter.LUCCI, 0xFFFF4A30, 2.4F, 0.7F, 1.45F, 2.4F, 45);

	public final Fighter fighter;
	public final int color;
	public final float damage;
	public final float speed;
	public final float scale;
	public final float drain;
	public final int cost;

	Form(Fighter fighter, int color, float damage, float speed, float scale, float drain, int cost) {
		this.fighter = fighter;
		this.color = color;
		this.damage = damage;
		this.speed = speed;
		this.scale = scale;
		this.drain = drain;
		this.cost = cost;
	}

	public String id() {
		return name().toLowerCase(Locale.ROOT);
	}

	public String translationKey() {
		return "form.onepiece." + id();
	}

	public boolean isBase() {
		return this == BASE_LUFFY || this == BASE_ZORO || this == BASE_SANJI || this == BASE_KAIDO || this == BASE_KATAKURI || this == BASE_LUCCI;
	}

	public boolean isGear4() {
		return this == GEAR_4_BOUNDMAN || this == GEAR_4_SNAKEMAN || this == GEAR_4_TANKMAN;
	}

	/** Forms that let the player keep jumping in mid-air (Sky Walk, bouncing, cloud riding). */
	public boolean hasAirJumps() {
		return fighter == Fighter.SANJI || fighter == Fighter.LUCCI || this == GEAR_4_BOUNDMAN || this == GEAR_5 || this == KAIDO_HYBRID;
	}

	/** Big transformations get a cinematic cutscene when they start. */
	public boolean hasCutscene() {
		return switch (this) {
			case GEAR_4_BOUNDMAN, GEAR_4_SNAKEMAN, GEAR_4_TANKMAN, GEAR_5, ASURA, KING_OF_HELL, IFRIT_JAMBE,
				KAIDO_HYBRID, KAIDO_DRAGON, KATAKURI_AWAKENED, LUCCI_HYBRID, LUCCI_AWAKENED -> true;
			default -> false;
		};
	}

	public static Form base(Fighter fighter) {
		return switch (fighter) {
			case ZORO -> BASE_ZORO;
			case SANJI -> BASE_SANJI;
			case KAIDO -> BASE_KAIDO;
			case KATAKURI -> BASE_KATAKURI;
			case LUCCI -> BASE_LUCCI;
			default -> BASE_LUFFY;
		};
	}

	public static List<Form> of(Fighter fighter) {
		List<Form> list = new ArrayList<>();
		for (Form form : values()) {
			if (form.fighter == fighter) {
				list.add(form);
			}
		}
		return list;
	}

	public static Form byId(int id) {
		Form[] values = values();
		return id >= 0 && id < values.length ? values[id] : BASE_LUFFY;
	}

	public static Form byName(String name) {
		for (Form form : values()) {
			if (form.id().equals(name)) {
				return form;
			}
		}
		return null;
	}
}
