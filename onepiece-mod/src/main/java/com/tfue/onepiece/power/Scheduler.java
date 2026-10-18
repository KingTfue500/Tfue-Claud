package com.tfue.onepiece.power;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.entity.LivingEntity;

/** Runs multi-tick moves (Gatling barrages, leaps that land later, charged punches). */
public final class Scheduler {
	private static final List<Task> TASKS = new ArrayList<>();

	private Scheduler() {
	}

	public interface Step {
		/** Called once per tick with ticks elapsed since start. Return false to stop early. */
		boolean run(int tick);
	}

	private static final class Task {
		final LivingEntity owner;
		final int length;
		final Step step;
		int tick;

		Task(LivingEntity owner, int length, Step step) {
			this.owner = owner;
			this.length = length;
			this.step = step;
		}
	}

	/** Repeats {@code step} every tick for {@code length} ticks while the owner is alive. */
	public static void repeat(LivingEntity owner, int length, Step step) {
		TASKS.add(new Task(owner, length, step));
	}

	/** Runs {@code action} once after {@code delay} ticks. */
	public static void later(LivingEntity owner, int delay, Runnable action) {
		TASKS.add(new Task(owner, delay + 1, tick -> {
			if (tick == delay) {
				action.run();
				return false;
			}
			return true;
		}));
	}

	public static void tick(MinecraftServer server) {
		List<Task> snapshot = new ArrayList<>(TASKS);
		TASKS.clear();
		List<Task> keep = new ArrayList<>();
		for (Task task : snapshot) {
			if (!task.owner.isAlive() || task.owner.isRemoved()) {
				continue;
			}
			boolean more = task.step.run(task.tick);
			task.tick++;
			if (more && task.tick < task.length) {
				keep.add(task);
			}
		}
		keep.addAll(TASKS);
		TASKS.clear();
		TASKS.addAll(keep);
	}

	public static void clearAll() {
		TASKS.clear();
	}

	public static void clear(LivingEntity owner) {
		Iterator<Task> it = TASKS.iterator();
		while (it.hasNext()) {
			if (it.next().owner == owner) {
				it.remove();
			}
		}
	}
}
