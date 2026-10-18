package com.tfue.onepiece.client.render;

import com.tfue.onepiece.OnePiece;
import com.tfue.onepiece.power.Form;
import java.util.EnumMap;
import java.util.Map;
import net.minecraft.core.ClientAsset;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.player.PlayerModelType;
import net.minecraft.world.entity.player.PlayerSkin;

/** One hand-made skin per form: textures/entity/skin/<form>.png */
public final class Skins {
	private static final Map<Form, ClientAsset.ResourceTexture> TEXTURES = new EnumMap<>(Form.class);

	private Skins() {
	}

	public static Identifier texture(Form form) {
		return asset(form).texturePath();
	}

	private static ClientAsset.ResourceTexture asset(Form form) {
		return TEXTURES.computeIfAbsent(form, f -> {
			Identifier path = OnePiece.id("textures/entity/skin/" + f.id() + ".png");
			return new ClientAsset.ResourceTexture(OnePiece.id("skin/" + f.id()), path);
		});
	}

	public static PlayerSkin forForm(Form form, PlayerSkin original) {
		return new PlayerSkin(asset(form), original.cape(), original.elytra(), PlayerModelType.WIDE, false);
	}
}
