package com.tfue.onepiece.entity;

import com.tfue.onepiece.power.Fighter;
import com.tfue.onepiece.power.Form;
import com.tfue.onepiece.registry.ModItems;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.BossEvent;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.level.Level;

/** Charlotte Katakuri. Mochi fighter with Future Sight, who awakens his fruit at half health. */
public class KatakuriEntity extends BossEntity {
	private static final Form[] PHASES = {Form.BASE_KATAKURI, Form.KATAKURI_AWAKENED};
	private static final float[] THRESHOLDS = {1.0F, 0.5F};

	public KatakuriEntity(EntityType<? extends Monster> type, Level level) {
		super(type, level, BossEvent.BossBarColor.PINK);
	}

	public static AttributeSupplier.Builder createAttributes() {
		return Monster.createMonsterAttributes()
			.add(Attributes.MAX_HEALTH, 1024.0)
			.add(Attributes.ATTACK_DAMAGE, 18.0)
			.add(Attributes.ARMOR, 12.0)
			.add(Attributes.ARMOR_TOUGHNESS, 6.0)
			.add(Attributes.MOVEMENT_SPEED, 0.33)
			.add(Attributes.KNOCKBACK_RESISTANCE, 1.0)
			.add(Attributes.FOLLOW_RANGE, 48.0)
			.add(Attributes.STEP_HEIGHT, 1.5);
	}

	@Override
	public Fighter fighter() {
		return Fighter.KATAKURI;
	}

	@Override
	protected float sizeFactor() {
		return 1.65F;
	}

	@Override
	protected Form[] phases() {
		return PHASES;
	}

	@Override
	protected float[] thresholds() {
		return THRESHOLDS;
	}

	@Override
	protected void dropCustomDeathLoot(ServerLevel level, DamageSource source, boolean killedByPlayer) {
		super.dropCustomDeathLoot(level, source, killedByPlayer);
		this.spawnAtLocation(level, ModItems.MOCHI_FRUIT);
		for (int n = 0; n < 4; n++) {
			this.spawnAtLocation(level, ModItems.MOCHI);
		}
	}
}
