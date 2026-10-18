package com.tfue.onepiece.mixin;

import com.tfue.onepiece.entity.VfxEntity;
import com.tfue.onepiece.entity.VfxType;
import com.tfue.onepiece.power.Fighter;
import com.tfue.onepiece.power.PowerData;
import com.tfue.onepiece.power.Powers;
import com.tfue.onepiece.registry.ModSounds;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.phys.Vec3;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(LivingEntity.class)
public abstract class LivingEntityMixin {
	/**
	 * Observation Haki: sometimes see an attack coming and sidestep it.
	 * Rubber body: Luffy shrugs off blunt hits and lightning a little better.
	 */
	@Inject(method = "hurtServer", at = @At("HEAD"), cancellable = true)
	private void onepiece$dodge(ServerLevel level, DamageSource source, float damage, CallbackInfoReturnable<Boolean> cir) {
		LivingEntity self = (LivingEntity) (Object) this;
		if (!(self instanceof ServerPlayer player)) {
			return;
		}
		PowerData data = Powers.get(player);
		if (!data.active()) {
			return;
		}
		// Big forms squeezed into tight spaces shouldn't choke on the blocks around them.
		if (source.is(net.minecraft.world.damagesource.DamageTypes.IN_WALL) && (data.form().scale > 1.05F || data.giantUntil() > level.getGameTime())) {
			cir.setReturnValue(false);
			return;
		}
		if (data.fighter() == Fighter.LUFFY && source.is(DamageTypeTags.IS_LIGHTNING)) {
			cir.setReturnValue(false);
			return;
		}
		if (source.getEntity() != null && source.getEntity() != player && !source.is(DamageTypeTags.BYPASSES_INVULNERABILITY) && player.getRandom().nextFloat() < Powers.dodgeChance(player)) {
			Vec3 away = player.position().subtract(source.getEntity().position()).normalize();
			Vec3 side = away.yRot((float) (Math.PI / 2) * (player.getRandom().nextBoolean() ? 1 : -1)).scale(0.8);
			VfxEntity.create(level, VfxType.DASH_TRAIL, player.position().add(0, 1, 0), 0xFF8FE6FF, 1.0F, 8)
				.target(player.position().add(side.scale(2.0)).add(0, 1, 0)).owner(player).spawn();
			player.setDeltaMovement(side.x, 0.2, side.z);
			player.hurtMarked = true;
			level.playSound(null, player.getX(), player.getY(), player.getZ(), ModSounds.WHOOSH, SoundSource.PLAYERS, 0.8F, 1.8F);
			if (!data.infinite()) {
				Powers.set(player, data.withStamina(data.stamina() - 3.0F));
			}
			cir.setReturnValue(false);
		}
	}
}
