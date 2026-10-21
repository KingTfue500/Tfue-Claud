package com.tfue.onepiece.network;

import com.tfue.onepiece.OnePiece;
import net.minecraft.network.RegistryFriendlyByteBuf;
import net.minecraft.network.codec.ByteBufCodecs;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;

/** Client to server: the player pressed one of the One Piece keys. */
public record ActionPayload(int action, int value) implements CustomPacketPayload {
	public static final int USE_MOVE = 0;
	public static final int SELECT_MOVE = 1;
	public static final int SELECT_FORM = 2;
	public static final int ARMAMENT = 3;
	public static final int OBSERVATION = 4;
	public static final int CONQUEROR = 5;
	public static final int CYCLE_FIGHTER = 6;
	public static final int AIR_JUMP = 7;
	public static final int CAST_MOVE = 8;

	public static final Type<ActionPayload> TYPE = new Type<>(OnePiece.id("action"));
	public static final StreamCodec<RegistryFriendlyByteBuf, ActionPayload> CODEC = StreamCodec.composite(
		ByteBufCodecs.VAR_INT, ActionPayload::action,
		ByteBufCodecs.VAR_INT, ActionPayload::value,
		ActionPayload::new
	);

	@Override
	public Type<? extends CustomPacketPayload> type() {
		return TYPE;
	}
}
