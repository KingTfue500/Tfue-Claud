package com.tfue.onepiece.registry;

import com.tfue.onepiece.OnePiece;
import com.tfue.onepiece.entity.KaidoEntity;
import com.tfue.onepiece.entity.KatakuriEntity;
import com.tfue.onepiece.entity.LucciEntity;
import com.tfue.onepiece.entity.VfxEntity;
import java.util.ArrayList;
import java.util.List;
import net.fabricmc.fabric.api.object.builder.v1.entity.FabricDefaultAttributeRegistry;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.Rarity;
import net.minecraft.world.item.SpawnEggItem;

public final class ModEntities {
	public static final List<Item> SPAWN_EGGS = new ArrayList<>();

	public static final EntityType<VfxEntity> VFX = register("vfx", EntityType.Builder.<VfxEntity>of(VfxEntity::new, MobCategory.MISC)
		.noLootTable().noSave().noSummon().sized(0.5F, 0.5F).clientTrackingRange(10).updateInterval(2));
	public static final EntityType<KaidoEntity> KAIDO = register("kaido", EntityType.Builder.<KaidoEntity>of(KaidoEntity::new, MobCategory.MONSTER)
		.sized(0.6F, 1.8F).eyeHeight(1.62F).fireImmune().clientTrackingRange(16));
	public static final EntityType<KatakuriEntity> KATAKURI = register("katakuri", EntityType.Builder.<KatakuriEntity>of(KatakuriEntity::new, MobCategory.MONSTER)
		.sized(0.6F, 1.8F).eyeHeight(1.62F).clientTrackingRange(16));
	public static final EntityType<LucciEntity> LUCCI = register("lucci", EntityType.Builder.<LucciEntity>of(LucciEntity::new, MobCategory.MONSTER)
		.sized(0.6F, 1.8F).eyeHeight(1.62F).clientTrackingRange(16));

	private ModEntities() {
	}

	private static <T extends net.minecraft.world.entity.Entity> EntityType<T> register(String name, EntityType.Builder<T> builder) {
		ResourceKey<EntityType<?>> key = ResourceKey.create(Registries.ENTITY_TYPE, OnePiece.id(name));
		return Registry.register(BuiltInRegistries.ENTITY_TYPE, key, builder.build(key));
	}

	public static void init() {
		FabricDefaultAttributeRegistry.register(KAIDO, KaidoEntity.createAttributes());
		FabricDefaultAttributeRegistry.register(KATAKURI, KatakuriEntity.createAttributes());
		FabricDefaultAttributeRegistry.register(LUCCI, LucciEntity.createAttributes());
		SPAWN_EGGS.add(ModItems.register("kaido_spawn_egg", SpawnEggItem::new, new Item.Properties().spawnEgg(KAIDO).rarity(Rarity.EPIC)));
		SPAWN_EGGS.add(ModItems.register("katakuri_spawn_egg", SpawnEggItem::new, new Item.Properties().spawnEgg(KATAKURI).rarity(Rarity.EPIC)));
		SPAWN_EGGS.add(ModItems.register("lucci_spawn_egg", SpawnEggItem::new, new Item.Properties().spawnEgg(LUCCI).rarity(Rarity.EPIC)));
	}
}
