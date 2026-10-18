package com.tfue.onepiece.power;

import com.tfue.onepiece.OnePiece;
import com.tfue.onepiece.entity.VfxEntity;
import com.tfue.onepiece.entity.VfxType;
import com.tfue.onepiece.network.ActionPayload;
import com.tfue.onepiece.network.ShakePayload;
import com.tfue.onepiece.registry.ModSounds;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import net.fabricmc.fabric.api.attachment.v1.AttachmentRegistry;
import net.fabricmc.fabric.api.attachment.v1.AttachmentSyncPredicate;
import net.fabricmc.fabric.api.attachment.v1.AttachmentType;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.ChatFormatting;
import net.minecraft.core.Holder;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.ai.attributes.Attribute;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.AttributeModifier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.monster.Enemy;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.phys.Vec3;

/** Server-side power logic: stamina, forms, moves, Haki and passive form bonuses. */
public final class Powers {
	public static final AttachmentType<PowerData> DATA = AttachmentRegistry.create(OnePiece.id("power"), builder -> builder
		.persistent(PowerData.CODEC)
		.initializer(() -> PowerData.EMPTY)
		.copyOnDeath()
		.syncWith(PowerData.STREAM_CODEC, AttachmentSyncPredicate.all()));

	private static final Identifier SPEED = OnePiece.id("form_speed");
	private static final Identifier SCALE = OnePiece.id("form_scale");
	private static final Identifier JUMP = OnePiece.id("form_jump");
	private static final Identifier SAFE_FALL = OnePiece.id("rubber_body");
	private static final Identifier STEP = OnePiece.id("form_step");
	private static final Identifier ARMOR = OnePiece.id("form_armor");
	private static final Identifier ATTACK = OnePiece.id("form_attack");
	private static final Identifier KNOCKBACK = OnePiece.id("form_knockback");
	private static final Identifier REACH = OnePiece.id("form_reach");

	private static final Map<UUID, Integer> AIR_JUMPS = new HashMap<>();
	private static final Map<UUID, Long> CONQUEROR_READY = new HashMap<>();
	private static final Map<UUID, Long> DODGE_UNTIL = new HashMap<>();
	private static final java.util.Set<UUID> DRAGON_FLIGHT = new java.util.HashSet<>();

	private Powers() {
	}

	public static void init() {
	}

	/** Forget per-session timers when the world closes, so they never leak into the next world. */
	public static void clearAll() {
		AIR_JUMPS.clear();
		CONQUEROR_READY.clear();
		DODGE_UNTIL.clear();
		DRAGON_FLIGHT.clear();
	}

	public static void onDisconnect(ServerPlayer player) {
		AIR_JUMPS.remove(player.getUUID());
		DODGE_UNTIL.remove(player.getUUID());
		Scheduler.clear(player);
	}

	public static PowerData get(Player player) {
		PowerData data = player.getAttached(DATA);
		return data != null ? data : PowerData.EMPTY;
	}

	public static void set(Player player, PowerData data) {
		player.setAttached(DATA, data);
	}

	/** Power state of any fighter: players read their attachment, bosses report their current form. */
	public static PowerData view(LivingEntity entity) {
		if (entity instanceof Player player) {
			return get(player);
		}
		if (entity instanceof com.tfue.onepiece.entity.BossEntity boss) {
			return boss.powerView();
		}
		return PowerData.EMPTY;
	}

	public static void grantDodge(LivingEntity entity, int ticks) {
		DODGE_UNTIL.put(entity.getUUID(), entity.level().getGameTime() + ticks);
	}

	/** Chance to sidestep an incoming hit: Observation Haki, Katakuri's Future Sight, Lucci's Kami-e. */
	public static float dodgeChance(LivingEntity entity) {
		if (DODGE_UNTIL.getOrDefault(entity.getUUID(), 0L) > entity.level().getGameTime()) {
			return 1.0F;
		}
		PowerData data = view(entity);
		if (!data.active()) {
			return 0.0F;
		}
		float chance = data.observation() ? 0.4F : 0.0F;
		if (data.fighter() == Fighter.KATAKURI) {
			chance = data.observation() ? 0.6F : 0.25F;
		}
		return chance;
	}

