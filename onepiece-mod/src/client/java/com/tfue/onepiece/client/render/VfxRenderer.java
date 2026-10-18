package com.tfue.onepiece.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import com.tfue.onepiece.entity.VfxEntity;
import com.tfue.onepiece.entity.VfxType;
import com.tfue.onepiece.power.Moves;
import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.state.EntityRenderState;
import net.minecraft.client.renderer.rendertype.RenderType;
import net.minecraft.client.renderer.state.level.CameraRenderState;
import net.minecraft.resources.Identifier;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.phys.Vec3;
import org.jspecify.annotations.Nullable;

/** Draws every effect in the mod with hand-built geometry and the mod's own textures. */
public class VfxRenderer extends EntityRenderer<VfxEntity, VfxRenderer.State> {
	private static final Identifier GLOW = ModRenderTypes.tex("glow");
	private static final Identifier SLASH = ModRenderTypes.tex("slash");
	private static final Identifier BAND = ModRenderTypes.tex("band");
	private static final Identifier FIRE = ModRenderTypes.tex("fire");
	private static final Identifier CLOUD = ModRenderTypes.tex("cloud");
	private static final Identifier IMPACT = ModRenderTypes.tex("impact");
	private static final Identifier WIND = ModRenderTypes.tex("wind");
	private static final Identifier WHITE = ModRenderTypes.tex("white");
	private static final String[] LOOKS = {"skin", "haki", "gear5", "gear2", "gear4", "mochi"};

	public VfxRenderer(EntityRendererProvider.Context context) {
		super(context);
		this.shadowRadius = 0.0F;
	}

	public static class State extends EntityRenderState {
		public VfxType type = VfxType.IMPACT;
		public int color = -1;
		public float size = 1.0F;
		public int life = 20;
		public float age;
		public int variant;
		public float spin;
		public float yaw;
		public float pitch;
		public int seed;
		/** Relative to the entity position. */
		public Vec3 target = Vec3.ZERO;
		public @Nullable Vec3 start;
		public Vec3 ownerPos = Vec3.ZERO;
	}

	@Override
	public State createRenderState() {
		return new State();
	}

	@Override
	protected boolean affectedByCulling(VfxEntity entity) {
		return false;
	}

	@Override
	public void extractRenderState(VfxEntity entity, State state, float partialTicks) {
		super.extractRenderState(entity, state, partialTicks);
		state.type = entity.getVfxType();
		state.color = entity.getColor();
		state.size = entity.getSize();
		state.life = Math.max(1, entity.getLife());
		state.age = entity.tickCount + partialTicks;
		state.variant = entity.getVariant();
		state.spin = entity.getSpin();
		state.yaw = entity.getYRot();
		state.pitch = entity.getXRot();
		state.seed = entity.getId();
		Vec3 pos = new Vec3(state.x, state.y, state.z);
		state.target = entity.getTarget().subtract(pos);
		state.start = null;
		Entity owner = entity.getOwner();
		if (owner != null) {
			Vec3 ownerPos = owner.getPosition(partialTicks);
			state.ownerPos = ownerPos.subtract(pos);
			if (state.type == VfxType.STRETCH_ARM || state.type == VfxType.STRETCH_LEG) {
				float bodyYaw = owner instanceof LivingEntity living ? Mth.rotLerp(partialTicks, living.yBodyRotO, living.yBodyRot) : owner.getYRot();
				float rad = bodyYaw * Mth.DEG_TO_RAD;
				Vec3 right = new Vec3(-Mth.cos(rad), 0, -Mth.sin(rad));
				float width = owner.getBbWidth() / 0.6F;
				boolean left = (state.variant & 16) != 0;
				Vec3 anchor = state.type == VfxType.STRETCH_ARM
					? ownerPos.add(0, owner.getEyeHeight() * 0.85, 0).add(right.scale((left ? -0.36 : 0.36) * width))
					: ownerPos.add(0, owner.getBbHeight() * 0.42, 0).add(right.scale(0.12 * width));
				state.start = anchor.subtract(pos);
			}
		}
	}

