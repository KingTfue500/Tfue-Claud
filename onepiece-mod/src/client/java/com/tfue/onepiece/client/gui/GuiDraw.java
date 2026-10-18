package com.tfue.onepiece.client.gui;

import com.tfue.onepiece.OnePiece;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.client.renderer.RenderPipelines;
import net.minecraft.resources.Identifier;

final class GuiDraw {
	private GuiDraw() {
	}

	static Identifier tex(String path) {
		return OnePiece.id("textures/gui/" + path + ".png");
	}

	/** Draws a whole square or rectangular texture of size texW x texH scaled into w x h. */
	static void image(GuiGraphicsExtractor g, Identifier texture, int x, int y, int w, int h, int texW, int texH, int color) {
		g.blit(RenderPipelines.GUI_TEXTURED, texture, x, y, 0, 0, w, h, texW, texH, texW, texH, color);
	}

	/** Draws the left {@code fraction} of a texture, used for filling bars. */
	static void imagePart(GuiGraphicsExtractor g, Identifier texture, int x, int y, int w, int h, int texW, int texH, float fraction, int color) {
		int cut = Math.max(0, Math.min(w, Math.round(w * fraction)));
		if (cut > 0) {
			g.blit(RenderPipelines.GUI_TEXTURED, texture, x, y, 0, 0, cut, h, Math.round(texW * (cut / (float) w)), texH, texW, texH, color);
		}
	}

	static int alpha(int color, float alpha) {
		int a = (int) (((color >>> 24) & 0xFF) * Math.max(0.0F, Math.min(1.0F, alpha)));
		return (a << 24) | (color & 0xFFFFFF);
	}
}
