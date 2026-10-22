# Journal des versions de Popaint

## 0.8.0 — 22 octobre 2026
- **Particules partout** (visibles par tout le monde, débit volontairement raisonnable) :
  - **ambiance par zone** dans l'air : pétales à Candy Meadow, bulles de savon aux Neon Docks,
    lucioles à Jelly Canyon, flocons à Crystal Peaks, poussière dorée à Rainbow Core, feuilles à
    Pumpkin Patch ; bulles et pétales au-dessus du hub (`lib.particles`, champ `Air` des thèmes) ;
  - **magie des œufs** : halo qui monte, étincelles autour de la coquille, gerbe d'étoiles 3D à
    l'éclosion ; **traînée** derrière les compagnons, plus marquée selon la rareté.
- **Le monde qui respire** : les œufs tremblent, les portails pulsent, l'eau de la fontaine coule
  vraiment (gouttes qui défilent), les guirlandes de fanions ondulent, la bulle des machines respire.
  Trois nouvelles animations : `Flow` (défilement), `Hop` (sautillement), `Shake` (tremblement).
- **Petits habitants** : oiseaux qui tournent dans le ciel, poissons qui sautent, lapins qui
  sautillent, crabes sur les plages — en plus des papillons.
- **Cycle jour / nuit doux** (`src/Client/DayNight.luau`) : le ciel passe lentement du matin au
  crépuscule (20 min par tour), la même heure pour tous, et **les lampes s'allument le soir**.
  Il ne fait jamais nuit noire, et la Rainbow Storm ramène le plein jour.
- **Encore plus de 3D** :
  - **bases** : cuve à savon en verre avec bulles qui montent, tuyau courbe, manomètre à aiguille,
    cheminée, auvent rayé, marche, rivets, boîte aux lettres, haut-parleur et serviette ;
  - **pièces centrales** : gros nœud de ruban sur le bonbon, rochers/ponton/drapeau au phare, halo
    d'arcs tournants et runes au cristal, cascade et maisonnette sur l'île volante, bottes de foin et
    vignes sur la citrouille, plus un jardin (marches, jardinières, lanternes) autour de chacune ;
  - **sol des zones** : relief refait (toutes les zones ont enfin des collines, jamais de falaise au
    bord), bordure décorée tout autour, chemin balisé du pont jusqu'au centre, coulées de peinture ;
  - **personnage** : réservoir à bulles dans le dos et pinceau dans la main, à la couleur de peinture
    du joueur, visibles par tous (`src/Server/LookService.luau`).

## 0.7.0 — 22 octobre 2026
- **Plus aucun fluo** : le matériau néon a disparu de tout le jeu (map, bulles, compagnons, interface).
  Les récompenses gardent un **doré doux** au lieu du jaune qui pique. Un test vérifie qu'aucun néon
  ne revient.
