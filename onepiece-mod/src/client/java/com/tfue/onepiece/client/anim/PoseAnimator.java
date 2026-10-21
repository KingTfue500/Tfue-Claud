package com.tfue.onepiece.client.anim;

import com.tfue.onepiece.client.render.PowerRenderInfo;
import com.tfue.onepiece.power.Anim;
import com.tfue.onepiece.power.Fighter;
import com.tfue.onepiece.power.Form;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.player.PlayerModel;
import net.minecraft.client.renderer.entity.state.AvatarRenderState;
import net.minecraft.util.Mth;

/**
 * Hand-keyed body animations for every move and the body shapes of each form
 * (Gear 4's bulk, Tankman's belly, Balloon, giant Gear 3 arms, Sanji's hands-in-pockets idle...).
 */
public final class PoseAnimator {
	private PoseAnimator() {
	}

	public static void apply(PlayerModel m, AvatarRenderState state) {
		PowerRenderInfo info = state.getData(PowerRenderInfo.KEY);
		if (info == null) {
			return;
		}
		float t = info.time();
		float aim = -Mth.HALF_PI + m.head.xRot;
		shape(m, info, t);
		if (info.animating()) {
			pose(m, info, info.progress(), aim, t);
		} else {
			idle(m, info, state, t);
		}
	}

	// ------------------------------------------------------------------ easing

	private static float clamp01(float v) {
		return v < 0 ? 0 : v > 1 ? 1 : v;
	}

	private static float smooth(float v) {
		v = clamp01(v);
		return v * v * (3 - 2 * v);
	}

	/** 0 to 1 over the first {@code in} of the move, 1 to 0 over the last {@code out}. */
	private static float env(float p, float in, float out) {
		return smooth(p / in) * smooth((1 - p) / out);
	}

	private static float seg(float p, float start, float end) {
		return smooth((p - start) / (end - start));
	}

	private static void scale(ModelPart part, float x, float y, float z) {
		part.xScale *= x;
		part.yScale *= y;
		part.zScale *= z;
	}

	// ------------------------------------------------------------------ body shapes

	private static void shape(PlayerModel m, PowerRenderInfo info, float t) {
		switch (info.form()) {
			case GEAR_4_BOUNDMAN -> {
				scale(m.rightArm, 1.6F, 1.08F, 1.6F);
				scale(m.leftArm, 1.6F, 1.08F, 1.6F);
				m.rightArm.x -= 2.2F;
				m.leftArm.x += 2.2F;
				m.rightArm.y += 0.5F;
				m.leftArm.y += 0.5F;
				scale(m.body, 1.5F, 1.0F, 1.7F);
				scale(m.rightLeg, 1.35F, 1.0F, 1.35F);
				scale(m.leftLeg, 1.35F, 1.0F, 1.35F);
				m.rightLeg.x -= 0.7F;
				m.leftLeg.x += 0.7F;
				m.body.xRot += 0.2F;
				m.head.z -= 1.2F;
				m.head.y += 0.8F;
			}
			case GEAR_4_TANKMAN -> {
				scale(m.body, 2.4F, 1.05F, 2.7F);
				scale(m.rightArm, 1.45F, 1.0F, 1.45F);
				scale(m.leftArm, 1.45F, 1.0F, 1.45F);
				m.rightArm.x -= 5.2F;
				m.leftArm.x += 5.2F;
				m.rightArm.zRot += 0.45F;
				m.leftArm.zRot -= 0.45F;
				scale(m.rightLeg, 1.5F, 1.0F, 1.5F);
				scale(m.leftLeg, 1.5F, 1.0F, 1.5F);
				m.rightLeg.x -= 1.4F;
				m.leftLeg.x += 1.4F;
			}
			case GEAR_4_SNAKEMAN -> {
				scale(m.rightArm, 1.25F, 1.18F, 1.25F);
				scale(m.leftArm, 1.25F, 1.18F, 1.25F);
				m.rightArm.x -= 0.8F;
				m.leftArm.x += 0.8F;
				scale(m.body, 1.15F, 1.0F, 1.25F);
				m.body.xRot += 0.15F;
				m.head.z -= 0.6F;
			}
			case ASURA -> {
				scale(m.body, 1.1F, 1.0F, 1.1F);
				m.rightArm.x -= 0.4F;
				m.leftArm.x += 0.4F;
			}
			default -> {
			}
		}
		if (info.giant()) {
			// Gear 5 giant: cartoon proportions, huge head and fists.
			scale(m.head, 1.25F, 1.25F, 1.25F);
			scale(m.rightArm, 1.2F, 1.0F, 1.2F);
			scale(m.leftArm, 1.2F, 1.0F, 1.2F);
		}
	}

