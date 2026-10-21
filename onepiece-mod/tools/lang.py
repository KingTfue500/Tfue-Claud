"""Writes assets/onepiece/lang/en_us.json."""
import json
import os

OUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'resources', 'assets', 'onepiece', 'lang')
os.makedirs(OUT, exist_ok=True)

MOVES = {
    'gum_gum_pistol': 'Gum-Gum Pistol', 'gum_gum_gatling': 'Gum-Gum Gatling', 'gum_gum_bazooka': 'Gum-Gum Bazooka',
    'gum_gum_rocket': 'Gum-Gum Rocket', 'gum_gum_whip': 'Gum-Gum Whip', 'gum_gum_balloon': 'Gum-Gum Balloon', 'gum_gum_storm': 'Gum-Gum Storm',
    'jet_pistol': 'Gum-Gum Jet Pistol', 'jet_gatling': 'Gum-Gum Jet Gatling', 'jet_bazooka': 'Gum-Gum Jet Bazooka',
    'jet_stamp': 'Gum-Gum Jet Stamp', 'jet_dash': 'Jet Dash', 'red_hawk': 'Gum-Gum Red Hawk',
    'gigant_pistol': 'Gum-Gum Gigant Pistol', 'elephant_gun': 'Gum-Gum Elephant Gun', 'elephant_gatling': 'Gum-Gum Elephant Gatling',
    'gigant_axe': 'Gum-Gum Gigant Axe', 'gigant_rifle': 'Gum-Gum Gigant Rifle', 'gigant_balloon': 'Gum-Gum Gigant Balloon',
    'kong_gun': 'Gum-Gum Kong Gun', 'kong_organ': 'Gum-Gum Kong Organ', 'rhino_schneider': 'Gum-Gum Rhino Schneider',
    'leo_bazooka': 'Gum-Gum Leo Bazooka', 'gorilla_culverin': 'Gum-Gum Culverin', 'bound_quake': 'Bound Quake',
    'king_cobra': 'Gum-Gum King Cobra', 'python': 'Gum-Gum Python', 'jet_culverin': 'Gum-Gum Jet Culverin',
    'black_mamba': 'Gum-Gum Black Mamba', 'snake_dash': 'Snake Dash',
    'chaser': 'Gum-Gum Chaser', 'cannonball': 'Gum-Gum Cannonball', 'tank_guard': 'Tank Guard', 'tank_stomp': 'Tank Stomp',
    'bajrang_gun': 'Gum-Gum Bajrang Gun', 'lightning_grab': 'Lightning Grab', 'dawn_whip': 'Gum-Gum Dawn Whip',
    'toon_ground': 'Rubber World', 'giant_mode': 'Gum-Gum Giant', 'dawn_gatling': 'Gum-Gum Dawn Gatling',
    'oni_giri': 'Santoryu: Oni Giri', 'tora_gari': 'Santoryu: Tora Gari', 'pound_cannon_108': '108 Pound Cannon',
    'pound_phoenix_36': '36 Pound Phoenix', 'tatsumaki': 'Santoryu: Tatsumaki', 'rengoku_onigiri': 'Rengoku Onigiri',
    'shishi_sonson': 'Ittoryu: Shishi Sonson',
    'asura_ichibugin': 'Asura: Ichibugin', 'asura_makyusen': 'Asura: Makyusen', 'asura_dead_mans_game': "Asura: Dead Man's Game",
    'asura_tornado': 'Asura: Nine Sword Tornado',
    'flaming_dragon': 'Hiryu Kaen: Flaming Dragon', 'koku_tatsumaki': 'Kokujo O Tatsumaki', 'shi_shishi_sonson': 'Shi Shishi Sonson',
    'sanzen_sekai': 'Sanzen Sekai', 'king_of_hell_purgatory': 'King of Hell: Purgatory Slash',
    'collier': 'Collier Shoot', 'mouton_shot': 'Mouton Shot', 'concasse': 'Concasse', 'party_table': 'Party Table Kick Course',
    'anti_manner_kick': 'Anti-Manner Kick Course', 'sky_walk': 'Sky Walk',
    'flanchet_shot': 'Diable Jambe: Flanchet Shot', 'bien_cuit_grill': 'Bien Cuit: Grill Shot', 'hell_memories': 'Hell Memories',
    'premier_hachis': 'Diable Jambe: Premier Hachis', 'diable_concasse': 'Diable Jambe: Concasse', 'diable_party_table': 'Diable Jambe: Party Table',
    'ifrit_jambe': 'Ifrit Jambe', 'boeuf_burst': 'Boeuf Burst', 'ifrit_meteor': 'Ifrit Meteor', 'ifrit_hachis': 'Ifrit Hachis', 'ifrit_nova': 'Ifrit Nova',
    'stealth_kick': 'Stealth Black: Kick', 'poele_spectre': 'Poele a Frire: Spectre', 'raid_sky_walk': 'Raid Sky Walk', 'raid_concasse': 'Stealth Concasse',
    'thunder_bagua': 'Thunder Bagua', 'kaido_club_sweep': 'Hassaikai Sweep', 'ragnaraku': 'Ragnaraku', 'kaido_roar': 'Roar of the Beasts',
    'goryu_charge': 'Goryu Charge',
    'bolo_breath': 'Bolo Breath', 'kamaitachi': 'Kamaitachi Rai Ho', 'hybrid_thunder_bagua': 'Thunder Bagua: Hybrid', 'lightning_rain': 'Lightning Rain',
    'kaido_spin': 'Tosen Kaiten',
    'dragon_bolo_breath': 'Bolo Breath: Azure Dragon', 'dragon_twister': 'Dragon Twister', 'thunder_storm': 'Thunder Storm', 'kaifu': 'Kaifu',
    'dragon_dive': 'Dragon Dive', 'flame_cloud_dash': 'Flame Cloud Dash',
    'mochi_fist': 'Zan Giri Mochi', 'power_mochi': 'Power Mochi', 'donut_barrage': 'Donut Barrage', 'mochi_trident': 'Mogura',
    'flowing_mochi': 'Flowing Mochi', 'mochi_wall': 'Mochi Wall',
    'buso_kirimochi': 'Buso Kirimochi', 'mochi_pillars': 'Mochi Pillars', 'mochi_quake': 'Mochi Quake', 'hakai_mochi': 'Hakai Mochi',
    'haki_trident': 'Haki Mogura',
    'shigan': 'Shigan', 'soru': 'Soru', 'rankyaku': 'Rankyaku', 'tekkai': 'Tekkai', 'rokuogan': 'Rokuogan', 'geppo': 'Geppo',
    'leopard_pounce': 'Leopard Pounce', 'shigan_oren': 'Shigan: Oren', 'rankyaku_ran': 'Rankyaku: Ran', 'leopard_claw': 'Leopard Claw',
    'hybrid_rokuogan': 'Rokuogan: Leopard', 'awakened_rokuogan': 'Rokuogan: Awakened', 'leopard_storm': 'Leopard Storm',
    'rankyaku_ten': 'Rankyaku: Ten Strikes', 'kami_e': 'Kami-e', 'awakened_claw': 'Awakened Claw',
}

