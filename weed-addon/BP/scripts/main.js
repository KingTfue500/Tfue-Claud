import { world, system, ItemStack, EquipmentSlot, ItemLockMode } from "@minecraft/server";

const SEC = 20;
const KNOCKOUT_LEVEL = 5; // reaching level 5 of anything = knocked out
const MIX_LIMIT = 6; // total levels across all substances = knocked out
const KNOCKOUT_TICKS = 15 * SEC;

// item -> what it does
const SUBSTANCES = {
  "weed:joint": { kind: "weed", ticks: 90 * SEC, dose: 1 },
  "weed:beer": { kind: "alcohol", ticks: 120 * SEC, dose: 1 },
  "weed:vodka": { kind: "alcohol", ticks: 120 * SEC, dose: 2 },
  "weed:cocaine": { kind: "cocaine", ticks: 60 * SEC, dose: 1 },
};

const NAMES = {
  weed: ["", "§aChill", "§aBaked", "§2Stoned", "§2Greening out"],
  alcohol: ["", "§6Tipsy", "§6Drunk", "§cWasted", "§4Blackout drunk"],
  cocaine: ["", "§fWired", "§fRacing", "§cToo much", "§4Overdosing"],
};

// Effects per level. Each level is worse than the last.
const LEVEL_EFFECTS = {
  weed(p, lvl, t) {
    fx(p, "slowness", t, lvl >= 3 ? 1 : 0);
    fx(p, "hunger", t, lvl - 1); // munchies
    if (lvl === 1) fx(p, "regeneration", 10 * SEC, 0);
    if (lvl >= 2) fx(p, "nausea", t, 0);
    if (lvl >= 3) fx(p, "weakness", t, 0);
    if (lvl >= 4) {
      fx(p, "blindness", 8 * SEC, 0);
      p.onScreenDisplay.setTitle("§2Greening out...", { fadeInDuration: 10, stayDuration: 40, fadeOutDuration: 20 });
    }
  },
  alcohol(p, lvl, t) {
    if (lvl === 1) fx(p, "strength", t, 0); // liquid courage
    if (lvl >= 2) fx(p, "nausea", t, 0);
    if (lvl >= 2) fx(p, "slowness", t, lvl - 2);
    if (lvl >= 3) fx(p, "mining_fatigue", t, 0);
    if (lvl >= 4) fx(p, "darkness", t, 0);
  },
  cocaine(p, lvl, t) {
    fx(p, "speed", t, lvl - 1);
    fx(p, "haste", t, Math.min(lvl, 2) - 1);
    if (lvl >= 2) fx(p, "jump_boost", t, 0);
    if (lvl >= 3) fx(p, "nausea", t, 0);
    if (lvl >= 4) fx(p, "darkness", t, 0);
    p.camera.fade({
      fadeColor: { red: 1, green: 1, blue: 1 },
      fadeTime: { fadeInTime: 0.1, holdTime: 0.1, fadeOutTime: 0.8 },
    });
  },
};

const GRASS = ["minecraft:short_grass", "minecraft:tall_grass", "minecraft:fern"];
const LIGHTERS = ["weed:lighter", "minecraft:flint_and_steel"];
const HAZES = ["weed:haze_green", "weed:haze_purple", "weed:haze_pink", "weed:haze_blue"];

// playerId -> { subs: { kind: { until, level } }, fog, koUntil }
const states = new Map();
// playerId -> item being used right now (for smoke/sounds while using)
const using = new Map();

function state(player) {
  let s = states.get(player.id);
  if (!s) states.set(player.id, (s = { subs: {}, fog: undefined, koUntil: 0 }));
  return s;
}

function fx(player, effect, ticks, amplifier) {
  player.addEffect(effect, ticks, { amplifier, showParticles: false });
}

// Grass drops weed buds, jungle leaves drop coca leaves
world.afterEvents.playerBreakBlock.subscribe(({ block, brokenBlockPermutation }) => {
  const id = brokenBlockPermutation.type.id;
  let drop;
  if (GRASS.includes(id) && Math.random() < 0.1) drop = "weed:bud";
  if (id === "minecraft:jungle_leaves" && Math.random() < 0.15) drop = "weed:coca_leaf";
  if (drop) block.dimension.spawnItem(new ItemStack(drop, 1), block.center());
});

