package com.tfue.onepiece.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import com.tfue.onepiece.power.Anim;
import com.tfue.onepiece.power.Fighter;
import com.tfue.onepiece.power.Form;
import com.tfue.onepiece.registry.ModItems;
import net.minecraft.client.model.geom.EntityModelSet;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.player.PlayerModel;
import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.client.renderer.entity.LivingEntityRenderer;
import net.minecraft.client.renderer.entity.RenderLayerParent;
import net.minecraft.client.renderer.entity.layers.RenderLayer;
import net.minecraft.client.renderer.entity.state.AvatarRenderState;
import net.minecraft.client.renderer.rendertype.RenderTypes;
import net.minecraft.resources.Identifier;
import net.minecraft.util.Mth;
import net.minecraft.world.phys.Vec3;

/**
 * Everything attached to a fighter's body: Armament Haki coating, Asura's ghost heads and arms, Zoro's extra
 * katanas, the 3D Straw Hat, Sanji's burning legs, Gear 5's flame hair, Kaido's horns and club, Katakuri's
 * scarf and trident, Lucci's top hat, ears and tail, and glowing eyes for awakened forms.
 */
public class FormLayer extends RenderLayer<AvatarRenderState, PlayerModel> {
	private static final float PX = 1.0F / 16.0F;
	private static final Identifier HAKI = Identifier.fromNamespaceAndPath("onepiece", "textures/entity/haki_overlay.png");
	private static final Identifier WHITE = ModRenderTypes.tex("white");
	private static final Identifier FIRE = ModRenderTypes.tex("fire");
	private static final Identifier GLOW = ModRenderTypes.tex("glow");
	private static final Identifier STRAW = ModRenderTypes.tex("straw");
	private static final Identifier HORN = ModRenderTypes.tex("horn");
	private static final Identifier CLUB = ModRenderTypes.tex("club");
	private static final Identifier SCARF = ModRenderTypes.tex("scarf");
	private static final Identifier FUR = ModRenderTypes.tex("fur");

	private final OverlayPlayerModel hakiArms;
	private final OverlayPlayerModel hakiLegs;
	private final OverlayPlayerModel ghostLeft;
	private final OverlayPlayerModel ghostRight;

	public FormLayer(RenderLayerParent<AvatarRenderState, PlayerModel> parent, EntityModelSet models) {
		super(parent);
		this.hakiArms = new OverlayPlayerModel(models.bakeLayer(ModModelLayers.HAKI), OverlayPlayerModel.ARMS, 0.0F);
		this.hakiLegs = new OverlayPlayerModel(models.bakeLayer(ModModelLayers.HAKI), OverlayPlayerModel.LEGS, 0.0F);
		this.ghostLeft = new OverlayPlayerModel(models.bakeLayer(ModModelLayers.GHOST), OverlayPlayerModel.HEAD | OverlayPlayerModel.ARMS, -0.95F);
		this.ghostRight = new OverlayPlayerModel(models.bakeLayer(ModModelLayers.GHOST), OverlayPlayerModel.HEAD | OverlayPlayerModel.ARMS, 0.95F);
	}

