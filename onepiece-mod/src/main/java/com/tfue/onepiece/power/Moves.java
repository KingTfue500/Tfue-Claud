package com.tfue.onepiece.power;

import static com.tfue.onepiece.power.Anim.*;
import static com.tfue.onepiece.power.Form.*;
import static com.tfue.onepiece.power.Move.Icon;

import com.tfue.onepiece.entity.VfxEntity;
import com.tfue.onepiece.entity.VfxType;
import com.tfue.onepiece.registry.ModSounds;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.projectile.Projectile;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.Vec3;

/**
 * The full move list. Each form has its own set of moves, shown in the move wheel when that form is active.
 */
public final class Moves {
	public static final List<Move> ALL = new ArrayList<>();
	private static final Map<String, Move> BY_ID = new HashMap<>();
	private static final Map<Form, List<Move>> BY_FORM = new EnumMap<>(Form.class);
	/** Finishing moves that play a short cinematic for the player who uses them. */
	public static final java.util.Set<String> ULTIMATES = java.util.Set.of(
		"gum_gum_storm", "red_hawk", "elephant_gatling", "kong_organ", "black_mamba", "cannonball", "bajrang_gun", "toon_ground",
		"rengoku_onigiri", "asura_ichibugin", "sanzen_sekai", "king_of_hell_purgatory",
		"party_table", "hell_memories", "ifrit_jambe", "ifrit_nova", "poele_spectre",
		"ragnaraku", "lightning_rain", "thunder_storm", "dragon_twister",
		"donut_barrage", "hakai_mochi", "mochi_pillars",
		"rokuogan", "leopard_storm", "awakened_rokuogan");

	// Arm/leg looks for stretch effects. Read by the client renderer.
	public static final int LOOK_SKIN = 0;
	public static final int LOOK_HAKI = 1;
	public static final int LOOK_GEAR5 = 2;
	public static final int LOOK_GEAR2 = 3;
	public static final int LOOK_GEAR4 = 4;
	public static final int LOOK_MOCHI = 5;

	private static final int WHITE = 0xFFFFFFFF;
	private static final int HAKI_BLACK = 0xFF1A1020;
	private static final int ZORO_GREEN = 0xFFB8FFD0;
	private static final int FIRE_ORANGE = 0xFFFF7A1A;
	private static final int BLUE_FIRE = 0xFF45B5FF;
	private static final int ENMA_PURPLE = 0xFFB040FF;
	private static final int MOCHI = 0xFFF6E7EE;
	private static final int KAIDO_PURPLE = 0xFF8C5CFF;

