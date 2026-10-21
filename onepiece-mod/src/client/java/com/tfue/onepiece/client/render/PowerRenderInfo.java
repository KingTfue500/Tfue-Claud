package com.tfue.onepiece.client.render;

import com.tfue.onepiece.power.Anim;
import com.tfue.onepiece.power.Fighter;
import com.tfue.onepiece.power.Form;
import net.fabricmc.fabric.api.client.rendering.v1.RenderStateDataKey;

/** Power info copied onto a player's render state each frame so models and layers can read it. */
public record PowerRenderInfo(
	Fighter fighter,
	Form form,
	Anim anim,
	float progress,
	boolean armament,
	boolean giant,
	float time,
	boolean sword,
	boolean strawHat,
	boolean firstPersonSelf
) {
	public static final RenderStateDataKey<PowerRenderInfo> KEY = RenderStateDataKey.create(() -> "onepiece:power");

	public boolean animating() {
		return progress >= 0.0F;
	}
}
