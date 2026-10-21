package com.tfue.onepiece.client.mixin;

import com.tfue.onepiece.client.Cutscene;
import net.minecraft.client.renderer.GameRenderer;
import net.minecraft.client.renderer.state.level.CameraRenderState;
import org.joml.Matrix4fc;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/** No first-person hand while the cutscene camera is flying around the fighter. */
@Mixin(GameRenderer.class)
public abstract class GameRendererMixin {
	private static final boolean DEV_CAM = System.getProperty("onepiece.devcam") != null;

	@Inject(method = "renderItemInHand", at = @At("HEAD"), cancellable = true)
	private void onepiece$hideHand(CameraRenderState cameraState, float deltaPartialTick, Matrix4fc modelViewMatrix, CallbackInfo ci) {
		if (Cutscene.active() || DEV_CAM) {
			ci.cancel();
		}
	}
}