	@Override
	public void submit(State state, PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera) {
		float q = Mth.clamp(state.age / state.life, 0.0F, 1.0F);
		Vec3 camRel = camera.pos.subtract(state.x, state.y, state.z);
		switch (state.type) {
			case STRETCH_ARM -> stretch(state, poseStack, collector, q, camRel, true);
			case STRETCH_LEG -> stretch(state, poseStack, collector, q, camRel, false);
			case GIANT_FIST -> giantFist(state, poseStack, collector, q, camRel);
			case SLASH -> slash(state, poseStack, collector, q);
			case TORNADO -> tornado(state, poseStack, collector, q);
			case SHOCKWAVE -> shockwave(state, poseStack, collector, q);
			case FIRE_BURST -> fireBurst(state, poseStack, collector, q, camera);
			case CONQUEROR -> conqueror(state, poseStack, collector, q, camRel);
			case LIGHTNING -> lightning(state, poseStack, collector, q, camRel, state.target, state.size, state.color);
			case IMPACT -> impact(state, poseStack, collector, q, camera);
			case CLOUD -> cloud(state, poseStack, collector, q, camera);
			case DRAGON -> dragon(state, poseStack, collector, q, camera);
			case DASH_TRAIL -> dashTrail(state, poseStack, collector, q, camRel);
			case SLASH_RING -> slashRing(state, poseStack, collector, q);
		}
	}

	private static RenderType glowOrSoft(int color, Identifier texture) {
		return Geo.luminance(color) < 0.22F ? ModRenderTypes.soft(texture) : ModRenderTypes.glow(texture);
	}

	private static void faceDirection(PoseStack poseStack, float yaw, float pitch) {
		poseStack.mulPose(Axis.YP.rotationDegrees(-yaw));
		poseStack.mulPose(Axis.XP.rotationDegrees(pitch));
	}

	// ------------------------------------------------------------------ rubber limbs

	private static float extension(float q) {
		if (q < 0.3F) {
			float e = q / 0.3F;
			return 1.0F - (1.0F - e) * (1.0F - e) * (1.0F - e);
		}
		if (q < 0.55F) {
			return 1.0F;
		}
		float r = (q - 0.55F) / 0.45F;
		return 1.0F - r * r;
	}

