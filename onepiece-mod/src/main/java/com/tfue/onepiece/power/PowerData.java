package com.tfue.onepiece.power;

import com.mojang.serialization.Codec;
import com.mojang.serialization.codecs.RecordCodecBuilder;
import java.util.HashMap;
import java.util.Map;
import net.minecraft.network.RegistryFriendlyByteBuf;
import net.minecraft.network.codec.ByteBufCodecs;
import net.minecraft.network.codec.StreamCodec;

/**
 * Everything the mod knows about one player's powers. Immutable: every change makes a copy,
 * which the attachment system then saves and syncs to every client that can see the player.
 */
public record PowerData(
	int owned,
	Fighter fighter,
	Form form,
	float stamina,
	boolean armament,
	boolean observation,
	boolean infinite,
	Anim anim,
	long animStart,
	int selected,
	Map<String, Long> cooldowns,
	long giantUntil
) {
	public static final float MAX_STAMINA = 100.0F;
	public static final PowerData EMPTY = new PowerData(0, Fighter.NONE, Form.BASE_LUFFY, MAX_STAMINA, false, false, false, Anim.NONE, 0L, 0, Map.of(), 0L);

	public static final Codec<PowerData> CODEC = RecordCodecBuilder.create(i -> i.group(
			Codec.INT.optionalFieldOf("owned", 0).forGetter(PowerData::owned),
			Codec.INT.xmap(Fighter::byId, Fighter::ordinal).optionalFieldOf("fighter", Fighter.NONE).forGetter(PowerData::fighter),
			Codec.INT.xmap(Form::byId, Form::ordinal).optionalFieldOf("form", Form.BASE_LUFFY).forGetter(PowerData::form),
			Codec.FLOAT.optionalFieldOf("stamina", MAX_STAMINA).forGetter(PowerData::stamina),
			Codec.BOOL.optionalFieldOf("armament", false).forGetter(PowerData::armament),
			Codec.BOOL.optionalFieldOf("observation", false).forGetter(PowerData::observation),
			Codec.BOOL.optionalFieldOf("infinite", false).forGetter(PowerData::infinite),
			Codec.INT.optionalFieldOf("selected", 0).forGetter(PowerData::selected)
		).apply(i, (owned, fighter, form, stamina, armament, observation, infinite, selected) ->
			new PowerData(owned, fighter, form, stamina, armament, observation, infinite, Anim.NONE, 0L, selected, Map.of(), 0L)));

	public static final StreamCodec<RegistryFriendlyByteBuf, PowerData> STREAM_CODEC = StreamCodec.of(PowerData::write, PowerData::read);

	private static void write(RegistryFriendlyByteBuf buf, PowerData data) {
		buf.writeVarInt(data.owned);
		buf.writeVarInt(data.fighter.ordinal());
		buf.writeVarInt(data.form.ordinal());
		buf.writeFloat(data.stamina);
		buf.writeBoolean(data.armament);
		buf.writeBoolean(data.observation);
		buf.writeBoolean(data.infinite);
		buf.writeVarInt(data.anim.ordinal());
		buf.writeVarLong(data.animStart);
		buf.writeVarInt(data.selected);
		buf.writeVarInt(data.cooldowns.size());
		data.cooldowns.forEach((id, until) -> {
			ByteBufCodecs.STRING_UTF8.encode(buf, id);
			buf.writeVarLong(until);
		});
		buf.writeVarLong(data.giantUntil);
	}

	private static PowerData read(RegistryFriendlyByteBuf buf) {
		int owned = buf.readVarInt();
		Fighter fighter = Fighter.byId(buf.readVarInt());
		Form form = Form.byId(buf.readVarInt());
		float stamina = buf.readFloat();
		boolean armament = buf.readBoolean();
		boolean observation = buf.readBoolean();
		boolean infinite = buf.readBoolean();
		Anim anim = Anim.byId(buf.readVarInt());
		long animStart = buf.readVarLong();
		int selected = buf.readVarInt();
		int count = buf.readVarInt();
		Map<String, Long> cooldowns = new HashMap<>();
		for (int n = 0; n < count; n++) {
			cooldowns.put(ByteBufCodecs.STRING_UTF8.decode(buf), buf.readVarLong());
		}
		long giantUntil = buf.readVarLong();
		return new PowerData(owned, fighter, form, stamina, armament, observation, infinite, anim, animStart, selected, cooldowns, giantUntil);
	}

	public boolean owns(Fighter f) {
		return (owned & f.bit()) != 0;
	}

	public boolean active() {
		return fighter != Fighter.NONE;
	}

	public long cooldownUntil(String moveId) {
		return cooldowns.getOrDefault(moveId, 0L);
	}

	public float animProgress(float time) {
		if (anim == Anim.NONE) {
			return -1.0F;
		}
		float progress = (time - animStart) / anim.duration;
		return progress >= 0.0F && progress <= 1.0F ? progress : -1.0F;
	}

	public PowerData withOwned(int owned) {
		return new PowerData(owned, fighter, form, stamina, armament, observation, infinite, anim, animStart, selected, cooldowns, giantUntil);
	}

	public PowerData withFighter(Fighter fighter) {
		return new PowerData(owned | fighter.bit(), fighter, Form.base(fighter), stamina, armament, observation, infinite, Anim.NONE, 0L, 0, cooldowns, 0L);
	}

	public PowerData withForm(Form form) {
		return new PowerData(owned, fighter, form, stamina, armament, observation, infinite, anim, animStart, 0, cooldowns, giantUntil);
	}

	public PowerData withStamina(float stamina) {
		return new PowerData(owned, fighter, form, Math.max(0.0F, Math.min(MAX_STAMINA, stamina)), armament, observation, infinite, anim, animStart, selected, cooldowns, giantUntil);
	}

	public PowerData withHaki(boolean armament, boolean observation) {
		return new PowerData(owned, fighter, form, stamina, armament, observation, infinite, anim, animStart, selected, cooldowns, giantUntil);
	}

	public PowerData withInfinite(boolean infinite) {
		return new PowerData(owned, fighter, form, stamina, armament, observation, infinite, anim, animStart, selected, cooldowns, giantUntil);
	}

	public PowerData withAnim(Anim anim, long start) {
		return new PowerData(owned, fighter, form, stamina, armament, observation, infinite, anim, start, selected, cooldowns, giantUntil);
	}

	public PowerData withSelected(int selected) {
		return new PowerData(owned, fighter, form, stamina, armament, observation, infinite, anim, animStart, selected, cooldowns, giantUntil);
	}

	public PowerData withCooldown(String moveId, long until) {
		Map<String, Long> map = new HashMap<>(cooldowns);
		map.put(moveId, until);
		return new PowerData(owned, fighter, form, stamina, armament, observation, infinite, anim, animStart, selected, map, giantUntil);
	}

	public PowerData clearCooldowns() {
		return new PowerData(owned, fighter, form, stamina, armament, observation, infinite, anim, animStart, selected, Map.of(), giantUntil);
	}

	public PowerData withGiantUntil(long giantUntil) {
		return new PowerData(owned, fighter, form, stamina, armament, observation, infinite, anim, animStart, selected, cooldowns, giantUntil);
	}
}