	public static void sendCutscene(LivingEntity entity, Form form) {
		if (!form.hasCutscene() || !(entity.level() instanceof ServerLevel level)) {
			return;
		}
		com.tfue.onepiece.network.CutscenePayload payload = new com.tfue.onepiece.network.CutscenePayload(entity.getId(), form.ordinal());
		// A player's transformation only takes over their own camera; a boss transforming is shown to everyone nearby.
		for (ServerPlayer near : level.getPlayers(pl -> entity instanceof Player ? pl == entity : pl.distanceToSqr(entity) < 64 * 64)) {
			if (ServerPlayNetworking.canSend(near, com.tfue.onepiece.network.CutscenePayload.TYPE)) {
				ServerPlayNetworking.send(near, payload);
			}
		}
	}

	// ------------------------------------------------------------------ granting and switching

	public static void grant(ServerPlayer player, Fighter fighter, boolean announce) {
		PowerData data = get(player);
		boolean isNew = !data.owns(fighter);
		set(player, data.withFighter(fighter));
		resetModifiers(player);
		if (announce) {
			player.sendSystemMessage(Component.translatable(isNew ? "message.onepiece.learned" : "message.onepiece.switched",
				Component.translatable(fighter.translationKey()).withColor(fighter.color() & 0xFFFFFF)));
			sound(player, ModSounds.FORM_UP, 1.0F, 1.0F);
		}
	}

	public static void cycleFighter(ServerPlayer player) {
		PowerData data = get(player);
		Fighter[] all = Fighter.PLAYABLE;
		int start = Math.max(0, data.fighter().ordinal() - 1);
		for (int n = 1; n <= all.length; n++) {
			Fighter next = all[(start + n) % all.length];
			if (data.owns(next)) {
				if (next != data.fighter()) {
					grant(player, next, true);
				}
				return;
			}
		}
		player.sendOverlayMessage(Component.translatable("message.onepiece.no_power").withStyle(ChatFormatting.RED));
	}

	public static void reset(ServerPlayer player) {
		set(player, PowerData.EMPTY);
		resetModifiers(player);
	}

	// ------------------------------------------------------------------ forms

	public static void setForm(ServerPlayer player, Form form, boolean free) {
		PowerData data = get(player);
		if (!data.active() || form.fighter != data.fighter() || form == data.form()) {
			return;
		}
		if (form.isBase()) {
			endForm(player, false);
			return;
		}
		if (!free && !data.infinite() && data.stamina() < form.cost) {
			player.sendOverlayMessage(Component.translatable("message.onepiece.tired").withStyle(ChatFormatting.RED));
			return;
		}
		if (!free && !hasRoom(player, form.scale)) {
			player.sendOverlayMessage(Component.translatable("message.onepiece.no_room").withStyle(ChatFormatting.RED));
			return;
		}
		long now = player.level().getGameTime();
		PowerData next = data.withForm(form).withGiantUntil(0L).withAnim(Anim.FORM_SHIFT, now);
		if (!free && !data.infinite()) {
			next = next.withStamina(data.stamina() - form.cost);
		}
		set(player, next);
		ServerLevel level = player.level();
		VfxEntity.create(level, VfxType.SHOCKWAVE, player.position().add(0, 0.1, 0), form.color, 4.0F, 16).spawn();
		VfxEntity.create(level, form.fighter == Fighter.SANJI ? VfxType.FIRE_BURST : VfxType.CLOUD, player.position().add(0, 1, 0),
			form == Form.IFRIT_JAMBE ? 0xFF45B5FF : form.color, 2.2F, 18).spawn();
		sound(player, ModSounds.FORM_UP, 1.4F, form == Form.GEAR_5 ? 0.8F : 1.0F);
		switch (form) {
			case GEAR_2 -> sound(player, ModSounds.STEAM, 1.4F, 1.0F);
			case GEAR_3, GEAR_4_TANKMAN -> sound(player, ModSounds.INFLATE, 1.4F, 0.6F);
			case GEAR_4_BOUNDMAN, GEAR_4_SNAKEMAN -> {
				sound(player, ModSounds.INFLATE, 1.4F, 0.5F);
				sound(player, ModSounds.HAKI, 1.0F, 0.8F);
			}
			case GEAR_5 -> sound(player, ModSounds.DRUMS, 2.0F, 1.0F);
			case ASURA, KING_OF_HELL -> sound(player, ModSounds.HAKI, 1.4F, 0.6F);
			case DIABLE_JAMBE, IFRIT_JAMBE -> sound(player, ModSounds.FIRE, 1.4F, form == Form.IFRIT_JAMBE ? 0.6F : 1.0F);
			default -> {
			}
		}
		if (!form.hasCutscene()) {
			player.sendOverlayMessage(Component.translatable(form.translationKey()).withColor(form.color & 0xFFFFFF).withStyle(ChatFormatting.BOLD));
		} else {
			// Brief protection while the cutscene plays.
			player.addEffect(new MobEffectInstance(MobEffects.RESISTANCE, 50, 4, false, false, false));
			sendCutscene(player, form);
		}
	}