world.beforeEvents.itemUse.subscribe((event) => {
  if (!SUBSTANCES[event.itemStack.typeId]) return;
  const player = event.source;
  if (state(player).koUntil > system.currentTick) {
    event.cancel = true;
    return;
  }
  if (event.itemStack.typeId !== "weed:joint") return;
  // Need a lighter (or flint and steel) in the inventory to light up
  if (findLighter(player) === undefined) {
    event.cancel = true;
    system.run(() => player.onScreenDisplay.setActionBar("§cYou need a lighter to smoke this"));
    return;
  }
  system.run(() => player.dimension.playSound("fire.ignite", player.location));
});

world.afterEvents.itemStartUse.subscribe(({ itemStack, source: player }) => {
  if (SUBSTANCES[itemStack.typeId]) using.set(player.id, { player, typeId: itemStack.typeId, tick: 0 });
});
world.afterEvents.itemStopUse.subscribe(({ source: player }) => using.delete(player.id));

// While using: joint smoulders, bottles glug, cocaine sniffs
system.runInterval(() => {
  for (const [id, u] of using) {
    const { player, typeId } = u;
    if (!player.isValid) {
      using.delete(id);
      continue;
    }
    const t = u.tick++;
    if (typeId === "weed:joint") {
      tipSmoke(player);
    } else if (typeId === "weed:cocaine") {
      if (t % 4 === 0) player.dimension.playSound("mob.fox.sniff", player.location, { pitch: 1.3 });
    } else if (t % 4 === 0) {
      player.dimension.playSound("random.drink", player.location, { volume: 0.6, pitch: 0.8 });
    }
  }
}, 4);

world.afterEvents.itemCompleteUse.subscribe(({ itemStack, source: player }) => {
  using.delete(player.id);
  if (itemStack.typeId === "minecraft:milk_bucket") return soberUp(player);
  const sub = SUBSTANCES[itemStack.typeId];
  if (!sub) return;
  const s = state(player);
  const now = system.currentTick;

  const prev = s.subs[sub.kind];
  const active = prev && prev.until > now;
  const level = (active ? prev.level : 0) + sub.dose;
  const until = (active ? prev.until : now) + sub.ticks;
  s.subs[sub.kind] = { until, level };

  const total = Object.values(s.subs).reduce((sum, x) => sum + x.level, 0);
  if (level >= KNOCKOUT_LEVEL || total >= MIX_LIMIT) {
    knockout(player, total >= MIX_LIMIT && level < KNOCKOUT_LEVEL ? "You mixed too much." : "You took too much.");
    return;
  }

  LEVEL_EFFECTS[sub.kind](player, level, until - now);

  if (sub.kind === "weed") {
    useLighter(player);
    smokeHit(player);
    wearRedEyes(player);
  } else if (sub.kind === "alcohol") {
    player.dimension.playSound("random.burp", player.location);
    shake(player, 0.1 * level, 1, "rotational");
  } else {
    player.dimension.playSound("mob.warden.heartbeat", player.location, { volume: 0.8 });
    shake(player, 0.2, 0.5, "positional");
  }
  player.onScreenDisplay.setActionBar(status(s));
});

function knockout(player, reason) {
  const s = state(player);
  s.subs = {};
  s.koUntil = system.currentTick + KNOCKOUT_TICKS;
  player.runCommand("effect @s clear");
  fx(player, "blindness", KNOCKOUT_TICKS, 0);
  fx(player, "slowness", KNOCKOUT_TICKS, 255);
  player.runCommand("inputpermission set @s movement disabled");
  player.runCommand("inputpermission set @s camera disabled");
  player.camera.fade({
    fadeColor: { red: 0, green: 0, blue: 0 },
    fadeTime: { fadeInTime: 0.5, holdTime: KNOCKOUT_TICKS / SEC - 1.5, fadeOutTime: 1 },
  });
  player.onScreenDisplay.setTitle("§4KNOCKED OUT", { fadeInDuration: 10, stayDuration: 80, fadeOutDuration: 20, subtitle: `§7${reason}` });
  player.dimension.playSound("random.hurt", player.location);
  shake(player, 1, 0.6, "rotational");
  for (let i = 1; i <= 4; i++) {
    system.runTimeout(() => player.isValid && player.playSound("mob.warden.heartbeat", { pitch: 0.7 }), i * 3 * SEC);
  }
  system.runTimeout(() => player.isValid && wakeUp(player), KNOCKOUT_TICKS);
}

function wakeUp(player) {
  const s = state(player);
  s.koUntil = 0;
  restoreInput(player);
  clearVisuals(player);
  fx(player, "nausea", 10 * SEC, 0);
  fx(player, "weakness", 60 * SEC, 0);
  fx(player, "slowness", 20 * SEC, 0);
  player.onScreenDisplay.setActionBar("§7You wake up with a terrible headache...");
}

