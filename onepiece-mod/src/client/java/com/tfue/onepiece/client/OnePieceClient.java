package com.tfue.onepiece.client;

import com.tfue.onepiece.OnePiece;
import com.tfue.onepiece.client.gui.PowerHud;
import com.tfue.onepiece.client.render.FormLayer;
import com.tfue.onepiece.client.render.ModModelLayers;
import com.tfue.onepiece.client.render.ModRenderTypes;
import com.tfue.onepiece.client.render.VfxRenderer;
import com.tfue.onepiece.client.render.boss.BossRenderer;
import com.tfue.onepiece.network.CutscenePayload;
import com.tfue.onepiece.network.ShakePayload;
import com.tfue.onepiece.power.Form;
import com.tfue.onepiece.registry.ModEntities;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.LivingEntityRenderLayerRegistrationCallback;
import net.fabricmc.fabric.api.client.rendering.v1.hud.HudElementRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.hud.VanillaHudElements;
import net.minecraft.client.Minecraft;
import net.minecraft.client.model.player.PlayerModel;
import net.minecraft.client.renderer.entity.player.AvatarRenderer;
import net.minecraft.client.renderer.entity.state.AvatarRenderState;
import net.minecraft.world.entity.EntityTypes;

public class OnePieceClient implements ClientModInitializer {
	@Override
	@SuppressWarnings("unchecked")
	public void onInitializeClient() {
		ModRenderTypes.glow(ModRenderTypes.tex("glow"));
		ModModelLayers.register();
		ClientInput.init();

		EntityRendererRegistry.register(ModEntities.VFX, VfxRenderer::new);
		EntityRendererRegistry.register(ModEntities.KAIDO, BossRenderer::new);
		EntityRendererRegistry.register(ModEntities.KATAKURI, BossRenderer::new);
		EntityRendererRegistry.register(ModEntities.LUCCI, BossRenderer::new);

		LivingEntityRenderLayerRegistrationCallback.EVENT.register((type, renderer, helper, context) -> {
			if (type == EntityTypes.PLAYER && renderer instanceof AvatarRenderer<?> avatar) {
				helper.register(new FormLayer((AvatarRenderer<net.minecraft.client.player.AbstractClientPlayer>) avatar, context.getModelSet()));
			}
		});

		HudElementRegistry.attachElementAfter(VanillaHudElements.HOTBAR, OnePiece.id("powers"), PowerHud::extract);

		ClientPlayNetworking.registerGlobalReceiver(ShakePayload.TYPE, (payload, context) -> CameraShake.start(payload.strength(), payload.ticks()));
		ClientPlayNetworking.registerGlobalReceiver(CutscenePayload.TYPE, (payload, context) -> Cutscene.play(payload.entityId(), Form.byId(payload.form())));

		ClientTickEvents.END_CLIENT_TICK.register(client -> {
			CameraShake.tick();
			ClientInput.tick(client);
		});
	}
}