	/** Whether a body of the given size fits where the player stands. */
	public static boolean hasRoom(ServerPlayer player, float scale) {
		double width = 0.6 * scale;
		double height = 1.8 * scale;
		net.minecraft.world.phys.AABB box = new net.minecraft.world.phys.AABB(
			player.getX() - width / 2, player.getY() + 0.01, player.getZ() - width / 2, player.getX() + width / 2, player.getY() + height, player.getZ() + width / 2);
		return player.level().noCollision(player, box);
	}

	public static void endForm(ServerPlayer player, boolean exhausted) {
		PowerData data = get(player);
		Form old = data.form();
		if (old.isBase()) {
			return;
		}
		set(player, data.withForm(Form.base(data.fighter())).withGiantUntil(0L));
		if (exhausted) {
			int length = old.isGear4() || old == Form.GEAR_5 ? 20 * 12 : 20 * 4;
			player.addEffect(new MobEffectInstance(MobEffects.SLOWNESS, length, 2));
			player.addEffect(new MobEffectInstance(MobEffects.WEAKNESS, length, 1));
			player.sendOverlayMessage(Component.translatable("message.onepiece.exhausted").withStyle(ChatFormatting.RED));
			sound(player, ModSounds.STEAM, 1.2F, 0.6F);
		}
	}

	// ------------------------------------------------------------------ moves

	public static void selectMove(ServerPlayer player, int index) {
		PowerData data = get(player);
		List<Move> moves = Moves.forForm(data.form());
		if (index >= 0 && index < moves.size()) {
			set(player, data.withSelected(index));
		}
	}

	public static void useSelected(ServerPlayer player) {
		PowerData data = get(player);
		List<Move> moves = Moves.forForm(data.form());
		if (!moves.isEmpty()) {
			use(player, moves.get(Math.min(data.selected(), moves.size() - 1)));
		}
	}

	public static void use(ServerPlayer player, Move move) {
		PowerData data = get(player);
		if (!data.active() || move.form() != data.form() || player.isSpectator()) {
			return;
		}
		long now = player.level().getGameTime();
		if (!data.infinite()) {
			if (data.cooldownUntil(move.id()) > now) {
				return;
			}
			if (data.stamina() < move.cost()) {
				player.sendOverlayMessage(Component.translatable("message.onepiece.tired").withStyle(ChatFormatting.RED));
				return;
			}
		}
		if (data.fighter() == Fighter.ZORO && !holdingSword(player) && !data.infinite()) {
			player.sendOverlayMessage(Component.translatable("message.onepiece.need_sword").withStyle(ChatFormatting.RED));
			return;
		}
		PowerData next = data.withAnim(move.anim(), now);
		if (!data.infinite()) {
			next = next.withStamina(data.stamina() - move.cost()).withCooldown(move.id(), now + move.cooldown());
		}
		set(player, next);
		move.perform(player);
		if (Moves.ULTIMATES.contains(move.id()) && ServerPlayNetworking.canSend(player, com.tfue.onepiece.network.CutscenePayload.TYPE)) {
			// Negative form ids mean "skill cutscene" for skill number -id - 1.
			ServerPlayNetworking.send(player, new com.tfue.onepiece.network.CutscenePayload(player.getId(), -1 - Moves.indexOf(move)));
		}
		player.sendOverlayMessage(Component.translatable(move.translationKey()).withColor(data.form().color & 0xFFFFFF).withStyle(ChatFormatting.BOLD, ChatFormatting.ITALIC));
	}