	@Override
	public void submit(PoseStack poseStack, SubmitNodeCollector collector, int light, AvatarRenderState state, float yRot, float xRot) {
		PlayerModel m = this.getParentModel();
		if (state.headEquipment.is(ModItems.STRAW_HAT)) {
			part(poseStack, m.head, () -> strawHat(poseStack, collector, light));
		}
		PowerRenderInfo info = state.getData(PowerRenderInfo.KEY);
		if (info == null || state.isInvisible) {
			return;
		}
		int overlay = LivingEntityRenderer.getOverlayCoords(state, 0.0F);
		Form form = info.form();
		float t = info.time();

		if (info.armament() && !form.isGear4()) {
			OverlayPlayerModel coat = info.fighter() == Fighter.SANJI ? this.hakiLegs : this.hakiArms;
			collector.submitModel(coat, state, poseStack, RenderTypes.entityTranslucent(HAKI), light, overlay, -1, null, state.outlineColor, null);
		}

		switch (info.fighter()) {
			case LUFFY -> {
				if (state.headEquipment.isEmpty()) {
					part(poseStack, m.head, () -> strawHat(poseStack, collector, light));
				}
				if (form == Form.GEAR_5) {
					part(poseStack, m.head, () -> flameHair(poseStack, collector, t, 0xF0FFFFFF, 1.0F));
				}
			}
			case ZORO -> zoro(poseStack, collector, light, overlay, state, info, m);
			case SANJI -> {
				if (form == Form.DIABLE_JAMBE) {
					part(poseStack, m.rightLeg, () -> legFlames(poseStack, collector, t, 0xFFFF7A1A, 1.0F));
				} else if (form == Form.IFRIT_JAMBE) {
					part(poseStack, m.rightLeg, () -> legFlames(poseStack, collector, t, 0xFF45B5FF, 1.35F));
					part(poseStack, m.leftLeg, () -> legFlames(poseStack, collector, t + 3, 0xFF45B5FF, 1.35F));
					part(poseStack, m.head, () -> flameHair(poseStack, collector, t, 0xA045B5FF, 0.7F));
				}
			}
			case KAIDO -> {
				float horns = form == Form.KAIDO_HYBRID ? 0.85F : 0.6F;
				part(poseStack, m.head, () -> kaidoHorns(poseStack, collector, light, horns));
				if (info.anim() != Anim.BREATH) {
					part(poseStack, m.rightArm, () -> club(poseStack, collector, light, info.armament()));
				}
				if (form == Form.KAIDO_HYBRID) {
					part(poseStack, m.head, () -> eyes(poseStack, collector, 0xFFFFD040));
				}
			}
			case KATAKURI -> {
				part(poseStack, m.head, () -> scarf(poseStack, collector, light));
				boolean punching = info.animating() && info.anim() != Anim.GUARD && info.anim() != Anim.STOMP;
				if (!punching || info.anim() == Anim.PUNCH_RIGHT && info.progress() > 0.6F) {
					part(poseStack, m.rightArm, () -> trident(poseStack, collector, light, form == Form.KATAKURI_AWAKENED || info.armament()));
				}
				if (form == Form.KATAKURI_AWAKENED) {
					part(poseStack, m.head, () -> eyes(poseStack, collector, 0xFFFF66AA));
				}
			}
			case LUCCI -> {
				if (form == Form.BASE_LUCCI) {
					part(poseStack, m.head, () -> topHat(poseStack, collector, light));
					part(poseStack, m.body, () -> hattori(poseStack, collector, light, t));
				} else {
					part(poseStack, m.head, () -> ears(poseStack, collector, light));
					part(poseStack, m.body, () -> tail(poseStack, collector, light, t, form == Form.LUCCI_AWAKENED ? 1.3F : 1.0F));
					if (form == Form.LUCCI_AWAKENED) {
						part(poseStack, m.head, () -> eyes(poseStack, collector, 0xFFFF2A20));
					}
				}
			}
			default -> {
			}
		}
	}

	private static void part(PoseStack poseStack, ModelPart part, Runnable draw) {
		poseStack.pushPose();
		part.translateAndRotate(poseStack);
		draw.run();
		poseStack.popPose();
	}

	// ------------------------------------------------------------------ Zoro

	private void zoro(PoseStack poseStack, SubmitNodeCollector collector, int light, int overlay, AvatarRenderState state, PowerRenderInfo info, PlayerModel m) {
		Form form = info.form();
		boolean haki = info.armament() || form == Form.KING_OF_HELL;
		int glow = form == Form.KING_OF_HELL ? 0xFFB040FF : 0xFF9C6BFF;
		if (info.sword()) {
			// Wado Ichimonji held in the mouth: the third sword of Santoryu.
			part(poseStack, m.head, () -> {
				poseStack.translate(0, -1.7F * PX, -4.3F * PX);
				poseStack.mulPose(Axis.YP.rotationDegrees(-90.0F));
				poseStack.translate(0, 0, 0.32F);
				katana(poseStack, collector, light, 0xFFF4F0E8, haki, glow);
			});
			if (state.leftHandItemStack.isEmpty()) {
				part(poseStack, m.leftArm, () -> {
					poseStack.translate(1.0F * PX, 10.5F * PX, -0.5F * PX);
					katana(poseStack, collector, light, 0xFF2A1A1A, haki, glow);
				});
			}
		}
		if (form == Form.ASURA) {
			ghost(poseStack, collector, light, overlay, state, this.ghostLeft, -1, haki, glow);
			ghost(poseStack, collector, light, overlay, state, this.ghostRight, 1, haki, glow);
			part(poseStack, m.head, () -> eyes(poseStack, collector, 0xFFC090FF));
		}
		if (form == Form.KING_OF_HELL) {
			part(poseStack, m.head, () -> demonHorns(poseStack, collector, info.time()));
			part(poseStack, m.head, () -> eyes(poseStack, collector, 0xFFD060FF));
		}
	}

