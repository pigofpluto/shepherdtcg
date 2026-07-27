# Bible TCG — Card Art Prompts

**Style:** realistic Renaissance oil painting, dramatic chiaroscuro lighting, rich
earthy palette, subtle gold-leaf highlights, museum quality. Portrait orientation,
single clear focal subject, ornate but uncluttered composition, no text or letters.

**How to use:** generate each image at a 5:7 portrait ratio, export as PNG, and add it
to `Assets.xcassets` as an imageset **named exactly after the card id** (e.g. `h_samson`).
The card renderer loads `UIImage(named: card.id)` and shows it automatically — no code
change. Until then a category-tinted procedural placeholder is displayed.

Each line below is: `card_id` — *scene to append to the style prefix.*

---

## Humans (20)

- `h_solomon` — an enthroned king in royal robes weighing a decision, scales and a scroll before him, golden temple pillars behind, calm wise expression.
- `h_moses` — a bearded prophet on a shore raising a wooden staff over a parting sea, walls of water rising, wind in his robes.
- `h_daniel` — a young man standing serene in a shadowed stone den, glowing-eyed lions crouched and calm around him, a shaft of light from above.
- `h_abraham` — an aged patriarch gazing up at a star-filled night sky, hand on his chest, desert tents behind him.
- `h_joseph` — a young Egyptian-robed noble in a coat of many colors interpreting a dream, granaries and sheaves of wheat behind him.
- `h_paul` — a balding, intense apostle writing a letter by candlelight, a broken chain at his feet, a Roman prison wall.
- `h_deborah` — a commanding prophetess-judge seated beneath a palm tree, warriors gathered below, a determined gaze.
- `h_david` — a youthful shepherd with a sling swinging, smooth stone in hand, defiant, a giant's shadow looming.
- `h_joshua` — an armored commander raising a horn/trumpet before massive crumbling city walls, dust and rubble.
- `h_gideon` — a warrior holding a clay torch and a trumpet at night, a small band of men behind him.
- `h_esther` — a queen in jeweled robes stepping toward a throne, brave but fearful, golden Persian hall.
- `h_elijah` — a wild-haired prophet with arms raised as fire falls from heaven onto a stone altar, storm clouds.
- `h_peter` — a rugged fisherman stepping out of a boat onto stormy waves, reaching forward, wind-torn sea.
- `h_baptist` — a lean man in camel-hair by the Jordan river, pointing, water dripping from a raised hand, wilderness.
- `h_samson` — a powerful long-haired warrior straining against two great stone temple pillars, cracks spreading, torchlight and dust.
- `h_goliath` — a towering armored giant with spear and bronze helmet, sneering down, Philistine banners.
- `h_benaiah` — a battle-scarred warrior gripping a spear, standing over a slain lion in a snowy pit, breath steaming.
- `h_caleb` — an old but vigorous warrior pointing up at a rugged mountain, cloak in the wind, sunrise.
- `h_jael` — a resolute woman holding a tent peg and mallet in a dim tent, shadow and lamplight.
- `h_nehemiah` — a builder-governor with a trowel in one hand and sword at his belt, half-rebuilt city wall behind, workers.

## Animals (20)

- `a_ant` — a single ant on a grain of wheat, extreme close macro, warm golden light, shallow depth.
- `a_fox` — a sly red fox among ruined stones, glancing back, dusk light.
- `a_dove` — a white dove in flight carrying an olive branch, soft radiant sky.
- `a_serpent` — a coiled bronze-scaled serpent on a branch, glinting eye, dark foliage.
- `a_raven` — a black raven perched on a dead branch holding bread in its beak, brooding sky.
- `a_sparrow` — a small brown sparrow on a twig, delicate, soft morning light.
- `a_donkey` — a grey donkey on a narrow desert path turning its head, warm dusk.
- `a_fish` — a silver fish leaping from dark water, a glint of a coin in its mouth, ripples.
- `a_dog` — a lean loyal dog beneath a stone table, alert, warm interior candlelight.
- `a_lamb` — a pure white lamb standing in soft light, gentle, meadow bokeh.
- `a_hen` — a mother hen with wings spread over chicks, warm rustic barn light.
- `a_eagle` — a golden eagle soaring with wings fully spread over craggy peaks, sunlit.
- `a_lion` — a roaring lion with a full mane prowling, dramatic side light, dark background.
- `a_sheep` — a woolly sheep on a green hillside at golden hour, shepherd's staff blurred behind.
- `a_leviathan` — a colossal sea leviathan breaching a black storm-tossed ocean, scales and spray, terrifying scale.
- `a_bear` — a huge brown bear rearing on hind legs, snarling, forest gloom.
- `a_ox` — a powerful yoked ox in a plowed field, muscular, dusty golden light.
- `a_camel` — a camel silhouetted against a vast desert dune, long shadows, sunset.
- `a_goat` — a lone goat on a rocky ledge in the wilderness, wind-blown, pale sky.
- `a_locust` — a single locust in sharp macro detail with a blurred swarm darkening the sky behind.

## Events (10)

- `e_redsea` — towering walls of parted sea water with a dry seabed path between, dramatic sky, tiny figures crossing.
- `e_jericho` — massive ancient city walls collapsing outward in a cloud of dust, trumpet blast light.
- `e_wilderness` — an endless cracked desert under a burning sun, a lone distant caravan, heat haze.
- `e_goliath` — a wide battle valley at dawn, two armies on opposing ridges, a lone giant's silhouette.
- `e_furnace` — a roaring stone furnace with three unharmed figures standing calm within the flames, a fourth glowing presence.
- `e_lionsden` — a dark stone pit with lions in shadow and a single shaft of holy light from a sealed opening above.
- `e_jordan` — a river held back in a shimmering heap of water, a dry crossing, priests bearing an ark.
- `e_passover` — a doorway with blood-marked lintel glowing warm, dark ominous night beyond, lamplight within.
- `e_flood` — a vast churning deluge under black storm clouds, a distant wooden ark riding immense waves.
- `e_sinai` — a smoking, lightning-crowned mountain at night, quaking, a lone figure ascending into cloud.

## Items (7)

- `i_sling` — a leather shepherd's sling with five smooth river stones on weathered wood, warm light.
- `i_armor` — a gleaming suit of ancient armor — breastplate, shield, helmet — arranged heroically, gold rim light.
- `i_staff` — a simple wooden shepherd's rod glowing faintly with power, laid on stone, dramatic shadow.
- `i_manna` — a golden jar overflowing with white manna wafers, soft heavenly glow, altar cloth.
- `i_oil` — a curved animal horn pouring shining anointing oil, droplets catching light, dark background.
- `i_cruse` — a humble clay barrel and jar of meal and oil that never empties, warm rustic still-life.
- `i_ark` — the golden Ark of the Covenant with two winged cherubim, radiant light between them, temple shadow.