	public static boolean holdingSword(Player player) {
		return player.getMainHandItem().is(net.minecraft.tags.ItemTags.SWORDS) || player.getOffhandItem().is(net.minecraft.tags.ItemTags.SWORDS);
	}

	// ------------------------------------------------------------------ haki

	public static void toggleArmament(ServerPlayer player) {
		PowerData data = get(player);
		if (!data.active()) {
			return;
		}
		boolean on = !data.armament();
		if (on && !data.infinite() && data.stamina() < 10) {
			player.sendOverlayMessage(Component.translatable("message.onepiece.tired").withStyle(ChatFormatting.RED));
			return;
		}
		set(player, data.withHaki(on, data.observation()));
		sound(player, ModSounds.HAKI, 1.0F, on ? 1.0F : 1.6F);
		player.sendOverlayMessage(Component.translatable(on ? "message.onepiece.armament_on" : "message.onepiece.armament_off").withStyle(ChatFormatting.DARK_PURPLE));
	}

	public static void toggleObservation(ServerPlayer player) {
		PowerData data = get(player);
		if (!data.active()) {
			return;
		}
		boolean on = !data.observation();
		set(player, data.withHaki(data.armament(), on));
		sound(player, ModSounds.HAKI, 0.8F, on ? 1.8F : 2.0F);
		player.sendOverlayMessage(Component.translatable(on ? "message.onepiece.observation_on" : "message.onepiece.observation_off").withStyle(ChatFormatting.AQUA));
	}

	public static void conqueror(ServerPlayer player) {
		PowerData data = get(player);
		if (!data.active()) {
			return;
		}
		long now = player.level().getGameTime();
		if (!data.infinite()) {
			if (CONQUEROR_READY.getOrDefault(player.getUUID(), 0L) > now) {
				player.sendOverlayMessage(Component.translatable("message.onepiece.conqueror_wait").withStyle(ChatFormatting.RED));
				return;
			}
			if (data.stamina() < 35) {
				player.sendOverlayMessage(Component.translatable("message.onepiece.tired").withStyle(ChatFormatting.RED));
				return;
			}
			set(player, data.withStamina(data.stamina() - 35));
			CONQUEROR_READY.put(player.getUUID(), now + 20 * 20);
		}
		set(player, get(player).withAnim(Anim.ROAR, now));
		ServerLevel level = player.level();
		double radius = 26.0;
		VfxEntity.create(level, VfxType.CONQUEROR, player.position().add(0, 1, 0), 0xFFE0102A, (float) radius, 36).owner(player).spawn();
		VfxEntity.create(level, VfxType.SHOCKWAVE, player.position().add(0, 0.1, 0), 0xFF12060C, (float) radius, 24).spawn();
		sound(player, ModSounds.CONQUEROR, 3.0F, 1.0F);
		int knocked = 0;
		for (LivingEntity e : Combat.inSphere(player, player.position(), radius)) {
			if (e instanceof Player other) {
				if (!other.isCreative() && !other.isSpectator()) {
					other.addEffect(new MobEffectInstance(MobEffects.NAUSEA, 100, 0));
					other.addEffect(new MobEffectInstance(MobEffects.DARKNESS, 80, 0));
					other.addEffect(new MobEffectInstance(MobEffects.SLOWNESS, 60, 2));
				}
			} else if (e instanceof Enemy && e instanceof Mob mob && !OnePiece.isBoss(mob)) {
				if (mob.getMaxHealth() <= 40.0F) {
					mob.hurtServer(level, level.damageSources().playerAttack(player), mob.getMaxHealth() * 4.0F);
					knocked++;
				} else {
					mob.addEffect(new MobEffectInstance(MobEffects.SLOWNESS, 140, 4));
					mob.addEffect(new MobEffectInstance(MobEffects.WEAKNESS, 140, 2));
				}
			} else if (OnePiece.isBoss(e)) {
				e.addEffect(new MobEffectInstance(MobEffects.SLOWNESS, 40, 1));
			}
		}
		for (ServerPlayer near : level.getPlayers(pl -> pl.distanceToSqr(player) < 48 * 48)) {
			shake(near, 1.0F, 30);
		}
		if (knocked > 0) {
			player.sendOverlayMessage(Component.translatable("message.onepiece.conqueror_knocked", knocked).withStyle(ChatFormatting.DARK_RED, ChatFormatting.BOLD));
		}
	}

