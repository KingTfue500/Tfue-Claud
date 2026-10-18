package com.tfue.onepiece.client;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.tfue.onepiece.OnePiece;
import java.io.IOException;
import java.io.Reader;
import java.io.Writer;
import java.nio.file.Files;
import java.nio.file.Path;
import net.fabricmc.loader.api.FabricLoader;

/** config/onepiece-client.json: lets players switch the cinematics off. */
public final class ClientConfig {
	private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
	private static Values values = new Values();

	private static final class Values {
		boolean transformationCutscenes = true;
		boolean skillCutscenes = true;
		boolean cameraShake = true;
	}

	private ClientConfig() {
	}

	public static boolean cutscenes() {
		return values.transformationCutscenes;
	}

	public static boolean skillCutscenes() {
		return values.skillCutscenes;
	}

	public static boolean cameraShake() {
		return values.cameraShake;
	}

	public static void load() {
		Path path = FabricLoader.getInstance().getConfigDir().resolve("onepiece-client.json");
		if (Files.exists(path)) {
			try (Reader reader = Files.newBufferedReader(path)) {
				Values read = GSON.fromJson(reader, Values.class);
				if (read != null) {
					values = read;
				}
			} catch (IOException | RuntimeException e) {
				OnePiece.LOGGER.warn("Could not read {}, using defaults", path, e);
			}
		}
		try (Writer writer = Files.newBufferedWriter(path)) {
			GSON.toJson(values, writer);
		} catch (IOException e) {
			OnePiece.LOGGER.warn("Could not write {}", path, e);
		}
	}
}
