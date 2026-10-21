package com.tfue.onepiece.item;

import com.tfue.onepiece.power.Fighter;
import com.tfue.onepiece.power.Powers;
import java.util.function.Consumer;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.item.component.TooltipDisplay;
import net.minecraft.world.level.Level;

/**
 * An item that teaches a fighting style when used: Zoro's katanas teach Santoryu, Sanji's cook book teaches Black Leg.
 */
public class StyleItem extends Item {
	private final Fighter fighter;
	private final String tooltip;

	public StyleItem(Properties properties, Fighter fighter, String tooltip) {
		super(properties);
		this.fighter = fighter;
		this.tooltip = tooltip;
	}

	@Override
	public InteractionResult use(Level level, Player player, InteractionHand hand) {
		if (player instanceof ServerPlayer serverPlayer) {
			var data = Powers.get(serverPlayer);
			if (!data.owns(fighter) || data.fighter() != fighter) {
				Powers.grant(serverPlayer, fighter, true);
				return InteractionResult.SUCCESS_SERVER;
			}
		}
		return Powers.get(player).owns(fighter) && Powers.get(player).fighter() == fighter ? InteractionResult.PASS : InteractionResult.SUCCESS;
	}

	@Override
	public void appendHoverText(ItemStack stack, TooltipContext context, TooltipDisplay display, Consumer<Component> builder, TooltipFlag flag) {
		builder.accept(Component.translatable(tooltip).withStyle(ChatFormatting.GOLD));
		builder.accept(Component.translatable("item.onepiece.style_hint").withStyle(ChatFormatting.DARK_GRAY, ChatFormatting.ITALIC));
	}
}
