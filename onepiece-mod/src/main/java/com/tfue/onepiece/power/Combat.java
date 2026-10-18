package com.tfue.onepiece.power;

import com.tfue.onepiece.entity.VfxEntity;
import com.tfue.onepiece.entity.VfxType;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.function.Consumer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;
import org.jspecify.annotations.Nullable;

/** Damage, targeting and movement helpers shared by every move and boss attack. */
public final class Combat {
	private Combat() {
	}

	public static float multiplier(LivingEntity attacker) {
		if (attacker instanceof ServerPlayer player) {
			PowerData data = Powers.get(player);
			float mult = data.active() ? data.form().damage : 1.0F;
			if (data.armament()) {
				mult *= 1.5F;
			}
			if (data.giantUntil() > player.level().getGameTime()) {
				mult *= 1.5F;
			}
			return mult * GearBonus.damage(player);
		}
		if (attacker instanceof com.tfue.onepiece.entity.BossEntity boss) {
			return boss.damageMultiplier();
		}
		return 1.0F;
	}

	public static void hit(@Nullable LivingEntity attacker, LivingEntity target, float damage, Vec3 dir, float knockback, float upward, boolean fire) {
		if (!(target.level() instanceof ServerLevel level) || target == attacker) {
			return;
		}
		if (attacker != null && attacker.isAlliedTo(target)) {
			return;
		}
		if (target instanceof Player p && (p.isCreative() || p.isSpectator())) {
			return;
		}
		if (!canHit(attacker, target, level)) {
			return;
		}
		DamageSource source;
		if (attacker instanceof Player player) {
			source = level.damageSources().playerAttack(player);
		} else if (attacker != null) {
			source = level.damageSources().mobAttack(attacker);
		} else {
			source = level.damageSources().magic();
		}
		float amount = attacker != null ? damage * multiplier(attacker) : damage;
		target.invulnerableTime = 0;
		target.hurtServer(level, source, amount);
		if (fire) {
			target.igniteForSeconds(5.0F);
		}
		Vec3 flat = new Vec3(dir.x, 0, dir.z);
		if (flat.lengthSqr() > 1.0E-6) {
			flat = flat.normalize();
		}
		double resist = 1.0 - Math.min(0.9, target.getAttributeValue(net.minecraft.world.entity.ai.attributes.Attributes.KNOCKBACK_RESISTANCE));
		if (attacker instanceof com.tfue.onepiece.entity.BossEntity && target instanceof Player) {
			// Boss skills are tuned against mobs; keep players in the fight instead of across the map.
			resist *= 0.3;
		}
		target.setDeltaMovement(target.getDeltaMovement().add(flat.x * knockback * 0.5 * resist, (upward + knockback * 0.08) * resist, flat.z * knockback * 0.5 * resist));
		target.hurtMarked = true;
	}

	/** Never hit your own pets or armor stands, and respect the server's PvP setting. */
	public static boolean canHit(@Nullable LivingEntity attacker, LivingEntity target, ServerLevel level) {
		if (target instanceof net.minecraft.world.entity.decoration.ArmorStand) {
			return false;
		}
		if (attacker != null && target instanceof net.minecraft.world.entity.OwnableEntity pet && pet.getOwner() == attacker) {
			return false;
		}
		if (attacker instanceof Player && target instanceof Player && !level.isPvpAllowed()) {
			return false;
		}
		return true;
	}

	public static List<LivingEntity> inSphere(@Nullable LivingEntity attacker, Vec3 center, double radius) {
		AABB box = new AABB(center, center).inflate(radius);
		List<LivingEntity> list = attacker != null
			? attacker.level().getEntitiesOfClass(LivingEntity.class, box, e -> e.isAlive() && e != attacker && e.position().distanceTo(center) <= radius + e.getBbWidth())
			: new ArrayList<>();
		return list;
	}

	public static int hitSphere(@Nullable LivingEntity attacker, Vec3 center, double radius, float damage, float knockback, float upward, boolean fire) {
		if (attacker == null) {
			return 0;
		}
		int count = 0;
		for (LivingEntity target : inSphere(attacker, center, radius)) {
			hit(attacker, target, damage, target.position().subtract(center), knockback, upward, fire);
			count++;
		}
		return count;
	}

	/** Everything inside a cone in front of the attacker. */
	public static List<LivingEntity> inCone(LivingEntity attacker, double range, double halfAngleDeg) {
		Vec3 eye = attacker.getEyePosition();
		Vec3 look = attacker.getLookAngle();
		double cos = Math.cos(Math.toRadians(halfAngleDeg));
		List<LivingEntity> out = new ArrayList<>();
		for (LivingEntity e : attacker.level().getEntitiesOfClass(LivingEntity.class, attacker.getBoundingBox().inflate(range), e -> e.isAlive() && e != attacker)) {
			Vec3 to = e.getBoundingBox().getCenter().subtract(eye);
			double dist = to.length();
			if (dist <= range + e.getBbWidth() && (dist < 1.5 || to.normalize().dot(look) >= cos)) {
				out.add(e);
			}
		}
		return out;
	}

	public static int hitCone(LivingEntity attacker, double range, double halfAngle, float damage, float knockback, float upward, boolean fire) {
		int count = 0;
		for (LivingEntity target : inCone(attacker, range, halfAngle)) {
			hit(attacker, target, damage, attacker.getLookAngle(), knockback, upward, fire);
			count++;
		}
		return count;
	}

