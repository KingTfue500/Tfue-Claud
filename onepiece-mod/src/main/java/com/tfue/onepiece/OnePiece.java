package com.tfue.onepiece;

import com.tfue.onepiece.command.OnePieceCommand;
import com.tfue.onepiece.entity.BossEntity;
import com.tfue.onepiece.network.ActionPayload;
import com.tfue.onepiece.network.ShakePayload;
import com.tfue.onepiece.power.Powers;
import com.tfue.onepiece.power.Scheduler;
import com.tfue.onepiece.registry.ModEntities;
import com.tfue.onepiece.registry.ModItems;
import com.tfue.onepiece.registry.ModSounds;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.entity.event.v1.ServerPlayerEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.networking.v1.PayloadTypeRegistry;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.resources.Identifier;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.Entity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class OnePiece implements ModInitializer {
	public static final String MOD_ID = "onepiece";
	public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

	public static Identifier id(String path) {
		return Identifier.fromNamespaceAndPath(MOD_ID, path);
	}

	public static boolean isBoss(Entity entity) {
		return entity instanceof BossEntity;
	}

	@Override
	public void onInitialize() {
		ModSounds.init();
		ModItems.init();
		ModEntities.init();
		Powers.init();

		PayloadTypeRegistry.serverboundPlay().register(ActionPayload.TYPE, ActionPayload.CODEC);
		PayloadTypeRegistry.clientboundPlay().register(ShakePayload.TYPE, ShakePayload.CODEC);
		PayloadTypeRegistry.clientboundPlay().register(com.tfue.onepiece.network.CutscenePayload.TYPE, com.tfue.onepiece.network.CutscenePayload.CODEC);
		ServerPlayNetworking.registerGlobalReceiver(ActionPayload.TYPE, (payload, context) -> Powers.handle(context.player(), payload));

		ServerTickEvents.END_SERVER_TICK.register(server -> {
			Scheduler.tick(server);
			for (ServerPlayer player : server.getPlayerList().getPlayers()) {
				Powers.tick(player);
			}
		});
		ServerPlayerEvents.AFTER_RESPAWN.register((oldPlayer, newPlayer, alive) -> Powers.onRespawn(newPlayer));
		CommandRegistrationCallback.EVENT.register((dispatcher, registries, selection) -> OnePieceCommand.register(dispatcher));

		LOGGER.info("One Piece: Straw Hat Powers loaded. Set sail!");
	}
}
