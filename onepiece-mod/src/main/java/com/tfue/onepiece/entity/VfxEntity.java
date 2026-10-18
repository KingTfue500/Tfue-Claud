package com.tfue.onepiece.entity;

import com.tfue.onepiece.power.Combat;
import com.tfue.onepiece.registry.ModEntities;
import java.util.HashSet;
import java.util.Set;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;
import org.joml.Vector3f;
import org.joml.Vector3fc;
import org.jspecify.annotations.Nullable;

/**
 * One entity type draws every custom effect in the mod. The client renderer picks the look from
 * {@link #getVfxType()}, and the server moves it and deals damage when it is a projectile.
 */
public class VfxEntity extends Entity {
	private static final EntityDataAccessor<Integer> TYPE = SynchedEntityData.defineId(VfxEntity.class, EntityDataSerializers.INT);
	private static final EntityDataAccessor<Integer> COLOR = SynchedEntityData.defineId(VfxEntity.class, EntityDataSerializers.INT);
	private static final EntityDataAccessor<Float> SIZE = SynchedEntityData.defineId(VfxEntity.class, EntityDataSerializers.FLOAT);
	private static final EntityDataAccessor<Integer> LIFE = SynchedEntityData.defineId(VfxEntity.class, EntityDataSerializers.INT);
	private static final EntityDataAccessor<Integer> OWNER = SynchedEntityData.defineId(VfxEntity.class, EntityDataSerializers.INT);
	private static final EntityDataAccessor<Integer> VARIANT = SynchedEntityData.defineId(VfxEntity.class, EntityDataSerializers.INT);
	private static final EntityDataAccessor<Vector3fc> TARGET = SynchedEntityData.defineId(VfxEntity.class, EntityDataSerializers.VECTOR3);
	private static final EntityDataAccessor<Float> SPIN = SynchedEntityData.defineId(VfxEntity.class, EntityDataSerializers.FLOAT);

	// Server-only projectile settings.
	private float damage;
	private float knockback;
	private float upward;
	private boolean fire;
	private boolean pierce;
	private boolean homing;
	private float hitRadius;
	private int impactEffect = -1;
	private final Set<Integer> alreadyHit = new HashSet<>();

	public VfxEntity(EntityType<? extends VfxEntity> type, Level level) {
		super(type, level);
		this.noPhysics = true;
	}

	public static VfxEntity create(Level level, VfxType type, Vec3 pos, int color, float size, int life) {
		VfxEntity vfx = new VfxEntity(ModEntities.VFX, level);
		vfx.setPos(pos);
		vfx.entityData.set(TYPE, type.ordinal());
		vfx.entityData.set(COLOR, color);
		vfx.entityData.set(SIZE, size);
		vfx.entityData.set(LIFE, life);
		vfx.entityData.set(TARGET, new Vector3f((float) pos.x, (float) pos.y, (float) pos.z));
		return vfx;
	}

	public VfxEntity owner(Entity owner) {
		this.entityData.set(OWNER, owner.getId());
		return this;
	}

	public VfxEntity variant(int variant) {
		this.entityData.set(VARIANT, variant);
		return this;
	}

	public VfxEntity spin(float spin) {
		this.entityData.set(SPIN, spin);
		return this;
	}

	public VfxEntity target(Vec3 target) {
		this.entityData.set(TARGET, new Vector3f((float) target.x, (float) target.y, (float) target.z));
		return this;
	}

	public VfxEntity facing(Vec3 dir) {
		double horizontal = dir.horizontalDistance();
		this.setYRot((float) (Math.atan2(-dir.x, dir.z) * 180.0 / Math.PI));
		this.setXRot((float) (-Math.atan2(dir.y, horizontal) * 180.0 / Math.PI));
		this.yRotO = this.getYRot();
		this.xRotO = this.getXRot();
		return this;
	}

	public VfxEntity projectile(Vec3 velocity, float damage, float knockback, float hitRadius) {
		this.setDeltaMovement(velocity);
		this.damage = damage;
		this.knockback = knockback;
		this.hitRadius = hitRadius;
		return this.facing(velocity);
	}

	public VfxEntity upward(float upward) {
		this.upward = upward;
		return this;
	}

	public VfxEntity fire() {
		this.fire = true;
		return this;
	}

	public VfxEntity pierce() {
		this.pierce = true;
		return this;
	}

	public VfxEntity homing() {
		this.homing = true;
		return this;
	}

	/** Spawn a shockwave of this color when the projectile hits something. */
	public VfxEntity impact(int color) {
		this.impactEffect = color;
		return this;
	}

	public VfxEntity spawn() {
		this.level().addFreshEntity(this);
		return this;
	}

