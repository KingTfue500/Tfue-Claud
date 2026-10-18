package com.tfue.onepiece.client.gui;

import com.mojang.blaze3d.platform.InputConstants;
import com.tfue.onepiece.client.ClientInput;
import com.tfue.onepiece.network.ActionPayload;
import com.tfue.onepiece.power.Form;
import com.tfue.onepiece.power.Move;
import com.tfue.onepiece.power.Moves;
import com.tfue.onepiece.power.PowerData;
import com.tfue.onepiece.power.Powers;
import java.util.ArrayList;
import java.util.List;
import net.fabricmc.fabric.api.client.keymapping.v1.KeyMappingHelper;
import net.minecraft.ChatFormatting;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.input.MouseButtonEvent;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import net.minecraft.util.Mth;

/**
 * Radial menu. Hold the key, point at a skill (or form) with the mouse and let go to pick it;
 * click to pick and use it right away.
 */
public class MoveWheelScreen extends Screen {
	private static final Identifier RING = GuiDraw.tex("wheel_ring");
	private static final Identifier SLOT = GuiDraw.tex("slot");
	private static final Identifier SLOT_HOVER = GuiDraw.tex("slot_hover");
	private static final Identifier CENTER = GuiDraw.tex("wheel_center");

	private final boolean forms;
	private final KeyMapping key;
	private final List<Entry> entries = new ArrayList<>();
	private int hovered = -1;
	private float open;

	private record Entry(Component name, Identifier icon, int color, Component line1, Component line2, int value, boolean locked, float cooldown) {
	}

	public MoveWheelScreen(boolean forms, KeyMapping key) {
		super(Component.translatable(forms ? "gui.onepiece.form_wheel" : "gui.onepiece.move_wheel"));
		this.forms = forms;
		this.key = key;
	}

	@Override
	protected void init() {
		this.entries.clear();
		if (this.minecraft == null || this.minecraft.player == null) {
			return;
		}
		PowerData data = Powers.get(this.minecraft.player);
		long now = this.minecraft.level != null ? this.minecraft.level.getGameTime() : 0;
		if (this.forms) {
			for (Form form : Form.of(data.fighter())) {
				boolean current = form == data.form();
				Component cost = form.isBase() ? Component.translatable("gui.onepiece.base_form") : Component.translatable("gui.onepiece.cost", form.cost);
				Component drain = form.isBase() ? Component.empty() : Component.translatable("gui.onepiece.drain", String.format("%.1f", form.drain));
				this.entries.add(new Entry(Component.translatable(form.translationKey()), GuiDraw.tex("forms/" + form.id()), form.color,
					current ? Component.translatable("gui.onepiece.active").withStyle(ChatFormatting.GREEN) : cost, drain, form.ordinal(), current, 0.0F));
			}
		} else {
			List<Move> moves = Moves.forForm(data.form());
			for (int n = 0; n < moves.size(); n++) {
				Move move = moves.get(n);
				long left = data.infinite() ? 0 : data.cooldownUntil(move.id()) - now;
				float cd = left > 0 ? left / (float) move.cooldown() : 0.0F;
				this.entries.add(new Entry(Component.translatable(move.translationKey()), GuiDraw.tex("icons/" + move.icon().texture()), data.form().color,
					Component.translatable("gui.onepiece.cost", move.cost()),
					Component.translatable("gui.onepiece.cooldown", String.format("%.1f", move.cooldown() / 20.0F)), n, false, cd));
			}
		}
	}

	@Override
	public boolean isPauseScreen() {
		return false;
	}

	@Override
	public void tick() {
		super.tick();
		InputConstants.Key bound = KeyMappingHelper.getBoundKeyOf(this.key);
		boolean held = switch (bound.getType()) {
			case KEYSYM -> InputConstants.isKeyDown(this.minecraft.getWindow(), bound.getValue());
			case MOUSE -> org.lwjgl.glfw.GLFW.glfwGetMouseButton(this.minecraft.getWindow().handle(), bound.getValue()) == org.lwjgl.glfw.GLFW.GLFW_PRESS;
			default -> false;
		};
		if (!held) {
			this.choose(false);
		}
	}

	private void choose(boolean cast) {
		if (this.hovered >= 0 && this.hovered < this.entries.size()) {
			Entry entry = this.entries.get(this.hovered);
			if (this.forms) {
				if (!entry.locked()) {
					ClientInput.send(ActionPayload.SELECT_FORM, entry.value());
				}
			} else {
				ClientInput.send(cast ? ActionPayload.CAST_MOVE : ActionPayload.SELECT_MOVE, entry.value());
			}
		}
		this.onClose();
	}

	@Override
	public boolean mouseClicked(MouseButtonEvent event, boolean doubleClick) {
		if (event.button() == 0) {
			this.choose(true);
			return true;
		}
		if (event.button() == 1) {
			this.onClose();
			return true;
		}
		return super.mouseClicked(event, doubleClick);
	}

