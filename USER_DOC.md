# Documentation utilisateur - Monster Hunter Wilds Geoguesser

Jeu de géolocalisation inspiré de *Geoguessr*, adapté pour la carte de *Monster Hunter Wilds*.

## Objectif

À chaque round, une image (capture d'écran) est affichée. Vous devez cliquer sur la carte principale pour ouvrir la carte de la région, puis placer un marqueur sur la carte de région au bon endroit.

Vous jouez au total sur **5 rounds** (constante `CONFIG.totalRounds` dans `src/App.vue`).

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

`monster_hunter_geoguesser_light.sql` ne remplit pas `game_screenshots` avec des images : ajoutez les captures via `POST /api/screenshots` ou utilisez le dump complet.

**Highscores avec temps restant total** : si votre base existante a été créée avant cette fonctionnalité, ajoutez la colonne une fois (voir migration ci-dessous).

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

> Après une modification du code backend, **redémarrez** `npm run server` pour que les changements soient pris en compte.

## Comment jouer

1. Écran d’accueil :
   - Cliquez sur **« Commencer la partie »**.
   - Vous pouvez également ouvrir **Highscores** depuis l’accueil.

2. Pendant un round — **compte à rebours (30 secondes)** :
   - Un compteur **Temps** s’affiche dans l’encadré entre **Score** et **Round**.
   - Il se **réinitialise à chaque nouveau round**.
   - Si le temps arrive à **0** avant que vous ne validiez, la manche se termine seule (**0 point** pour ce round) et l’écran de résultat s’affiche.

3. Carte principale :
   - Cliquez sur un **point doré** pour afficher la carte détaillée de la zone.
   - **Double-clic** pour zoomer/dézoomer (zoom géré côté frontend).

4. Carte de région :
   - Cliquez à l’endroit où vous pensez que la capture a été prise pour placer le marqueur.
   - S’il y a **plusieurs** cartes pour la région, utilisez **Précédent** / **Suivant** pour naviguer.
   - Cliquez sur **« Faire une supposition »** pour valider (bouton actif seulement si un marqueur est placé et que la manche n’est pas déjà terminée ou expirée).
   - **« Retour »** ramène à la carte générale.

5. Résultat :
   - Le jeu affiche la distance (si la bonne région est choisie) et le **score du round**.
   - Cliquez sur **« Continuer »** pour le round suivant ou pour terminer la partie après le dernier round.

6. Fin de partie / Highscores :
   - À la fin, vous pouvez enregistrer votre pseudo si le score est **éligible au top 50**.
   - Le highscore enregistre aussi le **temps restant total** de la partie (somme des secondes restantes au moment de chaque validation).
   - Dans la fenêtre **Highscores**, chaque ligne affiche le **score** et le **temps total** restant (format `m:ss`).

## Règles de score

- **Mauvaise région** (vous validez sur une carte qui ne correspond pas à la capture) : **0 point** pour le round.
- **Bonne région** : la distance entre votre marqueur et le point réel donne un **score de distance** ; le temps restant au moment de la validation ajoute un **bonus** :
  
  **Score du round = score_distance + (temps_restant × 50)**

  où `temps_restant` est en **secondes** (valeur du compteur au clic sur « Faire une supposition »).

- **Temps écoulé** sans validation : **0 point** pour le round.

## Données utilisées (cartes et coordonnées)

Le système utilise deux types d’images :

1. Carte principale (`public/map.png`) :
   - Les positions des « points dorés » proviennent des colonnes `locations.x` et `locations.y`.
   - Elles sont stockées sur une échelle `0-100` (le frontend convertit ces valeurs en pixels).

2. Cartes de régions (`public/maps/*.png`) :
   - Les chemins des cartes de région sont stockés dans `region_maps.file_path`.
   - Chaque capture d’écran est associée à une entrée précise de `region_maps` via `game_screenshots.region_map_id`.
   - Les coordonnées réelles du marqueur (vrai emplacement) sont stockées en pixels dans `game_screenshots.actual_x` et `game_screenshots.actual_y`, **dans le repère de l’image de la region_map**.

## Interface sur petits écrans

Sur les navigateurs avec une **faible hauteur** (ex. portable avec barre d’adresse), l’interface réduit légèrement marges, paddings et hauteur des cartes pour limiter le **défilement** et garder le bouton de validation plus accessible.

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
   - Paramètre optionnel `?exclude=1,2,3` (IDs de captures déjà utilisées dans la partie).

5. `GET /api/screenshots/:id/image`
   - Retourne le binaire de l'image stockée dans MySQL (champ BLOB).
   - Met le bon `Content-Type` suivant `image_type`.

6. **Highscores**
   - `GET /api/highscores` — top 50 : `pseudo`, `score`, `total_time_remaining_seconds`, `created_at`.
   - `GET /api/highscores/eligible?score=XXXX` — indique si un score peut entrer dans le top 50.

### Endpoints POST

**Ajouter une capture** — `POST /api/screenshots`

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

**Enregistrer un highscore** — `POST /api/highscores`

- Corps JSON : `pseudo` (string), `score` (nombre entier), `totalTimeRemainingSeconds` (nombre entier, optionnel ; défaut `0` si absent ou invalide).

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

Pour une base à jour **avec toutes les données** : réimportez **`monster_hunter_geoguesser.sql`**.  
**`monster_hunter_geoguesser_light.sql`** sert de **référence de schéma** ou d’install minimale sans BLOB. Si votre base existante a déjà des captures, vérifiez la structure puis adaptez ou complétez via l’API.

**Colonne highscores (temps restant total)** — si votre table `high_scores` n’a pas encore ce champ :

```sql
ALTER TABLE high_scores
  ADD COLUMN total_time_remaining_seconds INT NOT NULL DEFAULT 0;
```

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

4. `high_scores` (top 50 géré côté application après insertion)
   - `pseudo`, `score`, `total_time_remaining_seconds` (somme des secondes restantes sur la partie au moment de chaque validation de round), `created_at`

## Dépannage rapide

1. « Impossible de charger les localisations… »
   - Vérifiez que MySQL tourne et que la base `monster_hunter_geoguesser` existe.
   - Vérifiez aussi les informations de connexion dans `server/index.js` (ici : `host=localhost`, `user=root`, `password=''`).

2. Les points dorés n’apparaissent pas
   - Vérifiez `GET /api/locations` (erreur backend ou base non initialisée).

3. Le jeu affiche « Aucune capture d'écran disponible… »
   - Avec **`monster_hunter_geoguesser_light.sql`**, la table peut être vide de captures : importez **`monster_hunter_geoguesser.sql`** ou ajoutez des captures via `POST /api/screenshots`.

4. Le champ `total_time_remaining_seconds` reste à **0** en base après enregistrement d’un highscore
   - Redémarrez le serveur Node (`npm run server`) : l’API doit insérer explicitement ce champ ; un ancien processus ne l’enverrait pas encore.

## Documentation complémentaire

- **`MODIFICATIONS.md`** : liste des changements avec références aux fichiers et lignes de code.
- **`EXPLICATIONS_MODIFICATIONS.md`** : explications textuelles des implications fonctionnelles et techniques.
