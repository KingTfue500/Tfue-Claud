package com.tfue.onepiece.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import com.tfue.onepiece.power.Fighter;
import com.tfue.onepiece.power.Form;
import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.client.renderer.entity.state.LivingEntityRenderState;
import net.minecraft.client.renderer.state.level.CameraRenderState;
import net.minecraft.resources.Identifier;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.phys.Vec3;

/**
 * World-space form auras drawn around a player or boss: Gear 2 steam, Gear 4 shoulder steam,
 * Gear 5's cloud scarf and sun glow, Asura's dark flames, King of Hell's purple fire, Ifrit's blue heat.
 */
public final class AuraRenderer {
	private static final Identifier CLOUD = ModRenderTypes.tex("cloud");
	private static final Identifier FIRE = ModRenderTypes.tex("fire");
	private static final Identifier GLOW = ModRenderTypes.tex("glow");

	private AuraRenderer() {
	}

	public static void submit(LivingEntityRenderState state, PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera) {
		PowerRenderInfo info = state.getData(PowerRenderInfo.KEY);
		if (info == null || info.firstPersonSelf()) {
			return;
		}
		float t = info.time();
		float h = state.boundingBoxHeight;
		float w = state.boundingBoxWidth / 0.6F;
		float yaw = state.bodyRot * Mth.DEG_TO_RAD;
		Vec3 right = new Vec3(-Mth.cos(yaw), 0, -Mth.sin(yaw));
		switch (info.form()) {
			case GEAR_2 -> {
				steam(poseStack, collector, camera, t, h, w * 1.5F, Vec3.ZERO, 0xFFFFE8F0, 18, 0.6F);
				glow(poseStack, collector, camera, new Vec3(0, h * 0.55, 0), h * 0.7F, 0x30FF6B8A);
			}
			case GEAR_4_BOUNDMAN, GEAR_4_TANKMAN -> {
				steam(poseStack, collector, camera, t, h, w * 0.4F, right.scale(0.45 * w).add(0, h * 0.75, 0), 0xFFF2E6E6, 6, 0.3F);
				steam(poseStack, collector, camera, t + 7, h, w * 0.4F, right.scale(-0.45 * w).add(0, h * 0.75, 0), 0xFFF2E6E6, 6, 0.3F);
				glow(poseStack, collector, camera, new Vec3(0, h * 0.5, 0), h * 0.6F, 0x40B0103A);
			}
			case GEAR_4_SNAKEMAN -> {
				flames(poseStack, collector, camera, t, h, w, 0xC0D0203A, 10, true);
				steam(poseStack, collector, camera, t, h, w * 0.4F, new Vec3(0, h * 0.8, 0), 0xFFF2E6E6, 5, 0.25F);
			}
			case GEAR_5 -> {
				cloudScarf(poseStack, collector, camera, t, h, w);
				drumBeat(poseStack, collector, t, w);
				glow(poseStack, collector, camera, new Vec3(0, h * 0.6, 0), h * (0.85F + Mth.sin(t * 0.1F) * 0.05F), 0x40FFF2C0);
			}
			case ASURA -> {
				flames(poseStack, collector, camera, t, h, w * 1.4F, 0xB08A5AD8, 16, false);
				smoke(poseStack, collector, camera, t, h, w * 1.3F, 0x90201030);
			}
			case KING_OF_HELL -> {
				flames(poseStack, collector, camera, t, h, w * 1.2F, 0xC0B040FF, 18, false);
				smoke(poseStack, collector, camera, t, h, w, 0xA0100818);
				glow(poseStack, collector, camera, new Vec3(0, h * 0.5, 0), h * 0.7F, 0x40B040FF);
			}
			case DIABLE_JAMBE -> glow(poseStack, collector, camera, right.scale(-0.12 * w).add(0, h * 0.25, 0), h * 0.35F, 0x60FF6A1A);
			case IFRIT_JAMBE -> {
				flames(poseStack, collector, camera, t, h * 0.6F, w * 0.8F, 0x9045B5FF, 10, false);
				glow(poseStack, collector, camera, new Vec3(0, h * 0.3, 0), h * 0.5F, 0x5045B5FF);
			}
			case KAIDO_HYBRID -> {
				flames(poseStack, collector, camera, t, h, w, 0xB04F8BFF, 14, false);
				feetClouds(poseStack, collector, camera, t, w);
			}
			case BASE_KAIDO -> smoke(poseStack, collector, camera, t, h, w * 0.8F, 0x40303040);
			case KATAKURI_AWAKENED -> {
				steam(poseStack, collector, camera, t, h, w * 0.7F, Vec3.ZERO, 0xFFFFF0F6, 14, 0.6F);
				glow(poseStack, collector, camera, new Vec3(0, h * 0.5, 0), h * 0.6F, 0x40FF66AA);
			}
			case LUCCI_AWAKENED -> {
				flames(poseStack, collector, camera, t, h, w, 0xB0FF4A30, 14, false);
				mane(poseStack, collector, camera, t, h, w, yaw);
			}
			default -> {
			}
		}
		if (info.armament() && info.form() != Form.RAID_SUIT) {
			hakiSparks(poseStack, collector, camera, t, h, w, right, info.fighter() == Fighter.SANJI);
		}
	}

