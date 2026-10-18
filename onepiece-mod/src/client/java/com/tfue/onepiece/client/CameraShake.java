package com.tfue.onepiece.client;

import net.minecraft.client.Minecraft;
import net.minecraft.util.Mth;

/** Camera shake for huge impacts. */
public final class CameraShake {
	private static float strength;
	private static int ticksLeft;
	private static int length = 1;

	private CameraShake() {
	}

	public static void start(float power, int ticks) {
		if (power >= strength * (ticksLeft / (float) length)) {
			strength = Math.min(2.5F, power);
			ticksLeft = ticks;
			length = Math.max(1, ticks);
		}
	}

	public static void tick() {
		if (ticksLeft > 0) {
			ticksLeft--;
		}
	}

	public static boolean active() {
		return ticksLeft > 0;
	}

	private static float amount(float partialTicks) {
		return strength * Math.max(0.0F, (ticksLeft - partialTicks) / length);
	}

	public static float yaw(float partialTicks) {
		float time = (Minecraft.getInstance().level != null ? Minecraft.getInstance().level.getGameTime() : 0) + partialTicks;
		return Mth.sin(time * 2.7F) * 1.6F * amount(partialTicks);
	}

	public static float pitch(float partialTicks) {
		float time = (Minecraft.getInstance().level != null ? Minecraft.getInstance().level.getGameTime() : 0) + partialTicks;
		return Mth.cos(time * 3.3F) * 1.2F * amount(partialTicks);
	}
}