FORMS = {
    'base_luffy': 'Straw Hat Luffy', 'gear_2': 'Gear Second', 'gear_3': 'Gear Third', 'gear_4_boundman': 'Gear Fourth: Boundman',
    'gear_4_snakeman': 'Gear Fourth: Snakeman', 'gear_4_tankman': 'Gear Fourth: Tankman', 'gear_5': 'Gear Fifth',
    'base_zoro': 'Santoryu', 'asura': 'Asura', 'king_of_hell': 'King of Hell',
    'base_sanji': 'Black Leg', 'diable_jambe': 'Diable Jambe', 'ifrit_jambe': 'Ifrit Jambe', 'raid_suit': 'Raid Suit: Stealth Black',
    'base_kaido': 'Kaido of the Beasts', 'kaido_hybrid': 'Hybrid Form', 'kaido_dragon': 'Azure Dragon',
    'base_katakuri': 'Mochi Mochi', 'katakuri_awakened': 'Mochi Awakening',
    'base_lucci': 'Rokushiki', 'lucci_hybrid': 'Leopard Hybrid', 'lucci_awakened': 'Leopard Awakening',
}

FIGHTERS = {'none': 'None', 'luffy': 'Monkey D. Luffy', 'zoro': 'Roronoa Zoro', 'sanji': 'Sanji', 'kaido': 'Kaido',
            'katakuri': 'Charlotte Katakuri', 'lucci': 'Rob Lucci'}