	@Override
	public void extractBackground(GuiGraphicsExtractor g, int mouseX, int mouseY, float a) {
		g.fillGradient(0, 0, this.width, this.height, 0x70000000, 0xA0000000);
	}

	@Override
	public void extractRenderState(GuiGraphicsExtractor g, int mouseX, int mouseY, float a) {
		super.extractRenderState(g, mouseX, mouseY, a);
		this.open = Math.min(1.0F, this.open + a * 0.25F + 0.02F);
		float ease = 1.0F - (1.0F - this.open) * (1.0F - this.open);
		int cx = this.width / 2;
		int cy = this.height / 2;
		int count = this.entries.size();
		if (count == 0) {
			g.centeredText(this.font, Component.translatable("message.onepiece.no_power"), cx, cy, 0xFFFFFFFF);
			return;
		}
		int ringSize = (int) (232 * (0.8F + 0.2F * ease));
		GuiDraw.image(g, RING, cx - ringSize / 2, cy - ringSize / 2, ringSize, ringSize, 512, 512, GuiDraw.alpha(0xFFFFFFFF, ease));

		double dx = mouseX - cx;
		double dy = mouseY - cy;
		if (dx * dx + dy * dy > 18 * 18) {
			double angle = Math.atan2(dy, dx) + Math.PI / 2;
			if (angle < 0) {
				angle += Math.PI * 2;
			}
			this.hovered = (int) Math.floor((angle / (Math.PI * 2)) * count + 0.5) % count;
		}
		float radius = 86 * ease;
		for (int n = 0; n < count; n++) {
			Entry entry = this.entries.get(n);
			double angle = n / (double) count * Math.PI * 2 - Math.PI / 2;
			int x = cx + (int) Math.round(Math.cos(angle) * radius);
			int y = cy + (int) Math.round(Math.sin(angle) * radius);
			boolean hover = n == this.hovered;
			int size = hover ? 40 : 32;
			int color = entry.locked() ? 0xFF7FFF9F : entry.color();
			GuiDraw.image(g, hover ? SLOT_HOVER : SLOT, x - size / 2, y - size / 2, size, size, 128, 128, hover ? (0xFF000000 | color) : 0xE0FFFFFF);
			int icon = hover ? 26 : 20;
			int iconColor = entry.cooldown() > 0 ? 0xFF606060 : 0xFF000000 | brighten(color);
			GuiDraw.image(g, entry.icon(), x - icon / 2, y - icon / 2, icon, icon, 64, 64, iconColor);
			if (entry.cooldown() > 0) {
				int bar = (int) (size * 0.7F * entry.cooldown());
				g.fill(x - size * 7 / 20, y + size / 2 - 5, x - size * 7 / 20 + bar, y + size / 2 - 3, 0xFFE04040);
			}
		}
		GuiDraw.image(g, CENTER, cx - 44, cy - 44, 88, 88, 256, 256, GuiDraw.alpha(0xFFFFFFFF, ease));
		if (this.hovered >= 0 && this.hovered < count) {
			Entry entry = this.entries.get(this.hovered);
			Component name = entry.name().copy().withStyle(ChatFormatting.BOLD);
			this.centered(g, name, cx, cy - 14, 120, 0xFF000000 | brighten(entry.color()));
			this.centered(g, entry.line1(), cx, cy - 1, 80, 0xFFE8E8E8);
			this.centered(g, entry.line2(), cx, cy + 10, 80, 0xFFB0B0B0);
		} else {
			g.centeredText(this.font, this.title, cx, cy - 4, 0xFFFFFFFF);
		}
		g.centeredText(this.font, Component.translatable(this.forms ? "gui.onepiece.form_hint" : "gui.onepiece.move_hint"), cx, cy + ringSize / 2 + 8, 0xFFC0C0C0);
	}

	/** Centered text that shrinks to fit {@code maxWidth}. */
	private void centered(GuiGraphicsExtractor g, Component text, int x, int y, int maxWidth, int color) {
		int width = this.font.width(text);
		if (width <= maxWidth) {
			g.centeredText(this.font, text, x, y, color);
			return;
		}
		float scale = maxWidth / (float) width;
		g.pose().pushMatrix();
		g.pose().translate(x, y + (1.0F - scale) * 4.0F);
		g.pose().scale(scale, scale);
		g.centeredText(this.font, text, 0, 0, color);
		g.pose().popMatrix();
	}

	private static int brighten(int color) {
		int r = Mth.clamp(((color >> 16) & 0xFF) + 40, 0, 255);
		int gr = Mth.clamp(((color >> 8) & 0xFF) + 40, 0, 255);
		int b = Mth.clamp((color & 0xFF) + 40, 0, 255);
		return (r << 16) | (gr << 8) | b;
	}
}
