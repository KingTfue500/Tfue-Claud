package com.tfue.onepiece.client.gui;

import com.tfue.onepiece.client.Cutscene;
import com.tfue.onepiece.power.Form;
import com.tfue.onepiece.power.Move;
import com.tfue.onepiece.power.Moves;
import com.tfue.onepiece.power.PowerData;
import com.tfue.onepiece.power.Powers;
import java.util.List;
import net.minecraft.ChatFormatting;
import net.minecraft.client.DeltaTracker;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import net.minecraft.util.Mth;

/** Fighter emblem, form, stamina bar, Haki lights and the selected skill, plus the cutscene overlay. */
public final class PowerHud {
	private static final Identifier FRAME = GuiDraw.tex("hud_frame");
	private static final Identifier BAR = GuiDraw.tex("stamina_bar");
	private static final Identifier SLOT = GuiDraw.tex("slot_hover");
	private static float shownStamina = -1;

	private PowerHud() {
	}

	public static void extract(GuiGraphicsExtractor g, DeltaTracker delta) {
		Minecraft mc = Minecraft.getInstance();
		if (mc.player == null) {
			return;
		}
		float partial = delta.getGameTimeDeltaPartialTick(true);
		if (Cutscene.active()) {
			cutscene(g, mc, partial);
			return;
		}
		PowerData data = Powers.get(mc.player);
		if (!data.active()) {
			return;
		}
		int w = g.guiWidth();
		int h = g.guiHeight();
		Form form = data.form();
		int color = 0xFF000000 | form.color;

		// Left panel: emblem, form name, stamina, Haki.
		int x = 6;
		int y = h - 52;
		GuiDraw.image(g, FRAME, x, y, 150, 46, 512, 160, 0xF0FFFFFF);
		GuiDraw.image(g, GuiDraw.tex("emblems/" + data.fighter().id()), x + 5, y + 6, 34, 34, 128, 128, 0xFFFFFFFF);
		g.text(mc.font, Component.translatable(form.translationKey()).withStyle(ChatFormatting.BOLD), x + 44, y + 7, color, true);
		float target = data.stamina() / PowerData.MAX_STAMINA;
		shownStamina = shownStamina < 0 ? target : Mth.lerp(0.25F, shownStamina, target);
		GuiDraw.image(g, BAR, x + 44, y + 19, 98, 8, 256, 32, 0xFF303030);
		GuiDraw.imagePart(g, BAR, x + 44, y + 19, 98, 8, 256, 32, shownStamina, data.stamina() < 20 && (mc.player.tickCount / 4) % 2 == 0 ? 0xFFFF4040 : color);
		String stamina = data.infinite() ? "∞" : Integer.toString(Math.round(data.stamina()));
		g.text(mc.font, stamina, x + 146 - mc.font.width(stamina), y + 30, 0xFFE0E0E0, true);
		haki(g, x + 44, y + 30, "armament", data.armament(), 0xFFB040FF);
		haki(g, x + 58, y + 30, "observation", data.observation(), 0xFF40D0FF);
		haki(g, x + 72, y + 30, "conqueror", false, 0xFFE0102A);

		// Right panel: selected skill and its cooldown.
		List<Move> moves = Moves.forForm(form);
		if (!moves.isEmpty()) {
			Move move = moves.get(Math.min(data.selected(), moves.size() - 1));
			long now = mc.level != null ? mc.level.getGameTime() : 0;
			long left = data.infinite() ? 0 : data.cooldownUntil(move.id()) - now;
			int rx = w - 156;
			GuiDraw.image(g, FRAME, rx, y, 150, 46, 512, 160, 0xF0FFFFFF);
			GuiDraw.image(g, SLOT, rx + 4, y + 5, 36, 36, 128, 128, color);
			GuiDraw.image(g, GuiDraw.tex("icons/" + move.icon().texture()), rx + 10, y + 11, 24, 24, 64, 64, left > 0 ? 0xFF707070 : 0xFFFFFFFF);
			g.text(mc.font, Component.translatable(move.translationKey()).withStyle(ChatFormatting.BOLD), rx + 44, y + 9, 0xFFFFFFFF, true);
			if (left > 0) {
				float frac = left / (float) move.cooldown();
				g.fill(rx + 44, y + 22, rx + 44 + (int) (98 * frac), y + 25, 0xFFE04040);
				g.text(mc.font, String.format("%.1fs", left / 20.0F), rx + 44, y + 29, 0xFFFF8080, true);
			} else {
				g.text(mc.font, Component.translatable("gui.onepiece.ready"), rx + 44, y + 29, 0xFF80FF80, true);
			}
			g.text(mc.font, Component.translatable("gui.onepiece.cost_short", move.cost()), rx + 146 - mc.font.width(Component.translatable("gui.onepiece.cost_short", move.cost())), y + 29, 0xFFB0B0B0, true);
		}
	}

	private static void haki(GuiGraphicsExtractor g, int x, int y, String type, boolean on, int color) {
		GuiDraw.image(g, GuiDraw.tex("haki/" + type), x, y, 11, 11, 32, 32, on ? 0xFF000000 | color : 0xFF505050);
	}

	private static void cutscene(GuiGraphicsExtractor g, Minecraft mc, float partial) {
		float p = Cutscene.progress(partial);
		Form form = Cutscene.form();
		if (p < 0 || form == null) {
			return;
		}
		int w = g.guiWidth();
		int h = g.guiHeight();
		float bars = Math.min(1.0F, p * 6.0F) * Math.min(1.0F, (1.0F - p) * 6.0F);
		int bar = (int) (h * 0.13F * bars);
		g.fill(0, 0, w, bar, 0xFF000000);
		g.fill(0, h - bar, w, h, 0xFF000000);
		// White flash on the reveal.
		float flash = Math.max(0.0F, 1.0F - Math.abs(p - 0.42F) * 9.0F);
		if (flash > 0) {
			g.fill(0, 0, w, h, GuiDraw.alpha(0xFFFFFFFF, flash * 0.85F));
		}
		// Title card slides in after the flash.
		if (p > 0.45F) {
			float in = Math.min(1.0F, (p - 0.45F) * 5.0F);
			float out = Math.min(1.0F, (1.0F - p) * 8.0F);
			float alpha = in * out;
			int color = 0xFF000000 | form.color;
			Component title = Component.translatable(form.translationKey()).withStyle(ChatFormatting.BOLD);
			Component sub = Component.translatable(form.fighter.translationKey()).withStyle(ChatFormatting.ITALIC);
			int ty = h - bar - 46;
			int slide = (int) ((1.0F - in) * 40);
			g.pose().pushMatrix();
			g.pose().translate(w / 2.0F - slide, ty);
			g.pose().scale(2.6F, 2.6F);
			g.centeredText(mc.font, title, 0, 0, GuiDraw.alpha(color, alpha));
			g.pose().popMatrix();
			g.fill(w / 2 - 90 + slide, ty + 26, w / 2 + 90 + slide, ty + 27, GuiDraw.alpha(color, alpha));
			g.centeredText(mc.font, sub, w / 2 + slide, ty + 31, GuiDraw.alpha(0xFFFFFFFF, alpha));
		}
	}
}
