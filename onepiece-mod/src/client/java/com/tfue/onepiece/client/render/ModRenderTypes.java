package com.tfue.onepiece.client.render;

import com.mojang.blaze3d.pipeline.BlendFunction;
import com.mojang.blaze3d.pipeline.ColorTargetState;
import com.mojang.blaze3d.pipeline.DepthStencilState;
import com.mojang.blaze3d.pipeline.RenderPipeline;
import com.mojang.blaze3d.platform.CompareOp;
import com.tfue.onepiece.OnePiece;
import java.util.function.Function;
import net.minecraft.client.renderer.BindGroupLayouts;
import net.minecraft.client.renderer.RenderPipelines;
import net.minecraft.client.renderer.rendertype.RenderSetup;
import net.minecraft.client.renderer.rendertype.RenderType;
import net.minecraft.client.renderer.rendertype.RenderTypes;
import net.minecraft.resources.Identifier;
import net.minecraft.util.Util;

/** Render types for the mod's effects: an additive glow pass and a soft translucent pass. */
public final class ModRenderTypes {
	/** Additive, unlit, double-sided, does not write depth: fire, energy, lightning, slashes. */
	public static final RenderPipeline GLOW_PIPELINE = RenderPipelines.register(
		RenderPipeline.builder(RenderPipelines.ENTITY_EMISSIVE_SNIPPET)
			.withLocation(OnePiece.id("pipeline/glow"))
			.withShaderDefine("ALPHA_CUTOUT", 0.002F)
			.withBindGroupLayout(BindGroupLayouts.SAMPLER1)
			.withColorTargetState(new ColorTargetState(BlendFunction.LIGHTNING))
			.withCull(false)
			.withDepthStencilState(new DepthStencilState(CompareOp.GREATER_THAN_OR_EQUAL, false))
			.build());

	/** Translucent, double-sided and lit only by the light map (no sun shading): flat sprites look the same from both sides. */
	public static final RenderPipeline FLAT_PIPELINE = RenderPipelines.register(
		RenderPipeline.builder(RenderPipelines.ENTITY_SNIPPET)
			.withLocation(OnePiece.id("pipeline/flat"))
			.withShaderDefine("ALPHA_CUTOUT", 0.002F)
			.withShaderDefine("NO_CARDINAL_LIGHTING")
			.withBindGroupLayout(BindGroupLayouts.SAMPLER1)
			.withColorTargetState(new ColorTargetState(BlendFunction.TRANSLUCENT))
			.withCull(false)
			.build());

	private static final Function<Identifier, RenderType> FLAT = Util.memoize(texture -> RenderType.create("onepiece_flat",
		RenderSetup.builder(FLAT_PIPELINE).withTexture("Sampler0", texture).useLightmap().useOverlay().sortOnUpload().createRenderSetup()));

	private static final Function<Identifier, RenderType> GLOW = Util.memoize(texture -> RenderType.create("onepiece_glow",
		RenderSetup.builder(GLOW_PIPELINE).withTexture("Sampler0", texture).useOverlay().sortOnUpload().createRenderSetup()));

	private ModRenderTypes() {
	}

	public static RenderType glow(Identifier texture) {
		return GLOW.apply(texture);
	}

	/** Unlit (light map only) translucent: smoke, clouds, cloth and other flat or open shapes. */
	public static RenderType flat(Identifier texture) {
		return FLAT.apply(texture);
	}

	/** Lit, translucent, double-sided: solid shapes whose faces wind outward (boxes, tubes, fists). */
	public static RenderType soft(Identifier texture) {
		return RenderTypes.entityTranslucent(texture);
	}

	/** Unlit translucent: things that should stay bright but block what is behind them (fists, katanas). */
	public static RenderType bright(Identifier texture) {
		return RenderTypes.entityTranslucentEmissive(texture);
	}

	public static Identifier tex(String name) {
		return OnePiece.id("textures/vfx/" + name + ".png");
	}
}
