package com.tfue.onepiece.client.mixin;

import com.tfue.onepiece.power.PowerData;
import com.tfue.onepiece.power.Powers;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import org.jspecify.annotations.Nullable;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/** Observation Haki: see the outline of every living thing nearby, even through walls. */
@Mixin(Minecraft.class)
public abstract class MinecraftMixin {
	@Shadow
	public @Nullable LocalPlayer player;

	@Inject(method = "shouldEntityAppearGlowing", at = @At("HEAD"), cancellable = true)
	private void onepiece$observation(Entity entity, CallbackInfoReturnable<Boolean> cir) {
		if (this.player != null && entity != this.player && entity instanceof LivingEntity) {
			PowerData data = Powers.get(this.player);
			if (data.observation() && entity.distanceToSqr(this.player) < 48 * 48) {
				cir.setReturnValue(true);
			}
		}
	}
}