	/** One of Asura's two ghostly extra bodies: a head and two more arms, each with a blade. */
	private void ghost(PoseStack poseStack, SubmitNodeCollector collector, int light, int overlay, AvatarRenderState state, OverlayPlayerModel ghost, int side, boolean haki, int glow) {
		poseStack.pushPose();
		poseStack.translate(side * 0.42F, -0.04F, 0.1F);
		poseStack.mulPose(Axis.YP.rotation(-side * 0.38F));
		Identifier skin = Skins.texture(Form.ASURA);
		collector.submitModel(ghost, state, poseStack, RenderTypes.entityTranslucent(skin), light, overlay, 0xD0C8B8FF, null, state.outlineColor, null);
		ghost.setupAnim(state);
		part(poseStack, ghost.rightArm, () -> {
			poseStack.translate(-1.0F * PX, 10.5F * PX, -0.5F * PX);
			katana(poseStack, collector, light, 0xFF3A2A50, haki, glow);
		});
		part(poseStack, ghost.leftArm, () -> {
			poseStack.translate(1.0F * PX, 10.5F * PX, -0.5F * PX);
			katana(poseStack, collector, light, 0xFF3A2A50, haki, glow);
		});
		part(poseStack, ghost.head, () -> {
			poseStack.translate(0, -1.7F * PX, -4.3F * PX);
			poseStack.mulPose(Axis.YP.rotationDegrees(side * 90.0F));
			poseStack.translate(0, 0, 0.32F);
			katana(poseStack, collector, light, 0xFF3A2A50, haki, glow);
		});
		poseStack.popPose();
	}

