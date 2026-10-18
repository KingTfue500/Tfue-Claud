package com.tfue.onepiece.client;

import com.tfue.onepiece.power.Form;
import net.minecraft.client.Minecraft;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.phys.Vec3;
import org.jspecify.annotations.Nullable;

/**
 * Transformation cutscene: the camera swings around the fighter while the screen gets cinema bars,
 * a title card for the new form and a white flash on the reveal.
 */
public final class Cutscene {
	public static final int LENGTH = 64;

	private static int entityId = -1;
	private static @Nullable Form form;
	private static long start;
	private static float startAngle;

	private Cutscene() {
	}

	public static void play(int id, Form newForm) {
		Minecraft mc = Minecraft.getInstance();
		if (mc.level == null || mc.player == null) {
			return;
		}
		Entity entity = mc.level.getEntity(id);
		if (entity == null) {
			return;
		}
		entityId = id;
		form = newForm;
		start = mc.level.getGameTime();
		Vec3 toCamera = mc.player.position().subtract(entity.position());
		startAngle = (float) Math.atan2(toCamera.z, toCamera.x);
		if (entity == mc.player) {
			startAngle = (entity.getYRot() + 90.0F) * Mth.DEG_TO_RAD;
		}
	}

	public static void stop() {
		entityId = -1;
		form = null;
	}

	/** 0..1 through the cutscene, or -1 when none is playing. */
	public static float progress(float partialTicks) {
		Minecraft mc = Minecraft.getInstance();
		if (form == null || mc.level == null) {
			return -1.0F;
		}
		float p = (mc.level.getGameTime() - start + partialTicks) / LENGTH;
		if (p < 0.0F || p > 1.0F || mc.level.getEntity(entityId) == null) {
			if (p > 1.0F || mc.level.getEntity(entityId) == null) {
				stop();
			}
			return -1.0F;
		}
		return p;
	}

	public static boolean active() {
		return form != null;
	}

	public static @Nullable Form form() {
		return form;
	}

	public static @Nullable Entity target() {
		Minecraft mc = Minecraft.getInstance();
		return mc.level != null && entityId >= 0 ? mc.level.getEntity(entityId) : null;
	}

	/** Where the camera sits and looks during the cutscene: {position, look target}. */
	public static Vec3 @Nullable [] camera(float partialTicks) {
		float p = progress(partialTicks);
		Entity entity = target();
		if (p < 0.0F || entity == null) {
			return null;
		}
		float h = entity.getBbHeight();
		Vec3 center = entity.getPosition(partialTicks).add(0, h * 0.6, 0);
		float ease = p * p * (3 - 2 * p);
		float angle = startAngle + ease * Mth.PI * 1.15F;
		float radius = Math.max(3.2F, h * 1.6F) * (1.25F - 0.35F * Mth.sin(p * Mth.PI));
		float height = h * (0.1F + 0.35F * (1 - p));
		Vec3 eye = center.add(Mth.cos(angle) * radius, height, Mth.sin(angle) * radius);
		return new Vec3[] {eye, center};
	}
}
