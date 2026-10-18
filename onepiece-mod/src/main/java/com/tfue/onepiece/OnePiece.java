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
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
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

	/** First join: a short guide to getting powers and the controls. */
	private static void welcome(ServerPlayer player) {
		if (player.entityTags().contains("onepiece_welcomed")) {
			return;
		}
		player.addTag("onepiece_welcomed");
		player.sendSystemMessage(Component.translatable("message.onepiece.welcome.title").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD));
		for (int n = 1; n <= 4; n++) {
			player.sendSystemMessage(Component.translatable("message.onepiece.welcome." + n).withStyle(ChatFormatting.YELLOW));
		}
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
		ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> welcome(handler.getPlayer()));
		CommandRegistrationCallback.EVENT.register((dispatcher, registries, selection) -> OnePieceCommand.register(dispatcher));

		LOGGER.info("One Piece: Straw Hat Powers loaded. Set sail!");
	}
}
