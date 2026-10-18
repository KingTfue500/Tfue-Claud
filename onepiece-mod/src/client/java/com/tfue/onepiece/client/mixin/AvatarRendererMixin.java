package com.tfue.onepiece.client.mixin;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import com.tfue.onepiece.client.render.PowerRenderInfo;
import com.tfue.onepiece.power.Anim;
import com.tfue.onepiece.power.Form;
import com.tfue.onepiece.power.PowerData;
import com.tfue.onepiece.power.Powers;
import com.tfue.onepiece.registry.ModItems;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.entity.player.AvatarRenderer;
import net.minecraft.client.renderer.entity.state.AvatarRenderState;
import net.minecraft.tags.ItemTags;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Avatar;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.player.Player;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(AvatarRenderer.class)
public abstract class AvatarRendererMixin {
	@Inject(method = "extractRenderState(Lnet/minecraft/world/entity/Avatar;Lnet/minecraft/client/renderer/entity/state/AvatarRenderState;F)V", at = @At("TAIL"))
	private void onepiece$extract(Avatar avatar, AvatarRenderState state, float partialTicks, CallbackInfo ci) {
		if (!(avatar instanceof Player player)) {
			state.setData(PowerRenderInfo.KEY, null);
			return;
		}
		PowerData data = Powers.get(player);
		if (!data.active()) {
			state.setData(PowerRenderInfo.KEY, null);
			return;
		}
		float time = player.level().getGameTime() + partialTicks;
		boolean sword = player.getMainHandItem().is(ItemTags.SWORDS) || player.getOffhandItem().is(ItemTags.SWORDS);
		boolean hat = player.getItemBySlot(EquipmentSlot.HEAD).is(ModItems.STRAW_HAT);
		boolean self = player == Minecraft.getInstance().player && Minecraft.getInstance().options.getCameraType().isFirstPerson() && !com.tfue.onepiece.client.Cutscene.active();
		if (data.form() == Form.RAID_SUIT && player == Minecraft.getInstance().player) {
			// Stealth Black: you still see yourself as a faint ghost, everyone else sees nothing.
			state.isInvisibleToPlayer = false;
		}
		state.setData(PowerRenderInfo.KEY, new PowerRenderInfo(data.fighter(), data.form(), data.anim(), data.animProgress(time),
			data.armament(), data.giantUntil() > player.level().getGameTime(), time, sword, hat, self));
	}

	/** Whole-body spins and flips: Party Table handstand, Tatsumaki spin, Gum-Gum Whip. */
	@Inject(method = "setupRotations(Lnet/minecraft/client/renderer/entity/state/AvatarRenderState;Lcom/mojang/blaze3d/vertex/PoseStack;FF)V", at = @At("TAIL"))
	private void onepiece$spin(AvatarRenderState state, PoseStack poseStack, float bodyRot, float entityScale, CallbackInfo ci) {
		PowerRenderInfo info = state.getData(PowerRenderInfo.KEY);
		if (info == null) {
			return;
		}
		if (info.animating()) {
			float p = info.progress();
			Anim anim = info.anim();
			switch (anim) {
				case SWORD_SPIN, WHIP -> poseStack.mulPose(Axis.YP.rotation(-p * Mth.TWO_PI * (anim == Anim.SWORD_SPIN ? 3 : 1)));
				case KICK_SPIN -> {
					float flip = Math.min(1.0F, p * 6.0F) * Math.min(1.0F, (1.0F - p) * 6.0F);
					poseStack.translate(0.0F, state.boundingBoxHeight * 0.55F * flip / entityScale, 0.0F);
					poseStack.mulPose(Axis.ZP.rotationDegrees(180.0F * flip));
					poseStack.mulPose(Axis.YP.rotation(p * Mth.TWO_PI * 5));
				}
				case DASH, SWORD_DASH -> poseStack.mulPose(Axis.XP.rotationDegrees(-25.0F * Mth.sin(p * Mth.PI)));
				case KICK_DOWN -> poseStack.mulPose(Axis.XP.rotationDegrees(p < 0.5F ? -360.0F * p * 2.0F : 0.0F));
				default -> {
				}
			}
		}
		if (info.form() == Form.GEAR_4_BOUNDMAN) {
			// Boundman never stops bouncing.
			float bounce = Math.abs(Mth.sin(info.time() * 0.35F));
			poseStack.translate(0.0F, bounce * 0.35F, 0.0F);
		}
	}
}
