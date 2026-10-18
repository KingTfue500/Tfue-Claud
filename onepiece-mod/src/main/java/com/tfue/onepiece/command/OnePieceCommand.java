package com.tfue.onepiece.command;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.BoolArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.exceptions.CommandSyntaxException;
import com.mojang.brigadier.suggestion.SuggestionProvider;
import com.tfue.onepiece.power.Fighter;
import com.tfue.onepiece.power.Form;
import com.tfue.onepiece.power.PowerData;
import com.tfue.onepiece.power.Powers;
import com.tfue.onepiece.registry.ModEntities;
import com.tfue.onepiece.registry.ModItems;
import java.util.Arrays;
import java.util.Collection;
import java.util.List;
import net.minecraft.ChatFormatting;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.SharedSuggestionProvider;
import net.minecraft.commands.arguments.EntityArgument;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;

/**
 * /onepiece fighter|unlockall|form|infinite|reset|kit|boss|info
 */
public final class OnePieceCommand {
	private static final SuggestionProvider<CommandSourceStack> FIGHTERS = (ctx, b) ->
		SharedSuggestionProvider.suggest(Arrays.stream(Fighter.PLAYABLE).map(Fighter::id), b);
	private static final SuggestionProvider<CommandSourceStack> FORMS = (ctx, b) ->
		SharedSuggestionProvider.suggest(Arrays.stream(Form.values()).map(Form::id), b);
	private static final SuggestionProvider<CommandSourceStack> MOVES = (ctx, b) ->
		SharedSuggestionProvider.suggest(com.tfue.onepiece.power.Moves.ALL.stream().map(com.tfue.onepiece.power.Move::id), b);
	private static final SuggestionProvider<CommandSourceStack> BOSSES = (ctx, b) ->
		SharedSuggestionProvider.suggest(List.of("kaido", "katakuri", "lucci"), b);

	private OnePieceCommand() {
	}

	public static void register(CommandDispatcher<CommandSourceStack> dispatcher) {
		LiteralArgumentBuilder<CommandSourceStack> root = Commands.literal("onepiece").requires(Commands.hasPermission(Commands.LEVEL_GAMEMASTERS));

		root.then(Commands.literal("fighter")
			.then(Commands.argument("fighter", StringArgumentType.word()).suggests(FIGHTERS)
				.executes(ctx -> fighter(ctx, List.of(ctx.getSource().getPlayerOrException())))
				.then(Commands.argument("targets", EntityArgument.players())
					.executes(ctx -> fighter(ctx, EntityArgument.getPlayers(ctx, "targets"))))));

		root.then(Commands.literal("unlockall")
			.executes(ctx -> unlockAll(ctx.getSource(), List.of(ctx.getSource().getPlayerOrException())))
			.then(Commands.argument("targets", EntityArgument.players())
				.executes(ctx -> unlockAll(ctx.getSource(), EntityArgument.getPlayers(ctx, "targets")))));

		root.then(Commands.literal("form")
			.then(Commands.argument("form", StringArgumentType.word()).suggests(FORMS)
				.executes(ctx -> form(ctx, List.of(ctx.getSource().getPlayerOrException())))
				.then(Commands.argument("targets", EntityArgument.players())
					.executes(ctx -> form(ctx, EntityArgument.getPlayers(ctx, "targets"))))));

		root.then(Commands.literal("infinite")
			.then(Commands.argument("enabled", BoolArgumentType.bool())
				.executes(ctx -> infinite(ctx, List.of(ctx.getSource().getPlayerOrException())))
				.then(Commands.argument("targets", EntityArgument.players())
					.executes(ctx -> infinite(ctx, EntityArgument.getPlayers(ctx, "targets"))))));

		root.then(Commands.literal("reset")
			.executes(ctx -> reset(ctx.getSource(), List.of(ctx.getSource().getPlayerOrException())))
			.then(Commands.argument("targets", EntityArgument.players())
				.executes(ctx -> reset(ctx.getSource(), EntityArgument.getPlayers(ctx, "targets")))));

		root.then(Commands.literal("kit")
			.executes(ctx -> kit(ctx.getSource(), List.of(ctx.getSource().getPlayerOrException())))
			.then(Commands.argument("targets", EntityArgument.players())
				.executes(ctx -> kit(ctx.getSource(), EntityArgument.getPlayers(ctx, "targets")))));

		root.then(Commands.literal("boss")
			.then(Commands.argument("boss", StringArgumentType.word()).suggests(BOSSES)
				.executes(OnePieceCommand::boss)));

		root.then(Commands.literal("cast")
			.then(Commands.argument("skill", StringArgumentType.word()).suggests(MOVES)
				.executes(ctx -> cast(ctx, List.of(ctx.getSource().getPlayerOrException())))
				.then(Commands.argument("targets", EntityArgument.players())
					.executes(ctx -> cast(ctx, EntityArgument.getPlayers(ctx, "targets"))))));

		root.then(Commands.literal("info")
			.executes(ctx -> info(ctx.getSource(), ctx.getSource().getPlayerOrException()))
			.then(Commands.argument("target", EntityArgument.player())
				.executes(ctx -> info(ctx.getSource(), EntityArgument.getPlayer(ctx, "target")))));

		dispatcher.register(root);
	}

