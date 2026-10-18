package com.tfue.onepiece.entity;

import com.tfue.onepiece.OnePiece;
import com.tfue.onepiece.power.Anim;
import com.tfue.onepiece.power.Fighter;
import com.tfue.onepiece.power.Form;
import com.tfue.onepiece.power.Move;
import com.tfue.onepiece.power.Moves;
import com.tfue.onepiece.power.PowerData;
import com.tfue.onepiece.power.Powers;
import com.tfue.onepiece.registry.ModSounds;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import net.minecraft.network.chat.Component;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.resources.Identifier;
import net.minecraft.server.level.ServerBossEvent;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;
import net.minecraft.world.BossEvent;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.AttributeModifier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.FloatGoal;
import net.minecraft.world.entity.ai.goal.LookAtPlayerGoal;
import net.minecraft.world.entity.ai.goal.MeleeAttackGoal;
import net.minecraft.world.entity.ai.goal.RandomLookAroundGoal;
import net.minecraft.world.entity.ai.goal.WaterAvoidingRandomStrollGoal;
import net.minecraft.world.entity.ai.goal.target.HurtByTargetGoal;
import net.minecraft.world.entity.ai.goal.target.NearestAttackableTargetGoal;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import net.minecraft.world.phys.Vec3;

/**
 * A boss is a fighter controlled by the game: it uses the exact same forms, skins and moves a player
 * gets from that fighter's Devil Fruit, and transforms as its health drops.
 */
public abstract class BossEntity extends Monster {
	private static final EntityDataAccessor<Integer> FORM = SynchedEntityData.defineId(BossEntity.class, EntityDataSerializers.INT);
	private static final EntityDataAccessor<Integer> ANIM = SynchedEntityData.defineId(BossEntity.class, EntityDataSerializers.INT);
	private static final EntityDataAccessor<Long> ANIM_START = SynchedEntityData.defineId(BossEntity.class, EntityDataSerializers.LONG);
	private static final Identifier SIZE = OnePiece.id("boss_size");

	private final ServerBossEvent bossEvent;
	private final Map<String, Long> cooldowns = new HashMap<>();
	private int nextAttack = 50;

	protected BossEntity(EntityType<? extends Monster> type, Level level, BossEvent.BossBarColor color) {
		super(type, level);
		this.bossEvent = new ServerBossEvent(this.getUUID(), this.getDisplayName(), color, BossEvent.BossBarOverlay.NOTCHED_10);
		this.bossEvent.setDarkenScreen(true);
		this.xpReward = 500;
		this.setPersistenceRequired();
	}

	public abstract Fighter fighter();

	/** How much bigger than a player this boss is, before its form's own size. */
	protected abstract float sizeFactor();

	/** Forms in order, and the health fraction at which each one starts. */
	protected abstract Form[] phases();

	protected abstract float[] thresholds();

	@Override
	protected void defineSynchedData(SynchedEntityData.Builder builder) {
		super.defineSynchedData(builder);
		builder.define(FORM, Form.BASE_LUFFY.ordinal());
		builder.define(ANIM, 0);
		builder.define(ANIM_START, 0L);
	}

	@Override
	protected void registerGoals() {
		this.goalSelector.addGoal(0, new FloatGoal(this));
		this.goalSelector.addGoal(2, new MeleeAttackGoal(this, 1.1, true));
		this.goalSelector.addGoal(7, new WaterAvoidingRandomStrollGoal(this, 0.8));
		this.goalSelector.addGoal(8, new LookAtPlayerGoal(this, Player.class, 24.0F));
		this.goalSelector.addGoal(8, new RandomLookAroundGoal(this));
		this.targetSelector.addGoal(1, new HurtByTargetGoal(this));
		this.targetSelector.addGoal(2, new NearestAttackableTargetGoal<>(this, Player.class, true));
	}

	public Form getForm() {
		Form form = Form.byId(this.entityData.get(FORM));
		return form.fighter == this.fighter() ? form : this.phases()[0];
	}

	public PowerData powerView() {
		Form form = this.getForm();
		Fighter fighter = this.fighter();
		return new PowerData(fighter.bit(), fighter, form, PowerData.MAX_STAMINA, this.isEnraged(), false, false,
			Anim.byId(this.entityData.get(ANIM)), this.entityData.get(ANIM_START), 0, Map.of(), 0L);
	}

