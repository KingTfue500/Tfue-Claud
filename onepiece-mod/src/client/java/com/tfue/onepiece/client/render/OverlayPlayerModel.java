package com.tfue.onepiece.client.render;

import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.player.PlayerModel;
import net.minecraft.client.renderer.entity.state.AvatarRenderState;

/**
 * A second player model that copies the main model's animation but only shows some parts.
 * Used for the Armament Haki coating and Asura's ghost heads and arms.
 */
public class OverlayPlayerModel extends PlayerModel {
	public static final int HEAD = 1;
	public static final int BODY = 2;
	public static final int ARMS = 4;
	public static final int LEGS = 8;

	private final int mask;
	private final float spread;

	public OverlayPlayerModel(ModelPart root, int mask, float spread) {
		super(root, false);
		this.mask = mask;
		this.spread = spread;
	}

	@Override
	public void setupAnim(AvatarRenderState state) {
		super.setupAnim(state);
		boolean head = (mask & HEAD) != 0;
		boolean body = (mask & BODY) != 0;
		boolean arms = (mask & ARMS) != 0;
		boolean legs = (mask & LEGS) != 0;
		this.head.visible = head;
		this.hat.visible = head;
		this.body.visible = body;
		this.jacket.visible = body;
		this.rightArm.visible = arms;
		this.leftArm.visible = arms;
		this.rightSleeve.visible = arms;
		this.leftSleeve.visible = arms;
		this.rightLeg.visible = legs;
		this.leftLeg.visible = legs;
		this.rightPants.visible = legs;
		this.leftPants.visible = legs;
		if (spread != 0.0F) {
			// Asura's extra arms fan out, each holding a blade.
			float sway = net.minecraft.util.Mth.sin(state.ageInTicks * 0.15F + spread) * 0.12F;
			this.rightArm.zRot += Math.abs(spread) + sway;
			this.leftArm.zRot -= Math.abs(spread) + sway;
			this.rightArm.xRot -= 0.7F;
			this.leftArm.xRot -= 0.7F;
			this.head.yRot += spread * 0.4F;
		}
	}
}
