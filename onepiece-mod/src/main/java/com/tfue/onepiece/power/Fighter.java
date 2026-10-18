package com.tfue.onepiece.power;

import java.util.Locale;

public enum Fighter {
	NONE(0xFFFFFFFF),
	LUFFY(0xFFE8332F),
	ZORO(0xFF3FBF5A),
	SANJI(0xFFF2C744),
	KAIDO(0xFF7A6BFF),
	KATAKURI(0xFFE0457E),
	LUCCI(0xFFE8B030);

	public static final Fighter[] PLAYABLE = {LUFFY, ZORO, SANJI, KAIDO, KATAKURI, LUCCI};

	private final int color;

	Fighter(int color) {
		this.color = color;
	}

	public int color() {
		return color;
	}

	public int bit() {
		return 1 << ordinal();
	}

	public String id() {
		return name().toLowerCase(Locale.ROOT);
	}

	public String translationKey() {
		return "fighter.onepiece." + id();
	}

	public static Fighter byName(String name) {
		for (Fighter f : PLAYABLE) {
			if (f.id().equals(name)) {
				return f;
			}
		}
		return null;
	}

	public static Fighter byId(int id) {
		Fighter[] values = values();
		return id >= 0 && id < values.length ? values[id] : NONE;
	}
}
