package com.tfue.onepiece.registry;

import com.tfue.onepiece.OnePiece;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.sounds.SoundEvent;

public final class ModSounds {
	public static final SoundEvent STRETCH = register("stretch");
	public static final SoundEvent SNAP = register("snap");
	public static final SoundEvent PUNCH = register("punch");
	public static final SoundEvent HEAVY_IMPACT = register("heavy_impact");
	public static final SoundEvent GATLING = register("gatling");
	public static final SoundEvent WHOOSH = register("whoosh");
	public static final SoundEvent SLASH = register("slash");
	public static final SoundEvent BIG_SLASH = register("big_slash");
	public static final SoundEvent SHEATHE = register("sheathe");
	public static final SoundEvent TORNADO = register("tornado");
	public static final SoundEvent KICK = register("kick");
	public static final SoundEvent FIRE = register("fire");
	public static final SoundEvent FIRE_BLAST = register("fire_blast");
	public static final SoundEvent STEAM = register("steam");
	public static final SoundEvent INFLATE = register("inflate");
	public static final SoundEvent BOUNCE = register("bounce");
	public static final SoundEvent DRUMS = register("drums");
	public static final SoundEvent LIGHTNING = register("lightning");
	public static final SoundEvent HAKI = register("haki");
	public static final SoundEvent CONQUEROR = register("conqueror");
	public static final SoundEvent FORM_UP = register("form_up");
	public static final SoundEvent BOSS_ROAR = register("boss_roar");
	public static final SoundEvent EAT_FRUIT = register("eat_fruit");

	private ModSounds() {
	}

	private static SoundEvent register(String name) {
		Identifier id = OnePiece.id(name);
		return Registry.register(BuiltInRegistries.SOUND_EVENT, id, SoundEvent.createVariableRangeEvent(id));
	}

	public static void init() {
	}
}