	private static Fighter parseFighter(String name) {
		return switch (name) {
			case "luffy" -> Fighter.LUFFY;
			case "zoro" -> Fighter.ZORO;
			case "sanji" -> Fighter.SANJI;
			default -> null;
		};
	}

	private static int fighter(CommandContext<CommandSourceStack> ctx, Collection<ServerPlayer> targets) {
		Fighter fighter = Fighter.byName(StringArgumentType.getString(ctx, "fighter"));
		if (fighter == null) {
			ctx.getSource().sendFailure(Component.translatable("command.onepiece.unknown_fighter"));
			return 0;
		}
		for (ServerPlayer player : targets) {
			Powers.grant(player, fighter, true);
		}
		ctx.getSource().sendSuccess(() -> Component.translatable("command.onepiece.fighter", Component.translatable(fighter.translationKey()), targets.size()), true);
		return targets.size();
	}

	private static int unlockAll(CommandSourceStack source, Collection<ServerPlayer> targets) {
		for (ServerPlayer player : targets) {
			PowerData data = Powers.get(player);
			int all = 0;
			for (Fighter f : Fighter.PLAYABLE) {
				all |= f.bit();
			}
			Fighter active = data.active() ? data.fighter() : Fighter.LUFFY;
			Powers.set(player, data.withOwned(all).withFighter(active).withOwned(all).clearCooldowns().withStamina(PowerData.MAX_STAMINA));
			player.sendSystemMessage(Component.translatable("message.onepiece.unlocked_all").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD));
		}
		source.sendSuccess(() -> Component.translatable("command.onepiece.unlockall", targets.size()), true);
		return targets.size();
	}

	private static int form(CommandContext<CommandSourceStack> ctx, Collection<ServerPlayer> targets) {
		Form form = Form.byName(StringArgumentType.getString(ctx, "form"));
		if (form == null) {
			ctx.getSource().sendFailure(Component.translatable("command.onepiece.unknown_form"));
			return 0;
		}
		for (ServerPlayer player : targets) {
			PowerData data = Powers.get(player);
			if (data.fighter() != form.fighter) {
				Powers.grant(player, form.fighter, false);
			}
			Powers.setForm(player, form, true);
		}
		ctx.getSource().sendSuccess(() -> Component.translatable("command.onepiece.form", Component.translatable(form.translationKey()), targets.size()), true);
		return targets.size();
	}

	private static int infinite(CommandContext<CommandSourceStack> ctx, Collection<ServerPlayer> targets) {
		boolean on = BoolArgumentType.getBool(ctx, "enabled");
		for (ServerPlayer player : targets) {
			Powers.set(player, Powers.get(player).withInfinite(on).clearCooldowns().withStamina(PowerData.MAX_STAMINA));
		}
		ctx.getSource().sendSuccess(() -> Component.translatable(on ? "command.onepiece.infinite_on" : "command.onepiece.infinite_off", targets.size()), true);
		return targets.size();
	}

	private static int reset(CommandSourceStack source, Collection<ServerPlayer> targets) {
		for (ServerPlayer player : targets) {
			Powers.reset(player);
		}
		source.sendSuccess(() -> Component.translatable("command.onepiece.reset", targets.size()), true);
		return targets.size();
	}

	private static int kit(CommandSourceStack source, Collection<ServerPlayer> targets) {
		for (ServerPlayer player : targets) {
			for (Item item : ModItems.TAB_ORDER) {
				ItemStack stack = new ItemStack(item);
				if (!player.getInventory().add(stack)) {
					player.drop(stack, false);
				}
			}
		}
		source.sendSuccess(() -> Component.translatable("command.onepiece.kit", targets.size()), true);
		return targets.size();
	}

	private static int boss(CommandContext<CommandSourceStack> ctx) throws CommandSyntaxException {
		String name = StringArgumentType.getString(ctx, "boss");
		EntityType<? extends Mob> type = switch (name) {
			case "kaido" -> ModEntities.KAIDO;
			case "katakuri" -> ModEntities.KATAKURI;
			case "lucci" -> ModEntities.LUCCI;
			default -> null;
		};
		if (type == null) {
			ctx.getSource().sendFailure(Component.translatable("command.onepiece.unknown_boss"));
			return 0;
		}
		ServerLevel level = ctx.getSource().getLevel();
		Mob mob = type.create(level, EntitySpawnReason.COMMAND);
		if (mob == null) {
			return 0;
		}
		var pos = ctx.getSource().getPosition();
		var look = ctx.getSource().getRotation();
		double yaw = Math.toRadians(look.y);
		mob.snapTo(pos.x - Math.sin(yaw) * 8, pos.y, pos.z + Math.cos(yaw) * 8, (float) (look.y + 180), 0);
		level.addFreshEntity(mob);
		ctx.getSource().sendSuccess(() -> Component.translatable("command.onepiece.boss", mob.getDisplayName()), true);
		return 1;
	}

	/** Uses any skill right away, switching to its fighter and form first. Skips cost and cooldown. */
	private static int cast(CommandContext<CommandSourceStack> ctx, Collection<ServerPlayer> targets) {
		com.tfue.onepiece.power.Move move = com.tfue.onepiece.power.Moves.byId(StringArgumentType.getString(ctx, "skill"));
		if (move == null) {
			ctx.getSource().sendFailure(Component.translatable("command.onepiece.unknown_skill"));
			return 0;
		}
		for (ServerPlayer player : targets) {
			PowerData data = Powers.get(player);
			if (data.fighter() != move.form().fighter) {
				Powers.grant(player, move.form().fighter, false);
			}
			if (Powers.get(player).form() != move.form()) {
				Powers.setForm(player, move.form(), true);
			}
			Powers.set(player, Powers.get(player).withAnim(move.anim(), player.level().getGameTime()));
			move.action().run(player);
		}
		ctx.getSource().sendSuccess(() -> Component.translatable("command.onepiece.cast", Component.translatable(move.translationKey()), targets.size()), true);
		return targets.size();
	}

	private static int info(CommandSourceStack source, ServerPlayer player) {
		PowerData data = Powers.get(player);
		source.sendSuccess(() -> Component.translatable("command.onepiece.info", player.getDisplayName(),
			Component.translatable(data.fighter().translationKey()), Component.translatable(data.form().translationKey()),
			Math.round(data.stamina()), data.infinite()), false);
		return 1;
	}
}
