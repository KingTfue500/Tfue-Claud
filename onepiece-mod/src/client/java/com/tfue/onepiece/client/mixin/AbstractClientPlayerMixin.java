package com.tfue.onepiece.client.mixin;

import com.tfue.onepiece.client.render.Skins;
import com.tfue.onepiece.power.PowerData;
import com.tfue.onepiece.power.Powers;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.world.entity.player.PlayerSkin;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/** Swap the player's skin for the active fighter and form (also changes the first-person arm). */
@Mixin(AbstractClientPlayer.class)
public abstract class AbstractClientPlayerMixin {
	@Inject(method = "getSkin", at = @At("RETURN"), cancellable = true)
	private void onepiece$formSkin(CallbackInfoReturnable<PlayerSkin> cir) {
		PowerData data = Powers.get((AbstractClientPlayer) (Object) this);
		if (data.active()) {
			cir.setReturnValue(Skins.forForm(data.form(), cir.getReturnValue()));
		}
	}
}
