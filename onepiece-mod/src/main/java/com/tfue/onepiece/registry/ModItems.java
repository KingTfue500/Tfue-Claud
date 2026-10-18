package com.tfue.onepiece.registry;

import com.tfue.onepiece.OnePiece;
import com.tfue.onepiece.item.DevilFruitItem;
import com.tfue.onepiece.item.StyleItem;
import com.tfue.onepiece.power.Fighter;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceKey;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.tags.ItemTags;
import net.minecraft.world.food.FoodProperties;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Rarity;
import net.minecraft.world.item.ToolMaterial;
import net.minecraft.world.item.equipment.ArmorMaterial;
import net.minecraft.world.item.equipment.ArmorType;
import net.minecraft.world.item.equipment.EquipmentAsset;
import net.minecraft.world.item.equipment.EquipmentAssets;
import net.fabricmc.fabric.api.creativetab.v1.FabricCreativeModeTab;

public final class ModItems {
	public static final ResourceKey<EquipmentAsset> STRAW_HAT_ASSET = ResourceKey.create(EquipmentAssets.ROOT_ID, OnePiece.id("straw_hat"));
	public static final ResourceKey<EquipmentAsset> BANDANA_ASSET = ResourceKey.create(EquipmentAssets.ROOT_ID, OnePiece.id("zoro_bandana"));
	public static final ResourceKey<EquipmentAsset> SUIT_ASSET = ResourceKey.create(EquipmentAssets.ROOT_ID, OnePiece.id("sanji_suit"));

	private static final ArmorMaterial STRAW = material(STRAW_HAT_ASSET, 3, 25);
	private static final ArmorMaterial BANDANA = material(BANDANA_ASSET, 3, 20);
	private static final ArmorMaterial SUIT = material(SUIT_ASSET, 7, 20);

	public static final Item GUM_GUM_FRUIT = register("gum_gum_fruit", p -> new DevilFruitItem(p, Fighter.LUFFY),
		new Item.Properties().stacksTo(1).rarity(Rarity.EPIC).food(new FoodProperties.Builder().nutrition(4).saturationModifier(0.6F).alwaysEdible().build()));
	public static final Item DRAGON_FRUIT = register("dragon_fruit", p -> new DevilFruitItem(p, Fighter.KAIDO),
		new Item.Properties().stacksTo(1).rarity(Rarity.EPIC).food(new FoodProperties.Builder().nutrition(4).saturationModifier(0.6F).alwaysEdible().build()));
	public static final Item MOCHI_FRUIT = register("mochi_fruit", p -> new DevilFruitItem(p, Fighter.KATAKURI),
		new Item.Properties().stacksTo(1).rarity(Rarity.EPIC).food(new FoodProperties.Builder().nutrition(4).saturationModifier(0.6F).alwaysEdible().build()));
	public static final Item LEOPARD_FRUIT = register("leopard_fruit", p -> new DevilFruitItem(p, Fighter.LUCCI),
		new Item.Properties().stacksTo(1).rarity(Rarity.EPIC).food(new FoodProperties.Builder().nutrition(4).saturationModifier(0.6F).alwaysEdible().build()));
	public static final Item WADO_ICHIMONJI = register("wado_ichimonji", p -> new StyleItem(p, Fighter.ZORO, "item.onepiece.wado_ichimonji.desc"),
		new Item.Properties().sword(ToolMaterial.DIAMOND, 4.0F, -2.2F).rarity(Rarity.RARE));
	public static final Item SHUSUI = register("shusui", p -> new StyleItem(p, Fighter.ZORO, "item.onepiece.shusui.desc"),
		new Item.Properties().sword(ToolMaterial.NETHERITE, 4.0F, -2.3F).rarity(Rarity.RARE).fireResistant());
	public static final Item ENMA = register("enma", p -> new StyleItem(p, Fighter.ZORO, "item.onepiece.enma.desc"),
		new Item.Properties().sword(ToolMaterial.NETHERITE, 6.0F, -2.3F).rarity(Rarity.EPIC).fireResistant());
	public static final Item SANJI_COOKBOOK = register("sanji_cookbook", p -> new StyleItem(p, Fighter.SANJI, "item.onepiece.sanji_cookbook.desc"),
		new Item.Properties().stacksTo(1).rarity(Rarity.RARE));

	public static final Item STRAW_HAT = register("straw_hat", Item::new, new Item.Properties().humanoidArmor(STRAW, ArmorType.HELMET).rarity(Rarity.EPIC));
	public static final Item ZORO_BANDANA = register("zoro_bandana", Item::new, new Item.Properties().humanoidArmor(BANDANA, ArmorType.HELMET).rarity(Rarity.RARE));
	public static final Item SANJI_SUIT = register("sanji_suit", Item::new, new Item.Properties().humanoidArmor(SUIT, ArmorType.CHESTPLATE).rarity(Rarity.RARE));

	public static final Item DRAGON_SCALE = register("dragon_scale", Item::new, new Item.Properties().rarity(Rarity.EPIC).fireResistant());
	public static final Item MOCHI = register("mochi", Item::new,
		new Item.Properties().rarity(Rarity.RARE).food(new FoodProperties.Builder().nutrition(10).saturationModifier(1.2F).alwaysEdible().build()));
	public static final Item LEOPARD_FANG = register("leopard_fang", Item::new, new Item.Properties().rarity(Rarity.RARE));

	public static final List<Item> TAB_ORDER = List.of(GUM_GUM_FRUIT, DRAGON_FRUIT, MOCHI_FRUIT, LEOPARD_FRUIT, WADO_ICHIMONJI, SHUSUI, ENMA, SANJI_COOKBOOK, STRAW_HAT, ZORO_BANDANA, SANJI_SUIT, DRAGON_SCALE, MOCHI, LEOPARD_FANG);

	public static final CreativeModeTab TAB = Registry.register(BuiltInRegistries.CREATIVE_MODE_TAB, OnePiece.id("one_piece"),
		FabricCreativeModeTab.builder()
			.title(Component.translatable("itemGroup.onepiece"))
			.icon(() -> new ItemStack(STRAW_HAT))
			.displayItems((params, output) -> {
				TAB_ORDER.forEach(output::accept);
				ModEntities.SPAWN_EGGS.forEach(output::accept);
			})
			.build());

	private ModItems() {
	}

	private static ArmorMaterial material(ResourceKey<EquipmentAsset> asset, int defense, int enchant) {
		return new ArmorMaterial(25, Map.of(ArmorType.HELMET, defense, ArmorType.CHESTPLATE, defense + 3, ArmorType.LEGGINGS, defense + 1, ArmorType.BOOTS, defense, ArmorType.BODY, defense),
			enchant, SoundEvents.ARMOR_EQUIP_LEATHER, 1.0F, 0.0F, ItemTags.REPAIRS_LEATHER_ARMOR, asset);
	}

	static Item register(String name, Function<Item.Properties, Item> factory, Item.Properties properties) {
		ResourceKey<Item> key = ResourceKey.create(Registries.ITEM, OnePiece.id(name));
		return Registry.register(BuiltInRegistries.ITEM, key, factory.apply(properties.setId(key)));
	}

	public static void init() {
	}
}
