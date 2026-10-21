package com.tfue.onepiece.client.render.boss;

import com.mojang.blaze3d.vertex.PoseStack;
import com.tfue.onepiece.client.render.FormLayer;
import com.tfue.onepiece.client.render.PowerRenderInfo;
import com.tfue.onepiece.client.render.Skins;
import com.tfue.onepiece.entity.BossEntity;
import com.tfue.onepiece.power.PowerData;
import com.tfue.onepiece.power.Powers;
import net.minecraft.client.model.HumanoidModel;
import net.minecraft.client.model.geom.ModelLayers;
import net.minecraft.client.model.player.PlayerModel;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.HumanoidMobRenderer;
import net.minecraft.client.renderer.entity.LivingEntityRenderer;
import net.minecraft.client.renderer.entity.state.AvatarRenderState;
import net.minecraft.resources.Identifier;

/**
 * Bosses are drawn exactly like a player of the same fighter: same skins, body shapes, animations,
 * auras and transformations.
 */
public class BossRenderer<T extends BossEntity> extends LivingEntityRenderer<T, AvatarRenderState, PlayerModel> {
	public BossRenderer(EntityRendererProvider.Context context) {
		super(context, new PlayerModel(context.bakeLayer(ModelLayers.PLAYER), false), 0.6F);
		this.addLayer(new FormLayer(this, context.getModelSet()));
	}

	@Override
	public AvatarRenderState createRenderState() {
		return new AvatarRenderState();
	}

	@Override
	public void extractRenderState(T entity, AvatarRenderState state, float partialTicks) {
		super.extractRenderState(entity, state, partialTicks);
		HumanoidMobRenderer.extractHumanoidRenderState(entity, state, partialTicks, this.itemModelResolver);
		state.leftArmPose = HumanoidModel.ArmPose.EMPTY;
		state.rightArmPose = HumanoidModel.ArmPose.EMPTY;
		state.isSpectator = false;
		state.id = entity.getId();
		PowerData data = Powers.view(entity);
		// 26.2 draws any AvatarRenderState with the player renderer, which reads the skin from the state.
		state.skin = Skins.forForm(data.form(), net.minecraft.client.resources.DefaultPlayerSkin.getDefaultSkin());
		state.showHat = true;
		state.showJacket = true;
		state.showLeftPants = true;
		state.showRightPants = true;
		state.showLeftSleeve = true;
		state.showRightSleeve = true;
		state.showCape = false;
		float time = entity.level().getGameTime() + partialTicks;
		state.setData(PowerRenderInfo.KEY, new PowerRenderInfo(data.fighter(), data.form(), data.anim(), data.animProgress(time),
			data.armament(), false, time, false, false, false));
	}

	@Override
	public Identifier getTextureLocation(AvatarRenderState state) {
		PowerRenderInfo info = state.getData(PowerRenderInfo.KEY);
		return info != null ? Skins.texture(info.form()) : Skins.texture(com.tfue.onepiece.power.Form.BASE_KAIDO);
	}

	@Override
	protected void scale(AvatarRenderState state, PoseStack poseStack) {
		poseStack.scale(0.9375F, 0.9375F, 0.9375F);
	}
}
