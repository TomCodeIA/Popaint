# Journal des versions de Popaint

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
