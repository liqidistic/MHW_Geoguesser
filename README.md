# ⚔️ Monster Hunter Wilds Geoguesser 🎯

Doc utilisateur complète : `USER_DOC.md`.

Le reste de ce fichier est conservé pour compatibilité mais peut être incomplet. Réfère-toi à `USER_DOC.md`.
Un jeu de géolocalisation inspiré de Geoguessr, mais adapté pour la carte du jeu vidéo Monster Hunter Wilds.

## 🚀 Installation

1. Installez les dépendances :
```bash
npm install
```

2. Importez la base MySQL (**un seul fichier** suffit : chaque script contient `CREATE DATABASE IF NOT EXISTS`, `USE`, puis tables et données) :
```bash
mysql -u root < monster_hunter_geoguesser.sql
```
*(Si le compte `root` a un mot de passe : `mysql -u root -p < monster_hunter_geoguesser.sql`.)*

- **`monster_hunter_geoguesser.sql`** : base **complète**, y compris les captures en BLOB.
- **`monster_hunter_geoguesser_light.sql`** : même principe (**un import**), mais **sans** données lourdes dans `game_screenshots` (schéma + localisations / cartes ; tu complètes les captures via l’API si besoin).

3. Dans un premier terminal, lancez le serveur backend :
```bash
npm run server
```

4. Dans un second terminal, lancez le serveur de développement frontend :
```bash
npm run dev
```

5. Pour créer une version de production :
```bash
npm run build
```

## 🎮 Comment jouer

1. **Observez l'image** affichée à gauche - c'est une capture d'écran de Monster Hunter Wilds
2. **Cliquez sur une localisation** (point doré) sur la carte principale pour voir sa carte détaillée
3. **Placez votre marqueur** sur la carte de région où vous pensez que la capture d'écran a été prise
4. **Cliquez sur "Faire une supposition"** pour valider votre choix
5. **Consultez le résultat** et continuez pour les 5 rounds!

## 🛠️ Technologies utilisées

- Vue 3 (Composition API)
- Vite
- Express.js (Backend API)
- MySQL (Base de données)
- Canvas API
- HTML5 / CSS3

## 📁 Structure du projet

```
├── src/
│   ├── App.vue          # Composant principal
│   ├── main.js          # Point d'entrée
│   └── style.css        # Styles globaux
├── server/
│   └── index.js         # Serveur backend Express
├── public/
│   ├── map.png          # Carte principale
│   └── maps/            # Cartes de régions
├── monster_hunter_geoguesser.sql       # Import complet (CREATE DATABASE + données + BLOB)
├── monster_hunter_geoguesser_light.sql   # Import léger (CREATE DATABASE + schéma, sans BLOB)
├── package.json
└── vite.config.js
```

## 📝 Notes

Assurez-vous d'avoir :
- MySQL installé et en cours d'exécution
- La base importée avec `monster_hunter_geoguesser.sql` (ou `monster_hunter_geoguesser_light.sql` sans captures en base)
- Les cartes de régions dans le dossier `public/maps/`

## 📸 Ajouter des captures d'écran

Les captures sont stockées **uniquement en base de données** (pas de fichiers dans le projet). Utilisez l'API :

```bash
curl -X POST http://localhost:3000/api/screenshots \
  -F "image=@/chemin/vers/capture.png" \
  -F "region_map_id=12" \
  -F "actual_x=400" \
  -F "actual_y=300" \
  -F "difficulty=medium"
```

- **region_map_id** : ID de la region_map (voir `SELECT id, file_path FROM region_maps`)
- **actual_x, actual_y** : coordonnées réelles sur l'image de la region_map (en pixels)
- **difficulty** : `easy`, `medium` ou `hard` (optionnel)

Pour tirer une capture **sans répéter** des IDs déjà utilisés dans la partie, l’API `GET /api/screenshots/random` accepte un paramètre optionnel `exclude` (liste d’IDs séparés par des virgules), par ex. `?exclude=3,7,12`.

### Migration d'une base existante

Pour repartir de zéro avec le jeu complet : réimporte **`monster_hunter_geoguesser.sql`**.  
Pour une base légère ou la référence de schéma sans BLOB : **`monster_hunter_geoguesser_light.sql`**. Si tu as déjà des captures, vérifie la structure (`region_map_id`, `high_scores`, etc.) puis complète via l’API si besoin.

