# Popaint — instructions pour l'IA qui travaille sur ce dépôt

Popaint est un jeu Roblox (simulateur coloré « dopamine bomb », style stud) développé par Tom,
**100 % avec l'IA**. Tom n'écrit pas de code : il décrit ce qu'il veut, l'IA code, teste et lui livre
un fichier `build/Popaint.rbxl` qu'il ouvre dans Roblox Studio et publie par-dessus son jeu.
Des mises à jour de contenu sont prévues **toutes les 2 semaines**.

## Façon de travailler avec Tom (important)
- Tom parle français. Réponds en français, simplement, sans jargon.
- **Avant de coder, pose toutes les questions nécessaires** (Tom l'a demandé explicitement), puis
  continue à poser des questions à chaque étape. Propose des choix avec une option recommandée.
- Ne livre **jamais** sans que `tools/check.sh` soit entièrement vert.
- Livre le fichier `build/Popaint.rbxl` et rappelle comment l'installer : Studio → File → Open from
  File, puis File → Publish to Roblox As… sur le jeu existant (overwrite).
- Le document de conception (claude.ai) décrit le jeu ; tiens-le à jour quand une règle change.

## Démarrer une session
```bash
tools/setup.sh      # installe Lune + luau-lsp dans .tools/ (une fois)
tools/check.sh      # types, analyse stricte, construction, tests contenu/map, serveur simulé
```
`tools/check.sh --quick` saute le serveur simulé (plus rapide pendant le travail ; jamais pour livrer).

## Organisation
| Dossier | Contenu |
| --- | --- |
| `src/Shared/Content/` | **le contenu** : Zones, Companions, Quests, Events, Cosmetics (lu par le jeu ET le générateur de map) |
| `src/Shared/` | Config (équilibrage), Formulas (formules pures), Locale (textes en 5 langues), Remotes |
| `src/Server/` | services serveur (un fichier par système) ; `Main.server.luau` fixe l'ordre de démarrage |
| `src/Client/` | interface et effets côté joueur ; `ClientMain.client.luau` démarre les modules |
| `src/Client/Quality.luau` + `Detail.luau` + `DayNight.luau` | fluidité automatique, détails de près, cycle jour/nuit |
| `tools/build.luau` + `tools/map/` | fabrique le fichier de jeu : scripts + map entière (générée à partir du contenu) ; `tools/map/hub.luau` = fontaine, place, bord du hub, massifs |
| `tests/` | `unit` (formules, contenu), `place` (fichier de jeu, map), `integration` (vrais scripts dans un serveur simulé) |
| `CHANGELOG.md` | une entrée par version livrée |

La map est **entièrement générée** par `tools/map/` : ne demande jamais à Tom de construire à la main.

## Recettes de mise à jour
- **Nouvelle zone** : une entrée dans `Content/Zones.luau` (Cell libre et voisine de From, Shape,
  Centerpiece, Theme), 5 compagnons dans `Companions.luau` (une rareté chacun), le texte `Zone_<Id>`
  dans les 5 langues de `Locale.luau`. Nouvelle forme / pièce centrale / thème / objet de décor :
  `tools/map/shapes.luau`, `centerpieces.luau`, `themes.luau`, `props.luau` (et les listes connues dans
  `tests/unit.luau`). Les œufs, portails, ponts, mini-map et décor se font tout seuls.
- **Événement** : `Content/Events.luau` (dates UTC), sa zone (`Event = "<Id>"`), ses compagnons, ses
  quêtes (`Event`), ses traînées (`Event`), le texte `Ev_<Id>`. Dans Studio les événements sont toujours
  actifs (`Config.ForceEventsInStudio`) pour que Tom puisse tester.
- **Quêtes** : `Content/Quests.luau` ; types disponibles listés en tête du fichier. Un nouveau type
  demande du code dans `src/Server/QuestService.luau` + la liste `KNOWN_QUEST_TYPES` des tests.
- **Cosmétiques** : `Content/Cosmetics.luau`.
- **Apparence d'un compagnon** : champ `Look` (Body, Extras, Accent) dans `Content/Companions.luau` ;
  formes et accessoires dans `src/Shared/CompanionModels.luau` (listes vérifiées par les tests).
- **Style** : pastel (`lib.P` dans `tools/map/lib.luau`, couleurs de `Ui.luau`) ; le doré doux est
  réservé aux récompenses. **Aucun fluo** : le matériau `Neon` est interdit partout (un test le
  vérifie) ; pour faire briller, utilise `lib.glow` ou `M.Glass`.
- **Donner du volume** : `lib.roundBox` (boîte à coins arrondis), `lib.blob` (boule déformée) et
  `lib.drips` (glaçage qui coule le long d'un bord). Les petites pièces vont dans `lib.details(m)`
  (affichées seulement de près) et les animations se posent avec `lib.anim` (Spin, Bob, Pulse, Wobble,
  Sway, Drift, Swim, Blink, Flow, Hop, Shake). Une nouvelle animation s'ajoute dans
  `src/Client/Animator.luau` **et** dans la liste `valid` de `tests/place.luau`.
- **Particules** : `lib.particles(pièce, genre, couleurs, opts)` avec les genres de `lib.PARTICLE_KINDS`
  (Petals, Soap, Fireflies, Snow, Dust, Leaves, Sparkle, Aura) ; `lib.airBox` crée la pièce invisible
  qui les porte. L'ambiance d'une zone se règle dans le champ `Air` de son thème (`themes.luau`).
- **Fluidité** : `src/Client/Quality.luau` choisit un niveau (1 léger / 2 moyen / 3 beau) selon le
  réglage graphique du joueur et ses images par seconde ; Detail, Animator, Pets et Bubbles s'en
  servent. N'ajoute pas de distance en dur : passe par `Quality.settings()`.
- **Vérifier un modèle sans Studio** : `tools/preview.sh props|companions|base|centerpieces|showcase`
  → image dans `build/preview/` (à regarder, et à envoyer à Tom). `showcase` = fontaine, œuf, portail,
  pont, montagne, îlot.
- **Ne jamais couvrir une case peignable** : dans une zone, tout décor passe par `info.InMask`
  (cases) et `info.FreeR` (rayon libre au centre) ; un test vérifie qu'aucune pièce ne déborde.
- **Équilibrage** : `src/Shared/Config.luau`.

## Règles à ne jamais casser (sinon perte de progression des joueurs)
- Ne change jamais `Config.DataStoreName`.
- Dans `DataService.Template`, on **ajoute** des clés, on n'en renomme ni n'en supprime aucune.
- Ne supprime jamais un compagnon ni un cosmétique qui a déjà été disponible (des joueurs les ont).
  Après un événement, on peut retirer sa zone, l'événement et ses quêtes, mais on garde ses compagnons
  (leur `Egg` peut pointer vers une zone retirée : ils restent valides) et ses traînées.
- Le serveur décide de tout (pièces, achats, éclatements) ; le client ne fait qu'afficher et demander.
- Chaque texte visible passe par `Locale` et existe dans les 5 langues (un test le vérifie).

## Livrer une version
1. Augmente `Config.Version` et ajoute une entrée en haut de `CHANGELOG.md`.
2. `tools/check.sh` entièrement vert.
3. Envoie `build/Popaint.rbxl` à Tom (ne commit pas `build/`, il est ignoré).
4. Commit sur une branche, ouvre une PR vers `main` (ou pousse sur `main` si Tom l'a demandé).

## Limites connues des tests
Les tests exécutent les vrais scripts serveur dans un serveur simulé (Lune), mais l'**interface et le
rendu à l'écran** ne peuvent être vérifiés que par Tom dans Studio (y compris l'émulateur mobile).
Lune stocke les attributs entiers en float32 : le simulateur utilise donc des dates petites (1970) ;
les tests d'événements avancent l'horloge explicitement.
Le rendu d'aperçu est lent sur les très gros modèles (tout le hub) : préfère `showcase` ou un chemin
précis plutôt que `Workspace.Map.Hub`.