	// ------------------------------------------------------------------ idle stances

	private static void idle(PlayerModel m, PowerRenderInfo info, AvatarRenderState state, float t) {
		float still = 1.0F - clamp01(state.walkAnimationSpeed * 3.0F);
		switch (info.form()) {
			case GEAR_2 -> {
				// Low, ready-to-pounce stance with pumping shoulders.
				float pump = Mth.sin(t * 0.5F) * 0.05F;
				m.body.xRot += 0.18F * still;
				m.rightArm.xRot += (-0.45F + pump) * still;
				m.leftArm.xRot += (-0.7F - pump) * still;
				m.rightArm.yRot += -0.3F * still;
				m.leftArm.yRot += 0.3F * still;
				m.head.z -= 0.6F * still;
			}
			case GEAR_4_BOUNDMAN -> {
				float bob = Mth.sin(t * 0.35F);
				m.rightArm.xRot = -1.15F + bob * 0.12F;
				m.leftArm.xRot = -1.0F - bob * 0.12F;
				m.rightArm.zRot += 0.35F;
				m.leftArm.zRot -= 0.35F;
				m.rightLeg.xRot = -0.25F + Math.abs(bob) * 0.2F;
				m.leftLeg.xRot = 0.15F - Math.abs(bob) * 0.2F;
			}
			case GEAR_4_SNAKEMAN -> {
				float sway = Mth.sin(t * 0.25F);
				m.rightArm.xRot = -0.6F + sway * 0.2F;
				m.leftArm.xRot = -0.4F - sway * 0.2F;
				m.rightArm.zRot += 0.25F + sway * 0.1F;
				m.leftArm.zRot -= 0.25F + sway * 0.1F;
			}
			case GEAR_5 -> {
				// Noodle arms and a bobbing, laughing head.
				float wave = Mth.sin(t * 0.22F);
				m.rightArm.zRot += 0.35F + wave * 0.25F;
				m.leftArm.zRot -= 0.35F - wave * 0.25F;
				m.rightArm.xRot += Mth.sin(t * 0.31F) * 0.2F;
				m.leftArm.xRot += Mth.cos(t * 0.27F) * 0.2F;
				m.head.zRot += wave * 0.12F;
				m.head.xRot += Mth.sin(t * 0.6F) * 0.06F;
			}
			default -> {
				if (info.fighter() == Fighter.SANJI && !info.animating()) {
					// Hands in pockets, the way a gentleman walks.
					m.rightArm.xRot = m.rightArm.xRot * 0.25F + 0.08F;
					m.leftArm.xRot = m.leftArm.xRot * 0.25F + 0.08F;
					m.rightArm.zRot = 0.18F;
					m.leftArm.zRot = -0.18F;
					m.rightArm.yRot = 0.2F;
					m.leftArm.yRot = -0.2F;
				} else if (info.fighter() == Fighter.ZORO && info.sword()) {
					// Santoryu guard: both blades forward, crossed slightly.
					m.rightArm.xRot = m.rightArm.xRot * 0.3F - 0.75F * still - 0.3F;
					m.leftArm.xRot = m.leftArm.xRot * 0.3F - 0.65F * still - 0.3F;
					m.rightArm.yRot = -0.35F;
					m.leftArm.yRot = 0.35F;
				}
			}
		}
		if (info.form() == Form.ASURA || info.form() == Form.KING_OF_HELL) {
			m.head.xRot += 0.1F;
		}
	}

