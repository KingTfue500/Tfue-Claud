import { world, system, ItemStack } from "@minecraft/server";

const HIGH_TICKS = 20 * 90; // one joint = 90 seconds high
const GRASS = ["minecraft:short_grass", "minecraft:tall_grass", "minecraft:fern"];

// playerId -> { until: tick, level: joints smoked this high }
const highs = new Map();

// 10% chance for grass to drop a weed bud
world.afterEvents.playerBreakBlock.subscribe(({ block, brokenBlockPermutation }) => {
  if (!GRASS.includes(brokenBlockPermutation.type.id) || Math.random() > 0.1) return;
  block.dimension.spawnItem(new ItemStack("weed:bud", 1), block.center());
});

world.afterEvents.itemCompleteUse.subscribe(({ itemStack, source: player }) => {
  if (itemStack.typeId !== "weed:joint") return;

  const now = system.currentTick;
  const prev = highs.get(player.id);
  const level = prev && prev.until > now ? prev.level + 1 : 1;
  const until = Math.max(prev?.until ?? now, now) + HIGH_TICKS;
  highs.set(player.id, { until, level });

  const ticks = until - now;
  player.addEffect("slowness", ticks, { amplifier: 0, showParticles: false });
  player.addEffect("hunger", ticks, { amplifier: 0, showParticles: false }); // munchies
  player.addEffect("regeneration", 20 * 10, { amplifier: 0, showParticles: false });
  if (level >= 2) player.addEffect("nausea", 20 * 15 * level, { amplifier: 0, showParticles: false });
  if (level >= 4) {
    player.addEffect("blindness", 20 * 8, { amplifier: 0 });
    player.onScreenDisplay.setTitle("§2Greened out...", { fadeInDuration: 10, stayDuration: 40, fadeOutDuration: 20 });
  }

  puff(player, 12);
  redEyes(player);
  player.onScreenDisplay.setActionBar(`§aYou're high §7(level ${level})`);
});

function puff(player, count) {
  const head = player.getHeadLocation();
  const view = player.getViewDirection();
  for (let i = 0; i < count; i++) {
    player.dimension.spawnParticle("minecraft:campfire_smoke_particle", {
      x: head.x + view.x * 0.6 + (Math.random() - 0.5) * 0.3,
      y: head.y + 0.1,
      z: head.z + view.z * 0.6 + (Math.random() - 0.5) * 0.3,
    });
  }
}

// Red tint around the screen = bloodshot eyes
function redEyes(player) {
  player.camera.fade({
    fadeColor: { red: 0.7, green: 0.05, blue: 0.05 },
    fadeTime: { fadeInTime: 0.4, holdTime: 0.2, fadeOutTime: 1.6 },
  });
}

// While high: red-eye pulses, occasional smoke, tell player when it wears off
system.runInterval(() => {
  const now = system.currentTick;
  for (const player of world.getAllPlayers()) {
    const high = highs.get(player.id);
    if (!high) continue;
    if (high.until <= now) {
      highs.delete(player.id);
      player.onScreenDisplay.setActionBar("§7You feel sober again.");
      continue;
    }
    redEyes(player);
    if (Math.random() < 0.3) puff(player, 3);
  }
}, 20 * 6);

world.afterEvents.playerSpawn.subscribe(({ player }) => highs.delete(player.id));