	public static void shake(ServerPlayer player, float strength, int ticks) {
		if (ServerPlayNetworking.canSend(player, ShakePayload.TYPE)) {
			ServerPlayNetworking.send(player, new ShakePayload(strength, ticks));
		}
	}

	// ------------------------------------------------------------------ movement

	public static void airJump(ServerPlayer player) {
		PowerData data = get(player);
		if (!data.active() || player.onGround() || player.isInWater() || !data.form().hasAirJumps()) {
			return;
		}
		int max = switch (data.form()) {
			case GEAR_4_BOUNDMAN -> 5;
			case GEAR_5 -> 4;
			case IFRIT_JAMBE, DIABLE_JAMBE, RAID_SUIT, LUCCI_AWAKENED -> 8;
			case KAIDO_HYBRID -> 3;
			default -> 6;
		};
		int used = AIR_JUMPS.getOrDefault(player.getUUID(), 0);
		if (used >= max) {
			return;
		}
		AIR_JUMPS.put(player.getUUID(), used + 1);
		Vec3 motion = player.getDeltaMovement();
		Combat.launch(player, new Vec3(motion.x * 1.1, data.form() == Form.GEAR_4_BOUNDMAN ? 0.95 : 0.75, motion.z * 1.1));
		ServerLevel level = player.level();
		int color = data.fighter() == Fighter.SANJI || data.fighter() == Fighter.LUCCI ? (data.form() == Form.IFRIT_JAMBE ? 0xFF45B5FF : 0xFFFFFFFF) : data.form().color;
		VfxEntity.create(level, VfxType.SHOCKWAVE, player.position(), color, 1.6F, 8).spawn();
		VfxEntity.create(level, VfxType.CLOUD, player.position(), 0xFFFFFFFF, 0.9F, 10).spawn();
		sound(player, data.form() == Form.GEAR_4_BOUNDMAN ? ModSounds.BOUNCE : ModSounds.WHOOSH, 0.8F, 1.6F);
	}

	public static boolean canFloat(Player player) {
		PowerData data = get(player);
		return data.active() && data.fighter() != Fighter.ZORO && data.fighter() != Fighter.KATAKURI;
	}

	// ------------------------------------------------------------------ network

	public static void handle(ServerPlayer player, ActionPayload payload) {
		if (!player.isAlive() || player.isSpectator()) {
			return;
		}
		switch (payload.action()) {
			case ActionPayload.USE_MOVE -> useSelected(player);
			case ActionPayload.SELECT_MOVE -> selectMove(player, payload.value());
			case ActionPayload.CAST_MOVE -> {
				selectMove(player, payload.value());
				useSelected(player);
			}
			case ActionPayload.SELECT_FORM -> setForm(player, Form.byId(payload.value()), false);
			case ActionPayload.ARMAMENT -> toggleArmament(player);
			case ActionPayload.OBSERVATION -> toggleObservation(player);
			case ActionPayload.CONQUEROR -> conqueror(player);
			case ActionPayload.CYCLE_FIGHTER -> cycleFighter(player);
			case ActionPayload.AIR_JUMP -> airJump(player);
			default -> {
			}
		}
	}

	// ------------------------------------------------------------------ ticking

