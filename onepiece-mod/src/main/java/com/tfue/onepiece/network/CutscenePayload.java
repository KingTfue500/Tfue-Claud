package com.tfue.onepiece.network;

import com.tfue.onepiece.OnePiece;
import net.minecraft.network.RegistryFriendlyByteBuf;
import net.minecraft.network.codec.ByteBufCodecs;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;

/** Server to client: play the transformation cutscene for {@code entityId} entering {@code form}. */
public record CutscenePayload(int entityId, int form) implements CustomPacketPayload {
	public static final Type<CutscenePayload> TYPE = new Type<>(OnePiece.id("cutscene"));
	public static final StreamCodec<RegistryFriendlyByteBuf, CutscenePayload> CODEC = StreamCodec.composite(
		ByteBufCodecs.VAR_INT, CutscenePayload::entityId,
		ByteBufCodecs.VAR_INT, CutscenePayload::form,
		CutscenePayload::new
	);

	@Override
	public Type<? extends CustomPacketPayload> type() {
		return TYPE;
	}
}