	// ------------------------------------------------------------------ move animations

	private static void pose(PlayerModel m, PowerRenderInfo info, float p, float aim, float t) {
		Form form = info.form();
		boolean gear3 = form == Form.GEAR_3;
		boolean gear4 = form.isGear4();
		Anim anim = info.anim();
		switch (anim) {
			case PUNCH_RIGHT, PUNCH_LEFT, FINGER -> {
				boolean right = anim != Anim.PUNCH_LEFT;
				ModelPart arm = right ? m.rightArm : m.leftArm;
				ModelPart other = right ? m.leftArm : m.rightArm;
				float side = right ? 1 : -1;
				float wind = seg(p, 0.0F, 0.15F) * (1 - seg(p, 0.15F, 0.3F));
				float out = seg(p, 0.15F, 0.3F) * (1 - seg(p, 0.75F, 1.0F));
				arm.xRot = Mth.lerp(out, Mth.lerp(wind, arm.xRot, 0.9F), aim);
				arm.yRot = Mth.lerp(out, arm.yRot, m.head.yRot - 0.08F * side);
				arm.zRot = Mth.lerp(out, arm.zRot, 0.0F);
				other.xRot = Mth.lerp(out, other.xRot, 0.5F);
				m.body.yRot = side * (0.35F * wind - 0.4F * out);
				if (gear3) {
					float big = 1.0F + 2.6F * out;
					scale(arm, big, big, big);
				}
			}
			case GATLING -> {
				float e = env(p, 0.1F, 0.1F);
				float speed = 2.8F;
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, aim + Mth.sin(t * speed) * 0.4F);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, aim + Mth.sin(t * speed + Mth.PI) * 0.4F);
				m.rightArm.yRot = Mth.lerp(e, m.rightArm.yRot, m.head.yRot + Mth.cos(t * speed * 1.3F) * 0.25F);
				m.leftArm.yRot = Mth.lerp(e, m.leftArm.yRot, m.head.yRot - Mth.cos(t * speed * 1.1F) * 0.25F);
				m.body.yRot = Mth.sin(t * speed) * 0.18F * e;
				m.body.xRot += 0.15F * e;
				if (gear3) {
					scale(m.rightArm, 2.2F, 2.2F, 2.2F);
					scale(m.leftArm, 2.2F, 2.2F, 2.2F);
				}
			}
			case BAZOOKA -> {
				float back = seg(p, 0.0F, 0.3F) * (1 - seg(p, 0.3F, 0.42F));
				float out = seg(p, 0.3F, 0.42F) * (1 - seg(p, 0.8F, 1.0F));
				for (int n = 0; n < 2; n++) {
					ModelPart arm = n == 0 ? m.rightArm : m.leftArm;
					float side = n == 0 ? 1 : -1;
					arm.xRot = Mth.lerp(out, Mth.lerp(back, arm.xRot, 1.2F), aim);
					arm.yRot = Mth.lerp(out, arm.yRot, m.head.yRot + 0.18F * side);
					arm.zRot = Mth.lerp(back, arm.zRot, 0.25F * side);
				}
				m.body.xRot += -0.15F * back + 0.3F * out;
				m.rightLeg.xRot = Mth.lerp(out, m.rightLeg.xRot, 0.5F);
				m.leftLeg.xRot = Mth.lerp(out, m.leftLeg.xRot, -0.4F);
			}
			case ROCKET -> {
				float e = env(p, 0.15F, 0.3F);
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, aim - 0.8F);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, aim - 0.8F);
				m.rightArm.zRot = Mth.lerp(e, m.rightArm.zRot, -0.15F);
				m.leftArm.zRot = Mth.lerp(e, m.leftArm.zRot, 0.15F);
				m.rightLeg.xRot = Mth.lerp(e, m.rightLeg.xRot, 0.6F);
				m.leftLeg.xRot = Mth.lerp(e, m.leftLeg.xRot, 0.35F);
				scale(m.rightArm, 1, 1 + 0.5F * e, 1);
				scale(m.leftArm, 1, 1 + 0.5F * e, 1);
			}
			case WHIP -> {
				float e = env(p, 0.12F, 0.25F);
				m.rightLeg.xRot = Mth.lerp(e, m.rightLeg.xRot, -1.5F);
				m.rightLeg.zRot = Mth.lerp(e, m.rightLeg.zRot, 0.25F);
				scale(m.rightLeg, 1, 1 + 0.8F * e, 1);
				m.rightArm.zRot = Mth.lerp(e, m.rightArm.zRot, 1.25F);
				m.leftArm.zRot = Mth.lerp(e, m.leftArm.zRot, -1.25F);
			}
			case STOMP -> {
				float up = seg(p, 0.0F, 0.4F) * (1 - seg(p, 0.45F, 0.55F));
				float down = seg(p, 0.45F, 0.55F) * (1 - seg(p, 0.85F, 1.0F));
				m.rightLeg.xRot = -2.4F * up + -0.25F * down + m.rightLeg.xRot * (1 - up - down);
				m.body.xRot += -0.3F * up + 0.25F * down;
				m.rightArm.xRot = Mth.lerp(up, m.rightArm.xRot, -0.8F);
				m.leftArm.xRot = Mth.lerp(up, m.leftArm.xRot, -0.8F);
				m.rightArm.zRot += 0.6F * up;
				m.leftArm.zRot -= 0.6F * up;
				if (gear3) {
					float big = 1 + 2.0F * (up + down);
					scale(m.rightLeg, big, big, big);
				}
			}
			case BALLOON -> {
				float e = env(p, 0.12F, 0.12F);
				float wobble = 1 + Mth.sin(t * 0.6F) * 0.04F * e;
				scale(m.body, (1 + 2.4F * e) * wobble, 1 + 0.6F * e, (1 + 2.6F * e) * wobble);
				m.rightArm.x -= 9.0F * e;
				m.leftArm.x += 9.0F * e;
				m.rightArm.zRot += 1.1F * e;
				m.leftArm.zRot -= 1.1F * e;
				m.rightLeg.x -= 2.0F * e;
				m.leftLeg.x += 2.0F * e;
				m.rightLeg.zRot += 0.3F * e;
				m.leftLeg.zRot -= 0.3F * e;
				m.head.xRot -= 0.3F * e;
			}
			case CHARGE_PUNCH -> {
				float wind = seg(p, 0.0F, 0.35F) * (1 - seg(p, 0.5F, 0.6F));
				float out = seg(p, 0.5F, 0.6F) * (1 - seg(p, 0.85F, 1.0F));
				m.rightArm.xRot = Mth.lerp(out, Mth.lerp(wind, m.rightArm.xRot, 1.3F), aim);
				m.rightArm.zRot = Mth.lerp(wind, m.rightArm.zRot, 0.4F);
				m.rightArm.yRot = Mth.lerp(out, m.rightArm.yRot, m.head.yRot);
				m.leftArm.xRot = Mth.lerp(wind, m.leftArm.xRot, aim);
				m.body.yRot = 0.7F * wind - 0.45F * out;
				m.rightLeg.xRot = Mth.lerp(wind, m.rightLeg.xRot, 0.45F);
				m.leftLeg.xRot = Mth.lerp(wind, m.leftLeg.xRot, -0.35F);
				if (gear3) {
					// Bite the thumb and blow the arm up to giant size.
					float big = 1 + 3.0F * clamp01(p * 2.0F) * (1 - seg(p, 0.85F, 1.0F));
					scale(m.rightArm, big, big, big);
				} else if (gear4) {
					// Kong Gun: the arm sinks into the body, then fires out.
					float squash = 1 - 0.7F * wind;
					scale(m.rightArm, 1 + 0.3F * wind, squash, 1 + 0.3F * wind);
				}
			}
			case GRAB_SKY -> {
				float up = seg(p, 0.0F, 0.25F) * (1 - seg(p, 0.55F, 0.7F));
				float out = seg(p, 0.55F, 0.7F) * (1 - seg(p, 0.9F, 1.0F));
				m.rightArm.xRot = -Mth.PI * up + aim * out + m.rightArm.xRot * (1 - up - out);
				m.rightArm.zRot = Mth.lerp(up, m.rightArm.zRot, -0.15F);
				m.leftArm.zRot -= 0.5F * up;
				m.head.xRot -= 0.6F * up;
				m.body.xRot += 0.3F * out;
				scale(m.rightArm, 1, 1 + 1.5F * up, 1);
			}
			case SWORD_SLASH, CLAW -> {
				float e = seg(p, 0.0F, 0.35F);
				float fade = 1 - seg(p, 0.75F, 1.0F);
				m.rightArm.xRot = Mth.lerp(fade, m.rightArm.xRot, Mth.lerp(e, -2.5F, -0.45F));
				m.rightArm.yRot = Mth.lerp(fade, m.rightArm.yRot, Mth.lerp(e, 0.7F, -0.8F));
				m.leftArm.xRot = Mth.lerp(fade, m.leftArm.xRot, Mth.lerp(seg(p, 0.1F, 0.45F), -2.3F, -0.5F));
				m.leftArm.yRot = Mth.lerp(fade, m.leftArm.yRot, Mth.lerp(seg(p, 0.1F, 0.45F), -0.6F, 0.8F));
				m.body.yRot = Mth.lerp(e, 0.45F, -0.55F) * fade;
			}
			case SWORD_CROSS -> {
				float raise = seg(p, 0.0F, 0.25F) * (1 - seg(p, 0.35F, 0.5F));
				float sweep = seg(p, 0.35F, 0.5F) * (1 - seg(p, 0.85F, 1.0F));
				m.rightArm.xRot = -2.1F * raise + (aim + 0.35F) * sweep + m.rightArm.xRot * (1 - raise - sweep);
				m.leftArm.xRot = -2.1F * raise + (aim + 0.35F) * sweep + m.leftArm.xRot * (1 - raise - sweep);
				m.rightArm.yRot = 0.75F * raise - 0.9F * sweep;
				m.leftArm.yRot = -0.75F * raise + 0.9F * sweep;
				m.body.xRot += -0.15F * raise + 0.2F * sweep;
			}
			case SWORD_SPIN -> {
				float e = env(p, 0.1F, 0.15F);
				m.rightArm.zRot = Mth.lerp(e, m.rightArm.zRot, 1.5F);
				m.leftArm.zRot = Mth.lerp(e, m.leftArm.zRot, -1.5F);
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, -0.15F);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, -0.15F);
			}
			case SWORD_DASH -> {
				float e = env(p, 0.08F, 0.35F);
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, 0.95F);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, 0.95F);
				m.rightArm.yRot = Mth.lerp(e, m.rightArm.yRot, 0.45F);
				m.leftArm.yRot = Mth.lerp(e, m.leftArm.yRot, -0.45F);
				m.rightArm.zRot = Mth.lerp(e, m.rightArm.zRot, 0.5F);
				m.leftArm.zRot = Mth.lerp(e, m.leftArm.zRot, -0.5F);
				m.rightLeg.xRot = Mth.lerp(e, m.rightLeg.xRot, -0.8F);
				m.leftLeg.xRot = Mth.lerp(e, m.leftLeg.xRot, 0.7F);
				m.body.xRot += 0.35F * e;
			}
			case SWORD_RAISE, CLUB_SMASH -> {
				float up = seg(p, 0.0F, 0.3F) * (1 - seg(p, 0.5F, 0.62F));
				float down = seg(p, 0.5F, 0.62F) * (1 - seg(p, 0.85F, 1.0F));
				float x = -2.9F * up - 0.35F * down + m.rightArm.xRot * (1 - up - down);
				m.rightArm.xRot = x;
				m.leftArm.xRot = x;
				m.rightArm.yRot = -0.3F * (up + down);
				m.leftArm.yRot = 0.3F * (up + down);
				m.body.xRot += -0.2F * up + 0.4F * down;
			}
			case KICK_HIGH -> {
				float e = env(p, 0.18F, 0.4F);
				m.rightLeg.xRot = Mth.lerp(e, m.rightLeg.xRot, -1.75F + (m.head.xRot * 0.5F));
				m.rightLeg.yRot = Mth.lerp(e, m.rightLeg.yRot, 0.15F);
				m.leftLeg.xRot = Mth.lerp(e, m.leftLeg.xRot, 0.15F);
				m.body.xRot += -0.22F * e;
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, 0.65F);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, -0.4F);
				m.leftArm.zRot = Mth.lerp(e, m.leftArm.zRot, -0.7F);
			}
			case KICK_SPIN -> {
				float e = env(p, 0.15F, 0.15F);
				m.rightLeg.zRot = Mth.lerp(e, m.rightLeg.zRot, 1.25F);
				m.leftLeg.zRot = Mth.lerp(e, m.leftLeg.zRot, -1.25F);
				m.rightLeg.xRot = Mth.lerp(e, m.rightLeg.xRot, 0.0F);
				m.leftLeg.xRot = Mth.lerp(e, m.leftLeg.xRot, 0.0F);
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, -Mth.PI);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, -Mth.PI);
				m.rightArm.zRot = Mth.lerp(e, m.rightArm.zRot, 0.15F);
				m.leftArm.zRot = Mth.lerp(e, m.leftArm.zRot, -0.15F);
			}
			case KICK_DOWN -> {
				float up = seg(p, 0.0F, 0.4F) * (1 - seg(p, 0.5F, 0.6F));
				float down = seg(p, 0.5F, 0.6F) * (1 - seg(p, 0.85F, 1.0F));
				m.rightLeg.xRot = -2.95F * up - 0.3F * down + m.rightLeg.xRot * (1 - up - down);
				m.body.xRot += -0.25F * up + 0.3F * down;
				m.rightArm.zRot += 0.8F * up;
				m.leftArm.zRot -= 0.8F * up;
			}
			case KICK_RAPID -> {
				float e = env(p, 0.08F, 0.12F);
				float s = t * 3.2F;
				m.rightLeg.xRot = Mth.lerp(e, m.rightLeg.xRot, -1.4F + Mth.sin(s) * 0.55F);
				m.rightLeg.yRot = Mth.lerp(e, m.rightLeg.yRot, Mth.cos(s * 0.7F) * 0.35F);
				m.leftLeg.xRot = Mth.lerp(e, m.leftLeg.xRot, 0.2F);
				m.body.xRot += -0.2F * e;
				m.rightArm.zRot = Mth.lerp(e, m.rightArm.zRot, 0.9F);
				m.leftArm.zRot = Mth.lerp(e, m.leftArm.zRot, -0.9F);
			}
			case KICK_LAUNCH -> {
				float swing = seg(p, 0.05F, 0.35F);
				float fade = 1 - seg(p, 0.7F, 1.0F);
				m.rightLeg.xRot = Mth.lerp(fade, m.rightLeg.xRot, Mth.lerp(swing, 0.5F, -2.8F));
				m.body.xRot += -0.25F * swing * fade;
				m.rightArm.xRot = Mth.lerp(fade, m.rightArm.xRot, 0.5F);
				m.leftArm.zRot = Mth.lerp(fade, m.leftArm.zRot, -0.8F);
			}
			case ROAR -> {
				float e = env(p, 0.15F, 0.3F);
				m.rightArm.zRot = Mth.lerp(e, m.rightArm.zRot, 0.7F);
				m.leftArm.zRot = Mth.lerp(e, m.leftArm.zRot, -0.7F);
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, 0.25F);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, 0.25F);
				m.head.xRot = Mth.lerp(e, m.head.xRot, -0.55F);
				m.body.xRot += -0.18F * e;
				m.rightLeg.zRot += 0.15F * e;
				m.leftLeg.zRot -= 0.15F * e;
			}
			case FORM_SHIFT -> {
				float e = env(p, 0.2F, 0.3F);
				float shake = Mth.sin(t * 4.0F) * 0.05F * e;
				m.rightArm.zRot = Mth.lerp(e, m.rightArm.zRot, 1.25F + shake);
				m.leftArm.zRot = Mth.lerp(e, m.leftArm.zRot, -1.25F - shake);
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, -0.55F);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, -0.55F);
				m.body.xRot += 0.25F * e;
				m.rightLeg.zRot += 0.22F * e;
				m.leftLeg.zRot -= 0.22F * e;
				m.head.xRot = Mth.lerp(e, m.head.xRot, 0.35F);
			}
			case BREATH -> {
				float e = env(p, 0.12F, 0.2F);
				m.head.xRot = Mth.lerp(e, m.head.xRot, m.head.xRot - 0.25F);
				m.body.xRot += 0.3F * e;
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, 0.6F);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, 0.6F);
				m.rightArm.zRot = Mth.lerp(e, m.rightArm.zRot, 0.5F);
				m.leftArm.zRot = Mth.lerp(e, m.leftArm.zRot, -0.5F);
				m.rightLeg.xRot = Mth.lerp(e, m.rightLeg.xRot, 0.4F);
				m.leftLeg.xRot = Mth.lerp(e, m.leftLeg.xRot, -0.3F);
			}
			case POUNCE -> {
				float e = env(p, 0.12F, 0.3F);
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, aim - 0.3F);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, aim - 0.3F);
				m.rightArm.zRot = Mth.lerp(e, m.rightArm.zRot, -0.25F);
				m.leftArm.zRot = Mth.lerp(e, m.leftArm.zRot, 0.25F);
				m.rightLeg.xRot = Mth.lerp(e, m.rightLeg.xRot, 0.9F);
				m.leftLeg.xRot = Mth.lerp(e, m.leftLeg.xRot, 0.6F);
				m.body.xRot += 0.4F * e;
			}
			case GUARD -> {
				float e = env(p, 0.1F, 0.15F);
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, -1.35F);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, -1.35F);
				m.rightArm.yRot = Mth.lerp(e, m.rightArm.yRot, -0.75F);
				m.leftArm.yRot = Mth.lerp(e, m.leftArm.yRot, 0.75F);
				m.rightLeg.zRot += 0.12F * e;
				m.leftLeg.zRot -= 0.12F * e;
				m.body.xRot += 0.1F * e;
			}
			case DASH -> {
				float e = env(p, 0.1F, 0.4F);
				m.rightArm.xRot = Mth.lerp(e, m.rightArm.xRot, 1.0F);
				m.leftArm.xRot = Mth.lerp(e, m.leftArm.xRot, 1.0F);
				m.rightLeg.xRot = Mth.lerp(e, m.rightLeg.xRot, -0.9F);
				m.leftLeg.xRot = Mth.lerp(e, m.leftLeg.xRot, 0.8F);
			}
			default -> {
			}
		}
	}
}