	@Override
	protected void defineSynchedData(SynchedEntityData.Builder builder) {
		builder.define(TYPE, 0);
		builder.define(COLOR, 0xFFFFFFFF);
		builder.define(SIZE, 1.0F);
		builder.define(LIFE, 20);
		builder.define(OWNER, -1);
		builder.define(VARIANT, 0);
		builder.define(TARGET, new Vector3f());
		builder.define(SPIN, 0.0F);
	}

	public VfxType getVfxType() {
		return VfxType.byId(this.entityData.get(TYPE));
	}

	public int getColor() {
		return this.entityData.get(COLOR);
	}

	public float getSize() {
		return this.entityData.get(SIZE);
	}

	public int getLife() {
		return this.entityData.get(LIFE);
	}

	public int getVariant() {
		return this.entityData.get(VARIANT);
	}

	public float getSpin() {
		return this.entityData.get(SPIN);
	}

	public Vec3 getTarget() {
		Vector3fc t = this.entityData.get(TARGET);
		return new Vec3(t.x(), t.y(), t.z());
	}

	public @Nullable Entity getOwner() {
		int id = this.entityData.get(OWNER);
		return id < 0 ? null : this.level().getEntity(id);
	}

	@Override
	public void tick() {
		super.tick();
		this.xo = this.getX();
		this.yo = this.getY();
		this.zo = this.getZ();
		Vec3 motion = this.getDeltaMovement();
		if (!this.level().isClientSide()) {
			if (this.tickCount >= this.getLife()) {
				this.discard();
				return;
			}
			if (this.damage > 0.0F && this.level() instanceof ServerLevel serverLevel) {
				this.serverProjectileTick(serverLevel, motion);
			}
		}
		if (motion.lengthSqr() > 1.0E-6) {
			this.setPos(this.position().add(motion));
		}
	}

	private void serverProjectileTick(ServerLevel level, Vec3 motion) {
		Entity owner = this.getOwner();
		if (this.homing) {
			LivingEntity target = Combat.nearestTarget(owner instanceof LivingEntity l ? l : null, this.position(), 24.0, this);
			if (target != null && motion.lengthSqr() > 0) {
				Vec3 want = target.getBoundingBox().getCenter().subtract(this.position()).normalize().scale(motion.length());
				motion = motion.lerp(want, 0.25);
				this.setDeltaMovement(motion);
				this.facing(motion);
			}
		}

		if (motion.lengthSqr() > 1.0E-6 && this.getVfxType() != VfxType.TORNADO) {
			BlockHitResult hit = level.clip(new ClipContext(this.position(), this.position().add(motion), ClipContext.Block.COLLIDER, ClipContext.Fluid.NONE, this));
			if (hit.getType() == HitResult.Type.BLOCK) {
				this.explodeHere(level, owner);
				return;
			}
		}

		AABB box = new AABB(this.position(), this.position()).inflate(this.hitRadius).expandTowards(motion);
		for (LivingEntity target : level.getEntitiesOfClass(LivingEntity.class, box, e -> e.isAlive() && e != owner)) {
			if (!this.alreadyHit.add(target.getId())) {
				if (this.getVfxType() == VfxType.TORNADO && this.tickCount % 6 == 0) {
					this.alreadyHit.remove(target.getId());
				}
				continue;
			}
			Vec3 push = motion.lengthSqr() > 1.0E-6 ? motion.normalize() : target.position().subtract(this.position()).normalize();
			if (this.getVfxType() == VfxType.TORNADO) {
				target.setDeltaMovement(target.getDeltaMovement().add(0, 0.55, 0));
				target.hurtMarked = true;
			}
			Combat.hit(owner instanceof LivingEntity l ? l : null, target, this.damage, push, this.knockback, this.upward, this.fire);
			if (!this.pierce) {
				this.explodeHere(level, owner);
				return;
			}
		}
	}

	private void explodeHere(ServerLevel level, @Nullable Entity owner) {
		if (this.impactEffect != -1) {
			VfxEntity.create(level, VfxType.SHOCKWAVE, this.position(), this.impactEffect, this.getSize() * 1.6F, 14).spawn();
			VfxEntity.create(level, VfxType.IMPACT, this.position(), this.impactEffect, this.getSize(), 8).spawn();
			Combat.hitSphere(owner instanceof LivingEntity l ? l : null, this.position(), this.getSize() * 1.2, this.damage * 0.6F, this.knockback, 0.4F, this.fire);
		}
		this.discard();
	}

	@Override
	public boolean hurtServer(ServerLevel level, DamageSource source, float damage) {
		return false;
	}

	@Override
	public boolean isPickable() {
		return false;
	}

	@Override
	public boolean shouldBeSaved() {
		return false;
	}

	@Override
	protected void readAdditionalSaveData(ValueInput input) {
	}

	@Override
	protected void addAdditionalSaveData(ValueOutput output) {
	}
}