- **Beaucoup plus de 3D** : formes arrondies (nouvelle brique `lib.roundBox`), reliefs, coulées de
  glaçage et bien plus d'objets.
  - **Hub** : grande fontaine à 3 vasques, place en mosaïque, bord du hub en glaçage, massifs et haies
    entre les bases (`tools/map/hub.luau`).
  - **Œufs** : socle à étages avec perles et festons, coquille à zigzags et pois, reflet, étincelles qui
    tournent et couronne flottante.
  - **Portails et ponts** : arche arrondie avec rubans en spirale, guirlande de fanions, étoile au
    sommet ; ponts à balustres, lanternes et arche de soutien par-dessous.
  - **Zones** : bord de l'île en glaçage qui coule, bande de roche plus bas, et plus d'objets dedans.
  - **Montagnes** : terrasses arrondies, avancées rocheuses, petits arbres et cristaux sur les
    corniches, glaçage au sommet et parfois une cascade.
  - **Compagnons** : yeux avec iris et deux reflets, joues détaillées, petites mains qui font coucou
    et orteils.
  - **Bulles** : reflet blanc tourné vers la caméra et respiration (elles s'étirent doucement).
  - 8 nouveaux objets de décor : buisson à baies, massif de fleurs, rochers, corail, coquillage,
    moulin, charrette à bonbons, cerf-volant.
- **Qualité automatique** (`src/Client/Quality.luau`) : le jeu choisit un niveau de détail selon le
  réglage graphique du joueur, puis l'ajuste tout seul s'il rame ou s'il est très fluide. Cela règle la
  distance des détails, les animations, les compagnons et les particules.
- **Fichier de jeu en .rbxl** (binaire) au lieu de .rbxlx : **833 Ko au lieu de 59 Mo**, et Studio
  l'ouvre bien plus vite. Le contenu est identique.

## 0.6.0 — 21 octobre 2026
- **Ton pastel** partout : peinture, zones, décor, montagnes, terrain, interface, éclairage (moins de
  saturation et d'éblouissement). Les récompenses restent vives : pièces, bulles dorées, Rainbow Storm.
- **Compagnons en 3D détaillés** (15 à 40 pièces) : 10 formes de corps, 22 accessoires (oreilles, ailes,
  cornes, couronne, halo, flamme…), visage kawaii. Doré = couronne + éclat, Arc-en-ciel = halo, plus
  grand, couleurs qui changent. Apparence réglable par compagnon (`Look` dans `Content/Companions.luau`).
- Compagnons **vivants** : ils sautillent en marchant, flottent à l'arrêt, clignent des yeux, battent
  des ailes, remuent la queue et les oreilles. En 3D aussi dans l'inventaire et à l'éclosion.
- **Bases détaillées** : bordure, clôture en sucre d'orge, pots de fleurs, fanion ; machine avec hublot,
  boutons, cadran, levier, engrenages qui tournent, lumières qui clignotent, bulles qui s'échappent ;
  tapis avec rouleaux, poignées, console, gourde et ventilateur. La machine **saute** à chaque achat.
- Décor plus fouillé (35 objets, jusqu'à 105 pièces) et pièces centrales refaites (bonbons en orbite,
  mouettes, chauves-souris, éclats flottants, île fleurie…).
- **Animations partout** (seulement près du joueur) : arbres et sucettes qui se balancent, nuages qui
  dérivent, canards qui nagent, papillons, bateaux qui tanguent, lumières qui clignotent.
- Interface qui rebondit : boutons qui s'écrasent, fenêtres qui s'ouvrent et se ferment en rebond,
  cadeau du jour qui se dandine, pièces qui tournent en volant.
- Les petits détails ne s'affichent que de près (`src/Client/Detail.luau`) pour rester fluide sur mobile.
- Outil d'aperçu 3D sans Studio : `tools/preview.sh props|companions|base|centerpieces`.

## 0.5.0 — 21 octobre 2026
- Contenu centralisé dans `src/Shared/Content/` : zones, compagnons, quêtes, événements, cosmétiques.
  Ajouter une zone, un événement ou une traînée ne demande plus que quelques lignes.
- Map générée à partir du contenu : placement des zones sur une grille, ponts, portails, œufs, murs et
  mini-map automatiques.
- Décor très détaillé autour de chaque zone : montagnes à studs, collines lisses, îlots décorés,
  objets sur l'eau et dans le ciel, plus de 30 types d'objets, beaucoup animés :
  bonbons, gratte-ciel néon, bateaux, gelée, sapins enneigés, montgolfières, citrouilles, fantômes... Hub décoré (chemins, lampadaires, arbres,
  fleurs, bordure de bonbons).
- Chargement progressif (« render distance ») : le décor proche est détaillé, le lointain se décharge ;
  les montagnes restent visibles de loin en version simplifiée.
- Événements temporaires : premier événement **Halloween** (24 octobre – 4 novembre 2026, UTC) avec la
  zone Pumpkin Patch, un œuf de 5 compagnons, 2 quêtes et une traînée exclusive.
- Cosmétiques : 7 traînées achetables à sa machine, dont deux animées (une réservée à Halloween).
- Quêtes de zone (ne comptent que dans une zone donnée).

## 0.4.0 — 20 octobre 2026
- Zones en formes (rond, octogone, canyon en S, étoile, anneau) avec pièce centrale.
- Tapis de course dans chaque base, améliorables, qui augmentent la vitesse.
- Brouillard léger et animations du décor.

## 0.3.0 — 20 octobre 2026
- Collines peignables dans les zones, montagnes et terrain lisse autour.

## 0.2.0 — 20 octobre 2026
- Éclatement au contact, interface complète, boutique à la machine, compagnons et œufs, 5 zones,
  quêtes, cadeau des 7 jours, Rainbow Storm, didacticiel, niveau, gains hors ligne, sons choisis par Tom.

## 0.1.0 — 20 octobre 2026
- Première version : sauvegarde, bulles, peinture, pièces dans Candy Meadow.
