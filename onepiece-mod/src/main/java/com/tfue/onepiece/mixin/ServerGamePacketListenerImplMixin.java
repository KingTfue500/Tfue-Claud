package com.tfue.onepiece.mixin;

import com.tfue.onepiece.power.Powers;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.server.network.ServerGamePacketListenerImpl;
import net.minecraft.world.entity.Entity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/** Sky Walk, Gear 4 bouncing and Gear 5 cloud hops keep players in the air; don't kick them for it. */
@Mixin(ServerGamePacketListenerImpl.class)
public abstract class ServerGamePacketListenerImplMixin {
	@Shadow
	public ServerPlayer player;

	@Inject(method = "getMaximumFlyingTicks", at = @At("HEAD"), cancellable = true)
	private void onepiece$allowAirTime(Entity entity, CallbackInfoReturnable<Integer> cir) {
		if (entity == this.player && Powers.canFloat(this.player)) {
			cir.setReturnValue(20 * 60);
		}
	}
}
