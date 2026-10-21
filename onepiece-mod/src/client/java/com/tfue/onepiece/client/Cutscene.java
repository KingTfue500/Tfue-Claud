package com.tfue.onepiece.client;

import com.tfue.onepiece.power.Form;
import net.minecraft.client.Minecraft;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;
import net.minecraft.world.phys.shapes.CollisionContext;
import org.jspecify.annotations.Nullable;

/**
 * Transformation cutscene: the camera swings around the fighter while the screen gets cinema bars,
 * a title card for the new form and a white flash on the reveal.
 */
public final class Cutscene {
	public static final int LENGTH = 64;

	public static final int SKILL_LENGTH = 36;

	private static int entityId = -1;
	private static @Nullable Form form;
	private static com.tfue.onepiece.power.@Nullable Move skill;
	private static int length = LENGTH;
	private static long lastSkill = -1000;
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
		skill = null;
		length = LENGTH;
		start = mc.level.getGameTime();
		Vec3 toCamera = mc.player.position().subtract(entity.position());
		startAngle = (float) Math.atan2(toCamera.z, toCamera.x);
		if (entity == mc.player) {
			startAngle = (entity.getYRot() + 90.0F) * Mth.DEG_TO_RAD;
		}
	}

	/** Short cinematic for a finishing skill: low dramatic angle beside the fighter and the skill's name. */
	public static void playSkill(int id, com.tfue.onepiece.power.Move move) {
		Minecraft mc = Minecraft.getInstance();
		if (mc.level == null || mc.level.getEntity(id) == null) {
			return;
		}
		if (active() || mc.level.getGameTime() - lastSkill < 100) {
			return;
		}
		lastSkill = mc.level.getGameTime();
		Entity entity = mc.level.getEntity(id);
		entityId = id;
		form = move.form();
		skill = move;
		length = SKILL_LENGTH;
		start = mc.level.getGameTime();
		startAngle = (entity.getYRot() + 90.0F + 35.0F) * Mth.DEG_TO_RAD;
	}

	public static com.tfue.onepiece.power.@Nullable Move skill() {
		return skill;
	}

	public static void stop() {
		entityId = -1;
		form = null;
		skill = null;
	}

	/** 0..1 through the cutscene, or -1 when none is playing. */
	public static float progress(float partialTicks) {
		Minecraft mc = Minecraft.getInstance();
		if (form == null || mc.level == null) {
			return -1.0F;
		}
		float p = (mc.level.getGameTime() - start + partialTicks) / length;
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
		if (skill != null) {
			// Low angle from the front-side, slowly sliding past, looking slightly ahead of the fighter.
			float yaw = entity.getYRot() * Mth.DEG_TO_RAD;
			Vec3 forward = new Vec3(-Mth.sin(yaw), 0, Mth.cos(yaw));
			float side = startAngle + p * 0.5F;
			if (form == Form.KAIDO_DRAGON) {
				// The serpent trails far behind its head, so stay wide and above it.
				float radius = h * 3.4F;
				Vec3 eye = center.add(Mth.cos(side) * radius, h * 0.9, Mth.sin(side) * radius);
				return new Vec3[] {unblocked(entity, center, eye), center.add(forward.scale(h * 1.5))};
			}
			float radius = Math.max(3.0F, h * 1.7F);
			Vec3 eye = center.add(forward.scale(radius * 0.6)).add(Mth.cos(side) * radius, -h * 0.35, Mth.sin(side) * radius);
			return new Vec3[] {unblocked(entity, center, eye), center.add(forward.scale(h * 1.2))};
		}
		float ease = p * p * (3 - 2 * p);
		float angle = startAngle + ease * Mth.PI * 1.15F;
		// Start tight on the face, pull out for the reveal, then circle around.
		boolean dragon = form == Form.KAIDO_DRAGON;
		// The dragon is a long serpent coiling behind its head: frame all of it from wide and high.
		float base = dragon ? h * 2.8F : Math.max(3.2F, h * 1.6F);
		float pull = dragon ? 1.0F + 0.15F * Mth.sin(p * Mth.PI) : p < 0.4F ? 0.45F + 0.55F * (p / 0.4F) * (p / 0.4F) : 1.0F + 0.15F * Mth.sin((p - 0.4F) / 0.6F * Mth.PI);
		float radius = base * pull;
		Vec3 face = entity.getPosition(partialTicks).add(0, h * 0.85, 0);
		Vec3 focus = p < 0.4F && !dragon ? face.lerp(center, p / 0.4F) : center;
		float height = dragon ? h * (0.7F + 0.3F * p) : h * (0.05F + 0.3F * Math.max(0.0F, p - 0.3F));
		Vec3 eye = focus.add(Mth.cos(angle) * radius, height, Mth.sin(angle) * radius);
		return new Vec3[] {unblocked(entity, focus, eye), focus};
	}

	/** Pulls the camera in front of any block between it and the fighter, so it never ends up inside a hill or a tree. */
	private static Vec3 unblocked(Entity entity, Vec3 focus, Vec3 eye) {
		BlockHitResult hit = entity.level().clip(new ClipContext(focus, eye, ClipContext.Block.VISUAL, ClipContext.Fluid.NONE, CollisionContext.empty()));
		if (hit.getType() != HitResult.Type.BLOCK) {
			return eye;
		}
		Vec3 offset = eye.subtract(focus);
		double length = offset.length();
		double allowed = Math.max(0.8, hit.getLocation().distanceTo(focus) - 0.35);
		return allowed >= length ? eye : focus.add(offset.scale(allowed / length));
	}
}