	private static void sprite(PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera, Identifier texture, boolean additive,
		Vec3 p, float size, float roll, float u0, float u1, int color) {
		poseStack.pushPose();
		poseStack.translate(p.x, p.y, p.z);
		poseStack.mulPose(camera.orientation);
		poseStack.mulPose(Axis.ZP.rotationDegrees(roll));
		collector.submitCustomGeometry(poseStack, additive ? ModRenderTypes.glow(texture) : ModRenderTypes.soft(texture),
			(pose, buf) -> Geo.billboard(buf, pose, 0, 0, size, u0, 0, u1, 1, color, Geo.FULL_BRIGHT));
		poseStack.popPose();
	}

	private static void glow(PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera, Vec3 p, float size, int color) {
		sprite(poseStack, collector, camera, GLOW, true, p, size, 0, 0, 1, color);
	}

	private static void steam(PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera, float t, float h, float w, Vec3 origin, int color, int count, float spread) {
		for (int n = 0; n < count; n++) {
			float phase = (t * 0.035F + n / (float) count) % 1.0F;
			float angle = n * 2.39996F + t * 0.01F;
			float r = spread * w * (0.5F + phase * 0.6F);
			Vec3 base = origin.equals(Vec3.ZERO) ? new Vec3(0, h * (0.15 + 0.7 * ((n * 0.37F) % 1.0F)), 0) : origin;
			Vec3 p = base.add(Mth.cos(angle) * r, phase * h * 0.6, Mth.sin(angle) * r);
			float size = (0.12F + phase * 0.32F) * Math.max(1.0F, w * 0.8F);
			sprite(poseStack, collector, camera, CLOUD, false, p, size, angle * 57 + t * 2, 0, 1, Geo.alpha(color, (1.0F - phase) * 0.55F));
		}
	}

	private static void flames(PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera, float t, float h, float w, int color, int count, boolean backOnly) {
		for (int n = 0; n < count; n++) {
			float phase = (t * 0.05F + n / (float) count) % 1.0F;
			float angle = n * 2.39996F;
			float r = 0.35F * w;
			Vec3 p = new Vec3(Mth.cos(angle) * r, h * (0.1 + 0.85 * ((n * 0.61F) % 1.0F)) + phase * 0.6, Mth.sin(angle) * r);
			int frame = (int) (t * 0.6F + n * 3) % 8;
			float size = 0.25F + 0.2F * Mth.sin(phase * Mth.PI);
			sprite(poseStack, collector, camera, FIRE, true, p, size * Math.max(1.0F, w * 0.6F), 0, frame / 8.0F, (frame + 1) / 8.0F, Geo.alpha(color, Mth.sin(phase * Mth.PI)));
		}
	}

	private static void smoke(PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera, float t, float h, float w, int color) {
		for (int n = 0; n < 8; n++) {
			float phase = (t * 0.02F + n / 8.0F) % 1.0F;
			float angle = n * 2.39996F + t * 0.02F;
			Vec3 p = new Vec3(Mth.cos(angle) * 0.45 * w, phase * h * 1.1, Mth.sin(angle) * 0.45 * w);
			sprite(poseStack, collector, camera, CLOUD, false, p, 0.3F + phase * 0.4F, angle * 40, 0, 1, Geo.alpha(color, Mth.sin(phase * Mth.PI) * 0.8F));
		}
	}

	private static void cloudScarf(PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera, float t, float h, float w) {
		// Gear 5's ring of clouds around the shoulders, slowly drifting.
		int count = 14;
		for (int n = 0; n < count; n++) {
			float a = n / (float) count * Mth.TWO_PI + t * 0.02F;
			float wobble = Mth.sin(t * 0.08F + n) * 0.04F;
			float r = 0.42F * w + wobble;
			Vec3 p = new Vec3(Mth.cos(a) * r, h * 0.76 + Mth.sin(a * 2 + t * 0.05F) * 0.05, Mth.sin(a) * r);
			sprite(poseStack, collector, camera, CLOUD, false, p, 0.2F * w + wobble, a * 57, 0, 1, 0xF0FFFFFF);
		}
		// Trailing wisps rising off the clouds.
		for (int n = 0; n < 6; n++) {
			float phase = (t * 0.03F + n / 6.0F) % 1.0F;
			float a = n * 1.7F;
			Vec3 p = new Vec3(Mth.cos(a) * 0.5 * w, h * 0.8 + phase * 0.9, Mth.sin(a) * 0.5 * w);
			sprite(poseStack, collector, camera, CLOUD, false, p, 0.12F + phase * 0.2F, a * 57, 0, 1, Geo.alpha(0xFFFFFFFF, (1 - phase) * 0.6F));
		}
	}