	/** A katana pointing along -Z from the grip. */
	private static void katana(PoseStack poseStack, SubmitNodeCollector collector, int light, int hilt, boolean haki, int glow) {
		int blade = haki ? 0xFF16101C : 0xFFDDE4EC;
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(WHITE), (pose, buf) -> {
			Geo.box(buf, pose, -0.032F, -0.032F, -0.13F, 0.032F, 0.032F, 0.13F, hilt, light);
			Geo.box(buf, pose, -0.085F, -0.085F, -0.155F, 0.085F, 0.085F, -0.13F, 0xFFC8A040, light);
			Geo.box(buf, pose, -0.013F, -0.046F, -1.12F, 0.013F, 0.04F, -0.155F, blade, light);
			Geo.box(buf, pose, -0.006F, 0.04F, -1.1F, 0.006F, 0.05F, -0.16F, haki ? 0xFF2A2030 : 0xFFFFFFFF, light);
		});
		if (haki) {
			collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(GLOW), (pose, buf) -> {
				Geo.v(buf, pose, 0, -0.12F, -0.16F, 0, 0, Geo.alpha(glow, 0.0F), Geo.FULL_BRIGHT);
				Geo.v(buf, pose, 0, 0.12F, -0.16F, 0, 1, Geo.alpha(glow, 0.0F), Geo.FULL_BRIGHT);
				Geo.v(buf, pose, 0, 0.12F, -1.18F, 1, 1, Geo.alpha(glow, 0.7F), Geo.FULL_BRIGHT);
				Geo.v(buf, pose, 0, -0.12F, -1.18F, 1, 0, Geo.alpha(glow, 0.7F), Geo.FULL_BRIGHT);
			});
		}
	}

	private static void demonHorns(PoseStack poseStack, SubmitNodeCollector collector, float t) {
		int frame = (int) (t * 0.5F) % 8;
		for (int side = -1; side <= 1; side += 2) {
			poseStack.pushPose();
			poseStack.translate(side * 3.0F * PX, -8.0F * PX, -1.0F * PX);
			poseStack.mulPose(Axis.ZP.rotationDegrees(side * 18.0F));
			float height = 0.42F + Mth.sin(t * 0.4F + side) * 0.04F;
			collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(FIRE), (pose, buf) ->
				Geo.crossed(buf, pose, 0.09F, height, frame / 8.0F, (frame + 1) / 8.0F, 0xE0B040FF, Geo.FULL_BRIGHT));
			poseStack.popPose();
		}
	}

	// ------------------------------------------------------------------ Luffy and Sanji

	private static void strawHat(PoseStack poseStack, SubmitNodeCollector collector, int light) {
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(STRAW), (pose, buf) -> {
			Geo.cylinder(buf, pose, 4.5F * PX, 4.3F * PX, -7.6F * PX, -11.2F * PX, 20, 4, 0xFFFFFFFF, light);
			Geo.annulus(buf, pose, 0.0F, 4.3F * PX, -11.2F * PX, 0.0F, 20, 0xFFFFFFFF, light);
			Geo.annulus(buf, pose, 4.4F * PX, 9.0F * PX, -7.5F * PX, 0.6F * PX, 28, 0xFFFFFFFF, light);
		});
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(WHITE), (pose, buf) ->
			Geo.cylinder(buf, pose, 4.56F * PX, 4.5F * PX, -7.6F * PX, -8.9F * PX, 20, 1, 0xFFC81E28, light));
	}

	private static void flameHair(PoseStack poseStack, SubmitNodeCollector collector, float t, int color, float size) {
		int frame = (int) (t * 0.45F) % 8;
		for (int n = 0; n < 4; n++) {
			poseStack.pushPose();
			poseStack.translate((n - 1.5F) * 2.0F * PX, -7.5F * PX, (n % 2 == 0 ? -1 : 1.5F) * PX);
			poseStack.mulPose(Axis.YP.rotationDegrees(n * 45.0F));
			float h = (0.32F + Mth.sin(t * 0.3F + n * 1.7F) * 0.06F) * size;
			int f = (frame + n * 2) % 8;
			collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(FIRE), (pose, buf) ->
				Geo.crossed(buf, pose, 0.16F * size, h, f / 8.0F, (f + 1) / 8.0F, color, Geo.FULL_BRIGHT));
			poseStack.popPose();
		}
	}

	private static void legFlames(PoseStack poseStack, SubmitNodeCollector collector, float t, int color, float size) {
		int frame = (int) (t * 0.6F) % 8;
		for (int n = 0; n < 4; n++) {
			poseStack.pushPose();
			poseStack.translate(0, (12.5F - n * 3.2F) * PX, 0);
			poseStack.mulPose(Axis.YP.rotationDegrees(n * 33.0F + t * 4.0F));
			float h = (0.34F + Mth.sin(t * 0.5F + n) * 0.07F) * size;
			int f = (frame + n * 3) % 8;
			collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(FIRE), (pose, buf) -> {
				Geo.crossed(buf, pose, 0.2F * size, h, f / 8.0F, (f + 1) / 8.0F, color, Geo.FULL_BRIGHT);
				Geo.crossed(buf, pose, 0.12F * size, h * 0.7F, f / 8.0F, (f + 1) / 8.0F, 0xC0FFFFFF, Geo.FULL_BRIGHT);
			});
			poseStack.popPose();
		}
	}

	private static void eyes(PoseStack poseStack, SubmitNodeCollector collector, int color) {
		collector.submitCustomGeometry(poseStack, ModRenderTypes.glow(GLOW), (pose, buf) -> {
			for (int side = -1; side <= 1; side += 2) {
				float x = side * 2.0F * PX;
				float z = -4.25F * PX;
				float y = -4.0F * PX;
				float s = 1.3F * PX;
				Geo.v(buf, pose, x - s, y - s, z, 0, 0, color, Geo.FULL_BRIGHT);
				Geo.v(buf, pose, x + s, y - s, z, 1, 0, color, Geo.FULL_BRIGHT);
				Geo.v(buf, pose, x + s, y + s, z, 1, 1, color, Geo.FULL_BRIGHT);
				Geo.v(buf, pose, x - s, y + s, z, 0, 1, color, Geo.FULL_BRIGHT);
			}
		});
	}

	// ------------------------------------------------------------------ Kaido

	private static void kaidoHorns(PoseStack poseStack, SubmitNodeCollector collector, int light, float size) {
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(HORN), (pose, buf) -> {
			for (int side = -1; side <= 1; side += 2) {
				Vec3 a = new Vec3(side * 3.2F * PX, -7.0F * PX, -1.0F * PX);
				Vec3 b = a.add(side * 2.0F * PX * size, -4.5F * PX * size, 0.6F * PX * size);
				Vec3 c = b.add(side * 0.8F * PX * size, -4.6F * PX * size, 2.0F * PX * size);
				Vec3 d = c.add(side * -0.4F * PX * size, -3.0F * PX * size, 2.6F * PX * size);
				Geo.tube(buf, pose, a, b, 2.0F * PX * size, 0.2F, 0xFFFFFFFF, light);
				Geo.tube(buf, pose, b, c, 1.6F * PX * size, 0.2F, 0xFFFFFFFF, light);
				Geo.tube(buf, pose, c, d, 1.0F * PX * size, 0.2F, 0xFFE8E0D0, light);
			}
		});
	}

	/** Hassaikai, Kaido's spiked kanabo. */
	private static void club(PoseStack poseStack, SubmitNodeCollector collector, int light, boolean haki) {
		poseStack.pushPose();
		poseStack.translate(-1.0F * PX, 10.5F * PX, 0);
		int tint = haki ? 0xFF8070A0 : 0xFFFFFFFF;
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(CLUB), (pose, buf) -> {
			Geo.tube(buf, pose, new Vec3(0, 0, 0.2), new Vec3(0, 0, -0.35), 0.1F, 0.3F, tint, light);
			Geo.tube(buf, pose, new Vec3(0, 0, -0.35), new Vec3(0, 0, -1.9), 0.24F, 0.4F, tint, light);
			for (int n = 0; n < 8; n++) {
				float z = -0.55F - n * 0.18F;
				for (int k = 0; k < 4; k++) {
					float a = k * Mth.HALF_PI + (n % 2) * 0.785F;
					float x = Mth.cos(a) * 0.13F;
					float y = Mth.sin(a) * 0.13F;
					Geo.box(buf, pose, x - 0.03F, y - 0.03F, z - 0.03F, x + 0.03F, y + 0.03F, z + 0.03F, 0xFFC8C0B0, light);
				}
			}
		});
		poseStack.popPose();
	}

	// ------------------------------------------------------------------ Katakuri

	private static void scarf(PoseStack poseStack, SubmitNodeCollector collector, int light) {
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(SCARF), (pose, buf) -> {
			Geo.box(buf, pose, -4.7F * PX, -3.4F * PX, -4.8F * PX, 4.7F * PX, 1.2F * PX, 4.7F * PX, 0xFFFFFFFF, light);
			Geo.box(buf, pose, -4.2F * PX, 1.0F * PX, -4.3F * PX, 4.2F * PX, 2.6F * PX, 4.2F * PX, 0xFFE8D8D8, light);
		});
	}

	/** Mogura, the mochi trident. */
	private static void trident(PoseStack poseStack, SubmitNodeCollector collector, int light, boolean haki) {
		poseStack.pushPose();
		poseStack.translate(-1.0F * PX, 10.5F * PX, 0);
		int shaft = haki ? 0xFF221A26 : 0xFFF2E4EA;
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(WHITE), (pose, buf) -> {
			Geo.box(buf, pose, -0.04F, -0.04F, -1.9F, 0.04F, 0.04F, 0.6F, shaft, light);
			Geo.box(buf, pose, -0.28F, -0.05F, -2.0F, 0.28F, 0.05F, -1.9F, shaft, light);
			for (int n = -1; n <= 1; n++) {
				float x = n * 0.24F;
				Geo.box(buf, pose, x - 0.035F, -0.035F, -2.55F + Math.abs(n) * 0.12F, x + 0.035F, 0.035F, -2.0F, shaft, light);
			}
		});
		poseStack.popPose();
	}

	// ------------------------------------------------------------------ Lucci

	private static void topHat(PoseStack poseStack, SubmitNodeCollector collector, int light) {
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(WHITE), (pose, buf) -> {
			Geo.cylinder(buf, pose, 3.9F * PX, 3.9F * PX, -7.8F * PX, -14.0F * PX, 18, 1, 0xFF15151A, light);
			Geo.annulus(buf, pose, 0.0F, 3.9F * PX, -14.0F * PX, 0.0F, 18, 0xFF1C1C22, light);
			Geo.annulus(buf, pose, 3.8F * PX, 6.6F * PX, -7.8F * PX, 0.2F * PX, 22, 0xFF15151A, light);
			Geo.cylinder(buf, pose, 3.95F * PX, 3.95F * PX, -7.9F * PX, -9.0F * PX, 18, 1, 0xFF6A1A22, light);
		});
	}

	/** Hattori, Lucci's pigeon, on his shoulder. */
	private static void hattori(PoseStack poseStack, SubmitNodeCollector collector, int light, float t) {
		poseStack.pushPose();
		poseStack.translate(5.6F * PX, -1.6F * PX, 0);
		poseStack.mulPose(Axis.YP.rotationDegrees(Mth.sin(t * 0.05F) * 15.0F));
		float bob = Mth.sin(t * 0.3F) * 0.2F * PX;
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(WHITE), (pose, buf) -> {
			Geo.box(buf, pose, -1.2F * PX, -2.4F * PX + bob, -1.8F * PX, 1.2F * PX, 0, 2.2F * PX, 0xFFF4F4F4, light);
			Geo.box(buf, pose, -0.9F * PX, -4.0F * PX + bob, -2.6F * PX, 0.9F * PX, -2.2F * PX + bob, -0.8F * PX, 0xFFFFFFFF, light);
			Geo.box(buf, pose, -0.3F * PX, -3.3F * PX + bob, -3.4F * PX, 0.3F * PX, -2.8F * PX + bob, -2.6F * PX, 0xFFE8A040, light);
			Geo.box(buf, pose, -0.5F * PX, -2.2F * PX + bob, -1.9F * PX, 0.5F * PX, -1.0F * PX + bob, -1.7F * PX, 0xFF101010, light);
		});
		poseStack.popPose();
	}

	private static void ears(PoseStack poseStack, SubmitNodeCollector collector, int light) {
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(FUR), (pose, buf) -> {
			Geo.box(buf, pose, -4.2F * PX, -10.0F * PX, -1.0F * PX, -2.0F * PX, -7.8F * PX, 0.6F * PX, 0xFFFFFFFF, light);
			Geo.box(buf, pose, 2.0F * PX, -10.0F * PX, -1.0F * PX, 4.2F * PX, -7.8F * PX, 0.6F * PX, 0xFFFFFFFF, light);
		});
	}

	private static void tail(PoseStack poseStack, SubmitNodeCollector collector, int light, float t, float size) {
		collector.submitCustomGeometry(poseStack, ModRenderTypes.soft(FUR), (pose, buf) -> {
			Vec3 prev = new Vec3(0, 10.5F * PX, 2.0F * PX);
			for (int n = 1; n <= 7; n++) {
				float f = n / 7.0F;
				float sway = Mth.sin(t * 0.18F - n * 0.6F) * 0.12F * f;
				Vec3 next = new Vec3(sway, (10.5F + n * 1.6F) * PX - f * f * 0.35F, (2.0F + n * 2.6F) * PX);
				Geo.tube(buf, pose, prev, next, (2.2F - f * 1.0F) * PX * size, 0.15F, 0xFFFFFFFF, light);
				prev = next;
			}
		});
	}
}
