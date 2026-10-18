package com.tfue.onepiece.client.render;

import com.tfue.onepiece.OnePiece;
import net.fabricmc.fabric.api.client.rendering.v1.ModelLayerRegistry;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.model.geom.builders.CubeDeformation;
import net.minecraft.client.model.geom.builders.LayerDefinition;
import net.minecraft.client.model.player.PlayerModel;

public final class ModModelLayers {
	public static final ModelLayerLocation HAKI = new ModelLayerLocation(OnePiece.id("haki"), "main");
	public static final ModelLayerLocation GHOST = new ModelLayerLocation(OnePiece.id("ghost"), "main");

	private ModModelLayers() {
	}

	public static void register() {
		ModelLayerRegistry.registerModelLayer(HAKI, () -> LayerDefinition.create(PlayerModel.createMesh(new CubeDeformation(0.32F), false), 64, 64));
		ModelLayerRegistry.registerModelLayer(GHOST, () -> LayerDefinition.create(PlayerModel.createMesh(new CubeDeformation(0.0F), false), 64, 64));
	}
}