	public static void tick(ServerPlayer player) {
		PowerData data = get(player);
		if (player.onGround()) {
			AIR_JUMPS.remove(player.getUUID());
		}
		if (!data.active()) {
			updateFlight(player, false);
			return;
		}
		long now = player.level().getGameTime();
		applyModifiers(player, data, now);
		updateFlight(player, data.form() == Form.KAIDO_DRAGON);

		if (data.form() == Form.RAID_SUIT && now % 20 == 0) {
			player.addEffect(new MobEffectInstance(MobEffects.INVISIBILITY, 40, 0, false, false, false));
		}
		if (data.form() == Form.DIABLE_JAMBE || data.form() == Form.IFRIT_JAMBE) {
			player.clearFire();
			if (now % 40 == 0) {
				player.addEffect(new MobEffectInstance(MobEffects.FIRE_RESISTANCE, 60, 0, false, false, false));
			}
		}
		if (data.giantUntil() != 0 && data.giantUntil() <= now) {
			set(player, data.withGiantUntil(0L));
			data = get(player);
		}
		if (data.anim() != Anim.NONE && now > data.animStart() + data.anim().duration + 2) {
			set(player, data.withAnim(Anim.NONE, 0L));
			data = get(player);
		}

		if (now % 5 != 0 || data.infinite()) {
			if (data.infinite() && data.stamina() < PowerData.MAX_STAMINA) {
				set(player, data.withStamina(PowerData.MAX_STAMINA));
			}
			return;
		}
		// Stamina: regen in base form, slower regen minus a drain while transformed or using Haki.
		float perSecond = 7.0F * GearBonus.regen(player);
		if (!data.form().isBase()) {
			perSecond = perSecond * 0.5F - data.form().drain;
		}
		if (data.armament()) {
			perSecond -= 1.0F;
		}
		if (data.observation()) {
			perSecond -= 0.6F;
		}
		float stamina = data.stamina() + perSecond / 4.0F;
		if (stamina <= 0.0F) {
			PowerData drained = data.withStamina(0.0F).withHaki(false, false);
			set(player, drained);
			if (!data.form().isBase()) {
				endForm(player, true);
			}
			return;
		}
		if (Math.abs(stamina - data.stamina()) > 0.001F) {
			set(player, data.withStamina(stamina));
		}
	}

	/** Kaido's dragon form flies on flame clouds. */
	private static void updateFlight(ServerPlayer player, boolean dragon) {
		boolean granted = DRAGON_FLIGHT.contains(player.getUUID());
		if (dragon) {
			DRAGON_FLIGHT.add(player.getUUID());
			// Re-grant every tick check: switching game modes resets the ability.
			if (!player.getAbilities().mayfly && !player.isSpectator()) {
				player.getAbilities().mayfly = true;
				player.onUpdateAbilities();
			}
		} else if (granted) {
			DRAGON_FLIGHT.remove(player.getUUID());
			if (!player.isCreative() && !player.isSpectator()) {
				if (!player.onGround()) {
					// Leaving the dragon form in the air should not mean a deadly fall.
					player.addEffect(new MobEffectInstance(MobEffects.SLOW_FALLING, 160, 0, false, false, true));
				}
				player.getAbilities().mayfly = false;
				player.getAbilities().flying = false;
				player.onUpdateAbilities();
			}
		}
	}

