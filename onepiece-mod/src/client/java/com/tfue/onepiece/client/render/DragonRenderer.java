package com.tfue.onepiece.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import com.tfue.onepiece.power.Anim;
import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.client.renderer.entity.state.LivingEntityRenderState;
import net.minecraft.client.renderer.state.level.CameraRenderState;
import net.minecraft.resources.Identifier;
import net.minecraft.util.Mth;
import net.minecraft.world.phys.Vec3;

/**
 * Kaido's Azure Dragon form: a long serpentine dragon built from segments that ripple through the air,
 * with horns, whiskers, a flowing mane, small clawed arms and the flame clouds it rides on.
 */
public final class DragonRenderer {
	private static final Identifier SCALES = ModRenderTypes.tex("dragon_scales");
	private static final Identifier BELLY = ModRenderTypes.tex("dragon_belly");
	private static final Identifier HORN = ModRenderTypes.tex("horn");
	private static final Identifier MANE = ModRenderTypes.tex("mane");
	private static final Identifier FIRE = ModRenderTypes.tex("fire");
	private static final Identifier CLOUD = ModRenderTypes.tex("cloud");
	private static final Identifier GLOW = ModRenderTypes.tex("glow");
	private static final int SEGMENTS = 26;

	private DragonRenderer() {
	}

