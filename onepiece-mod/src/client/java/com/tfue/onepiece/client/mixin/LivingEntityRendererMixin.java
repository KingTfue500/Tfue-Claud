package com.tfue.onepiece.client.mixin;

import com.mojang.blaze3d.vertex.PoseStack;
import com.tfue.onepiece.client.render.AuraRenderer;
import com.tfue.onepiece.client.render.DragonRenderer;
import com.tfue.onepiece.client.render.PowerRenderInfo;
import com.tfue.onepiece.power.Form;
import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.client.renderer.entity.LivingEntityRenderer;
import net.minecraft.client.renderer.entity.state.LivingEntityRenderState;
import net.minecraft.client.renderer.state.level.CameraRenderState;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/** Draws form auras around fighters, and replaces the body with the Azure Dragon in Kaido's dragon form. */
@Mixin(LivingEntityRenderer.class)
public abstract class LivingEntityRendererMixin {
	@Inject(method = "submit(Lnet/minecraft/client/renderer/entity/state/LivingEntityRenderState;Lcom/mojang/blaze3d/vertex/PoseStack;Lnet/minecraft/client/renderer/SubmitNodeCollector;Lnet/minecraft/client/renderer/state/level/CameraRenderState;)V",
		at = @At("HEAD"), cancellable = true)
	private void onepiece$aura(LivingEntityRenderState state, PoseStack poseStack, SubmitNodeCollector collector, CameraRenderState camera, CallbackInfo ci) {
		PowerRenderInfo info = state.getData(PowerRenderInfo.KEY);
		if (info == null) {
			return;
		}
		if (!state.isInvisible) {
			AuraRenderer.submit(state, poseStack, collector, camera);
		}
		if (info.form() == Form.KAIDO_DRAGON) {
			if (!state.isInvisible) {
				DragonRenderer.submit(state, info, poseStack, collector, camera);
			}
			ci.cancel();
		}
	}
}
