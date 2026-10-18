package com.tfue.onepiece.power;

import com.tfue.onepiece.registry.ModItems;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.player.Player;

/** Small bonuses for wearing your own crew gear: Straw Hat, Zoro's bandana, Sanji's suit. */
public final class GearBonus {
	private GearBonus() {
	}

	private static boolean wearing(Player player, EquipmentSlot slot, net.minecraft.world.item.Item item) {
		return player.getItemBySlot(slot).is(item);
	}

	/** Damage bonus for moves. */
	public static float damage(Player player) {
		PowerData data = Powers.get(player);
		float bonus = 1.0F;
		if (data.fighter() == Fighter.ZORO && wearing(player, EquipmentSlot.HEAD, ModItems.ZORO_BANDANA)) {
			bonus += 0.2F;
		}
		if (data.fighter() == Fighter.SANJI && wearing(player, EquipmentSlot.CHEST, ModItems.SANJI_SUIT)) {
			bonus += 0.15F;
		}
		return bonus;
	}

	/** Stamina regen bonus. */
	public static float regen(Player player) {
		PowerData data = Powers.get(player);
		float bonus = 1.0F;
		if (data.fighter() == Fighter.LUFFY && wearing(player, EquipmentSlot.HEAD, ModItems.STRAW_HAT)) {
			bonus += 0.6F;
		}
		if (wearing(player, EquipmentSlot.HEAD, ModItems.STRAW_HAT)) {
			bonus += 0.15F;
		}
		return bonus;
	}
}
