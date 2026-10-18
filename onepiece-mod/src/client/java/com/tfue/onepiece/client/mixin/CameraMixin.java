package com.tfue.onepiece.client.mixin;

import com.tfue.onepiece.client.CameraShake;
import com.tfue.onepiece.client.Cutscene;
import net.minecraft.client.Camera;
import net.minecraft.world.phys.Vec3;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(Camera.class)
public abstract class CameraMixin {
	@Shadow
	private boolean detached;

	@Shadow
	protected abstract void setRotation(float yRot, float xRot);

	@Shadow
	protected abstract void setPosition(Vec3 position);

	@Shadow
	public abstract float yRot();

	@Shadow
	public abstract float xRot();

	@Inject(method = "alignWithEntity", at = @At("TAIL"))
	private void onepiece$cinematics(float partialTicks, CallbackInfo ci) {
		Vec3[] shot = Cutscene.camera(partialTicks);
		if (shot != null) {
			Vec3 eye = shot[0];
			Vec3 look = shot[1].subtract(eye);
			float yaw = (float) (Math.atan2(look.z, look.x) * 180.0 / Math.PI) - 90.0F;
			float pitch = (float) -(Math.atan2(look.y, look.horizontalDistance()) * 180.0 / Math.PI);
			this.detached = true;
			this.setPosition(eye);
			this.setRotation(yaw, pitch);
		}
		if (CameraShake.active()) {
			this.setRotation(this.yRot() + CameraShake.yaw(partialTicks), this.xRot() + CameraShake.pitch(partialTicks));
		}
	}
}