	public static void submit(LivingEntityRenderState state, PowerRenderInfo info, PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera) {
		float h = state.boundingBoxHeight;
		float t = info.time();
		int light = state.lightCoords;
		poseStack.pushPose();
		poseStack.mulPose(Axis.YP.rotationDegrees(-state.bodyRot));

		// Spine: head at the front, body trailing back and curling.
		Vec3[] spine = new Vec3[SEGMENTS + 1];
		for (int n = 0; n <= SEGMENTS; n++) {
			float f = n / (float) SEGMENTS;
			double x = Mth.sin(t * 0.09F + n * 0.42F) * 0.32 * h * f;
			double y = h * 0.62 + Mth.sin(t * 0.07F + n * 0.33F) * 0.2 * h * f + f * f * h * 0.35;
			double z = h * 0.35 - n * 0.2 * h * (1.0 - f * 0.25);
			spine[n] = new Vec3(x, y, z);
		}
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(SCALES), (pose, buf) -> {
			for (int n = 1; n < SEGMENTS; n++) {
				float f = n / (float) SEGMENTS;
				float w = h * 0.2F * (1.0F - f * 0.75F);
				float wNext = h * 0.2F * (1.0F - (n + 1) / (float) SEGMENTS * 0.75F);
				Geo.roundTube(buf, pose, spine[n], spine[n + 1], w * 0.55F, wNext * 0.55F, 10, w * 1.2F, 0xFFFFFFFF, light);
			}
		});
		// Lighter belly plates under the front half.
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(BELLY), (pose, buf) -> {
			for (int n = 1; n < SEGMENTS / 2; n++) {
				float f = n / (float) SEGMENTS;
				float w = h * 0.2F * (1.0F - f * 0.75F);
				Vec3 down = new Vec3(0, -w * 0.32, 0);
				Geo.roundTube(buf, pose, spine[n].add(down), spine[n + 1].add(down), w * 0.42F, w * 0.4F, 8, w, 0xFFFFFFFF, light);
			}
		});
		// Mane spikes along the back.
		int frame = (int) (t * 0.4F) % 8;
		for (int n = 1; n < SEGMENTS - 2; n += 2) {
			float f = n / (float) SEGMENTS;
			float w = h * 0.2F * (1.0F - f * 0.75F);
			poseStack.pushPose();
			poseStack.translate(spine[n].x, spine[n].y + w * 0.4, spine[n].z);
			poseStack.mulPose(Axis.XP.rotationDegrees(180.0F));
			poseStack.mulPose(Axis.XP.rotationDegrees(-35.0F));
			float mh = w * (1.4F + Mth.sin(t * 0.2F + n) * 0.15F);
			collector.submitCustomGeometry(poseStack, ModRenderTypes.flat(MANE), (pose, buf) -> Geo.crossed(buf, pose, w * 0.45F, -mh, 0, 1, 0xFFFFFFFF, light));
			poseStack.popPose();
		}
		// Small clawed arms.
		for (int leg : new int[] {3, 10}) {
			for (int side = -1; side <= 1; side += 2) {
				float w = h * 0.2F * (1.0F - leg / (float) SEGMENTS * 0.75F);
				Vec3 root = spine[leg].add(side * w * 0.5, -w * 0.2, 0);
				Vec3 knee = root.add(side * w * 0.6, -w * 0.9, w * 0.2 * Mth.sin(t * 0.1F + leg));
				Vec3 foot = knee.add(side * w * 0.1, -w * 0.4, -w * 0.5);
				collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(SCALES), (pose, buf) -> {
					Geo.tube(buf, pose, root, knee, w * 0.32F, w * 0.4F, 0xFFFFFFFF, light);
					Geo.tube(buf, pose, knee, foot, w * 0.26F, w * 0.4F, 0xFFFFFFFF, light);
				});
				collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(HORN), (pose, buf) -> {
					for (int c = -1; c <= 1; c++) {
						Geo.tube(buf, pose, foot, foot.add(c * w * 0.12, -w * 0.12, -w * 0.3), w * 0.07F, w * 0.2F, 0xFFFFFFFF, light);
					}
				});
			}
		}
		head(state, info, poseStack, collector, camera, spine[0], spine[1], h, t, light);
		// Flame clouds the dragon rides on.
		for (int n = 0; n < SEGMENTS; n += 3) {
			float f = n / (float) SEGMENTS;
			float w = h * 0.2F * (1.0F - f * 0.75F);
			for (int k = 0; k < 2; k++) {
				Vec3 at = spine[n].add((k - 0.5) * w * 1.2, -w * (1.0 + 0.2 * Mth.sin(t * 0.2F + n)), 0);
				int fr = (frame + n + k * 3) % 8;
				sprite(poseStack, collector, camera, FIRE, true, at, w * 0.8F, fr / 8.0F, (fr + 1) / 8.0F, 0xD0FF8A30);
				sprite(poseStack, collector, camera, CLOUD, false, at.add(0, -w * 0.3, 0), w * 0.7F, 0, 1, 0xC0F0E8E0);
			}
		}
		poseStack.popPose();
	}

	private static void head(LivingEntityRenderState state, PowerRenderInfo info, PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera,
		Vec3 neck, Vec3 behind, float h, float t, int light) {
		float s = h * 0.13F;
		poseStack.pushPose();
		poseStack.translate(neck.x, neck.y, neck.z);
		poseStack.mulPose(Axis.YP.rotationDegrees(-state.yRot));
		poseStack.mulPose(Axis.XP.rotationDegrees(state.xRot * 0.6F));
		boolean breathing = info.animating() && info.anim() == Anim.BREATH;
		float jaw = breathing ? 25.0F : 6.0F + Mth.sin(t * 0.1F) * 3.0F;
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(SCALES), (pose, buf) -> {
			Geo.box(buf, pose, -s * 1.1F, -s * 0.8F, -s * 0.6F, s * 1.1F, s * 0.9F, s * 1.6F, 0xFFFFFFFF, light);
			Geo.box(buf, pose, -s * 0.75F, -s * 0.45F, s * 1.6F, s * 0.75F, s * 0.55F, s * 3.2F, 0xFFFFFFFF, light);
			Geo.box(buf, pose, -s * 0.3F, s * 0.55F, s * 2.6F, -s * 0.1F, s * 0.75F, s * 3.0F, 0xFF2A3A80, light);
			Geo.box(buf, pose, s * 0.1F, s * 0.55F, s * 2.6F, s * 0.3F, s * 0.75F, s * 3.0F, 0xFF2A3A80, light);
		});
		// Lower jaw, opens wide for Bolo Breath.
		poseStack.pushPose();
		poseStack.translate(0, -s * 0.45F, s * 1.4F);
		poseStack.mulPose(Axis.XP.rotationDegrees(jaw));
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(SCALES), (pose, buf) ->
			Geo.box(buf, pose, -s * 0.65F, -s * 0.35F, 0, s * 0.65F, 0, s * 1.7F, 0xFFD0D8FF, light));
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(HORN), (pose, buf) -> {
			for (int n = 0; n < 5; n++) {
				float x = (n - 2) * s * 0.28F;
				Geo.box(buf, pose, x - s * 0.06F, 0, s * 1.5F, x + s * 0.06F, s * 0.18F, s * 1.62F, 0xFFFFFFFF, light);
			}
		});
		poseStack.popPose();
		// Horns sweeping back.
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(HORN), (pose, buf) -> {
			for (int side = -1; side <= 1; side += 2) {
				Vec3 a = new Vec3(side * s * 0.7, s * 0.8, s * 0.2);
				Vec3 b = a.add(side * s * 0.5, s * 1.1, -s * 1.4);
				Vec3 c = b.add(side * s * 0.3, s * 0.5, -s * 1.8);
				Geo.roundTube(buf, pose, a, b, s * 0.18F, s * 0.13F, 6, s * 0.6F, 0xFFFFFFFF, light);
				Geo.roundTube(buf, pose, b, c, s * 0.13F, s * 0.03F, 6, s * 0.6F, 0xFFF0E8D8, light);
			}
		});
		// Whiskers drifting in the wind.
		collector.submitCustomGeometry(poseStack, ModRenderTypes.flat(MANE), (pose, buf) -> {
			for (int side = -1; side <= 1; side += 2) {
				Vec3 prev = new Vec3(side * s * 0.7, s * 0.1, s * 3.0);
				for (int n = 1; n <= 6; n++) {
					Vec3 next = prev.add(side * s * 0.45, -s * 0.15 + Mth.sin(t * 0.15F + n * 0.7F + side) * s * 0.25, -s * 0.5);
					Geo.tube(buf, pose, prev, next, s * 0.08F, s * 0.5F, 0xFFFFFFFF, light);
					prev = next;
				}
			}
		});
		// Glowing eyes.
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(GLOW), (pose, buf) -> {
			for (int side = -1; side <= 1; side += 2) {
				float x = side * s * 0.75F;
				Geo.v(buf, pose, x - s * 0.22F, s * 0.25F, s * 1.65F, 0, 0, 0xFFFFE040, Geo.FULL_BRIGHT);
				Geo.v(buf, pose, x + s * 0.22F, s * 0.25F, s * 1.65F, 1, 0, 0xFFFFE040, Geo.FULL_BRIGHT);
				Geo.v(buf, pose, x + s * 0.22F, s * 0.6F, s * 1.65F, 1, 1, 0xFFFFE040, Geo.FULL_BRIGHT);
				Geo.v(buf, pose, x - s * 0.22F, s * 0.6F, s * 1.65F, 0, 1, 0xFFFFE040, Geo.FULL_BRIGHT);
			}
		});
		if (breathing) {
			poseStack.translate(0, -s * 0.2F, s * 3.4F);
			poseStack.mulPose(camera.orientation);
			collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(GLOW), (pose, buf) -> Geo.billboard(buf, pose, 0, 0, s * 2.2F, 0, 0, 1, 1, 0xC0FF9A30, Geo.FULL_BRIGHT));
		}
		poseStack.popPose();
	}

	private static void sprite(PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera, Identifier texture, boolean additive,
		Vec3 p, float size, float u0, float u1, int color) {
		poseStack.pushPose();
		poseStack.translate(p.x, p.y, p.z);
		poseStack.mulPose(camera.orientation);
		collector.submitCustomGeometry(poseStack, additive ? ModRenderTypes.glow(texture) : ModRenderTypes.flat(texture),
			(pose, buf) -> Geo.billboard(buf, pose, 0, 0, size, u0, 0, u1, 1, color, Geo.FULL_BRIGHT));
		poseStack.popPose();
	}
}