	static {
		// ===================== LUFFY: BASE =====================
		add("gum_gum_pistol", BASE_LUFFY, 8, 14, PUNCH_RIGHT, Icon.FIST, p -> stretchPunch(p, 18, 9, 2.0F, 0.8, false, 1.0F, true));
		add("gum_gum_gatling", BASE_LUFFY, 22, 70, GATLING, Icon.GATLING, p -> gatling(p, 36, 9, 3.0F, 1.0F, 1.0F));
		add("gum_gum_bazooka", BASE_LUFFY, 18, 50, BAZOOKA, Icon.PALMS, p -> bazooka(p, 12, 15, 5.0F, 1.0F));
		add("gum_gum_rocket", BASE_LUFFY, 12, 30, ROCKET, Icon.ROCKET, p -> rocket(p, 34, 2.2));
		add("gum_gum_whip", BASE_LUFFY, 14, 36, WHIP, Icon.WHIP, p -> whip(p, 6.5, 10, 3.0F, 0.5F, 1.0F));
		add("gum_gum_balloon", BASE_LUFFY, 15, 120, BALLOON, Icon.BALLOON, p -> balloon(p, 100, 1.0F));
		add("gum_gum_storm", BASE_LUFFY, 40, 200, GATLING, Icon.GATLING, p -> gatling(p, 60, 13, 4.0F, 1.3F, 1.2F));

		// ===================== LUFFY: GEAR 2 =====================
		add("jet_pistol", GEAR_2, 10, 10, PUNCH_RIGHT, Icon.FIST, p -> stretchPunch(p, 26, 15, 3.0F, 0.9, false, 1.0F, true));
		add("jet_gatling", GEAR_2, 26, 70, GATLING, Icon.GATLING, p -> gatling(p, 40, 12, 5.0F, 1.0F, 1.2F));
		add("jet_bazooka", GEAR_2, 22, 50, BAZOOKA, Icon.PALMS, p -> bazooka(p, 16, 24, 7.0F, 1.0F));
		add("jet_stamp", GEAR_2, 18, 40, STOMP, Icon.STOMP, p -> stamp(p, 18, 20, 1.0F));
		add("jet_dash", GEAR_2, 8, 16, DASH, Icon.DASH, p -> dash(p, 14, 6, 1.5F, Form.GEAR_2.color, false));
		add("red_hawk", GEAR_2, 32, 110, PUNCH_RIGHT, Icon.FIRE_FIST, p -> redHawk(p));

		// ===================== LUFFY: GEAR 3 =====================
		add("gigant_pistol", GEAR_3, 26, 60, CHARGE_PUNCH, Icon.GIANT_FIST, p -> chargedFist(p, 6, 4.0F, 32, 7.0F, WHITE, LOOK_SKIN));
		add("elephant_gun", GEAR_3, 38, 110, CHARGE_PUNCH, Icon.GIANT_FIST, p -> chargedFist(p, 8, 6.0F, 46, 9.0F, HAKI_BLACK, LOOK_HAKI));
		add("elephant_gatling", GEAR_3, 50, 200, GATLING, Icon.GATLING, p -> giantGatling(p, 40, 4.5F, 20, LOOK_HAKI, HAKI_BLACK));
		add("gigant_axe", GEAR_3, 32, 90, STOMP, Icon.STOMP, p -> gigantAxe(p, 30, 8.0, 1.0F));
		add("gigant_rifle", GEAR_3, 34, 90, CHARGE_PUNCH, Icon.GIANT_FIST, p -> chargedFist(p, 6, 4.5F, 34, 6.0F, WHITE, LOOK_SKIN, true));
		add("gigant_balloon", GEAR_3, 20, 160, BALLOON, Icon.BALLOON, p -> balloon(p, 140, 2.2F));

		// ===================== LUFFY: GEAR 4 BOUNDMAN =====================
		add("kong_gun", GEAR_4_BOUNDMAN, 36, 70, CHARGE_PUNCH, Icon.GIANT_FIST, p -> chargedFist(p, 10, 3.6F, 48, 11.0F, HAKI_BLACK, LOOK_GEAR4));
		add("kong_organ", GEAR_4_BOUNDMAN, 60, 220, GATLING, Icon.GATLING, p -> giantGatling(p, 36, 3.2F, 30, LOOK_GEAR4, HAKI_BLACK));
		add("rhino_schneider", GEAR_4_BOUNDMAN, 28, 50, DASH, Icon.DASH, p -> dash(p, 18, 32, 6.0F, Form.GEAR_4_BOUNDMAN.color, false));
		add("leo_bazooka", GEAR_4_BOUNDMAN, 40, 100, BAZOOKA, Icon.PALMS, p -> bazooka(p, 18, 44, 12.0F, 2.0F));
		add("gorilla_culverin", GEAR_4_BOUNDMAN, 30, 50, PUNCH_RIGHT, Icon.SNAKE, p -> homingFists(p, 2, 3.0F, 30));
		add("bound_quake", GEAR_4_BOUNDMAN, 30, 80, STOMP, Icon.STOMP, p -> groundSlam(p, 10.0, 30, 1.6F, Form.GEAR_4_BOUNDMAN.color, ModSounds.BOUNCE));

		// ===================== LUFFY: GEAR 4 SNAKEMAN =====================
		add("king_cobra", GEAR_4_SNAKEMAN, 40, 90, CHARGE_PUNCH, Icon.SNAKE, p -> homingFists(p, 1, 4.5F, 55));
		add("python", GEAR_4_SNAKEMAN, 24, 36, PUNCH_RIGHT, Icon.SNAKE, p -> homingArms(p, 1, 30));
		add("jet_culverin", GEAR_4_SNAKEMAN, 34, 60, PUNCH_LEFT, Icon.SNAKE, p -> homingArms(p, 4, 22));
		add("black_mamba", GEAR_4_SNAKEMAN, 60, 200, GATLING, Icon.GATLING, p -> mamba(p));
		add("snake_dash", GEAR_4_SNAKEMAN, 12, 16, DASH, Icon.DASH, p -> dash(p, 20, 12, 2.0F, Form.GEAR_4_SNAKEMAN.color, false));

		// ===================== LUFFY: GEAR 4 TANKMAN =====================
		add("chaser", GEAR_4_TANKMAN, 36, 80, BAZOOKA, Icon.PALMS, p -> chaser(p));
		add("cannonball", GEAR_4_TANKMAN, 40, 110, DASH, Icon.BALLOON, p -> cannonball(p));
		add("tank_guard", GEAR_4_TANKMAN, 20, 160, BALLOON, Icon.SHIELD, p -> balloon(p, 120, 3.0F));
		add("tank_stomp", GEAR_4_TANKMAN, 30, 80, STOMP, Icon.STOMP, p -> groundSlam(p, 12.0, 34, 1.2F, Form.GEAR_4_TANKMAN.color, ModSounds.HEAVY_IMPACT));

		// ===================== LUFFY: GEAR 5 =====================
		add("bajrang_gun", GEAR_5, 90, 400, GRAB_SKY, Icon.GIANT_FIST, p -> bajrang(p));
		add("lightning_grab", GEAR_5, 40, 100, GRAB_SKY, Icon.LIGHTNING, p -> lightningGrab(p));
		add("dawn_whip", GEAR_5, 34, 60, WHIP, Icon.WHIP, p -> whip(p, 11.0, 36, 7.0F, 0.9F, 3.0F));
		add("toon_ground", GEAR_5, 44, 140, STOMP, Icon.CLOUD, p -> toonGround(p));
		add("giant_mode", GEAR_5, 60, 600, FORM_SHIFT, Icon.GIANT, p -> giantMode(p));
		add("dawn_gatling", GEAR_5, 60, 160, GATLING, Icon.GATLING, p -> giantGatling(p, 40, 2.6F, 14, LOOK_GEAR5, WHITE));

		// ===================== ZORO: SANTORYU =====================
		add("oni_giri", BASE_ZORO, 14, 28, SWORD_DASH, Icon.X_SLASH, p -> swordDash(p, 9, 18, ZORO_GREEN, false));
		add("tora_gari", BASE_ZORO, 20, 50, SWORD_RAISE, Icon.SLASH, p -> leapSlam(p, 22, 5.0, ZORO_GREEN));
		add("pound_cannon_108", BASE_ZORO, 24, 46, SWORD_CROSS, Icon.SLASH_WAVE, p -> flyingSlash(p, 3.2F, 1.6, 24, 3.0F, ZORO_GREEN, 0.0F, true));
		add("pound_phoenix_36", BASE_ZORO, 12, 22, SWORD_SLASH, Icon.SLASH_WAVE, p -> flyingSlash(p, 2.0F, 2.2, 15, 1.5F, WHITE, 25.0F, false));
		add("tatsumaki", BASE_ZORO, 30, 90, SWORD_SPIN, Icon.TORNADO, p -> tornado(p, 5.0F, 4.0F, 50, ZORO_GREEN, 0.0));
		add("rengoku_onigiri", BASE_ZORO, 28, 70, SWORD_DASH, Icon.X_SLASH, p -> swordDash(p, 13, 30, 0xFF9CFF7A, false));
		add("shishi_sonson", BASE_ZORO, 20, 40, SWORD_SLASH, Icon.SLASH, p -> iai(p, 12, 28, WHITE));

		// ===================== ZORO: ASURA =====================
		add("asura_ichibugin", ASURA, 48, 120, SWORD_DASH, Icon.SPIN_BLADES, p -> swordDash(p, 16, 48, 0xFFC6A8FF, true));
		add("asura_makyusen", ASURA, 40, 90, SWORD_SPIN, Icon.SPIN_BLADES, p -> slashRing(p, 8.0, 32, 0xFFC6A8FF));
		add("asura_dead_mans_game", ASURA, 44, 100, SWORD_CROSS, Icon.SLASH_WAVE, p -> fanSlashes(p, 9, 22, 0xFFC6A8FF));
		add("asura_tornado", ASURA, 40, 120, SWORD_SPIN, Icon.TORNADO, p -> tornado(p, 7.0F, 6.0F, 60, 0xFF8F6BD6, 0.15));

		// ===================== ZORO: KING OF HELL =====================
		add("flaming_dragon", KING_OF_HELL, 44, 100, SWORD_CROSS, Icon.DRAGON, p -> dragonSlash(p));
		add("koku_tatsumaki", KING_OF_HELL, 54, 160, SWORD_SPIN, Icon.TORNADO, p -> tornado(p, 9.0F, 9.0F, 70, 0xFF2A0F3D, 0.12));
		add("shi_shishi_sonson", KING_OF_HELL, 38, 60, SWORD_DASH, Icon.X_SLASH, p -> swordDash(p, 18, 52, ENMA_PURPLE, false));
		add("sanzen_sekai", KING_OF_HELL, 60, 160, SWORD_SPIN, Icon.SPIN_BLADES, p -> sanzenSekai(p));
		add("king_of_hell_purgatory", KING_OF_HELL, 50, 120, SWORD_CROSS, Icon.SLASH_WAVE, p -> flyingSlash(p, 7.0F, 1.4, 60, 8.0F, ENMA_PURPLE, 0.0F, true));

		// ===================== SANJI: BLACK LEG =====================
		add("collier", BASE_SANJI, 8, 14, KICK_HIGH, Icon.KICK, p -> kick(p, 4.5, 13, 2.0F, 0.9F, false, WHITE));
		add("mouton_shot", BASE_SANJI, 14, 30, KICK_HIGH, Icon.KICK, p -> dashKick(p, 9, 18, 5.0F, false, WHITE));
		add("concasse", BASE_SANJI, 20, 46, KICK_DOWN, Icon.KICK_DOWN, p -> leapSlam(p, 22, 5.0, WHITE));
		add("party_table", BASE_SANJI, 24, 70, KICK_SPIN, Icon.KICK_SPIN, p -> partyTable(p, 5.0, 4.0F, false, WHITE));
		add("anti_manner_kick", BASE_SANJI, 18, 46, KICK_LAUNCH, Icon.KICK, p -> launchKick(p, 15, false));
		add("sky_walk", BASE_SANJI, 6, 6, DASH, Icon.SKY_WALK, p -> skyDash(p));

		// ===================== SANJI: DIABLE JAMBE =====================
		add("flanchet_shot", DIABLE_JAMBE, 24, 46, KICK_HIGH, Icon.FIRE_KICK, p -> dashKick(p, 11, 28, 8.0F, true, FIRE_ORANGE));
		add("bien_cuit_grill", DIABLE_JAMBE, 28, 70, KICK_RAPID, Icon.FIRE_KICK, p -> rapidKicks(p, 30, 6.0F, true, FIRE_ORANGE));
		add("hell_memories", DIABLE_JAMBE, 60, 200, KICK_DOWN, Icon.FIRE_KICK, p -> fireNova(p, 10.0, 40, FIRE_ORANGE, 1));
		add("premier_hachis", DIABLE_JAMBE, 38, 100, KICK_RAPID, Icon.FIRE_KICK, p -> rapidKicks(p, 40, 5.0F, true, FIRE_ORANGE));
		add("diable_concasse", DIABLE_JAMBE, 34, 80, KICK_DOWN, Icon.KICK_DOWN, p -> leapSlam(p, 34, 6.5, FIRE_ORANGE));
		add("diable_party_table", DIABLE_JAMBE, 30, 80, KICK_SPIN, Icon.KICK_SPIN, p -> partyTable(p, 6.0, 6.0F, true, FIRE_ORANGE));

		// ===================== SANJI: IFRIT JAMBE =====================
		add("ifrit_jambe", IFRIT_JAMBE, 60, 140, KICK_HIGH, Icon.FIRE_KICK, p -> ifritKick(p));
		add("boeuf_burst", IFRIT_JAMBE, 48, 110, KICK_HIGH, Icon.FIRE_KICK, p -> dashKick(p, 16, 50, 12.0F, true, BLUE_FIRE));
		add("ifrit_meteor", IFRIT_JAMBE, 44, 100, KICK_DOWN, Icon.KICK_DOWN, p -> leapSlam(p, 46, 8.0, BLUE_FIRE));
		add("ifrit_hachis", IFRIT_JAMBE, 50, 140, KICK_RAPID, Icon.FIRE_KICK, p -> rapidKicks(p, 40, 9.0F, true, BLUE_FIRE));
		add("ifrit_nova", IFRIT_JAMBE, 66, 220, KICK_SPIN, Icon.FIRE_KICK, p -> fireNova(p, 13.0, 56, BLUE_FIRE, 2));

		// ===================== SANJI: RAID SUIT =====================
		add("stealth_kick", RAID_SUIT, 22, 36, KICK_HIGH, Icon.STEALTH, p -> stealthKick(p));
		add("poele_spectre", RAID_SUIT, 44, 120, KICK_RAPID, Icon.STEALTH, p -> rapidKicks(p, 40, 6.0F, false, 0xFF6F8CFF));
		add("raid_sky_walk", RAID_SUIT, 6, 6, DASH, Icon.SKY_WALK, p -> skyDash(p));
		add("raid_concasse", RAID_SUIT, 26, 60, KICK_DOWN, Icon.KICK_DOWN, p -> leapSlam(p, 30, 6.0, 0xFF6F8CFF));

		// ===================== KAIDO: HUMAN (Hassaikai club) =====================
		add("thunder_bagua", BASE_KAIDO, 30, 70, CLUB_SMASH, Icon.CLUB, p -> thunderBagua(p, 34, 8.0));
		add("kaido_club_sweep", BASE_KAIDO, 22, 46, SWORD_SPIN, Icon.CLUB, p -> slashRing(p, 7.5, 26, 0xFFB79CFF));
		add("ragnaraku", BASE_KAIDO, 40, 120, CLUB_SMASH, Icon.LIGHTNING, p -> ragnaraku(p, 30));
		add("kaido_roar", BASE_KAIDO, 24, 90, ROAR, Icon.ROAR, p -> roarBlast(p, 12.0, 10, 0xFF7A6BFF));
		add("goryu_charge", BASE_KAIDO, 18, 40, DASH, Icon.DASH, p -> dash(p, 14, 24, 7.0F, Form.BASE_KAIDO.color, false));

		// ===================== KAIDO: HYBRID =====================
		add("bolo_breath", KAIDO_HYBRID, 36, 90, BREATH, Icon.BREATH, p -> breath(p, 24, 34, 0xFFFF7A1A, 1.6F));
		add("kamaitachi", KAIDO_HYBRID, 34, 80, SWORD_CROSS, Icon.SLASH_WAVE, p -> fanSlashes(p, 7, 26, 0xFFBFE4FF));
		add("hybrid_thunder_bagua", KAIDO_HYBRID, 44, 110, CLUB_SMASH, Icon.CLUB, p -> thunderBagua(p, 52, 11.0));
		add("lightning_rain", KAIDO_HYBRID, 46, 140, GRAB_SKY, Icon.LIGHTNING, p -> lightningRain(p, 8, 16.0, 30));
		add("kaido_spin", KAIDO_HYBRID, 36, 100, SWORD_SPIN, Icon.TORNADO, p -> tornado(p, 7.0F, 6.0F, 50, 0xFF8FB0FF, 0.1));

		// ===================== KAIDO: AZURE DRAGON =====================
		add("dragon_bolo_breath", KAIDO_DRAGON, 50, 120, BREATH, Icon.BREATH, p -> breath(p, 36, 48, 0xFFFF6A10, 2.6F));
		add("dragon_twister", KAIDO_DRAGON, 60, 200, ROAR, Icon.TORNADO, p -> tornado(p, 12.0F, 10.0F, 90, 0xFF9CD8FF, 0.2));
		add("thunder_storm", KAIDO_DRAGON, 60, 200, ROAR, Icon.LIGHTNING, p -> lightningRain(p, 16, 24.0, 40));
		add("kaifu", KAIDO_DRAGON, 44, 100, ROAR, Icon.SLASH_WAVE, p -> fanSlashes(p, 11, 34, 0xFFDFF4FF));
		add("dragon_dive", KAIDO_DRAGON, 40, 90, DASH, Icon.DRAGON, p -> dragonDive(p));
		add("flame_cloud_dash", KAIDO_DRAGON, 14, 20, DASH, Icon.CLOUD, p -> dash(p, 22, 20, 5.0F, 0xFFFF9A40, true));

		// ===================== KATAKURI: MOCHI =====================
		add("mochi_fist", BASE_KATAKURI, 10, 16, PUNCH_RIGHT, Icon.MOCHI, p -> stretchPunch(p, 20, 14, 3.0F, 1.0, false, 1.6F, true));
		add("power_mochi", BASE_KATAKURI, 30, 70, CHARGE_PUNCH, Icon.GIANT_FIST, p -> chargedFist(p, 8, 4.5F, 36, 8.0F, MOCHI, LOOK_MOCHI));
		add("donut_barrage", BASE_KATAKURI, 40, 140, GATLING, Icon.GATLING, p -> giantGatling(p, 36, 2.4F, 12, LOOK_MOCHI, MOCHI));
		add("mochi_trident", BASE_KATAKURI, 20, 40, PUNCH_RIGHT, Icon.TRIDENT, p -> trident(p, 14, 26));
		add("flowing_mochi", BASE_KATAKURI, 22, 60, BAZOOKA, Icon.MOCHI, p -> flowingMochi(p));
		add("mochi_wall", BASE_KATAKURI, 20, 160, GUARD, Icon.SHIELD, p -> balloon(p, 100, 2.0F));

		// ===================== KATAKURI: AWAKENED =====================
		add("buso_kirimochi", KATAKURI_AWAKENED, 50, 160, GATLING, Icon.GATLING, p -> giantGatling(p, 40, 3.0F, 20, LOOK_HAKI, HAKI_BLACK));
		add("mochi_pillars", KATAKURI_AWAKENED, 44, 120, STOMP, Icon.MOCHI, p -> mochiPillars(p));
		add("mochi_quake", KATAKURI_AWAKENED, 40, 120, STOMP, Icon.MOCHI, p -> mochiQuake(p));
		add("hakai_mochi", KATAKURI_AWAKENED, 56, 160, CHARGE_PUNCH, Icon.GIANT_FIST, p -> hakaiMochi(p));
		add("haki_trident", KATAKURI_AWAKENED, 34, 60, PUNCH_RIGHT, Icon.TRIDENT, p -> trident(p, 20, 46));

		// ===================== LUCCI: ROKUSHIKI =====================
		add("shigan", BASE_LUCCI, 10, 14, FINGER, Icon.FINGER, p -> shigan(p, 6, 16));
		add("soru", BASE_LUCCI, 6, 10, DASH, Icon.DASH, p -> dash(p, 12, 0, 0.0F, 0xFFFFF0C0, false));
		add("rankyaku", BASE_LUCCI, 14, 24, KICK_HIGH, Icon.SLASH_WAVE, p -> flyingSlash(p, 2.4F, 2.0, 16, 2.0F, WHITE, 0.0F, false));
		add("tekkai", BASE_LUCCI, 14, 120, GUARD, Icon.SHIELD, p -> tekkai(p, 60));
		add("rokuogan", BASE_LUCCI, 28, 70, PUNCH_RIGHT, Icon.FIST, p -> rokuogan(p, 4.5, 34, 1.0F));
		add("geppo", BASE_LUCCI, 6, 6, DASH, Icon.SKY_WALK, p -> skyDash(p));

		// ===================== LUCCI: LEOPARD HYBRID =====================
		add("leopard_pounce", LUCCI_HYBRID, 20, 36, POUNCE, Icon.POUNCE, p -> pounce(p, 30));
		add("shigan_oren", LUCCI_HYBRID, 30, 80, KICK_RAPID, Icon.FINGER, p -> fingerBarrage(p));
		add("rankyaku_ran", LUCCI_HYBRID, 30, 70, KICK_HIGH, Icon.SLASH_WAVE, p -> fanSlashes(p, 6, 20, WHITE));
		add("leopard_claw", LUCCI_HYBRID, 18, 30, CLAW, Icon.CLAW, p -> claw(p, 24));
		add("hybrid_rokuogan", LUCCI_HYBRID, 36, 90, PUNCH_RIGHT, Icon.FIST, p -> rokuogan(p, 6.0, 48, 1.5F));

		// ===================== LUCCI: AWAKENED =====================
		add("awakened_rokuogan", LUCCI_AWAKENED, 50, 140, CHARGE_PUNCH, Icon.FIST, p -> rokuogan(p, 9.0, 66, 2.4F));
		add("leopard_storm", LUCCI_AWAKENED, 50, 140, DASH, Icon.POUNCE, p -> leopardStorm(p));
		add("rankyaku_ten", LUCCI_AWAKENED, 44, 100, KICK_SPIN, Icon.SLASH_WAVE, p -> fanSlashes(p, 12, 26, 0xFFFFD0C0));
		add("kami_e", LUCCI_AWAKENED, 30, 300, GUARD, Icon.STEALTH, p -> kamiE(p));
		add("awakened_claw", LUCCI_AWAKENED, 26, 30, CLAW, Icon.CLAW, p -> claw(p, 40));
	}