// Milk bucket clears everything (but not while knocked out)
function soberUp(player) {
  const s = states.get(player.id);
  if (!s || s.koUntil > system.currentTick) return;
  states.delete(player.id);
  clearVisuals(player);
  player.onScreenDisplay.setActionBar("§bYou feel clear-headed again.");
}

function shake(player, intensity, seconds, type) {
  player.runCommand(`camerashake add @s ${Math.min(intensity, 4).toFixed(2)} ${seconds} ${type}`);
}

function restoreInput(player) {
  player.runCommand("inputpermission set @s movement enabled");
  player.runCommand("inputpermission set @s camera enabled");
}

function status(s) {
  const parts = Object.entries(s.subs).map(([kind, x]) => NAMES[kind][x.level]);
  return parts.join(" §7| ");
}

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

function smokeHit(player) {
  puff(player, 4);
  player.camera.fade({
    fadeColor: { red: 0.7, green: 0.05, blue: 0.05 },
    fadeTime: { fadeInTime: 0.3, holdTime: 0.1, fadeOutTime: 1.2 },
  });
  // Hold it in, then exhale a big cloud
  system.runTimeout(() => {
    if (!player.isValid) return;
    puff(player, 18);
    player.dimension.playSound("random.fizz", player.location, { volume: 0.4, pitch: 0.6 });
  }, 30);
}

// Thin wisp of smoke from the lit end of the joint
function tipSmoke(player) {
  const head = player.getHeadLocation();
  const view = player.getViewDirection();
  player.dimension.spawnParticle("minecraft:basic_smoke_particle", {
    x: head.x + view.x * 0.5 - view.z * 0.25,
    y: head.y - 0.15,
    z: head.z + view.z * 0.5 + view.x * 0.25,
  });
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

function stumble(player, strength) {
  const angle = Math.random() * Math.PI * 2;
  player.applyKnockback({ x: Math.cos(angle) * strength, z: Math.sin(angle) * strength }, 0.1);
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

function removeRedEyes(player) {
  const equip = player.getComponent("minecraft:equippable");
  if (equip?.getEquipment(EquipmentSlot.Head)?.typeId === "weed:red_eyes") {
    equip.setEquipment(EquipmentSlot.Head, undefined);
  }
}

function clearVisuals(player) {
  removeRedEyes(player);
  const s = states.get(player.id);
  if (s) s.fog = undefined;
  player.runCommand("fog @s remove weed_high");
}

function wearOff(player, kind, level) {
  if (kind === "weed") removeRedEyes(player);
  if (kind === "cocaine") {
    // The crash
    fx(player, "slowness", 30 * SEC, 1);
    fx(player, "weakness", 30 * SEC, 0);
    fx(player, "mining_fatigue", 30 * SEC, 0);
    player.onScreenDisplay.setActionBar("§8You're crashing hard...");
  } else {
    player.onScreenDisplay.setActionBar(`§7The ${kind} wore off.`);
  }
}

// Every 3 seconds: wear-off checks, haze colors, stumbling, heartbeat, damage
system.runInterval(() => {
  const now = system.currentTick;
  for (const player of world.getAllPlayers()) {
    const s = states.get(player.id);
    if (!s || s.koUntil > now) continue;

    for (const [kind, x] of Object.entries(s.subs)) {
      if (x.until <= now) {
        delete s.subs[kind];
        wearOff(player, kind, x.level);
      }
    }
    const { weed, alcohol, cocaine } = s.subs;

    // Only touch the fog when it needs to change; changing fog causes lag
    const fog = weed ? HAZES[(weed.level - 1) % HAZES.length] : alcohol ? "weed:haze_amber" : undefined;
    if (fog !== s.fog) {
      if (s.fog) player.runCommand("fog @s remove weed_high");
      if (fog) player.runCommand(`fog @s push ${fog} weed_high`);
      s.fog = fog;
    }

    if (weed && Math.random() < 0.3) puff(player, 3);
    if (alcohol?.level >= 4 && Math.random() < 0.4) stumble(player, 0.3);
    if (cocaine?.level >= 2) player.playSound("mob.warden.heartbeat", { pitch: 1 + cocaine.level * 0.2 });
    if (cocaine?.level >= 4) player.applyDamage(1);

    if (Object.keys(s.subs).length) player.onScreenDisplay.setActionBar(status(s));
  }
}, 3 * SEC);

// Clean up after death or rejoining
world.afterEvents.playerSpawn.subscribe(({ player }) => {
  states.delete(player.id);
  using.delete(player.id);
  restoreInput(player);
  clearVisuals(player);
});