L = {
    'itemGroup.onepiece': 'One Piece',
    'item.onepiece.gum_gum_fruit': 'Gum-Gum Fruit', 'item.onepiece.gum_gum_fruit.desc': 'Turns your body into rubber. Unlocks Luffy.',
    'item.onepiece.dragon_fruit': 'Fish-Fish Fruit, Model: Azure Dragon', 'item.onepiece.dragon_fruit.desc': 'Become a dragon that rides on flame clouds. Unlocks Kaido.',
    'item.onepiece.mochi_fruit': 'Mochi-Mochi Fruit', 'item.onepiece.mochi_fruit.desc': 'Make and become mochi. Unlocks Katakuri.',
    'item.onepiece.leopard_fruit': 'Cat-Cat Fruit, Model: Leopard', 'item.onepiece.leopard_fruit.desc': 'Turn into a leopard. Unlocks Lucci.',
    'item.onepiece.devil_fruit.warning': 'Tastes awful. Eat it anyway.',
    'item.onepiece.wado_ichimonji': 'Wado Ichimonji', 'item.onepiece.wado_ichimonji.desc': 'A promise to a friend. Use it to learn Santoryu.',
    'item.onepiece.shusui': 'Shusui', 'item.onepiece.shusui.desc': 'Black blade of Ryuma. Use it to learn Santoryu.',
    'item.onepiece.enma': 'Enma', 'item.onepiece.enma.desc': "Drinks the wielder's Haki. Use it to learn Santoryu.",
    'item.onepiece.sanji_cookbook': "Sanji's Cook Book", 'item.onepiece.sanji_cookbook.desc': 'Recipes and kicks. Use it to learn Black Leg.',
    'item.onepiece.style_hint': 'Right-click to learn this fighting style',
    'item.onepiece.straw_hat': 'Straw Hat', 'item.onepiece.zoro_bandana': "Zoro's Bandana", 'item.onepiece.sanji_suit': "Sanji's Suit",
    'item.onepiece.dragon_scale': 'Azure Dragon Scale', 'item.onepiece.mochi': 'Mochi', 'item.onepiece.leopard_fang': 'Leopard Fang',
    'item.onepiece.kaido_spawn_egg': 'Kaido Spawn Egg', 'item.onepiece.katakuri_spawn_egg': 'Katakuri Spawn Egg', 'item.onepiece.lucci_spawn_egg': 'Lucci Spawn Egg',
    'entity.onepiece.kaido': 'Kaido', 'entity.onepiece.katakuri': 'Charlotte Katakuri', 'entity.onepiece.lucci': 'Rob Lucci', 'entity.onepiece.vfx': 'Effect',
    'key.category.onepiece.powers': 'One Piece Powers',
    'key.onepiece.skill': 'Use Skill (tap) / Skill Wheel (hold)', 'key.onepiece.form': 'Form Wheel (hold) / Base Form (tap)',
    'key.onepiece.fighter': 'Switch Fighter', 'key.onepiece.armament': 'Armament Haki', 'key.onepiece.observation': 'Observation Haki',
    'key.onepiece.conqueror': "Conqueror's Haki",
    'gui.onepiece.move_wheel': 'Skills', 'gui.onepiece.form_wheel': 'Forms', 'gui.onepiece.base_form': 'Base form',
    'gui.onepiece.cost': 'Stamina: %s', 'gui.onepiece.cost_short': '%s ST', 'gui.onepiece.drain': 'Drain: %s / s', 'gui.onepiece.active': 'Active',
    'gui.onepiece.cooldown': 'Cooldown: %ss', 'gui.onepiece.ready': 'Ready',
    'gui.onepiece.move_hint': 'Point and release to pick, click to use now',
    'gui.onepiece.form_hint': 'Point and release to transform',
    'message.onepiece.learned': 'You can now fight as %s! Hold V for forms, hold R for skills.',
    'message.onepiece.switched': 'Now fighting as %s',
    'message.onepiece.no_power': 'You have no powers yet. Eat a Devil Fruit, use a katana or read the Cook Book.',
    'message.onepiece.no_room': 'Not enough room to grow that big here!',
    'message.onepiece.tired': 'Not enough stamina!', 'message.onepiece.exhausted': 'You pushed too hard. Exhausted!',
    'message.onepiece.need_sword': 'Hold a sword to use Santoryu', 'message.onepiece.armament_on': 'Armament Haki: ON',
    'message.onepiece.armament_off': 'Armament Haki: OFF', 'message.onepiece.observation_on': 'Observation Haki: ON',
    'message.onepiece.observation_off': 'Observation Haki: OFF', 'message.onepiece.conqueror_wait': "Conqueror's Haki needs time to recover",
    'message.onepiece.conqueror_knocked': "Conqueror's Haki knocked out %s enemies!",
    'message.onepiece.boss_transform': '%s transformed: %s!',
    'message.onepiece.already_ate': 'You already have the power of %s',
    'message.onepiece.ate_fruit.luffy': 'Your body stretches like rubber!',
    'message.onepiece.ate_fruit.kaido': 'Scales and horns burst out. You are the Azure Dragon!',
    'message.onepiece.ate_fruit.katakuri': 'Your body turns soft and sticky. Mochi!',
    'message.onepiece.ate_fruit.lucci': 'Fangs, claws and a tail. The leopard awakens!',
    'message.onepiece.unlocked_all': 'Every fighter unlocked! Press B to switch.',
    'command.onepiece.unknown_fighter': 'Unknown fighter. Use luffy, zoro, sanji, kaido, katakuri or lucci',
    'command.onepiece.unknown_form': 'Unknown form', 'command.onepiece.unknown_boss': 'Unknown boss. Use kaido, katakuri or lucci',
    'command.onepiece.fighter': 'Gave %s to %s player(s)', 'command.onepiece.unlockall': 'Unlocked everything for %s player(s)',
    'command.onepiece.form': 'Set form %s for %s player(s)', 'command.onepiece.infinite_on': 'Infinite stamina ON for %s player(s)',
    'command.onepiece.infinite_off': 'Infinite stamina OFF for %s player(s)', 'command.onepiece.reset': 'Reset powers of %s player(s)',
    'command.onepiece.kit': 'Gave the One Piece kit to %s player(s)', 'command.onepiece.boss': 'Summoned %s',
    'message.onepiece.welcome.title': '=== One Piece: Straw Hat Powers ===',
    'message.onepiece.welcome.1': 'Get powers: eat a Devil Fruit (Gum-Gum, Azure Dragon, Mochi, Leopard), right-click a katana, or read Sanji\'s Cook Book.',
    'message.onepiece.welcome.2': 'R: tap to use your skill, hold for the skill wheel. V: hold for the form wheel, tap to go back to base.',
    'message.onepiece.welcome.3': 'H / J / K: Armament, Observation and Conqueror\'s Haki. B: switch fighter. Space in mid-air: Sky Walk, Geppo or bounce.',
    'message.onepiece.welcome.4': 'Operators: /onepiece unlockall, /onepiece boss kaido, /onepiece cast <skill>, /onepiece infinite true.',
    'command.onepiece.unknown_skill': 'Unknown skill', 'command.onepiece.cast': 'Used %s for %s player(s)',
    'command.onepiece.info': '%s: %s, %s, stamina %s, infinite %s',
}
for k, v in MOVES.items():
    L['move.onepiece.' + k] = v
for k, v in FORMS.items():
    L['form.onepiece.' + k] = v
for k, v in FIGHTERS.items():
    L['fighter.onepiece.' + k] = v
for s in ['stretch', 'snap', 'punch', 'heavy_impact', 'gatling', 'whoosh', 'slash', 'big_slash', 'sheathe', 'tornado', 'kick', 'fire',
          'fire_blast', 'steam', 'inflate', 'bounce', 'drums', 'lightning', 'haki', 'conqueror', 'form_up', 'boss_roar', 'eat_fruit']:
    L['subtitles.onepiece.' + s] = s.replace('_', ' ').title()

json.dump(L, open(os.path.join(OUT, 'en_us.json'), 'w'), indent=2, ensure_ascii=False)
print(len(L), 'keys')