	private Moves() {
	}

	private static void add(String id, Form form, int cost, int cooldown, Anim anim, Icon icon, Move.Action action) {
		Move move = new Move(id, form, cost, cooldown, anim, icon, action);
		ALL.add(move);
		BY_ID.put(id, move);
		BY_FORM.computeIfAbsent(form, f -> new ArrayList<>()).add(move);
	}

	public static List<Move> forForm(Form form) {
		return BY_FORM.getOrDefault(form, List.of());
	}

	public static Move byId(String id) {
		return BY_ID.get(id);
	}

	public static int indexOf(Move move) {
		return ALL.indexOf(move);
	}

	// ------------------------------------------------------------------ helpers

	/** Teleports only into open space (also tries one block up); returns whether it moved. */
	static boolean safeTeleport(LivingEntity p, Vec3 pos) {
		for (double up = 0; up <= 1.0; up += 1.0) {
			Vec3 at = pos.add(0, up, 0);
			if (lvl(p).noCollision(p, p.getBoundingBox().move(at.subtract(p.position())))) {
				p.teleportTo(at.x, at.y, at.z);
				p.fallDistance = 0;
				return true;
			}
		}
		return false;
	}

	static ServerLevel lvl(LivingEntity e) {
		return (ServerLevel) e.level();
	}

	static void sound(LivingEntity p, SoundEvent sound, float volume, float pitch) {
		lvl(p).playSound(null, p.getX(), p.getY(), p.getZ(), sound, SoundSource.PLAYERS, volume, pitch);
	}

	static void soundAt(ServerLevel level, Vec3 pos, SoundEvent sound, float volume, float pitch) {
		level.playSound(null, pos.x, pos.y, pos.z, sound, SoundSource.PLAYERS, volume, pitch);
	}

	static Vec3 right(LivingEntity p) {
		float yaw = p.getYRot() * Mth.DEG_TO_RAD;
		return new Vec3(-Mth.cos(yaw), 0, -Mth.sin(yaw));
	}

	static Vec3 shoulder(LivingEntity p, boolean rightSide) {
		float scale = p.getScale();
		return p.position().add(0, 1.38 * scale, 0).add(right(p).scale((rightSide ? 0.36 : -0.36) * scale));
	}

	static int look(LivingEntity p) {
		PowerData data = Powers.view(p);
		if (data.fighter() == Fighter.KATAKURI) {
			return data.armament() || data.form() == Form.KATAKURI_AWAKENED ? LOOK_HAKI : LOOK_MOCHI;
		}
		return switch (data.form()) {
			case GEAR_5 -> LOOK_GEAR5;
			case GEAR_4_BOUNDMAN, GEAR_4_SNAKEMAN, GEAR_4_TANKMAN -> LOOK_GEAR4;
			case GEAR_2 -> data.armament() ? LOOK_HAKI : LOOK_GEAR2;
			default -> data.armament() ? LOOK_HAKI : LOOK_SKIN;
		};
	}

	static VfxEntity arm(LivingEntity p, Vec3 end, int look, float size, int life, boolean rightSide) {
		return VfxEntity.create(lvl(p), VfxType.STRETCH_ARM, shoulder(p, rightSide), WHITE, size, life)
			.owner(p).target(end).variant(look + (rightSide ? 0 : 16)).spawn();
	}

	static void shock(ServerLevel level, Vec3 pos, int color, float size, int life) {
		VfxEntity.create(level, VfxType.SHOCKWAVE, pos, color, size, life).spawn();
	}

	static void impact(ServerLevel level, Vec3 pos, int color, float size) {
		VfxEntity.create(level, VfxType.IMPACT, pos, color, size, 8).spawn();
	}

	static float hakiColorMix(LivingEntity p) {
		return Powers.view(p).armament() ? 1.0F : 0.0F;
	}

	// ------------------------------------------------------------------ Luffy

	static void stretchPunch(LivingEntity p, double range, float damage, float knock, double radius, boolean fire, float size, boolean rightSide) {
		LivingEntity target = Combat.firstInLine(p, range, radius);
		Vec3 end = target != null ? target.getBoundingBox().getCenter() : Combat.rayEnd(p, range);
		arm(p, end, look(p), size, 12, rightSide);
		sound(p, ModSounds.STRETCH, 1.0F, 1.0F + p.getRandom().nextFloat() * 0.2F);
		if (target != null) {
			Combat.hit(p, target, damage, p.getLookAngle(), knock, 0.25F, fire);
			impact(lvl(p), end, Powers.view(p).form().color, 1.2F * size);
			soundAt(lvl(p), end, ModSounds.PUNCH, 1.0F, 1.0F);
		}
	}

	static void gatling(LivingEntity p, int ticks, double range, float damage, float size, float speedMul) {
		sound(p, ModSounds.GATLING, 1.2F, 1.0F * speedMul);
		Scheduler.repeat(p, ticks, tick -> {
			if (tick % 2 == 0) {
				ServerLevel level = lvl(p);
				Vec3 look = p.getLookAngle();
				Vec3 spread = right(p).scale((p.getRandom().nextFloat() - 0.5) * 2.4).add(0, (p.getRandom().nextFloat() - 0.5) * 1.6, 0);
				Vec3 end = Combat.rayEnd(p, range * (0.6 + p.getRandom().nextFloat() * 0.4)).add(spread);
				arm(p, end, look(p), size, 5, tick % 4 == 0);
				for (LivingEntity target : Combat.inCone(p, range, 22)) {
					Combat.hit(p, target, damage, look, 0.35F, 0.06F, false);
				}
				if (tick % 6 == 0) {
					impact(level, end, Powers.view(p).form().color, 0.8F);
					soundAt(level, end, ModSounds.PUNCH, 0.6F, 1.2F + p.getRandom().nextFloat() * 0.3F);
				}
			}
			return true;
		});
	}