	public float damageMultiplier() {
		return 0.3F * this.getForm().damage * (this.isEnraged() ? 1.25F : 1.0F);
	}

	public boolean isEnraged() {
		return this.getHealth() < this.getMaxHealth() * 0.5F;
	}

	private void setForm(Form form) {
		this.entityData.set(FORM, form.ordinal());
		AttributeInstance scale = this.getAttribute(Attributes.SCALE);
		if (scale != null) {
			scale.addOrUpdateTransientModifier(new AttributeModifier(SIZE, form.scale * this.sizeFactor() - 1.0, AttributeModifier.Operation.ADD_MULTIPLIED_BASE));
		}
		this.setNoGravity(form == Form.KAIDO_DRAGON);
		this.refreshDimensions();
	}

	@Override
	public void tick() {
		super.tick();
		if (!this.level().isClientSide() && this.tickCount == 1) {
			this.setForm(this.getForm());
		}
	}

	@Override
	protected void customServerAiStep(ServerLevel level) {
		super.customServerAiStep(level);
		this.bossEvent.setProgress(this.getHealth() / this.getMaxHealth());
		this.checkPhase(level);
		LivingEntity target = this.getTarget();
		if (target == null || !target.isAlive()) {
			if (this.getForm() == Form.KAIDO_DRAGON) {
				this.setDeltaMovement(this.getDeltaMovement().scale(0.8).add(0, -0.01, 0));
			}
			return;
		}
		if (this.getForm() == Form.KAIDO_DRAGON) {
			this.dragonFlight(target);
		}
		if (this.entityData.get(ANIM) != 0 && level.getGameTime() > this.entityData.get(ANIM_START) + 60) {
			this.entityData.set(ANIM, 0);
		}
		if (--this.nextAttack <= 0 && this.distanceToSqr(target) < 36 * 36 && this.hasLineOfSight(target)) {
			this.attack(level, target);
		}
	}

	private void checkPhase(ServerLevel level) {
		Form[] phases = this.phases();
		float[] at = this.thresholds();
		float health = this.getHealth() / this.getMaxHealth();
		Form want = phases[0];
		for (int n = 0; n < phases.length; n++) {
			if (health <= at[n]) {
				want = phases[n];
			}
		}
		Form current = this.getForm();
		if (want.ordinal() > current.ordinal()) {
			this.transform(level, want);
		}
	}

	private void transform(ServerLevel level, Form form) {
		this.setForm(form);
		this.entityData.set(ANIM, Anim.FORM_SHIFT.ordinal());
		this.entityData.set(ANIM_START, level.getGameTime());
		this.nextAttack = 50;
		this.level().playSound(null, this.getX(), this.getY(), this.getZ(), ModSounds.BOSS_ROAR, SoundSource.HOSTILE, 3.0F, 0.7F);
		this.level().playSound(null, this.getX(), this.getY(), this.getZ(), ModSounds.FORM_UP, SoundSource.HOSTILE, 3.0F, 0.6F);
		VfxEntity.create(level, VfxType.CONQUEROR, this.position().add(0, 2, 0), 0xFFE0102A, 22.0F, 36).owner(this).spawn();
		VfxEntity.create(level, VfxType.SHOCKWAVE, this.position().add(0, 0.1, 0), form.color, 16.0F, 24).spawn();
		Powers.sendCutscene(this, form);
		for (ServerPlayer near : level.getPlayers(p -> p.distanceToSqr(this) < 64 * 64)) {
			Powers.shake(near, 1.0F, 30);
			if (near.distanceToSqr(this) > 64 * 64 || !form.hasCutscene()) {
				near.sendOverlayMessage(Component.translatable("message.onepiece.boss_transform", this.getDisplayName(), Component.translatable(form.translationKey())).withColor(form.color & 0xFFFFFF));
			}
		}
		this.heal(this.getMaxHealth() * 0.05F);
	}

	private void attack(ServerLevel level, LivingEntity target) {
		List<Move> moves = Moves.forForm(this.getForm());
		if (moves.isEmpty()) {
			return;
		}
		long now = level.getGameTime();
		double dist = this.distanceTo(target);
		Move pick = null;
		for (int tries = 0; tries < 6 && pick == null; tries++) {
			Move candidate = moves.get(this.random.nextInt(moves.size()));
			if (this.cooldowns.getOrDefault(candidate.id(), 0L) <= now && suits(candidate, dist)) {
				pick = candidate;
			}
		}
		if (pick == null) {
			this.nextAttack = 10;
			return;
		}
		this.faceTarget(target);
		this.entityData.set(ANIM, pick.anim().ordinal());
		this.entityData.set(ANIM_START, now);
		this.cooldowns.put(pick.id(), now + (long) (pick.cooldown() * 0.7F) + 20);
		pick.action().run(this);
		this.nextAttack = (this.isEnraged() ? 28 : 45) + this.random.nextInt(25);
	}