	private static void hakiSparks(PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera, float t, float h, float w, Vec3 right, boolean legs) {
		RandomSource random = RandomSource.create((long) (t * 0.5F));
		Vec3 camRel = camera.pos;
		for (int side = -1; side <= 1; side += 2) {
			Vec3 at = legs ? right.scale(side * 0.12 * w).add(0, h * 0.2, 0) : right.scale(side * 0.4 * w).add(0, h * 0.45, 0);
			if (random.nextFloat() < 0.6F) {
				Vec3 a = at.add((random.nextFloat() - 0.5) * 0.3, (random.nextFloat() - 0.5) * 0.4, (random.nextFloat() - 0.5) * 0.3);
				Vec3 b = a.add((random.nextFloat() - 0.5) * 0.4, (random.nextFloat() - 0.5) * 0.4, (random.nextFloat() - 0.5) * 0.4);
				Vec3 c = b.add((random.nextFloat() - 0.5) * 0.3, (random.nextFloat() - 0.5) * 0.3, (random.nextFloat() - 0.5) * 0.3);
				collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(ModRenderTypes.tex("beam")), (pose, buf) -> {
					Geo.beam(buf, pose, a, b, new Vec3(0, 100, 0), 0.05F, 0xFFC060FF, 0xFFC060FF, Geo.FULL_BRIGHT);
					Geo.beam(buf, pose, b, c, new Vec3(0, 100, 0), 0.04F, 0xFFC060FF, 0x00C060FF, Geo.FULL_BRIGHT);
					Geo.beam(buf, pose, a, b, new Vec3(100, 0, 0), 0.05F, 0xFFC060FF, 0xFFC060FF, Geo.FULL_BRIGHT);
				});
			}
		}
	}

	/** The Drums of Liberation: a soft ring pulses out from Gear 5 Luffy's feet with every beat. */
	private static void drumBeat(PoseStack poseStack, SubmitNodeCollector collector, float t, float w) {
		float beat = (t % 30.0F) / 30.0F;
		float r = (0.4F + beat * 2.2F) * w;
		int color = Geo.alpha(0xFFFFF6D8, (1.0F - beat) * 0.7F);
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(ModRenderTypes.tex("band")), (pose, buf) -> {
			int steps = 40;
			float inner = r * 0.82F;
			for (int n = 0; n < steps; n++) {
				float a0 = n / (float) steps * Mth.TWO_PI;
				float a1 = (n + 1) / (float) steps * Mth.TWO_PI;
				Geo.v(buf, pose, Mth.cos(a0) * inner, 0.05F, Mth.sin(a0) * inner, 0, 0, color, Geo.FULL_BRIGHT);
				Geo.v(buf, pose, Mth.cos(a1) * inner, 0.05F, Mth.sin(a1) * inner, 0, 0, color, Geo.FULL_BRIGHT);
				Geo.v(buf, pose, Mth.cos(a1) * r, 0.05F, Mth.sin(a1) * r, 1, 1, color, Geo.FULL_BRIGHT);
				Geo.v(buf, pose, Mth.cos(a0) * r, 0.05F, Mth.sin(a0) * r, 1, 1, color, Geo.FULL_BRIGHT);
			}
		});
	}

	private static void feetClouds(PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera, float t, float w) {
		for (int n = 0; n < 6; n++) {
			float a = n / 6.0F * Mth.TWO_PI + t * 0.03F;
			Vec3 p = new Vec3(Mth.cos(a) * 0.4 * w, 0.1, Mth.sin(a) * 0.4 * w);
			int frame = (int) (t * 0.5F + n * 2) % 8;
			sprite(poseStack, collector, camera, FIRE, true, p, 0.3F * w, 0, frame / 8.0F, (frame + 1) / 8.0F, 0xC0FF8A30);
			sprite(poseStack, collector, camera, CLOUD, false, p.add(0, -0.05, 0), 0.28F * w, a * 57, 0, 1, 0xA0F0E8E0);
		}
	}

	private static void mane(PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera, float t, float h, float w, float yaw) {
		Vec3 back = new Vec3(Mth.sin(yaw), 0, -Mth.cos(yaw));
		Vec3 side = new Vec3(-Mth.cos(yaw), 0, -Mth.sin(yaw));
		// Awakened Lucci's flowing white mane.
		for (int n = 0; n < 10; n++) {
			float phase = (t * 0.04F + n / 10.0F) % 1.0F;
			float a = n * 0.63F - 1.4F;
			Vec3 p = side.scale(Mth.sin(a) * 0.25 * w).add(back.scale(0.15 * w + phase * 0.5 * w)).add(0, h * (0.86 - phase * 0.3), 0);
			sprite(poseStack, collector, camera, CLOUD, false, p, 0.16F * w * (1 + phase), a * 57 + t, 0, 1, Geo.alpha(0xFFFFFFFF, (1 - phase) * 0.85F));
		}
	}
}