	static void bazooka(LivingEntity p, double range, float damage, float knock, float size) {
		sound(p, ModSounds.STRETCH, 1.0F, 0.7F);
		Scheduler.later(p, 5, () -> {
			Vec3 end = Combat.rayEnd(p, range);
			arm(p, end, look(p), size * 1.2F, 10, true);
			arm(p, end, look(p), size * 1.2F, 10, false);
			for (LivingEntity target : Combat.inLine(p, range, 1.6)) {
				Combat.hit(p, target, damage, p.getLookAngle(), knock, 0.5F, false);
			}
			shock(lvl(p), end, Powers.view(p).form().color, 3.5F * size, 12);
			soundAt(lvl(p), end, ModSounds.HEAVY_IMPACT, 1.2F, 1.0F);
		});
	}

	static void rocket(LivingEntity p, double range, double power) {
		BlockHitResult block = Combat.rayBlock(p, range);
		Vec3 target = block != null ? block.getLocation() : p.getEyePosition().add(p.getLookAngle().scale(range * 0.6)).add(0, 4, 0);
		arm(p, target, look(p), 1.0F, 10, true);
		arm(p, target, look(p), 1.0F, 10, false);
		sound(p, ModSounds.STRETCH, 1.0F, 0.8F);
		Scheduler.later(p, 4, () -> {
			Vec3 dir = target.subtract(p.position()).normalize();
			double dist = Math.min(1.0, target.distanceTo(p.position()) / range);
			Combat.launch(p, dir.scale(power * (0.8 + dist)).add(0, 0.5, 0));
			sound(p, ModSounds.SNAP, 1.0F, 1.0F);
			java.util.Set<Integer> hit = new java.util.HashSet<>();
			Scheduler.repeat(p, 30, tick -> {
				for (LivingEntity e : lvl(p).getEntitiesOfClass(LivingEntity.class, p.getBoundingBox().inflate(1.0), e -> e != p && e.isAlive())) {
					if (hit.add(e.getId())) {
						Combat.hit(p, e, 10, p.getDeltaMovement(), 3.0F, 0.4F, false);
					}
				}
				p.fallDistance = 0;
				return !p.onGround() || tick < 3;
			});
		});
	}

	static void whip(LivingEntity p, double radius, float damage, float knock, float upward, float legSize) {
		ServerLevel level = lvl(p);
		Vec3 base = p.position().add(0, 0.5, 0);
		VfxEntity.create(level, VfxType.STRETCH_LEG, base, WHITE, legSize, 12).owner(p).target(base.add(p.getLookAngle().scale(radius))).variant(look(p)).spin(1.0F).spawn();
		Combat.hitSphere(p, base, radius, damage, knock, upward, false);
		shock(level, p.position().add(0, 0.1, 0), Powers.view(p).form().color, (float) radius, 14);
		sound(p, ModSounds.WHOOSH, 1.2F, 0.8F);
	}

	static void balloon(LivingEntity p, int ticks, float size) {
		sound(p, ModSounds.INFLATE, 1.2F, 1.0F / size);
		p.addEffect(new MobEffectInstance(MobEffects.RESISTANCE, ticks, size >= 3 ? 3 : 2, false, false, true));
		Scheduler.repeat(p, ticks, tick -> {
			AABB box = p.getBoundingBox().inflate(2.5 * size);
			for (Projectile proj : lvl(p).getEntitiesOfClass(Projectile.class, box, e -> e.getOwner() != p)) {
				Vec3 bounce = proj.position().subtract(p.position()).normalize().scale(Math.max(1.0, proj.getDeltaMovement().length()));
				proj.setDeltaMovement(bounce);
				proj.setOwner(p);
				proj.hurtMarked = true;
				if (tick % 3 == 0) {
					sound(p, ModSounds.BOUNCE, 0.8F, 1.4F);
				}
			}
			if (tick % 5 == 0) {
				for (LivingEntity e : lvl(p).getEntitiesOfClass(LivingEntity.class, p.getBoundingBox().inflate(0.8 * size), e -> e != p && e.isAlive())) {
					Combat.hit(p, e, 1, e.position().subtract(p.position()), 2.5F * size, 0.4F, false);
				}
			}
			return true;
		});
	}

	static void stamp(LivingEntity p, double range, float damage, float size) {
		Vec3 end = Combat.rayEnd(p, range);
		VfxEntity.create(lvl(p), VfxType.STRETCH_LEG, p.position().add(0, 0.7, 0), WHITE, size, 12).owner(p).target(end).variant(look(p)).spawn();
		sound(p, ModSounds.STRETCH, 1.0F, 0.9F);
		for (LivingEntity target : Combat.inLine(p, range, 1.2)) {
			Combat.hit(p, target, damage, p.getLookAngle(), 4.0F, 0.6F, false);
		}
		impact(lvl(p), end, Powers.view(p).form().color, 1.6F);
	}

	static void dash(LivingEntity p, double distance, float damage, float knock, int color, boolean fire) {
		sound(p, ModSounds.WHOOSH, 1.2F, 1.4F);
		Combat.dash(p, distance, color, e -> {
			if (damage > 0) {
				Combat.hit(p, e, damage, p.getLookAngle(), knock, 0.3F, fire);
			}
		});
	}

	static void redHawk(LivingEntity p) {
		LivingEntity target = Combat.firstInLine(p, 24, 1.0);
		Vec3 end = target != null ? target.getBoundingBox().getCenter() : Combat.rayEnd(p, 24);
		arm(p, end, LOOK_HAKI, 1.2F, 12, true);
		VfxEntity.create(lvl(p), VfxType.FIRE_BURST, end, FIRE_ORANGE, 3.0F, 18).spawn();
		sound(p, ModSounds.FIRE_BLAST, 1.2F, 1.1F);
		for (LivingEntity e : Combat.inLine(p, 24, 1.3)) {
			Combat.hit(p, e, 28, p.getLookAngle(), 5.0F, 0.4F, true);
		}
		Combat.hitSphere(p, end, 3.5, 12, 3.0F, 0.4F, true);
	}

	static void chargedFist(LivingEntity p, int windup, float size, float damage, float knock, int color, int look) {
		chargedFist(p, windup, size, damage, knock, color, look, false);
	}

	static void chargedFist(LivingEntity p, int windup, float size, float damage, float knock, int color, int look, boolean pierce) {
		sound(p, ModSounds.INFLATE, 1.2F, 0.6F);
		Scheduler.later(p, windup, () -> {
			Vec3 dir = p.getLookAngle();
			VfxEntity fist = VfxEntity.create(lvl(p), VfxType.GIANT_FIST, shoulder(p, true).add(dir.scale(1.5 + size * 0.6)), color, size, 40)
				.owner(p).variant(look).projectile(dir.scale(1.6), damage, knock, size * 0.7F).upward(0.5F).impact(Powers.view(p).form().color);
			if (pierce) {
				fist.pierce().spin(1.0F);
			}
			fist.spawn();
			sound(p, ModSounds.HEAVY_IMPACT, 1.0F, 1.3F);
			sound(p, ModSounds.SNAP, 1.0F, 0.6F);
		});
	}

	static void giantGatling(LivingEntity p, int ticks, float size, float damage, int look, int color) {
		sound(p, ModSounds.GATLING, 1.4F, 0.6F);
		Scheduler.repeat(p, ticks, tick -> {
			if (tick % 4 == 0) {
				Vec3 dir = p.getLookAngle();
				Vec3 spread = right(p).scale((p.getRandom().nextFloat() - 0.5) * 5.0).add(0, (p.getRandom().nextFloat() - 0.3) * 3.0, 0);
				VfxEntity.create(lvl(p), VfxType.GIANT_FIST, shoulder(p, tick % 8 == 0).add(dir.scale(1.5 + size * 0.6)).add(spread.scale(0.4)), color, size, 24)
					.owner(p).variant(look).projectile(dir.scale(1.8).add(spread.scale(0.03)), damage, 3.0F, size * 0.7F).impact(Powers.view(p).form().color).spawn();
				if (tick % 8 == 0) {
					sound(p, ModSounds.HEAVY_IMPACT, 0.7F, 1.3F);
				}
			}
			return true;
		});
	}

	static void gigantAxe(LivingEntity p, float damage, double radius, float size) {
		sound(p, ModSounds.INFLATE, 1.2F, 0.5F);
		Vec3 spot = p.position().add(p.getLookAngle().multiply(1, 0, 1).normalize().scale(5));
		VfxEntity.create(lvl(p), VfxType.STRETCH_LEG, p.position().add(0, 0.7, 0), WHITE, 4.0F * size, 18).owner(p).target(spot.add(0, 9, 0)).variant(look(p)).spin(2.0F).spawn();
		Scheduler.later(p, 10, () -> {
			groundBurst(p, spot, radius, damage, 1.4F, Powers.view(p).form().color);
			soundAt(lvl(p), spot, ModSounds.HEAVY_IMPACT, 1.6F, 0.6F);
		});
	}

	/** Cracked ground decal that lingers after a big hit. */
	static void crater(ServerLevel level, Vec3 spot, double radius) {
		VfxEntity.create(level, VfxType.CRATER, spot.add(0, 0.03, 0), 0xFFFFFFFF, (float) radius, 120).spawn();
	}

	static void groundBurst(LivingEntity p, Vec3 spot, double radius, float damage, float upward, int color) {
		ServerLevel level = lvl(p);
		crater(level, spot, radius * 0.8);
		shock(level, spot.add(0, 0.1, 0), color, (float) radius, 16);
		shock(level, spot.add(0, 0.1, 0), WHITE, (float) radius * 0.6F, 10);
		VfxEntity.create(level, VfxType.CLOUD, spot, 0xFFD8D0C0, (float) radius * 0.5F, 20).spawn();
		Combat.hitSphere(p, spot, radius, damage, 3.0F, upward, false);
	}

	static void groundSlam(LivingEntity p, double radius, float damage, float upward, int color, SoundEvent sound) {
		Combat.launch(p, new Vec3(0, 1.1, 0));
		Scheduler.repeat(p, 60, tick -> {
			if (tick > 4 && (p.onGround() || tick == 59)) {
				groundBurst(p, p.position(), radius, damage, upward, color);
				sound(p, sound, 1.6F, 0.7F);
				sound(p, ModSounds.HEAVY_IMPACT, 1.4F, 0.6F);
				return false;
			}
			if (tick == 8) {
				Combat.launch(p, new Vec3(0, -2.4, 0));
			}
			return true;
		});
	}

