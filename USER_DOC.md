# Documentation utilisateur - Monster Hunter Wilds Geoguesser

Jeu de géolocalisation inspiré de *Geoguessr*, adapté pour la carte de *Monster Hunter Wilds*.

## Objectif

À chaque round, une image (capture d'écran) est affichée. Tu dois cliquer sur la carte principale pour ouvrir la carte de la région, puis placer un marqueur sur la carte de région au bon endroit.

Tu joues au total sur `5` rounds (voir `CONFIG.totalRounds` dans `src/App.vue`).

## Pré-requis

1. Node.js (pour le frontend et le backend)
2. MySQL (pour stocker les localisations, cartes de région et captures d'écran)
3. Un dossier `public/` contenant les images de carte nécessaires :
   - `public/map.png` : carte principale
   - `public/maps/*.png` : cartes de régions

## Installation (local)

1. Installer les dépendances :

```bash
npm install
```

2. Importer la base MySQL en **une seule commande**. Les scripts **`monster_hunter_geoguesser.sql`** et **`monster_hunter_geoguesser_light.sql`** commencent tous les deux par **`CREATE DATABASE IF NOT EXISTS`** puis **`USE`**, puis créent les tables ; seul le fichier **complet** inclut les **BLOB** des captures.

```bash
mysql -u root < monster_hunter_geoguesser.sql
```

*(Avec mot de passe sur `root` : `mysql -u root -p < monster_hunter_geoguesser.sql`.)*

**Version légère** (même principe d’import, un seul fichier) :

```bash
mysql -u root < monster_hunter_geoguesser_light.sql
```

`monster_hunter_geoguesser_light.sql` ne remplit pas `game_screenshots` avec des images : ajoute les captures via `POST /api/screenshots` ou utilise le dump complet.

3. Démarrer les deux serveurs (deux terminaux) :

- Backend (API) :

```bash
npm run server
```

- Frontend (interface) :

```bash
npm run dev
```

Le backend écoute sur `http://localhost:3000` et le frontend utilise le proxy Vite pour appeler `/api`.

## Comment jouer

1. Écran d'accueil :
   - Clique sur “Commencer la partie”.

2. Carte principale :
   - Clique sur un point doré pour afficher la carte détaillée de la zone.
   - Double-clic pour zoomer/dézoomer (zoom géré côté frontend).

3. Carte de région :
   - Clique à l’endroit où tu penses que la capture a été prise pour placer le marqueur.
   - Clique sur “Faire une supposition” pour valider.

4. Résultat :
   - Le jeu affiche la distance et le score du round.
   - Passe au round suivant via “Round suivant”, jusqu’à la fin de partie.

## Données utilisées (cartes et coordonnées)

Le système utilise deux types d’images :

1. Carte principale (`public/map.png`) :
   - Les positions des “points dorés” proviennent des colonnes `locations.x` et `locations.y`.
   - Elles sont stockées sur une échelle `0-100` (le frontend convertit ces valeurs en pixels).

2. Cartes de régions (`public/maps/*.png`) :
   - Les chemin(s) des cartes de région sont stockés dans `region_maps.file_path`.
   - Chaque capture d’écran est associée à une entrée précise de `region_maps` via `game_screenshots.region_map_id`.
   - Les coordonnées réelles du marqueur (vrai emplacement) sont stockées en pixels dans `game_screenshots.actual_x` et `game_screenshots.actual_y`, **dans le repère de l’image de la region_map**.

## Backend : API utilisée par le jeu

### Endpoints GET

1. `GET /api/locations`
   - Retourne la liste des localisations, et pour chacune les chemins des cartes de région.
   - Utilisé au démarrage pour afficher les points dorés.

2. `GET /api/locations/:id`
   - Retourne les données d’une localisation, incluant :
     - `images` (cartes de région via `region_maps`)
     - `gameImages` (URLs des captures via `/api/screenshots/:id/image`)

3. `GET /api/locations/with-screenshots`
   - Retourne les localisations qui ont au moins une capture d'écran.
   - (Peu/pas utilisé par l'interface actuelle, mais disponible.)

4. `GET /api/screenshots/random`
   - Retourne une capture aléatoire et les infos nécessaires au round, incluant :
     - `screenshot_path` (URL pour récupérer l'image)
     - `region_maps` (liste des chemins des cartes de région)

5. `GET /api/screenshots/:id/image`
   - Retourne le binaire de l'image stockée dans MySQL (champ BLOB).
   - Met le bon `Content-Type` suivant `image_type`.

### Endpoint POST (ajouter une capture)

`POST /api/screenshots`

- Requiert un `multipart/form-data` avec :
  - `image` (fichier image)
  - `region_map_id` (int) : clé de la région_map (voir `region_maps.id`)
  - `actual_x` (int, coordonnées réelles en pixels sur l’image de la region_map)
  - `actual_y` (int, coordonnées réelles en pixels sur l’image de la region_map)
  - `difficulty` (optionnel : `easy`, `medium`, `hard`)
  - `notes` (optionnel)

Exemple :

```bash
curl -X POST http://localhost:3000/api/screenshots \
  -F "image=@/chemin/vers/capture.png" \
  -F "region_map_id=12" \
  -F "actual_x=400" \
  -F "actual_y=300" \
  -F "difficulty=medium"
```

Notes :

- Le serveur accepte `png`, `jpg`, `jpeg`, `webp`. Sinon, il stocke comme `png`.
- Les captures sont stockées en base (champ `game_screenshots.image_data`) : le dossier `public/screenshots/` n'est pas utilisé pour les données du jeu.

### Récupérer un `region_map_id`
```sql
SELECT
  rm.id,
  l.name AS location_name,
  rm.display_order,
  rm.file_path
FROM region_maps rm
JOIN locations l ON l.id = rm.location_id
ORDER BY l.name, rm.display_order;
```

### Migration d'une base existante

Pour une base à jour **avec toutes les données** : réimporte **`monster_hunter_geoguesser.sql`**.  
**`monster_hunter_geoguesser_light.sql`** sert de **référence de schéma** ou d’install minimale sans BLOB. Si ta base existante a déjà des captures, vérifie la structure puis adapte ou complète via l’API.

## Structure de la base de données

Les scripts SQL décrivent / créent notamment :

1. `locations`
   - `id`, `name`, `x`, `y`, `description`
   - `x`/`y` sont des coordonnées normalisées pour la carte principale (`0-100`).

2. `region_maps`
   - `location_id`, `file_path`, `display_order`
   - Sert à afficher la carte de région correspondante à la localisation.

3. `game_screenshots`
   - `location_id`, `region_map_id`, `image_data` (BLOB), `image_type`
   - `actual_x`, `actual_y` (coordonnées réelles en pixels sur l’image de la region_map)
   - `difficulty`, `notes`

## Dépannage rapide

1. “Impossible de charger les localisations…”
   - Vérifie que MySQL tourne et que la base `monster_hunter_geoguesser` existe.
   - Vérifie aussi les informations de connexion dans `server/index.js` (ici : `host=localhost`, `user=root`, `password=''`).

2. Les points dorés n’apparaissent pas
   - Vérifie `GET /api/locations` (erreur backend ou base non initialisée).

3. Le jeu affiche “Aucune capture d'écran disponible…”
   - Avec **`monster_hunter_geoguesser_light.sql`**, la table peut être vide de captures : importe **`monster_hunter_geoguesser.sql`** ou ajoute des captures via `POST /api/screenshots`.