	private void stretch(State state, PoseStack poseStack, SubmitNodeCollector collector, float q, Vec3 camRel, boolean arm) {
		Vec3 start = state.start != null ? state.start : Vec3.ZERO;
		Vec3 target = state.target;
		if (!arm && state.spin == 1.0F) {
			// Whip: the leg sweeps a full circle around the owner.
			Vec3 offset = target.subtract(start);
			double angle = q * Mth.TWO_PI * 1.2;
			offset = new Vec3(offset.x * Math.cos(angle) - offset.z * Math.sin(angle), 0, offset.x * Math.sin(angle) + offset.z * Math.cos(angle));
			target = start.add(offset);
		} else if (!arm && state.spin == 2.0F) {
			// Gigant Axe: raised high, then chopped down in front.
			Vec3 ground = new Vec3(target.x, start.y - 1.0, target.z);
			float drop = Mth.clamp((q - 0.45F) / 0.15F, 0.0F, 1.0F);
			target = target.lerp(ground, drop);
		}
		float e = extension(q);
		if (!arm && (state.spin == 1.0F || state.spin == 2.0F)) {
			e = Math.min(1.0F, q * 6.0F) * Math.min(1.0F, (1.0F - q) * 5.0F);
		}
		Vec3 end = start.lerp(target, e);
		int look = state.variant & 15;
		String name = LOOKS[Math.min(look, LOOKS.length - 1)];
		Identifier limb = ModRenderTypes.tex((arm ? "arm_" : "leg_") + name);
		Identifier tip = ModRenderTypes.tex(arm ? "fist_" + name : "foot_" + name);
		float w = (arm ? 0.26F : 0.3F) * state.size;
		int light = state.lightCoords;
		boolean curve = state.spin > 0.0F && arm;
		Vec3 dir = end.subtract(start);
		Vec3 side = dir.cross(new Vec3(0, 1, 0));
		side = side.lengthSqr() > 1.0E-6 ? side.normalize() : new Vec3(1, 0, 0);
		int segments = curve ? 10 : 1;
		Vec3 prev = start;
		float sway = (state.seed % 2 == 0 ? 1 : -1) * (float) dir.length() * 0.22F;
		for (int n = 1; n <= segments; n++) {
			float f = n / (float) segments;
			Vec3 point = start.lerp(end, f);
			if (curve) {
				point = point.add(side.scale(Math.sin(f * Math.PI) * sway * Math.sin(state.age * 0.5 + f * 4)));
			}
			Vec3 a = prev;
			Vec3 b = point;
			collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(limb), (pose, buf) -> Geo.tube(buf, pose, a, b, w, w * 1.6F, -1, light));
			prev = point;
		}
		// Fist or foot at the end, a little bigger than the limb.
		Vec3 tipPos = prev;
		float fs = (arm ? 0.24F : 0.22F) * state.size;
		poseStack.pushPose();
		poseStack.translate(tipPos.x, tipPos.y, tipPos.z);
		Vec3 d = dir.normalize();
		float yaw = (float) (Math.atan2(-d.x, d.z) * Mth.RAD_TO_DEG);
		float pitch = (float) (-Math.atan2(d.y, d.horizontalDistance()) * Mth.RAD_TO_DEG);
		faceDirection(poseStack, yaw, pitch);
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(tip), (pose, buf) -> Geo.cube(buf, pose, fs, fs, fs * 1.15F, -1, light));
		poseStack.popPose();
		// Speed lines while the limb shoots out.
		if (q < 0.35F && dir.length() > 2.0) {
			int color = look == Moves.LOOK_GEAR5 ? 0xC0FFFFFF : 0x90FFFFFF;
			RandomSource random = RandomSource.create(state.seed * 31L + (long) (state.age));
			collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(GLOW), (pose, buf) -> {
				for (int n = 0; n < 5; n++) {
					Vec3 off = new Vec3(random.nextFloat() - 0.5, random.nextFloat() - 0.5, random.nextFloat() - 0.5).scale(w * 3);
					Vec3 a = start.lerp(end, 0.2 + random.nextFloat() * 0.3).add(off);
					Vec3 b = start.lerp(end, 0.7 + random.nextFloat() * 0.3).add(off);
					Geo.beam(buf, pose, a, b, camRel, 0.05F * state.size, Geo.alpha(color, 0.0F), color, Geo.FULL_BRIGHT);
				}
			});
		}
	}

	private void giantFist(State state, PoseStack poseStack, SubmitNodeCollector collector, float q, Vec3 camRel) {
		int look = state.variant & 15;
		String name = LOOKS[Math.min(look, LOOKS.length - 1)];
		float s = state.size;
		float pop = Math.min(1.0F, state.age / 3.0F);
		float fs = s * 0.5F * (0.6F + 0.4F * pop);
		poseStack.pushPose();
		faceDirection(poseStack, state.yaw, state.pitch);
		if (state.spin > 0.0F) {
			poseStack.mulPose(Axis.ZP.rotation(state.age * 0.6F));
		}
		int light = Geo.FULL_BRIGHT;
		Identifier fistTex = ModRenderTypes.tex("fist_" + name);
		Identifier armTex = ModRenderTypes.tex("arm_" + name);
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(fistTex), (pose, buf) -> Geo.cube(buf, pose, fs, fs * 0.9F, fs, -1, light));
		Vec3 back = new Vec3(0, 0, -s * 2.4);
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(armTex),
			(pose, buf) -> Geo.tube(buf, pose, new Vec3(0, 0, -fs * 0.8), back, fs * 1.1F, fs * 1.4F, -1, light));
		// Glowing aura and motion streaks behind the fist.
		int aura = look == Moves.LOOK_GEAR5 ? 0xA0FFF6D0 : look == Moves.LOOK_HAKI || look == Moves.LOOK_GEAR4 ? 0xA0B0103A : 0x70FFFFFF;
		RandomSource random = RandomSource.create(state.seed);
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(WIND), (pose, buf) -> {
			for (int n = 0; n < 8; n++) {
				float a = n / 8.0F * Mth.TWO_PI + state.age * 0.2F;
				float r = fs * (1.1F + random.nextFloat() * 0.4F);
				Vec3 p0 = new Vec3(Mth.cos(a) * r, Mth.sin(a) * r, fs * 0.5);
				Vec3 p1 = new Vec3(Mth.cos(a) * r * 0.6, Mth.sin(a) * r * 0.6, -s * (2.0 + random.nextFloat() * 2.0));
				Geo.beam(buf, pose, p0, p1, new Vec3(0, 0, 50), fs * 0.25F, aura, Geo.alpha(aura, 0.0F), Geo.FULL_BRIGHT);
			}
		});
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(GLOW), (pose, buf) ->
			Geo.billboard(buf, pose, 0, 0, fs * 2.2F, 0, 0, 1, 1, Geo.alpha(aura, 0.6F), Geo.FULL_BRIGHT));
		poseStack.popPose();
	}

	// ------------------------------------------------------------------ swords

	/** A crescent blade of energy, bulging forward along +Z. */
	private static void crescent(VertexConsumer buf, PoseStack.Pose pose, float radius, float thickness, float bulge, int color, int light) {
		int steps = 24;
		for (int n = 0; n < steps; n++) {
			float f0 = n / (float) steps;
			float f1 = (n + 1) / (float) steps;
			float a0 = (f0 - 0.5F) * Mth.PI * 0.9F;
			float a1 = (f1 - 0.5F) * Mth.PI * 0.9F;
			float t0 = Mth.sin(f0 * Mth.PI) * thickness;
			float t1 = Mth.sin(f1 * Mth.PI) * thickness;
			float x0 = Mth.sin(a0) * radius;
			float x1 = Mth.sin(a1) * radius;
			float z0 = Mth.cos(a0) * radius * bulge;
			float z1 = Mth.cos(a1) * radius * bulge;
			Geo.v(buf, pose, x0, 0, z0 - t0, f0, 1, color, light);
			Geo.v(buf, pose, x1, 0, z1 - t1, f1, 1, color, light);
			Geo.v(buf, pose, x1, 0, z1 + t1 * 0.3F, f1, 0, color, light);
			Geo.v(buf, pose, x0, 0, z0 + t0 * 0.3F, f0, 0, color, light);
		}
	}

	private void slash(State state, PoseStack poseStack, SubmitNodeCollector collector, float q) {
		float fade = 1.0F - q * q;
		float grow = 0.75F + 0.25F * Math.min(1.0F, state.age / 4.0F);
		float r = state.size * grow;
		poseStack.pushPose();
		faceDirection(poseStack, state.yaw, state.pitch);
		poseStack.mulPose(Axis.ZP.rotationDegrees(state.spin));
		poseStack.translate(0, 0, -r * 0.6F);
		int color = state.color;
		RenderType outer = glowOrSoft(color, SLASH);
		collector.submitCustomGeometry(poseStack, outer, (pose, buf) ->
			crescent(buf, pose, r, r * 0.22F, 0.55F, Geo.alpha(color, 0.85F * fade), Geo.FULL_BRIGHT));
		poseStack.translate(0, 0.02F, 0);
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(SLASH), (pose, buf) ->
			crescent(buf, pose, r * 0.98F, r * 0.08F, 0.55F, Geo.alpha(0xFFFFFFFF, fade), Geo.FULL_BRIGHT));
		poseStack.translate(0, -0.04F, 0);
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(SLASH), (pose, buf) ->
			crescent(buf, pose, r * 1.05F, r * 0.3F, 0.5F, Geo.alpha(color, 0.35F * fade), Geo.FULL_BRIGHT));
		poseStack.popPose();
	}

	private void slashRing(State state, PoseStack poseStack, SubmitNodeCollector collector, float q) {
		float fade = 1.0F - q;
		float r = state.size * (0.3F + 0.7F * (1 - (1 - q) * (1 - q)));
		int color = state.color;
		for (int k = 0; k < 9; k++) {
			poseStack.pushPose();
			poseStack.mulPose(Axis.YP.rotationDegrees(k * 40.0F + state.age * 12.0F));
			poseStack.mulPose(Axis.ZP.rotationDegrees((k % 3 - 1) * 25.0F));
			poseStack.translate(0, 0, r * 0.4F);
			collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(SLASH), (pose, buf) -> {
				crescent(buf, pose, r * 0.6F, r * 0.12F, 0.5F, Geo.alpha(color, fade), Geo.FULL_BRIGHT);
				crescent(buf, pose, r * 0.58F, r * 0.04F, 0.5F, Geo.alpha(0xFFFFFFFF, fade), Geo.FULL_BRIGHT);
			});
			poseStack.popPose();
		}
	}

	private void tornado(State state, PoseStack poseStack, SubmitNodeCollector collector, float q) {
		float fade = Math.min(1.0F, q * 8.0F) * Math.min(1.0F, (1.0F - q) * 4.0F);
		float height = state.size * 2.6F;
		int color = state.color;
		boolean dark = Geo.luminance(color) < 0.22F;
		RenderType type = dark ? ModRenderTypes.soft(WIND) : ModRenderTypes.glow(WIND);
		collector.submitCustomGeometry(poseStack, type, (pose, buf) -> {
			int ribbons = 7;
			int steps = 28;
			for (int k = 0; k < ribbons; k++) {
				float phase = k * Mth.TWO_PI / ribbons;
				for (int n = 0; n < steps; n++) {
					float f0 = n / (float) steps;
					float f1 = (n + 1) / (float) steps;
					float y0 = f0 * height;
					float y1 = f1 * height;
					float r0 = state.size * (0.25F + f0 * 0.75F);
					float r1 = state.size * (0.25F + f1 * 0.75F);
					float a0 = phase + f0 * 7.0F - state.age * 0.7F;
					float a1 = phase + f1 * 7.0F - state.age * 0.7F;
					float h = height / steps * 2.2F;
					int c = Geo.alpha(color, fade * (0.35F + 0.65F * Mth.sin(f0 * Mth.PI)));
					Geo.v(buf, pose, Mth.cos(a0) * r0, y0, Mth.sin(a0) * r0, f0 * 3, 0, c, Geo.FULL_BRIGHT);
					Geo.v(buf, pose, Mth.cos(a1) * r1, y1, Mth.sin(a1) * r1, f1 * 3, 0, c, Geo.FULL_BRIGHT);
					Geo.v(buf, pose, Mth.cos(a1) * r1, y1 + h, Mth.sin(a1) * r1, f1 * 3, 1, c, Geo.FULL_BRIGHT);
					Geo.v(buf, pose, Mth.cos(a0) * r0, y0 + h, Mth.sin(a0) * r0, f0 * 3, 1, c, Geo.FULL_BRIGHT);
				}
			}
		});
		if (dark) {
			// Black tornado gets a burning purple edge.
			collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(WIND), (pose, buf) -> {
				for (int n = 0; n < 24; n++) {
					float f0 = n / 24.0F;
					float f1 = (n + 1) / 24.0F;
					float a0 = f0 * 9 - state.age * 0.9F;
					float a1 = f1 * 9 - state.age * 0.9F;
					float r0 = state.size * (0.35F + f0 * 0.8F);
					float r1 = state.size * (0.35F + f1 * 0.8F);
					int c = Geo.alpha(0xFFB040FF, fade * 0.8F);
					Geo.v(buf, pose, Mth.cos(a0) * r0, f0 * height, Mth.sin(a0) * r0, f0, 0, c, Geo.FULL_BRIGHT);
					Geo.v(buf, pose, Mth.cos(a1) * r1, f1 * height, Mth.sin(a1) * r1, f1, 0, c, Geo.FULL_BRIGHT);
					Geo.v(buf, pose, Mth.cos(a1) * r1, f1 * height + 0.3F, Mth.sin(a1) * r1, f1, 1, c, Geo.FULL_BRIGHT);
					Geo.v(buf, pose, Mth.cos(a0) * r0, f0 * height + 0.3F, Mth.sin(a0) * r0, f0, 1, c, Geo.FULL_BRIGHT);
				}
			});
		}
	}

	// ------------------------------------------------------------------ rings and bursts

	private static void ring(VertexConsumer buf, PoseStack.Pose pose, float radius, float width, float y, int color) {
		int steps = 48;
		float inner = Math.max(0.0F, radius - width);
		for (int n = 0; n < steps; n++) {
			float a0 = n / (float) steps * Mth.TWO_PI;
			float a1 = (n + 1) / (float) steps * Mth.TWO_PI;
			Geo.v(buf, pose, Mth.cos(a0) * inner, y, Mth.sin(a0) * inner, 0, 0, color, Geo.FULL_BRIGHT);
			Geo.v(buf, pose, Mth.cos(a1) * inner, y, Mth.sin(a1) * inner, 0, 0, color, Geo.FULL_BRIGHT);
			Geo.v(buf, pose, Mth.cos(a1) * radius, y, Mth.sin(a1) * radius, 1, 1, color, Geo.FULL_BRIGHT);
			Geo.v(buf, pose, Mth.cos(a0) * radius, y, Mth.sin(a0) * radius, 1, 1, color, Geo.FULL_BRIGHT);
		}
	}

	private static void wall(VertexConsumer buf, PoseStack.Pose pose, float radius, float height, int color) {
		int steps = 48;
		for (int n = 0; n < steps; n++) {
			float a0 = n / (float) steps * Mth.TWO_PI;
			float a1 = (n + 1) / (float) steps * Mth.TWO_PI;
			Geo.v(buf, pose, Mth.cos(a0) * radius, 0, Mth.sin(a0) * radius, 0, 1, color, Geo.FULL_BRIGHT);
			Geo.v(buf, pose, Mth.cos(a1) * radius, 0, Mth.sin(a1) * radius, 1, 1, color, Geo.FULL_BRIGHT);
			Geo.v(buf, pose, Mth.cos(a1) * radius, height, Mth.sin(a1) * radius, 1, 0, Geo.alpha(color, 0.0F), Geo.FULL_BRIGHT);
			Geo.v(buf, pose, Mth.cos(a0) * radius, height, Mth.sin(a0) * radius, 0, 0, Geo.alpha(color, 0.0F), Geo.FULL_BRIGHT);
		}
	}

	private void shockwave(State state, PoseStack poseStack, SubmitNodeCollector collector, float q) {
		float ease = 1.0F - (1.0F - q) * (1.0F - q) * (1.0F - q);
		float radius = state.size * (0.15F + 0.85F * ease);
		float fade = 1.0F - q;
		int color = state.color;
		RenderType type = glowOrSoft(color, BAND);
		collector.submitCustomGeometry(poseStack, type, (pose, buf) -> {
			ring(buf, pose, radius, Math.max(0.35F, radius * 0.28F), 0.05F, Geo.alpha(color, fade));
			wall(buf, pose, radius * 0.97F, Math.max(0.6F, state.size * 0.18F) * fade, Geo.alpha(color, fade * 0.8F));
		});
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(BAND), (pose, buf) ->
			ring(buf, pose, radius * 0.92F, Math.max(0.12F, radius * 0.06F), 0.07F, Geo.alpha(0xFFFFFFFF, fade * 0.7F)));
	}

	private void fireBurst(State state, PoseStack poseStack, SubmitNodeCollector collector, float q, CameraRenderState camera) {
		RandomSource random = RandomSource.create(state.seed * 7919L);
		int frameBase = (int) (q * 8);
		float s = state.size;
		int color = state.color;
		int count = 6 + (int) Math.min(18, s * 3);
		for (int n = 0; n < count; n++) {
			Vec3 dir = new Vec3(random.nextFloat() - 0.5, random.nextFloat() * 0.7 - 0.15, random.nextFloat() - 0.5).normalize();
			float speed = 0.4F + random.nextFloat() * 0.6F;
			float dist = s * speed * (1 - (1 - q) * (1 - q));
			Vec3 p = dir.scale(dist).add(0, q * s * 0.3, 0);
			float size = s * (0.35F + random.nextFloat() * 0.25F) * (1.0F - q * 0.4F);
			int frame = Math.min(7, frameBase + random.nextInt(2));
			float u0 = frame / 8.0F;
			float u1 = (frame + 1) / 8.0F;
			int c = Geo.alpha(color, (1.0F - q) * 1.2F);
			poseStack.pushPose();
			poseStack.translate(p.x, p.y, p.z);
			poseStack.mulPose(camera.orientation);
			poseStack.mulPose(Axis.ZP.rotationDegrees(random.nextFloat() * 360));
			collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(FIRE), (pose, buf) -> Geo.billboard(buf, pose, 0, 0, size, u0, 0, u1, 1, c, Geo.FULL_BRIGHT));
			poseStack.popPose();
		}
		poseStack.pushPose();
		poseStack.mulPose(camera.orientation);
		int core = Geo.alpha(color, (1.0F - q) * 0.9F);
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(GLOW), (pose, buf) -> Geo.billboard(buf, pose, 0, 0, s * (0.6F + q), 0, 0, 1, 1, core, Geo.FULL_BRIGHT));
		poseStack.popPose();
	}

	private void conqueror(State state, PoseStack poseStack, SubmitNodeCollector collector, float q, Vec3 camRel) {
		float reach = state.size * (1 - (1 - q) * (1 - q));
		float fade = 1.0F - q;
		RandomSource random = RandomSource.create(state.seed * 13L + (long) (state.age / 2.0F));
		int bolts = 14;
		Vec3[][] paths = new Vec3[bolts][];
		for (int k = 0; k < bolts; k++) {
			Vec3 dir = new Vec3(random.nextFloat() - 0.5, (random.nextFloat() - 0.4) * 0.6, random.nextFloat() - 0.5).normalize();
			int steps = 9;
			paths[k] = new Vec3[steps + 1];
			Vec3 p = Vec3.ZERO;
			paths[k][0] = p;
			for (int n = 1; n <= steps; n++) {
				Vec3 jitter = new Vec3(random.nextFloat() - 0.5, random.nextFloat() - 0.5, random.nextFloat() - 0.5).scale(reach * 0.12);
				p = dir.scale(reach * n / steps).add(jitter);
				paths[k][n] = p;
			}
		}
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(WHITE), (pose, buf) -> {
			for (Vec3[] path : paths) {
				for (int n = 0; n < path.length - 1; n++) {
					Geo.beam(buf, pose, path[n], path[n + 1], camRel, 0.55F * (1 - n / (float) path.length) + 0.1F, Geo.alpha(0xFF0A0408, fade), Geo.alpha(0xFF0A0408, fade * 0.8F), Geo.FULL_BRIGHT);
				}
			}
		});
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(GLOW), (pose, buf) -> {
			for (Vec3[] path : paths) {
				for (int n = 0; n < path.length - 1; n++) {
					Geo.beam(buf, pose, path[n], path[n + 1], camRel, 0.22F * (1 - n / (float) path.length) + 0.05F, Geo.alpha(state.color, fade), Geo.alpha(state.color, fade * 0.6F), Geo.FULL_BRIGHT);
				}
			}
		});
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(BAND), (pose, buf) ->
			ring(buf, pose, reach, reach * 0.35F, -0.9F, Geo.alpha(0xFF10040A, fade * 0.7F)));
	}

	private void lightning(State state, PoseStack poseStack, SubmitNodeCollector collector, float q, Vec3 camRel, Vec3 target, float width, int color) {
		float fade = q < 0.7F ? 1.0F : (1.0F - q) / 0.3F;
		RandomSource random = RandomSource.create(state.seed * 17L + (long) (state.age / 1.5F));
		int steps = 14;
		Vec3[] path = new Vec3[steps + 1];
		Vec3 len = target;
		double jitter = Math.max(0.6, len.length() * 0.05);
		for (int n = 0; n <= steps; n++) {
			Vec3 p = target.scale(n / (double) steps);
			if (n > 0 && n < steps) {
				p = p.add(new Vec3(random.nextFloat() - 0.5, random.nextFloat() - 0.5, random.nextFloat() - 0.5).scale(jitter));
			}
			path[n] = p;
		}
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(GLOW), (pose, buf) -> {
			for (int n = 0; n < steps; n++) {
				Geo.beam(buf, pose, path[n], path[n + 1], camRel, 0.9F * width, Geo.alpha(color, fade * 0.7F), Geo.alpha(color, fade * 0.7F), Geo.FULL_BRIGHT);
				Geo.beam(buf, pose, path[n], path[n + 1], camRel, 0.3F * width, Geo.alpha(0xFFFFFFFF, fade), Geo.alpha(0xFFFFFFFF, fade), Geo.FULL_BRIGHT);
				if (n % 4 == 2) {
					Vec3 branch = path[n].add(new Vec3(random.nextFloat() - 0.5, random.nextFloat() - 0.6, random.nextFloat() - 0.5).scale(jitter * 3));
					Geo.beam(buf, pose, path[n], branch, camRel, 0.25F * width, Geo.alpha(color, fade * 0.8F), Geo.alpha(color, 0.0F), Geo.FULL_BRIGHT);
				}
			}
		});
	}

	private void impact(State state, PoseStack poseStack, SubmitNodeCollector collector, float q, CameraRenderState camera) {
		float s = state.size * (0.5F + 1.1F * (1 - (1 - q) * (1 - q)));
		float fade = 1.0F - q;
		poseStack.pushPose();
		poseStack.mulPose(camera.orientation);
		poseStack.mulPose(Axis.ZP.rotationDegrees(state.seed * 37 % 360));
		int color = Geo.luminance(state.color) < 0.22F ? 0xFFB0103A : state.color;
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(IMPACT), (pose, buf) -> {
			Geo.billboard(buf, pose, 0, 0, s, 0, 0, 1, 1, Geo.alpha(color, fade), Geo.FULL_BRIGHT);
			Geo.billboard(buf, pose, 0, 0, s * 0.55F, 0, 0, 1, 1, Geo.alpha(0xFFFFFFFF, fade), Geo.FULL_BRIGHT);
		});
		poseStack.popPose();
	}

	private void cloud(State state, PoseStack poseStack, SubmitNodeCollector collector, float q, CameraRenderState camera) {
		RandomSource random = RandomSource.create(state.seed * 4513L);
		float s = state.size;
		int count = 8 + (int) Math.min(16, s * 2);
		for (int n = 0; n < count; n++) {
			double a = random.nextFloat() * Math.PI * 2;
			float speed = 0.5F + random.nextFloat() * 0.5F;
			float dist = s * speed * (1 - (1 - q) * (1 - q));
			Vec3 p = new Vec3(Math.cos(a) * dist, random.nextFloat() * s * 0.4 + q * 0.5, Math.sin(a) * dist);
			float size = s * (0.3F + random.nextFloat() * 0.3F) * (0.6F + q * 0.6F);
			int c = Geo.alpha(state.color, (1.0F - q) * 0.9F);
			poseStack.pushPose();
			poseStack.translate(p.x, p.y, p.z);
			poseStack.mulPose(camera.orientation);
			poseStack.mulPose(Axis.ZP.rotationDegrees(random.nextFloat() * 360 + state.age * 2));
			collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(CLOUD), (pose, buf) -> Geo.billboard(buf, pose, 0, 0, size, 0, 0, 1, 1, c, Geo.FULL_BRIGHT));
			poseStack.popPose();
		}
	}

	private void dragon(State state, PoseStack poseStack, SubmitNodeCollector collector, float q, CameraRenderState camera) {
		float s = state.size;
		poseStack.pushPose();
		faceDirection(poseStack, state.yaw, state.pitch);
		// Serpent body: fire sprites trailing behind along a sine wave.
		for (int n = 0; n < 16; n++) {
			float f = n / 16.0F;
			float wave = Mth.sin(state.age * 0.5F - n * 0.55F) * s * 0.4F;
			float lift = Mth.cos(state.age * 0.35F - n * 0.5F) * s * 0.25F;
			Vec3 p = new Vec3(wave, lift, -n * s * 0.35F);
			float size = s * 0.45F * (1.0F - f * 0.7F);
			int frame = (int) (state.age * 0.5F + n) % 8;
			int c = Geo.alpha(n < 2 ? 0xFFFFE0A0 : state.color, 1.0F - f * 0.6F);
			poseStack.pushPose();
			poseStack.translate(p.x, p.y, p.z);
			poseStack.mulPose(Axis.XP.rotationDegrees(-state.pitch));
			poseStack.mulPose(Axis.YP.rotationDegrees(state.yaw));
			poseStack.mulPose(camera.orientation);
			collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(FIRE), (pose, buf) -> Geo.billboard(buf, pose, 0, 0, size, frame / 8.0F, 0, (frame + 1) / 8.0F, 1, c, Geo.FULL_BRIGHT));
			poseStack.popPose();
		}
		// Slash at the dragon's head.
		poseStack.translate(0, 0, s * 0.2F);
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(SLASH), (pose, buf) -> {
			crescent(buf, pose, s * 0.7F, s * 0.15F, 0.6F, Geo.alpha(0xFFFFB060, 0.9F), Geo.FULL_BRIGHT);
		});
		poseStack.popPose();
	}

	private void dashTrail(State state, PoseStack poseStack, SubmitNodeCollector collector, float q, Vec3 camRel) {
		float fade = 1.0F - q;
		Vec3 end = state.target;
		RandomSource random = RandomSource.create(state.seed * 101L);
		int color = state.color;
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(GLOW), (pose, buf) -> {
			for (int n = 0; n < 9; n++) {
				Vec3 off = new Vec3(random.nextFloat() - 0.5, (random.nextFloat() - 0.5) * 1.6, random.nextFloat() - 0.5).scale(0.9);
				float from = random.nextFloat() * 0.3F + q * 0.5F;
				Vec3 a = end.scale(from).add(off);
				Vec3 b = end.scale(Math.min(1.0F, from + 0.5F)).add(off);
				Geo.beam(buf, pose, a, b, camRel, 0.12F + random.nextFloat() * 0.1F, Geo.alpha(color, 0.0F), Geo.alpha(color, fade), Geo.FULL_BRIGHT);
			}
			Geo.beam(buf, pose, Vec3.ZERO, end, camRel, 0.7F * fade, Geo.alpha(color, 0.0F), Geo.alpha(color, fade * 0.6F), Geo.FULL_BRIGHT);
		});
	}
}