	static void homingFists(LivingEntity p, int count, float size, float damage) {
		sound(p, ModSounds.INFLATE, 1.2F, 0.7F);
		Scheduler.later(p, 6, () -> {
			for (int n = 0; n < count; n++) {
				Vec3 dir = p.getLookAngle().add(right(p).scale((n - (count - 1) / 2.0) * 0.4)).normalize();
				VfxEntity.create(lvl(p), VfxType.GIANT_FIST, shoulder(p, n % 2 == 0).add(dir.scale(1.5 + size * 0.6)), HAKI_BLACK, size, 50)
					.owner(p).variant(LOOK_GEAR4).projectile(dir.scale(1.3), damage, 7.0F, size * 0.7F).homing().impact(Powers.view(p).form().color).spawn();
			}
			sound(p, ModSounds.SNAP, 1.2F, 0.6F);
		});
	}

	static void homingArms(LivingEntity p, int count, float damage) {
		sound(p, ModSounds.STRETCH, 1.2F, 0.8F);
		List<LivingEntity> targets = Combat.inCone(p, 28, 45);
		for (int n = 0; n < count; n++) {
			LivingEntity target = targets.isEmpty() ? null : targets.get(n % targets.size());
			Vec3 end = target != null ? target.getBoundingBox().getCenter() : Combat.rayEnd(p, 24).add(right(p).scale((n - count / 2.0) * 2.0));
			arm(p, end, LOOK_GEAR4, 1.3F, 12, n % 2 == 0).spin(1.0F);
			if (target != null) {
				Combat.hit(p, target, damage, p.getLookAngle(), 4.0F, 0.3F, false);
				impact(lvl(p), end, Form.GEAR_4_SNAKEMAN.color, 1.6F);
			}
		}
	}

	static void mamba(LivingEntity p) {
		sound(p, ModSounds.GATLING, 1.4F, 0.8F);
		Scheduler.repeat(p, 40, tick -> {
			if (tick % 2 == 0) {
				List<LivingEntity> targets = Combat.inCone(p, 26, 60);
				LivingEntity target = targets.isEmpty() ? null : targets.get(p.getRandom().nextInt(targets.size()));
				Vec3 end = target != null ? target.getBoundingBox().getCenter() : Combat.rayEnd(p, 20).add(right(p).scale((p.getRandom().nextFloat() - 0.5) * 6));
				arm(p, end, LOOK_GEAR4, 1.2F, 6, tick % 4 == 0).spin(1.0F);
				if (target != null) {
					Combat.hit(p, target, 9, p.getLookAngle(), 0.6F, 0.1F, false);
				}
			}
			return true;
		});
	}

	static void chaser(LivingEntity p) {
		sound(p, ModSounds.INFLATE, 1.4F, 0.4F);
		Scheduler.later(p, 10, () -> {
			for (LivingEntity e : Combat.inCone(p, 14, 40)) {
				Combat.hit(p, e, 38, p.getLookAngle(), 14.0F, 0.8F, false);
			}
			Vec3 front = p.getEyePosition().add(p.getLookAngle().scale(4));
			shock(lvl(p), front, Form.GEAR_4_TANKMAN.color, 6.0F, 14);
			VfxEntity.create(lvl(p), VfxType.CLOUD, front, 0xFFE8E0D0, 4.0F, 18).spawn();
			sound(p, ModSounds.HEAVY_IMPACT, 1.6F, 0.5F);
		});
	}

	static void cannonball(LivingEntity p) {
		Vec3 dir = p.getLookAngle();
		Combat.launch(p, dir.scale(2.6).add(0, 0.6, 0));
		sound(p, ModSounds.SNAP, 1.4F, 0.5F);
		java.util.Set<Integer> hit = new java.util.HashSet<>();
		Scheduler.repeat(p, 50, tick -> {
			for (LivingEntity e : lvl(p).getEntitiesOfClass(LivingEntity.class, p.getBoundingBox().inflate(1.5), e -> e != p && e.isAlive())) {
				if (hit.add(e.getId())) {
					Combat.hit(p, e, 30, p.getDeltaMovement(), 8.0F, 0.6F, false);
				}
			}
			if (tick > 4 && (p.onGround() || p.horizontalCollision)) {
				groundBurst(p, p.position(), 7.0, 24, 1.0F, Form.GEAR_4_TANKMAN.color);
				sound(p, ModSounds.HEAVY_IMPACT, 1.6F, 0.6F);
				return false;
			}
			return true;
		});
	}

	static void bajrang(LivingEntity p) {
		ServerLevel level = lvl(p);
		Vec3 spot = Combat.rayEnd(p, 30);
		Vec3 sky = spot.add(0, 34, 0);
		sound(p, ModSounds.DRUMS, 2.0F, 1.0F);
		VfxEntity.create(level, VfxType.STRETCH_ARM, shoulder(p, true), WHITE, 3.0F, 46).owner(p).target(sky).variant(LOOK_GEAR5).spawn();
		Scheduler.later(p, 16, () -> {
			VfxEntity.create(level, VfxType.GIANT_FIST, sky, WHITE, 13.0F, 60).owner(p).variant(LOOK_GEAR5)
				.projectile(spot.subtract(sky).normalize().scale(1.4), 90, 14.0F, 9.0F).pierce().phase().spawn();
			sound(p, ModSounds.SNAP, 2.0F, 0.4F);
		});
		Scheduler.later(p, 40, () -> {
			groundBurst(p, spot, 14.0, 60, 1.8F, Form.GEAR_5.color);
			VfxEntity.create(level, VfxType.IMPACT, spot.add(0, 2, 0), 0xFFFFE070, 10.0F, 14).spawn();
			soundAt(level, spot, ModSounds.HEAVY_IMPACT, 3.0F, 0.4F);
			for (ServerPlayer near : level.getPlayers(pl -> pl.distanceToSqr(spot) < 60 * 60)) {
				Powers.shake(near, 1.4F, 30);
			}
		});
	}

	static void lightningGrab(LivingEntity p) {
		ServerLevel level = lvl(p);
		Vec3 hand = shoulder(p, true).add(0, 0.9, 0);
		VfxEntity.create(level, VfxType.LIGHTNING, hand.add(0, 30, 0), 0xFFFFF3A0, 1.0F, 14).target(hand).spawn();
		sound(p, ModSounds.LIGHTNING, 2.0F, 1.2F);
		Scheduler.later(p, 12, () -> {
			LivingEntity target = Combat.firstInLine(p, 40, 1.5);
			Vec3 end = target != null ? target.getBoundingBox().getCenter() : Combat.rayEnd(p, 40);
			VfxEntity.create(level, VfxType.LIGHTNING, shoulder(p, true), 0xFFFFF3A0, 1.6F, 16).target(end).spawn();
			Combat.hitSphere(p, end, 4.5, 42, 4.0F, 0.6F, true);
			for (LivingEntity e : Combat.inLine(p, 40, 1.4)) {
				Combat.hit(p, e, 20, p.getLookAngle(), 2.0F, 0.2F, true);
			}
			impact(level, end, 0xFFFFF3A0, 4.0F);
			soundAt(level, end, ModSounds.LIGHTNING, 2.0F, 0.8F);
		});
	}

	static void toonGround(LivingEntity p) {
		ServerLevel level = lvl(p);
		sound(p, ModSounds.DRUMS, 1.6F, 1.2F);
		sound(p, ModSounds.BOUNCE, 1.6F, 0.6F);
		for (int ring = 0; ring < 4; ring++) {
			final int r = ring;
			Scheduler.later(p, ring * 5, () -> shock(level, p.position().add(0, 0.1, 0), r % 2 == 0 ? WHITE : 0xFFFFE070, 4.0F + r * 4.0F, 16));
		}
		for (LivingEntity e : Combat.inSphere(p, p.position(), 16)) {
			Combat.hit(p, e, 16, e.position().subtract(p.position()), 1.0F, 1.9F, false);
			impact(level, e.position().add(0, 1, 0), WHITE, 1.4F);
		}
		VfxEntity.create(level, VfxType.CLOUD, p.position(), WHITE, 6.0F, 26).spawn();
	}

	static void giantMode(LivingEntity p) {
		if (p instanceof ServerPlayer player && !Powers.hasRoom(player, 4.0F)) {
			player.sendOverlayMessage(net.minecraft.network.chat.Component.translatable("message.onepiece.no_room").withStyle(net.minecraft.ChatFormatting.RED));
			return;
		}
		if (p instanceof ServerPlayer player) {
			Powers.set(player, Powers.get(player).withGiantUntil(lvl(p).getGameTime() + 20 * 18));
		}
		sound(p, ModSounds.DRUMS, 2.0F, 0.8F);
		sound(p, ModSounds.INFLATE, 2.0F, 0.4F);
		VfxEntity.create(lvl(p), VfxType.CLOUD, p.position(), WHITE, 8.0F, 30).spawn();
	}

	// ------------------------------------------------------------------ Zoro

	static void swordDash(LivingEntity p, double distance, float damage, int color, boolean asura) {
		sound(p, ModSounds.SHEATHE, 1.0F, 1.2F);
		Vec3 start = p.position().add(0, 1, 0);
		Vec3 end = Combat.dash(p, distance, color, e -> {
			Combat.hit(p, e, damage, p.getLookAngle(), 2.0F, 0.3F, false);
			VfxEntity.create(lvl(p), VfxType.SLASH, e.getBoundingBox().getCenter(), color, 2.4F, 10).spin(45.0F).facing(p.getLookAngle()).spawn();
			VfxEntity.create(lvl(p), VfxType.SLASH, e.getBoundingBox().getCenter(), color, 2.4F, 10).spin(-45.0F).facing(p.getLookAngle()).spawn();
		});
		Scheduler.later(p, 4, () -> {
			sound(p, ModSounds.SLASH, 1.4F, 0.9F);
			if (asura) {
				for (int n = 0; n < 9; n++) {
					VfxEntity.create(lvl(p), VfxType.SLASH, start.lerp(end.add(0, 1, 0), n / 9.0), color, 3.0F, 12).spin(n * 40.0F).facing(p.getLookAngle()).spawn();
				}
			}
		});
	}

