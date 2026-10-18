package com.tfue.onepiece.network;

import com.tfue.onepiece.OnePiece;
import net.minecraft.network.RegistryFriendlyByteBuf;
import net.minecraft.network.codec.ByteBufCodecs;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;

/** Server to client: shake the camera (Conqueror's Haki, Bajrang Gun, boss slams). */
public record ShakePayload(float strength, int ticks) implements CustomPacketPayload {
	public static final Type<ShakePayload> TYPE = new Type<>(OnePiece.id("shake"));
	public static final StreamCodec<RegistryFriendlyByteBuf, ShakePayload> CODEC = StreamCodec.composite(
		ByteBufCodecs.FLOAT, ShakePayload::strength,
		ByteBufCodecs.VAR_INT, ShakePayload::ticks,
		ShakePayload::new
	);

	@Override
	public Type<? extends CustomPacketPayload> type() {
		return TYPE;
	}
}