	/** Skip defensive or movement-only skills and keep melee moves for close range. */
	private static boolean suits(Move move, double dist) {
		return switch (move.id()) {
			case "geppo", "sky_walk", "soru", "tekkai", "kami_e", "mochi_wall", "gum_gum_balloon" -> false;
			default -> switch (move.anim()) {
				case KICK_HIGH, KICK_SPIN, CLAW, SWORD_SPIN, FINGER -> dist < 8;
				default -> true;
			};
		};
	}

	private void faceTarget(LivingEntity target) {
		Vec3 to = target.getBoundingBox().getCenter().subtract(this.getEyePosition());
		float yaw = (float) (Mth.atan2(to.z, to.x) * Mth.RAD_TO_DEG) - 90.0F;
		float pitch = (float) -(Mth.atan2(to.y, to.horizontalDistance()) * Mth.RAD_TO_DEG);
		this.setYRot(yaw);
		this.setXRot(pitch);
		this.yHeadRot = yaw;
		this.yBodyRot = yaw;
	}

	/** The Azure Dragon circles above its target instead of walking. */
	private void dragonFlight(LivingEntity target) {
		this.getNavigation().stop();
		double angle = this.tickCount * 0.03;
		Vec3 goal = target.position().add(Math.cos(angle) * 14, 8 + Math.sin(this.tickCount * 0.05) * 2, Math.sin(angle) * 14);
		Vec3 move = goal.subtract(this.position());
		Vec3 velocity = this.getDeltaMovement().scale(0.85).add(move.normalize().scale(Math.min(0.12, move.length() * 0.02)));
		this.setDeltaMovement(velocity);
		this.getLookControl().setLookAt(target);
	}

	@Override
	public boolean hurtServer(ServerLevel level, DamageSource source, float damage) {
		if (source.getEntity() != null && this.random.nextFloat() < Powers.dodgeChance(this)) {
			Vec3 side = this.position().subtract(source.getEntity().position()).normalize().yRot((float) Math.PI / 2).scale(this.random.nextBoolean() ? 2.0 : -2.0);
			this.setDeltaMovement(side.x * 0.5, 0.3, side.z * 0.5);
			this.hurtMarked = true;
			VfxEntity.create(level, VfxType.DASH_TRAIL, this.position().add(0, 2, 0), 0xFFFF66AA, 1.0F, 10).target(this.position().add(side).add(0, 2, 0)).spawn();
			this.level().playSound(null, this.getX(), this.getY(), this.getZ(), ModSounds.WHOOSH, SoundSource.HOSTILE, 1.2F, 1.6F);
			return false;
		}
		return super.hurtServer(level, source, damage);
	}

	@Override
	public boolean causeFallDamage(double distance, float multiplier, DamageSource source) {
		return false;
	}

	@Override
	public void startSeenByPlayer(ServerPlayer player) {
		super.startSeenByPlayer(player);
		this.bossEvent.addPlayer(player);
	}

	@Override
	public void stopSeenByPlayer(ServerPlayer player) {
		super.stopSeenByPlayer(player);
		this.bossEvent.removePlayer(player);
	}

	@Override
	public void setCustomName(Component name) {
		super.setCustomName(name);
		this.bossEvent.setName(this.getDisplayName());
	}

	@Override
	protected void addAdditionalSaveData(ValueOutput output) {
		super.addAdditionalSaveData(output);
		output.putInt("OnePieceForm", this.getForm().ordinal());
	}

	@Override
	protected void readAdditionalSaveData(ValueInput input) {
		super.readAdditionalSaveData(input);
		this.entityData.set(FORM, input.getIntOr("OnePieceForm", this.phases()[0].ordinal()));
		if (this.hasCustomName()) {
			this.bossEvent.setName(this.getDisplayName());
		}
	}

	@Override
	public boolean removeWhenFarAway(double distSqr) {
		return false;
	}

	@Override
	public boolean canUsePortal(boolean ignorePassenger) {
		return false;
	}
}