	/** Everything along the look ray, stopping at the first solid block. */
	public static List<LivingEntity> inLine(LivingEntity attacker, double range, double radius) {
		Vec3 eye = attacker.getEyePosition();
		Vec3 end = rayEnd(attacker, range);
		Vec3 dir = end.subtract(eye);
		double len = dir.length();
		Vec3 n = len > 0 ? dir.scale(1.0 / len) : attacker.getLookAngle();
		List<LivingEntity> out = new ArrayList<>();
		AABB box = new AABB(eye, end).inflate(radius + 1.0);
		for (LivingEntity e : attacker.level().getEntitiesOfClass(LivingEntity.class, box, e -> e.isAlive() && e != attacker)) {
			Vec3 c = e.getBoundingBox().getCenter().subtract(eye);
			double t = Math.max(0, Math.min(len, c.dot(n)));
			Vec3 closest = n.scale(t);
			if (c.distanceTo(closest) <= radius + e.getBbWidth() * 0.7) {
				out.add(e);
			}
		}
		out.sort(Comparator.comparingDouble(e -> e.distanceToSqr(eye)));
		return out;
	}

	public static @Nullable LivingEntity firstInLine(LivingEntity attacker, double range, double radius) {
		List<LivingEntity> list = inLine(attacker, range, radius);
		return list.isEmpty() ? null : list.get(0);
	}

	public static Vec3 rayEnd(LivingEntity entity, double range) {
		Vec3 eye = entity.getEyePosition();
		Vec3 end = eye.add(entity.getLookAngle().scale(range));
		BlockHitResult hit = entity.level().clip(new ClipContext(eye, end, ClipContext.Block.COLLIDER, ClipContext.Fluid.NONE, entity));
		return hit.getType() == HitResult.Type.BLOCK ? hit.getLocation() : end;
	}

	public static @Nullable BlockHitResult rayBlock(LivingEntity entity, double range) {
		Vec3 eye = entity.getEyePosition();
		BlockHitResult hit = entity.level().clip(new ClipContext(eye, eye.add(entity.getLookAngle().scale(range)), ClipContext.Block.COLLIDER, ClipContext.Fluid.NONE, entity));
		return hit.getType() == HitResult.Type.BLOCK ? hit : null;
	}

	public static @Nullable LivingEntity nearestTarget(@Nullable LivingEntity owner, Vec3 from, double range, @Nullable Entity except) {
		if (owner == null) {
			return null;
		}
		LivingEntity best = null;
		double bestDist = range * range;
		for (LivingEntity e : owner.level().getEntitiesOfClass(LivingEntity.class, new AABB(from, from).inflate(range), e -> e.isAlive() && e != owner && e != except && !(e instanceof Player p && (p.isCreative() || p.isSpectator())))) {
			double d = e.distanceToSqr(from);
			if (d < bestDist) {
				bestDist = d;
				best = e;
			}
		}
		return best;
	}

	/**
	 * Moves the attacker forward in small steps until a wall, calling {@code onPass} for each entity crossed.
	 * Used by Oni Giri, Jet Dash, Rhino Schneider and every other dash.
	 */
	public static Vec3 dash(LivingEntity player, double distance, int trailColor, Consumer<LivingEntity> onPass) {
		return dash(player, distance, trailColor, onPass, false);
	}

	/** Dash forward; with {@code stopAtTarget} the dash ends right in front of the first creature it reaches. */
	public static Vec3 dash(LivingEntity player, double distance, int trailColor, Consumer<LivingEntity> onPass, boolean stopAtTarget) {
		ServerLevel level = (ServerLevel) player.level();
		Vec3 dir = player.getLookAngle();
		Vec3 flat = new Vec3(dir.x, Math.max(-0.3, Math.min(0.3, dir.y)), dir.z).normalize();
		Vec3 start = player.position();
		Vec3 pos = start;
		List<Integer> passed = new ArrayList<>();
		boolean struck = false;
		for (double d = 0; d < distance; d += 0.5) {
			Vec3 next = pos.add(flat.scale(0.5));
			AABB box = player.getBoundingBox().move(next.subtract(player.position()));
			if (!level.noCollision(player, box)) {
				Vec3 up = next.add(0, 1.0, 0);
				AABB upBox = player.getBoundingBox().move(up.subtract(player.position()));
				if (level.noCollision(player, upBox)) {
					next = up;
				} else {
					break;
				}
			}
			if (stopAtTarget) {
				List<LivingEntity> ahead = level.getEntitiesOfClass(LivingEntity.class, player.getBoundingBox().move(next.subtract(player.position())).inflate(1.5),
					e -> e.isAlive() && e != player && canHit(player, e, level));
				if (!ahead.isEmpty()) {
					ahead.forEach(onPass);
					break;
				}
			}
			pos = next;
			for (LivingEntity e : level.getEntitiesOfClass(LivingEntity.class, player.getBoundingBox().move(pos.subtract(player.position())).inflate(1.2), e -> e.isAlive() && e != player)) {
				if (!passed.contains(e.getId())) {
					passed.add(e.getId());
					onPass.accept(e);
					struck |= canHit(player, e, level);
				}
			}
			if (stopAtTarget && struck) {
				break;
			}
		}
		VfxEntity.create(level, VfxType.DASH_TRAIL, start.add(0, 1, 0), trailColor, 1.0F, 12).target(pos.add(0, 1, 0)).owner(player).spawn();
		player.teleportTo(pos.x, pos.y, pos.z);
		player.setDeltaMovement(flat.scale(0.4));
		player.hurtMarked = true;
		player.fallDistance = 0;
		return pos;
	}

	public static void launch(LivingEntity player, Vec3 velocity) {
		player.setDeltaMovement(velocity);
		player.hurtMarked = true;
		player.fallDistance = 0;
	}
}
