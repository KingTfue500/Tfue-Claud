package com.tfue.onepiece.item;

import com.tfue.onepiece.power.Fighter;
import com.tfue.onepiece.power.Powers;
import com.tfue.onepiece.registry.ModSounds;
import java.util.function.Consumer;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.item.component.TooltipDisplay;
import net.minecraft.world.level.Level;

/**
 * A Devil Fruit. Eating one gives you that fighter's powers: Gum-Gum (Luffy), Fish-Fish Model: Azure Dragon (Kaido),
 * Mochi-Mochi (Katakuri) or Cat-Cat Model: Leopard (Lucci).
 */
public class DevilFruitItem extends Item {
	private final Fighter fighter;

	public DevilFruitItem(Properties properties, Fighter fighter) {
		super(properties);
		this.fighter = fighter;
	}

	@Override
	public ItemStack finishUsingItem(ItemStack stack, Level level, LivingEntity entity) {
		if (entity instanceof ServerPlayer player) {
			if (Powers.get(player).owns(fighter)) {
				player.sendSystemMessage(Component.translatable("message.onepiece.already_ate", Component.translatable(getDescriptionId())).withStyle(ChatFormatting.GRAY));
			} else {
				Powers.grant(player, fighter, true);
				player.addEffect(new MobEffectInstance(MobEffects.NAUSEA, 120, 0));
				level.playSound(null, player.getX(), player.getY(), player.getZ(), ModSounds.EAT_FRUIT, SoundSource.PLAYERS, 1.0F, 1.0F);
				player.sendSystemMessage(Component.translatable("message.onepiece.ate_fruit." + fighter.id()).withStyle(ChatFormatting.LIGHT_PURPLE, ChatFormatting.BOLD));
			}
		}
		return super.finishUsingItem(stack, level, entity);
	}

	@Override
	public boolean isFoil(ItemStack stack) {
		return true;
	}

	@Override
	public void appendHoverText(ItemStack stack, TooltipContext context, TooltipDisplay display, Consumer<Component> builder, TooltipFlag flag) {
		builder.accept(Component.translatable(getDescriptionId() + ".desc").withStyle(ChatFormatting.LIGHT_PURPLE));
		builder.accept(Component.translatable("item.onepiece.devil_fruit.warning").withStyle(ChatFormatting.DARK_GRAY, ChatFormatting.ITALIC));
	}
}
