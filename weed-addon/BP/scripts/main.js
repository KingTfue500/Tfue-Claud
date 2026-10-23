import { world, system, ItemStack, EquipmentSlot, ItemLockMode } from "@minecraft/server";

const HIGH_TICKS = 20 * 90; // one joint = 90 seconds high
const GRASS = ["minecraft:short_grass", "minecraft:tall_grass", "minecraft:fern"];
const LIGHTERS = ["weed:lighter", "minecraft:flint_and_steel"];
const HAZES = ["weed:haze_green", "weed:haze_purple", "weed:haze_pink", "weed:haze_blue"];

// playerId -> { until: tick, level: joints smoked this high, haze: index }
const highs = new Map();

// 10% chance for grass to drop a weed bud
world.afterEvents.playerBreakBlock.subscribe(({ block, brokenBlockPermutation }) => {
  if (!GRASS.includes(brokenBlockPermutation.type.id) || Math.random() > 0.1) return;
  block.dimension.spawnItem(new ItemStack("weed:bud", 1), block.center());
});

// Need a lighter (or flint and steel) in the inventory to light up
world.beforeEvents.itemUse.subscribe((event) => {
  if (event.itemStack.typeId !== "weed:joint") return;
  const player = event.source;
  if (findLighter(player) === undefined) {
    event.cancel = true;
    system.run(() => player.onScreenDisplay.setActionBar("§cYou need a lighter to smoke this"));
    return;
  }
  system.run(() => player.dimension.playSound("fire.ignite", player.location));
});

world.afterEvents.itemCompleteUse.subscribe(({ itemStack, source: player }) => {
  if (itemStack.typeId !== "weed:joint") return;
  useLighter(player);

  const now = system.currentTick;
  const prev = highs.get(player.id);
  const level = prev && prev.until > now ? prev.level + 1 : 1;
  const until = Math.max(prev?.until ?? now, now) + HIGH_TICKS;
  highs.set(player.id, { until, level, haze: prev?.haze ?? 0 });

  const ticks = until - now;
  player.addEffect("slowness", ticks, { amplifier: 0, showParticles: false });
  player.addEffect("hunger", ticks, { amplifier: 0, showParticles: false }); // munchies
  player.addEffect("regeneration", 20 * 10, { amplifier: 0, showParticles: false });
  if (level >= 2) player.addEffect("nausea", 20 * 15 * level, { amplifier: 0, showParticles: false });
  if (level >= 4) {
    player.addEffect("blindness", 20 * 8, { amplifier: 0 });
    player.onScreenDisplay.setTitle("§2Greened out...", { fadeInDuration: 10, stayDuration: 40, fadeOutDuration: 20 });
  }

  puff(player, 4);
  // Hold it in, then exhale a big cloud
  system.runTimeout(() => {
    if (!player.isValid) return;
    puff(player, 18);
    player.dimension.playSound("random.fizz", player.location, { volume: 0.4, pitch: 0.6 });
  }, 30);

  redFlash(player);
  wearRedEyes(player);
  player.onScreenDisplay.setActionBar(`§aYou're high §7(level ${level})`);
});

function findLighter(player) {
  const inv = player.getComponent("minecraft:inventory").container;
  for (let i = 0; i < inv.size; i++) {
    if (LIGHTERS.includes(inv.getItem(i)?.typeId)) return i;
  }
}

function useLighter(player) {
  const slot = findLighter(player);
  if (slot === undefined) return;
  const inv = player.getComponent("minecraft:inventory").container;
  const item = inv.getItem(slot);
  const durability = item.getComponent("minecraft:durability");
  if (!durability) return;
  if (durability.damage + 1 >= durability.maxDurability) {
    inv.setItem(slot, undefined);
    player.dimension.playSound("random.break", player.location);
  } else {
    durability.damage += 1;
    inv.setItem(slot, item);
  }
}

function puff(player, count) {
  const head = player.getHeadLocation();
  const view = player.getViewDirection();
  for (let i = 0; i < count; i++) {
    player.dimension.spawnParticle("minecraft:campfire_smoke_particle", {
      x: head.x + view.x * 0.6 + (Math.random() - 0.5) * 0.4,
      y: head.y + 0.1,
      z: head.z + view.z * 0.6 + (Math.random() - 0.5) * 0.4,
    });
  }
}

function redFlash(player) {
  player.camera.fade({
    fadeColor: { red: 0.7, green: 0.05, blue: 0.05 },
    fadeTime: { fadeInTime: 0.3, holdTime: 0.1, fadeOutTime: 1.2 },
  });
}

// Red eyes on the player's face, visible to everyone. Only if no helmet is on.
function wearRedEyes(player) {
  const equip = player.getComponent("minecraft:equippable");
  if (equip.getEquipment(EquipmentSlot.Head)) return;
  const eyes = new ItemStack("weed:red_eyes", 1);
  eyes.lockMode = ItemLockMode.slot;
  eyes.keepOnDeath = true;
  equip.setEquipment(EquipmentSlot.Head, eyes);
}

function sober(player) {
  highs.delete(player.id);
  const equip = player.getComponent("minecraft:equippable");
  if (equip?.getEquipment(EquipmentSlot.Head)?.typeId === "weed:red_eyes") {
    equip.setEquipment(EquipmentSlot.Head, undefined);
  }
  player.runCommand("fog @s remove weed_high");
}

// While high: colors shift through a trippy haze, occasional smoke
system.runInterval(() => {
  const now = system.currentTick;
  for (const player of world.getAllPlayers()) {
    const high = highs.get(player.id);
    if (!high) continue;
    if (high.until <= now) {
      sober(player);
      player.onScreenDisplay.setActionBar("§7You feel sober again.");
      continue;
    }
    high.haze = (high.haze + 1) % HAZES.length;
    player.runCommand("fog @s remove weed_high");
    player.runCommand(`fog @s push ${HAZES[high.haze]} weed_high`);
    if (Math.random() < 0.3) puff(player, 3);
  }
}, 20 * 3);

// Clean up after death or rejoining
world.afterEvents.playerSpawn.subscribe(({ player }) => sober(player));
