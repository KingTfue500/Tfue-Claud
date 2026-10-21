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

	/** Side-on camera for recording and testing, only when launched with -Donepiece.devcam=<distance>. */
	private static final String DEV_CAM = System.getProperty("onepiece.devcam");

	@Inject(method = "alignWithEntity", at = @At("TAIL"))
	private void onepiece$cinematics(float partialTicks, CallbackInfo ci) {
		Vec3[] shot = Cutscene.camera(partialTicks);
		if (shot == null && DEV_CAM != null) {
			net.minecraft.client.Minecraft mc = net.minecraft.client.Minecraft.getInstance();
			if (mc.player != null) {
				float dist = Float.parseFloat(DEV_CAM);
				float yaw = mc.player.getYRot() * (float) (Math.PI / 180.0);
				Vec3 forward = new Vec3(-Math.sin(yaw), 0, Math.cos(yaw));
				Vec3 right = new Vec3(-Math.cos(yaw), 0, -Math.sin(yaw));
				Vec3 base = mc.player.getPosition(partialTicks);
				float h = mc.player.getBbHeight();
				shot = new Vec3[] {base.add(right.scale(dist)).add(forward.scale(dist * 0.35)).add(0, h * 0.8 + dist * 0.15, 0),
					base.add(forward.scale(dist * 0.45)).add(0, h * 0.55, 0)};
			}
		}
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