	static void leapSlam(LivingEntity p, float damage, double radius, int color) {
		Vec3 dir = p.getLookAngle().multiply(1, 0, 1).normalize();
		Combat.launch(p, dir.scale(1.1).add(0, 1.15, 0));
		sound(p, ModSounds.WHOOSH, 1.0F, 0.9F);
		boolean fire = color == FIRE_ORANGE || color == BLUE_FIRE;
		Scheduler.repeat(p, 60, tick -> {
			if (tick == 10) {
				Combat.launch(p, p.getDeltaMovement().multiply(1, 0, 1).add(0, -2.2, 0));
			}
			if (tick > 4 && (p.onGround() || tick == 59)) {
				ServerLevel level = lvl(p);
				shock(level, p.position().add(0, 0.1, 0), color, (float) radius * 1.3F, 14);
				crater(level, p.position(), radius * 0.7);
				if (fire) {
					VfxEntity.create(level, VfxType.FIRE_BURST, p.position().add(0, 0.5, 0), color, (float) radius * 0.7F, 18).spawn();
					sound(p, ModSounds.FIRE_BLAST, 1.4F, color == BLUE_FIRE ? 0.7F : 1.0F);
				} else {
					VfxEntity.create(level, VfxType.SLASH, p.position().add(0, 0.6, 0), color, (float) radius, 10).spin(90.0F).facing(p.getLookAngle()).spawn();
				}
				Combat.hitSphere(p, p.position(), radius, damage, 3.0F, 0.9F, fire);
				sound(p, ModSounds.HEAVY_IMPACT, 1.4F, 0.8F);
				return false;
			}
			return true;
		});
	}

	static void flyingSlash(LivingEntity p, float size, double speed, float damage, float knock, int color, float roll, boolean big) {
		Vec3 dir = p.getLookAngle();
		VfxEntity.create(lvl(p), VfxType.SLASH, p.getEyePosition().add(dir.scale(1.2)).add(0, -0.3, 0), color, size, 40)
			.owner(p).spin(roll).projectile(dir.scale(speed), damage, knock, size * 0.55F).pierce().spawn();
		sound(p, big ? ModSounds.BIG_SLASH : ModSounds.SLASH, 1.2F, big ? 0.8F : 1.2F);
	}

	static void tornado(LivingEntity p, float size, float damage, int life, int color, double drift) {
		Vec3 dir = p.getLookAngle().multiply(1, 0, 1).normalize();
		VfxEntity.create(lvl(p), VfxType.TORNADO, p.position().add(dir.scale(2.0)), color, size, life)
			.owner(p).projectile(dir.scale(drift), damage, 0.6F, size * 0.7F).pierce().spawn();
		sound(p, ModSounds.TORNADO, 1.6F, 1.0F);
		sound(p, ModSounds.BIG_SLASH, 1.0F, 1.2F);
	}

	static void iai(LivingEntity p, double range, float damage, int color) {
		LivingEntity target = Combat.firstInLine(p, range, 1.5);
		sound(p, ModSounds.SHEATHE, 1.2F, 1.4F);
		if (target != null) {
			Vec3 behind = target.position().add(p.getLookAngle().multiply(1, 0, 1).normalize().scale(1.8));
			VfxEntity.create(lvl(p), VfxType.DASH_TRAIL, p.position().add(0, 1, 0), color, 1.0F, 10).target(behind.add(0, 1, 0)).owner(p).spawn();
			safeTeleport(p, behind);
			Scheduler.later(p, 6, () -> {
				Combat.hit(p, target, damage, p.getLookAngle(), 2.0F, 0.2F, false);
				VfxEntity.create(lvl(p), VfxType.SLASH, target.getBoundingBox().getCenter(), color, 3.0F, 10).spin(-20.0F).facing(p.getLookAngle()).spawn();
				sound(p, ModSounds.SLASH, 1.4F, 1.5F);
			});
		} else {
			flyingSlash(p, 2.0F, 2.4, damage * 0.6F, 1.0F, color, -20.0F, false);
		}
	}

	static void slashRing(LivingEntity p, double radius, float damage, int color) {
		ServerLevel level = lvl(p);
		VfxEntity.create(level, VfxType.SLASH_RING, p.position().add(0, 1, 0), color, (float) radius, 18).owner(p).spawn();
		Combat.hitSphere(p, p.position(), radius, damage, 3.0F, 0.4F, false);
		sound(p, ModSounds.BIG_SLASH, 1.6F, 0.8F);
		Scheduler.later(p, 6, () -> Combat.hitSphere(p, p.position(), radius, damage * 0.5F, 2.0F, 0.3F, false));
	}

	static void fanSlashes(LivingEntity p, int count, float damage, int color) {
		Vec3 look = p.getLookAngle();
		for (int n = 0; n < count; n++) {
			double angle = (n - (count - 1) / 2.0) * 9.0 * Mth.DEG_TO_RAD;
			Vec3 dir = look.yRot((float) angle);
			VfxEntity.create(lvl(p), VfxType.SLASH, p.getEyePosition().add(dir.scale(1.2)).add(0, -0.3, 0), color, 2.6F, 30)
				.owner(p).spin(n * 30.0F).projectile(dir.scale(1.5), damage, 2.0F, 1.4F).pierce().spawn();
		}
		sound(p, ModSounds.BIG_SLASH, 1.6F, 1.0F);
	}

	static void dragonSlash(LivingEntity p) {
		Vec3 dir = p.getLookAngle();
		VfxEntity.create(lvl(p), VfxType.DRAGON, p.getEyePosition().add(dir.scale(1.5)), 0xFFFF6A2A, 4.0F, 40)
			.owner(p).projectile(dir.scale(1.3), 46, 7.0F, 2.6F).pierce().fire().spawn();
		sound(p, ModSounds.BIG_SLASH, 1.6F, 0.6F);
		sound(p, ModSounds.FIRE_BLAST, 1.4F, 0.8F);
	}

	static void sanzenSekai(LivingEntity p) {
		sound(p, ModSounds.TORNADO, 1.4F, 1.4F);
		Vec3 start = p.position().add(0, 1, 0);
		Scheduler.later(p, 8, () -> {
			Vec3 end = Combat.dash(p, 16, ENMA_PURPLE, e -> Combat.hit(p, e, 58, p.getLookAngle(), 4.0F, 0.6F, false));
			for (int n = 0; n < 6; n++) {
				VfxEntity.create(lvl(p), VfxType.SLASH, start.lerp(end.add(0, 1, 0), n / 6.0), ENMA_PURPLE, 3.4F, 14).spin(n * 60.0F).facing(p.getLookAngle()).spawn();
			}
			VfxEntity.create(lvl(p), VfxType.SLASH_RING, end.add(0, 1, 0), ENMA_PURPLE, 6.0F, 18).spawn();
			sound(p, ModSounds.BIG_SLASH, 2.0F, 0.6F);
		});
	}

	// ------------------------------------------------------------------ Sanji

	static void kick(LivingEntity p, double range, float damage, float knock, float upward, boolean fire, int color) {
		Combat.hitCone(p, range, 50, damage, knock, upward, fire);
		Vec3 front = p.getEyePosition().add(p.getLookAngle().scale(2.0));
		impact(lvl(p), front, color, 1.4F);
		if (fire) {
			VfxEntity.create(lvl(p), VfxType.FIRE_BURST, front, color, 1.6F, 12).spawn();
		}
		sound(p, ModSounds.KICK, 1.2F, 1.0F);
	}

	static void dashKick(LivingEntity p, double distance, float damage, float knock, boolean fire, int color) {
		sound(p, ModSounds.WHOOSH, 1.0F, 1.3F);
		Combat.dash(p, distance, color, e -> {
			Combat.hit(p, e, damage, p.getLookAngle(), knock, 0.6F, fire);
			impact(lvl(p), e.getBoundingBox().getCenter(), color, 1.6F);
			if (fire) {
				VfxEntity.create(lvl(p), VfxType.FIRE_BURST, e.getBoundingBox().getCenter(), color, 2.0F, 14).spawn();
			}
		});
		sound(p, fire ? ModSounds.FIRE_BLAST : ModSounds.KICK, 1.2F, 1.0F);
	}

	static void partyTable(LivingEntity p, double radius, float damage, boolean fire, int color) {
		sound(p, ModSounds.WHOOSH, 1.2F, 0.8F);
		Scheduler.repeat(p, 40, tick -> {
			if (tick % 5 == 0) {
				Combat.hitSphere(p, p.position(), radius, damage, 2.0F, 0.35F, fire);
				shock(lvl(p), p.position().add(0, 0.6, 0), color, (float) radius, 8);
				if (fire) {
					VfxEntity.create(lvl(p), VfxType.FIRE_BURST, p.position().add(0, 0.6, 0), color, (float) radius * 0.5F, 10).spawn();
				}
				sound(p, ModSounds.KICK, 0.8F, 1.2F);
			}
			return true;
		});
	}

	static void launchKick(LivingEntity p, float damage, boolean fire) {
		for (LivingEntity e : Combat.inCone(p, 4.5, 55)) {
			Combat.hit(p, e, damage, p.getLookAngle(), 0.5F, 2.2F, fire);
			impact(lvl(p), e.position(), WHITE, 1.6F);
		}
		shock(lvl(p), p.position().add(0, 0.1, 0), WHITE, 3.0F, 10);
		sound(p, ModSounds.KICK, 1.4F, 0.8F);
	}

	static void skyDash(LivingEntity p) {
		Vec3 dir = p.getLookAngle();
		Combat.launch(p, dir.scale(1.4).add(0, 0.7, 0));
		VfxEntity.create(lvl(p), VfxType.CLOUD, p.position(), WHITE, 1.2F, 12).spawn();
		shock(lvl(p), p.position(), WHITE, 1.6F, 8);
		sound(p, ModSounds.WHOOSH, 1.0F, 1.6F);
	}

	static void rapidKicks(LivingEntity p, int ticks, float damage, boolean fire, int color) {
		sound(p, ModSounds.GATLING, 1.0F, 1.4F);
		Scheduler.repeat(p, ticks, tick -> {
			if (tick % 3 == 0) {
				Combat.hitCone(p, 5.0, 50, damage, 0.4F, 0.1F, fire);
				Vec3 front = p.getEyePosition().add(p.getLookAngle().scale(2.0)).add(right(p).scale((p.getRandom().nextFloat() - 0.5) * 1.6)).add(0, (p.getRandom().nextFloat() - 0.6), 0);
				impact(lvl(p), front, color, 0.9F);
				if (fire && tick % 6 == 0) {
					VfxEntity.create(lvl(p), VfxType.FIRE_BURST, front, color, 1.2F, 10).spawn();
				}
			}
			return true;
		});
	}

	static void fireNova(LivingEntity p, double radius, float damage, int color, int strength) {
		ServerLevel level = lvl(p);
		sound(p, ModSounds.FIRE, 1.6F, 0.8F);
		Scheduler.later(p, 8, () -> {
			VfxEntity.create(level, VfxType.FIRE_BURST, p.position().add(0, 1, 0), color, (float) radius * 0.8F, 26).spawn();
			shock(level, p.position().add(0, 0.1, 0), color, (float) radius * 1.3F, 18);
			Combat.hitSphere(p, p.position(), radius, damage, 5.0F, 0.8F, true);
			sound(p, ModSounds.FIRE_BLAST, 2.0F, strength == 2 ? 0.6F : 0.8F);
			for (ServerPlayer near : level.getPlayers(pl -> pl.distanceToSqr(p) < 40 * 40)) {
				Powers.shake(near, 0.6F * strength, 16);
			}
		});
	}