	private static void applyModifiers(ServerPlayer player, PowerData data, long now) {
		Form form = data.form();
		boolean giant = data.giantUntil() > now;
		float scale = giant ? 4.0F : form.scale;
		modifier(player, Attributes.MOVEMENT_SPEED, SPEED, form.speed, AttributeModifier.Operation.ADD_MULTIPLIED_BASE);
		modifier(player, Attributes.SCALE, SCALE, scale - 1.0F, AttributeModifier.Operation.ADD_MULTIPLIED_BASE);
		double jump = switch (form) {
			case GEAR_4_BOUNDMAN -> 0.6;
			case GEAR_5 -> 0.5;
			case GEAR_2, GEAR_4_SNAKEMAN, LUCCI_HYBRID -> 0.3;
			case LUCCI_AWAKENED -> 0.45;
			default -> data.fighter() == Fighter.SANJI || data.fighter() == Fighter.LUCCI ? 0.25 : 0.0;
		};
		modifier(player, Attributes.JUMP_STRENGTH, JUMP, jump, AttributeModifier.Operation.ADD_MULTIPLIED_BASE);
		double safeFall = switch (data.fighter()) {
			case LUFFY, KATAKURI -> 200.0;
			case SANJI, LUCCI, KAIDO -> 30.0;
			default -> 10.0;
		};
		modifier(player, Attributes.SAFE_FALL_DISTANCE, SAFE_FALL, safeFall, AttributeModifier.Operation.ADD_VALUE);
		modifier(player, Attributes.STEP_HEIGHT, STEP, giant ? 2.5 : form.scale > 1.2F ? 0.6 + (form.scale - 1.2) : 0.0, AttributeModifier.Operation.ADD_VALUE);
		double armor = switch (form) {
			case GEAR_4_TANKMAN, KAIDO_DRAGON -> 14.0;
			case KAIDO_HYBRID, BASE_KAIDO -> 10.0;
			case GEAR_5, KATAKURI_AWAKENED, LUCCI_AWAKENED -> 8.0;
			case GEAR_4_BOUNDMAN, GEAR_4_SNAKEMAN, ASURA, LUCCI_HYBRID -> 6.0;
			default -> 0.0;
		};
		modifier(player, Attributes.ARMOR, ARMOR, armor, AttributeModifier.Operation.ADD_VALUE);
		double attack = (form.damage - 1.0F) + (data.armament() ? 0.5 : 0.0) + (giant ? 1.0 : 0.0);
		modifier(player, Attributes.ATTACK_DAMAGE, ATTACK, attack, AttributeModifier.Operation.ADD_MULTIPLIED_BASE);
		boolean huge = form == Form.GEAR_4_TANKMAN || giant || form.fighter == Fighter.KAIDO;
		modifier(player, Attributes.KNOCKBACK_RESISTANCE, KNOCKBACK, huge ? 1.0 : form.isGear4() || form.fighter == Fighter.KATAKURI ? 0.6 : 0.0, AttributeModifier.Operation.ADD_VALUE);
		modifier(player, Attributes.ENTITY_INTERACTION_RANGE, REACH, giant ? 6.0 : Math.max(0.0, (form.scale - 1.0) * 2.5), AttributeModifier.Operation.ADD_VALUE);
	}

	private static void modifier(ServerPlayer player, Holder<Attribute> attribute, Identifier id, double amount, AttributeModifier.Operation op) {
		AttributeInstance instance = player.getAttribute(attribute);
		if (instance == null) {
			return;
		}
		AttributeModifier existing = instance.getModifier(id);
		if (Math.abs(amount) < 1.0E-4) {
			if (existing != null) {
				instance.removeModifier(id);
			}
			return;
		}
		if (existing == null || Math.abs(existing.amount() - amount) > 1.0E-4 || existing.operation() != op) {
			instance.addOrUpdateTransientModifier(new AttributeModifier(id, amount, op));
		}
	}

	public static void resetModifiers(ServerPlayer player) {
		for (var pair : List.of(
			Map.entry(Attributes.MOVEMENT_SPEED, SPEED), Map.entry(Attributes.SCALE, SCALE), Map.entry(Attributes.JUMP_STRENGTH, JUMP),
			Map.entry(Attributes.SAFE_FALL_DISTANCE, SAFE_FALL), Map.entry(Attributes.STEP_HEIGHT, STEP), Map.entry(Attributes.ARMOR, ARMOR),
			Map.entry(Attributes.ATTACK_DAMAGE, ATTACK), Map.entry(Attributes.KNOCKBACK_RESISTANCE, KNOCKBACK), Map.entry(Attributes.ENTITY_INTERACTION_RANGE, REACH))) {
			AttributeInstance instance = player.getAttribute(pair.getKey());
			if (instance != null) {
				instance.removeModifier(pair.getValue());
			}
		}
	}

	static void sound(ServerPlayer player, net.minecraft.sounds.SoundEvent sound, float volume, float pitch) {
		player.level().playSound(null, player.getX(), player.getY(), player.getZ(), sound, SoundSource.PLAYERS, volume, pitch);
	}

	public static void onRespawn(ServerPlayer player) {
		PowerData data = get(player);
		if (data.active()) {
			set(player, data.withForm(Form.base(data.fighter())).withStamina(PowerData.MAX_STAMINA).withHaki(false, false).withGiantUntil(0L).withAnim(Anim.NONE, 0L));
		}
		Scheduler.clear(player);
		updateFlight(player, false);
	}
}
