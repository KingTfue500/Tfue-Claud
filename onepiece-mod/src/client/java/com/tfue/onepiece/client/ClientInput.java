package com.tfue.onepiece.client;

import com.mojang.blaze3d.platform.InputConstants;
import com.tfue.onepiece.OnePiece;
import com.tfue.onepiece.client.gui.MoveWheelScreen;
import com.tfue.onepiece.network.ActionPayload;
import com.tfue.onepiece.power.Form;
import com.tfue.onepiece.power.PowerData;
import com.tfue.onepiece.power.Powers;
import net.fabricmc.fabric.api.client.keymapping.v1.KeyMappingHelper;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.Minecraft;
import org.lwjgl.glfw.GLFW;

/**
 * Keys (all rebindable in Controls > One Piece):
 * R tap = use skill, R hold = skill wheel, V hold = form wheel, V tap = back to base form,
 * B = switch fighter, H/J/K = Armament/Observation/Conqueror's Haki, Space in mid-air = Sky Walk / Geppo / bounce.
 */
public final class ClientInput {
	private static final KeyMapping.Category CATEGORY = KeyMapping.Category.register(OnePiece.id("powers"));
	public static final KeyMapping SKILL = key("skill", GLFW.GLFW_KEY_R);
	public static final KeyMapping FORM = key("form", GLFW.GLFW_KEY_V);
	public static final KeyMapping FIGHTER = key("fighter", GLFW.GLFW_KEY_B);
	public static final KeyMapping ARMAMENT = key("armament", GLFW.GLFW_KEY_H);
	public static final KeyMapping OBSERVATION = key("observation", GLFW.GLFW_KEY_J);
	public static final KeyMapping CONQUEROR = key("conqueror", GLFW.GLFW_KEY_K);

	private static final int HOLD_TICKS = 5;
	private static int skillHeld;
	private static int formHeld;
	private static boolean jumpWasDown;

	private ClientInput() {
	}

	private static KeyMapping key(String name, int code) {
		return KeyMappingHelper.registerKeyMapping(new KeyMapping("key.onepiece." + name, InputConstants.Type.KEYSYM, code, CATEGORY));
	}

	public static void init() {
	}

	public static void send(int action, int value) {
		if (ClientPlayNetworking.canSend(ActionPayload.TYPE)) {
			ClientPlayNetworking.send(new ActionPayload(action, value));
		}
	}

	public static void tick(Minecraft mc) {
		if (mc.player == null || mc.level == null) {
			return;
		}
		PowerData data = Powers.get(mc.player);
		if (mc.gui.screen() != null) {
			skillHeld = 0;
			formHeld = 0;
			return;
		}
		// Skill key: tap to use, hold for the wheel.
		if (SKILL.isDown()) {
			skillHeld++;
			if (skillHeld == HOLD_TICKS && data.active()) {
				mc.gui.setScreen(new MoveWheelScreen(false, SKILL));
			}
		} else {
			if (skillHeld > 0 && skillHeld < HOLD_TICKS) {
				send(ActionPayload.USE_MOVE, 0);
			}
			skillHeld = 0;
		}
		while (SKILL.consumeClick()) {
			// clicks are handled through isDown above
		}
		if (FORM.isDown()) {
			formHeld++;
			if (formHeld == HOLD_TICKS && data.active()) {
				mc.gui.setScreen(new MoveWheelScreen(true, FORM));
			}
		} else {
			if (formHeld > 0 && formHeld < HOLD_TICKS && data.active() && !data.form().isBase()) {
				send(ActionPayload.SELECT_FORM, Form.base(data.fighter()).ordinal());
			}
			formHeld = 0;
		}
		while (FORM.consumeClick()) {
			// handled above
		}
		while (FIGHTER.consumeClick()) {
			send(ActionPayload.CYCLE_FIGHTER, 0);
		}
		while (ARMAMENT.consumeClick()) {
			send(ActionPayload.ARMAMENT, 0);
		}
		while (OBSERVATION.consumeClick()) {
			send(ActionPayload.OBSERVATION, 0);
		}
		while (CONQUEROR.consumeClick()) {
			send(ActionPayload.CONQUEROR, 0);
		}
		// Mid-air jumps.
		boolean jumpDown = mc.options.keyJump.isDown();
		if (jumpDown && !jumpWasDown && data.active() && data.form().hasAirJumps() && !mc.player.onGround()
			&& !mc.player.isInWater() && !mc.player.getAbilities().flying && !mc.player.onClimbable()) {
			send(ActionPayload.AIR_JUMP, 0);
		}
		jumpWasDown = jumpDown;
	}
}