	static void ifritKick(LivingEntity p) {
		ServerLevel level = lvl(p);
		Vec3 dir = p.getLookAngle();
		sound(p, ModSounds.FIRE, 1.6F, 0.6F);
		Scheduler.later(p, 6, () -> {
			for (int n = 1; n <= 8; n++) {
				Vec3 at = p.getEyePosition().add(dir.scale(n * 2.4));
				final int delay = n;
				Scheduler.later(p, delay, () -> VfxEntity.create(level, VfxType.FIRE_BURST, at, BLUE_FIRE, 1.4F + delay * 0.3F, 16).spawn());
			}
			for (LivingEntity e : Combat.inLine(p, 22, 2.2)) {
				Combat.hit(p, e, 62, dir, 10.0F, 0.8F, true);
			}
			sound(p, ModSounds.FIRE_BLAST, 2.0F, 0.5F);
			sound(p, ModSounds.KICK, 1.6F, 0.6F);
		});
	}

	static void stealthKick(LivingEntity p) {
		LivingEntity target = Combat.nearestTarget(p, p.getEyePosition().add(p.getLookAngle().scale(6)), 14, null);
		if (target == null) {
			dashKick(p, 10, 22, 4.0F, false, 0xFF6F8CFF);
			return;
		}
		Vec3 behind = target.position().subtract(target.getLookAngle().multiply(1, 0, 1).normalize().scale(1.6));
		VfxEntity.create(lvl(p), VfxType.DASH_TRAIL, p.position().add(0, 1, 0), 0xFF6F8CFF, 1.0F, 10).target(behind.add(0, 1, 0)).owner(p).spawn();
		safeTeleport(p, behind);
		Combat.hit(p, target, 30, target.position().subtract(p.position()), 5.0F, 0.6F, false);
		impact(lvl(p), target.getBoundingBox().getCenter(), 0xFF6F8CFF, 1.8F);
		sound(p, ModSounds.KICK, 1.4F, 0.7F);
	}
	// ------------------------------------------------------------------ Kaido

	static void thunderBagua(LivingEntity p, float damage, double radius) {
		Vec3 dir = p.getLookAngle().multiply(1, 0, 1).normalize();
		Combat.launch(p, dir.scale(1.0).add(0, 1.0, 0));
		sound(p, ModSounds.WHOOSH, 1.4F, 0.6F);
		Scheduler.repeat(p, 60, tick -> {
			if (tick == 9) {
				Combat.launch(p, p.getDeltaMovement().multiply(1, 0, 1).add(0, -2.4, 0));
			}
			if (tick > 4 && (p.onGround() || tick == 59)) {
				ServerLevel level = lvl(p);
				Vec3 at = p.position().add(dir.scale(2.0));
				shock(level, at.add(0, 0.1, 0), KAIDO_PURPLE, (float) radius * 1.4F, 18);
				shock(level, at.add(0, 0.1, 0), 0xFFFFFFFF, (float) radius * 0.7F, 12);
				for (int n = 0; n < 5; n++) {
					double a = n / 5.0 * Math.PI * 2;
					Vec3 strike = at.add(Math.cos(a) * radius * 0.6, 0, Math.sin(a) * radius * 0.6);
					VfxEntity.create(level, VfxType.LIGHTNING, strike.add(0, 18, 0), 0xFFC9B3FF, 1.2F, 12).target(strike).spawn();
				}
				VfxEntity.create(level, VfxType.CLOUD, at, 0xFFB8A890, (float) radius * 0.5F, 20).spawn();
				crater(level, at, radius);
				Combat.hitSphere(p, at, radius, damage, 4.0F, 1.0F, false);
				soundAt(level, at, ModSounds.LIGHTNING, 2.0F, 0.7F);
				soundAt(level, at, ModSounds.HEAVY_IMPACT, 2.0F, 0.5F);
				for (ServerPlayer near : level.getPlayers(pl -> pl.distanceToSqr(at) < 40 * 40)) {
					Powers.shake(near, 0.9F, 18);
				}
				return false;
			}
			return true;
		});
	}

	static void ragnaraku(LivingEntity p, float damage) {
		ServerLevel level = lvl(p);
		Vec3 dir = p.getLookAngle().multiply(1, 0, 1).normalize();
		sound(p, ModSounds.HEAVY_IMPACT, 2.0F, 0.5F);
		for (int n = 1; n <= 8; n++) {
			final int step = n;
			Scheduler.later(p, n * 2, () -> {
				Vec3 at = p.position().add(dir.scale(step * 2.6));
				shock(level, at.add(0, 0.1, 0), KAIDO_PURPLE, 3.5F, 12);
				VfxEntity.create(level, VfxType.LIGHTNING, at.add(0, 20, 0), 0xFFD8C8FF, 1.4F, 10).target(at).spawn();
				Combat.hitSphere(p, at, 3.0, damage * 0.5F, 2.0F, 0.9F, false);
				if (step % 2 == 0) {
					soundAt(level, at, ModSounds.LIGHTNING, 1.4F, 0.8F + step * 0.05F);
				}
			});
		}
	}

	static void roarBlast(LivingEntity p, double radius, float damage, int color) {
		ServerLevel level = lvl(p);
		sound(p, ModSounds.BOSS_ROAR, 2.4F, 0.8F);
		shock(level, p.position().add(0, 1, 0), color, (float) radius, 20);
		VfxEntity.create(level, VfxType.CONQUEROR, p.position().add(0, 1.5, 0), color, (float) radius * 0.8F, 24).owner(p).spawn();
		for (LivingEntity e : Combat.inSphere(p, p.position(), radius)) {
			Combat.hit(p, e, damage, e.position().subtract(p.position()), 6.0F, 0.6F, false);
			e.addEffect(new MobEffectInstance(MobEffects.SLOWNESS, 60, 2));
		}
		for (ServerPlayer near : level.getPlayers(pl -> pl.distanceToSqr(p) < 30 * 30)) {
			Powers.shake(near, 0.8F, 20);
		}
	}

	static void breath(LivingEntity p, double length, float damage, int color, float size) {
		ServerLevel level = lvl(p);
		sound(p, ModSounds.FIRE_BLAST, 2.4F, 0.5F);
		sound(p, ModSounds.BOSS_ROAR, 1.6F, 1.2F);
		Scheduler.repeat(p, 24, tick -> {
			if (tick % 2 == 0) {
				Vec3 dir = p.getLookAngle();
				Vec3 mouth = p.getEyePosition().add(dir.scale(p.getBbWidth()));
				double reach = length * Math.min(1.0, (tick + 4) / 12.0);
				for (int n = 1; n <= 6; n++) {
					Vec3 at = mouth.add(dir.scale(reach * n / 6.0));
					VfxEntity.create(level, VfxType.FIRE_BURST, at, color, size * (0.6F + n * 0.25F), 12).spawn();
				}
				for (LivingEntity e : Combat.inLine(p, reach, size * 1.2)) {
					Combat.hit(p, e, damage / 8.0F, dir, 0.6F, 0.1F, true);
				}
				if (tick % 8 == 0) {
					sound(p, ModSounds.FIRE, 1.6F, 0.6F);
				}
			}
			return true;
		});
	}

	static void lightningRain(LivingEntity p, int count, double radius, float damage) {
		ServerLevel level = lvl(p);
		sound(p, ModSounds.LIGHTNING, 2.4F, 0.6F);
		List<LivingEntity> targets = Combat.inSphere(p, p.position(), radius);
		for (int n = 0; n < count; n++) {
			Vec3 spot;
			if (n < targets.size()) {
				spot = targets.get(n).position();
			} else {
				double a = p.getRandom().nextDouble() * Math.PI * 2;
				double r = 3 + p.getRandom().nextDouble() * radius;
				spot = p.position().add(Math.cos(a) * r, 0, Math.sin(a) * r);
			}
			final Vec3 at = spot;
			Scheduler.later(p, 4 + n * 3, () -> {
				VfxEntity.create(level, VfxType.LIGHTNING, at.add(0, 28, 0), 0xFFE0D8FF, 1.6F, 12).target(at).spawn();
				shock(level, at.add(0, 0.1, 0), 0xFFC9B3FF, 3.0F, 10);
				Combat.hitSphere(p, at, 2.6, damage, 1.5F, 0.6F, true);
				soundAt(level, at, ModSounds.LIGHTNING, 1.6F, 0.8F + p.getRandom().nextFloat() * 0.4F);
			});
		}
	}

	static void dragonDive(LivingEntity p) {
		Combat.launch(p, new Vec3(0, 1.6, 0));
		sound(p, ModSounds.BOSS_ROAR, 2.0F, 1.0F);
		Scheduler.repeat(p, 80, tick -> {
			if (tick == 12) {
				Combat.launch(p, p.getLookAngle().multiply(1, 0, 1).normalize().scale(1.4).add(0, -2.8, 0));
			}
			if (tick > 12 && (p.onGround() || tick == 79)) {
				groundBurst(p, p.position(), 12.0, 50, 1.6F, Form.KAIDO_DRAGON.color);
				VfxEntity.create(lvl(p), VfxType.FIRE_BURST, p.position().add(0, 1, 0), 0xFFFF7A1A, 6.0F, 20).spawn();
				sound(p, ModSounds.HEAVY_IMPACT, 2.4F, 0.4F);
				for (ServerPlayer near : lvl(p).getPlayers(pl -> pl.distanceToSqr(p) < 40 * 40)) {
					Powers.shake(near, 1.2F, 24);
				}
				return false;
			}
			return true;
		});
	}

	// ------------------------------------------------------------------ Katakuri

	static void trident(LivingEntity p, double range, float damage) {
		Vec3 end = Combat.rayEnd(p, range);
		VfxEntity.create(lvl(p), VfxType.SPEAR, shoulder(p, true), Powers.view(p).armament() || Powers.view(p).form() == Form.KATAKURI_AWAKENED ? HAKI_BLACK : MOCHI, 1.4F, 14)
			.owner(p).target(end).spawn();
		sound(p, ModSounds.STRETCH, 1.4F, 0.7F);
		for (LivingEntity e : Combat.inLine(p, range, 1.2)) {
			Combat.hit(p, e, damage, p.getLookAngle(), 3.0F, 0.2F, false);
			impact(lvl(p), e.getBoundingBox().getCenter(), 0xFFFFB8D8, 1.6F);
		}
	}

	static void flowingMochi(LivingEntity p) {
		sound(p, ModSounds.STRETCH, 1.4F, 0.5F);
		for (LivingEntity e : Combat.inCone(p, 18, 40)) {
			Vec3 pull = p.position().subtract(e.position()).normalize().scale(1.6);
			e.setDeltaMovement(pull.x, 0.4, pull.z);
			e.hurtMarked = true;
			e.addEffect(new MobEffectInstance(MobEffects.SLOWNESS, 80, 3));
			Combat.hit(p, e, 8, Vec3.ZERO, 0.0F, 0.0F, false);
			VfxEntity.create(lvl(p), VfxType.STRETCH_ARM, shoulder(p, true), WHITE, 2.2F, 14).owner(p).target(e.getBoundingBox().getCenter()).variant(LOOK_MOCHI).spawn();
		}
	}

	static void mochiPillars(LivingEntity p) {
		ServerLevel level = lvl(p);
		sound(p, ModSounds.HEAVY_IMPACT, 1.6F, 0.7F);
		List<LivingEntity> targets = Combat.inSphere(p, p.position(), 18);
		int n = 0;
		for (LivingEntity e : targets) {
			if (n++ > 8) {
				break;
			}
			Vec3 at = e.position().add(0, -2.5, 0);
			Scheduler.later(p, n * 2, () -> {
				VfxEntity.create(level, VfxType.GIANT_FIST, at, MOCHI, 3.0F, 18).owner(p).variant(LOOK_HAKI)
					.projectile(new Vec3(0, 0.9, 0), 30, 1.0F, 2.0F).upward(1.6F).pierce().phase().spawn();
				shock(level, at.add(0, 2.6, 0), 0xFFFFB8D8, 3.0F, 10);
			});
		}
		if (targets.isEmpty()) {
			Vec3 at = Combat.rayEnd(p, 10).add(0, -2.5, 0);
			VfxEntity.create(level, VfxType.GIANT_FIST, at, MOCHI, 3.0F, 18).owner(p).variant(LOOK_HAKI).projectile(new Vec3(0, 0.9, 0), 30, 1.0F, 2.0F).upward(1.6F).pierce().phase().spawn();
		}
	}

	static void mochiQuake(LivingEntity p) {
		ServerLevel level = lvl(p);
		sound(p, ModSounds.INFLATE, 2.0F, 0.4F);
		for (int ring = 0; ring < 4; ring++) {
			final int r = ring;
			Scheduler.later(p, ring * 5, () -> {
				shock(level, p.position().add(0, 0.1, 0), r % 2 == 0 ? MOCHI : 0xFFFFB8D8, 5.0F + r * 4.0F, 18);
				for (LivingEntity e : Combat.inSphere(p, p.position(), 5.0 + r * 4.0)) {
					e.addEffect(new MobEffectInstance(MobEffects.SLOWNESS, 60, 4));
					Combat.hit(p, e, 8, e.position().subtract(p.position()), 1.0F, 0.9F, false);
				}
			});
		}
	}

	static void hakaiMochi(LivingEntity p) {
		ServerLevel level = lvl(p);
		LivingEntity target = Combat.nearestTarget(p, p.getEyePosition().add(p.getLookAngle().scale(8)), 16, null);
		Vec3 at = target != null ? target.getBoundingBox().getCenter() : Combat.rayEnd(p, 14);
		Vec3 side = right(p).scale(9);
		sound(p, ModSounds.INFLATE, 2.0F, 0.5F);
		for (int s = -1; s <= 1; s += 2) {
			Vec3 from = at.add(side.scale(s)).add(0, 1, 0);
			VfxEntity.create(level, VfxType.GIANT_FIST, from, HAKI_BLACK, 4.0F, 24).owner(p).variant(LOOK_HAKI)
				.projectile(at.subtract(from).normalize().scale(0.9), 30, 2.0F, 2.6F).pierce().spawn();
		}
		Scheduler.later(p, 10, () -> {
			groundBurst(p, at, 6.0, 40, 1.0F, 0xFFFFB8D8);
			soundAt(level, at, ModSounds.HEAVY_IMPACT, 2.4F, 0.6F);
		});
	}

	// ------------------------------------------------------------------ Lucci

	static void shigan(LivingEntity p, double range, float damage) {
		sound(p, ModSounds.WHOOSH, 1.0F, 1.8F);
		LivingEntity target = Combat.firstInLine(p, range, 0.9);
		if (target != null) {
			Combat.hit(p, target, damage, p.getLookAngle(), 1.5F, 0.1F, false);
			impact(lvl(p), target.getBoundingBox().getCenter(), WHITE, 1.0F);
			VfxEntity.create(lvl(p), VfxType.DASH_TRAIL, shoulder(p, true), 0xFFFFF0C0, 1.0F, 6).target(target.getBoundingBox().getCenter()).owner(p).spawn();
			sound(p, ModSounds.PUNCH, 1.2F, 1.6F);
		}
	}

	static void tekkai(LivingEntity p, int ticks) {
		p.addEffect(new MobEffectInstance(MobEffects.RESISTANCE, ticks, 3, false, false, true));
		p.addEffect(new MobEffectInstance(MobEffects.SLOWNESS, ticks, 2, false, false, true));
		shock(lvl(p), p.position().add(0, 1, 0), 0xFFB0B8C8, 2.2F, 12);
		sound(p, ModSounds.HAKI, 1.4F, 0.5F);
	}

	static void rokuogan(LivingEntity p, double radius, float damage, float size) {
		ServerLevel level = lvl(p);
		sound(p, ModSounds.INFLATE, 1.0F, 1.4F);
		Scheduler.later(p, 3, () -> {
			Vec3 front = p.getEyePosition().add(p.getLookAngle().scale(1.8 * size)).add(0, -0.4, 0);
			shock(level, front, 0xFFFFE070, (float) radius, 14);
			impact(level, front, 0xFFFFE070, 2.0F * size);
			VfxEntity.create(level, VfxType.CLOUD, front, 0xFFFFF4D0, size * 1.6F, 14).spawn();
			for (LivingEntity e : Combat.inCone(p, radius + 1.5, 60)) {
				Combat.hit(p, e, damage, p.getLookAngle(), 9.0F * size, 0.5F, false);
			}
			sound(p, ModSounds.HEAVY_IMPACT, 1.8F, 1.3F);
			for (ServerPlayer near : level.getPlayers(pl -> pl.distanceToSqr(p) < 24 * 24)) {
				Powers.shake(near, 0.4F * size, 12);
			}
		});
	}

	static void pounce(LivingEntity p, float damage) {
		LivingEntity target = Combat.nearestTarget(p, p.getEyePosition().add(p.getLookAngle().scale(6)), 16, null);
		Vec3 dir = target != null ? target.position().subtract(p.position()) : p.getLookAngle().scale(10);
		Combat.launch(p, new Vec3(dir.x * 0.14, 0.8, dir.z * 0.14));
		sound(p, ModSounds.BOSS_ROAR, 1.0F, 1.6F);
		Scheduler.repeat(p, 50, tick -> {
			for (LivingEntity e : lvl(p).getEntitiesOfClass(LivingEntity.class, p.getBoundingBox().inflate(1.2), e -> e != p && e.isAlive())) {
				Combat.hit(p, e, damage, p.getDeltaMovement(), 3.0F, 0.4F, false);
				VfxEntity.create(lvl(p), VfxType.CLAW, e.getBoundingBox().getCenter(), 0xFFFFE070, 2.0F, 10).facing(p.getLookAngle()).spawn();
				return false;
			}
			return !(tick > 4 && p.onGround());
		});
	}

	static void fingerBarrage(LivingEntity p) {
		sound(p, ModSounds.GATLING, 1.0F, 1.6F);
		Scheduler.repeat(p, 30, tick -> {
			if (tick % 2 == 0) {
				Combat.hitCone(p, 5.0, 40, 5.0F, 0.2F, 0.05F, false);
				Vec3 front = p.getEyePosition().add(p.getLookAngle().scale(2.2)).add(right(p).scale((p.getRandom().nextFloat() - 0.5) * 1.6)).add(0, (p.getRandom().nextFloat() - 0.5), 0);
				impact(lvl(p), front, WHITE, 0.6F);
			}
			return true;
		});
	}

	static void claw(LivingEntity p, float damage) {
		ServerLevel level = lvl(p);
		Vec3 front = p.getEyePosition().add(p.getLookAngle().scale(2.2));
		VfxEntity.create(level, VfxType.CLAW, front, Powers.view(p).form() == Form.LUCCI_AWAKENED ? 0xFFFF4A30 : 0xFFFFE070, 2.6F, 12).facing(p.getLookAngle()).spawn();
		Combat.hitCone(p, 5.0, 55, damage, 3.0F, 0.3F, false);
		sound(p, ModSounds.SLASH, 1.4F, 1.4F);
	}

	static void leopardStorm(LivingEntity p) {
		List<LivingEntity> targets = Combat.inSphere(p, p.position(), 20);
		sound(p, ModSounds.BOSS_ROAR, 1.4F, 1.4F);
		int n = 0;
		for (LivingEntity target : targets) {
			if (n >= 6) {
				break;
			}
			final int delay = n * 5;
			n++;
			Scheduler.later(p, delay, () -> {
				if (!target.isAlive()) {
					return;
				}
				Vec3 behind = target.position().add(target.position().subtract(p.position()).multiply(1, 0, 1).normalize().scale(1.6));
				VfxEntity.create(lvl(p), VfxType.DASH_TRAIL, p.position().add(0, 1, 0), 0xFFFF4A30, 1.0F, 10).target(behind.add(0, 1, 0)).owner(p).spawn();
				safeTeleport(p, behind);
				Combat.hit(p, target, 34, target.position().subtract(p.position()), 4.0F, 0.6F, false);
				VfxEntity.create(lvl(p), VfxType.CLAW, target.getBoundingBox().getCenter(), 0xFFFF4A30, 2.4F, 10).facing(p.getLookAngle()).spawn();
				sound(p, ModSounds.SLASH, 1.4F, 1.2F);
			});
		}
		if (targets.isEmpty()) {
			dash(p, 18, 30, 4.0F, 0xFFFF4A30, false);
		}
	}

	static void kamiE(LivingEntity p) {
		Powers.grantDodge(p, 20 * 6);
		VfxEntity.create(lvl(p), VfxType.CLOUD, p.position(), 0xFFFFF0E0, 1.6F, 16).spawn();
		sound(p, ModSounds.WHOOSH, 1.2F, 0.8F);
	}
}
