# ⚔️ Monster Hunter Wilds Geoguesser 🎯

Doc utilisateur complète : `USER_DOC.md`.

Le reste de ce fichier est conservé pour compatibilité mais peut être incomplet. Réfère-toi à `USER_DOC.md`.
Un jeu de géolocalisation inspiré de Geoguessr, mais adapté pour la carte du jeu vidéo Monster Hunter Wilds.

## 🚀 Installation

1. Installez les dépendances :
```bash
npm install
```

2. Créez la base de données MySQL :
```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS monster_hunter_geoguesser;"
mysql -u root monster_hunter_geoguesser < database.sql
```

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
├── database.sql         # Script de création de la base de données
├── package.json
└── vite.config.js
```

## 📝 Notes

Assurez-vous d'avoir :
- MySQL installé et en cours d'exécution
- La base de données créée et initialisée avec `database.sql`
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

### Migration d'une base existante

`database.sql` contient désormais le schéma complet (y compris la colonne `region_map_id` et les tables nécessaires).  
Si tu as déjà une base existante, vérifie que la structure correspond bien (au minimum `game_screenshots.region_map_id` et la table `high_scores`), puis ré-ajuste/import si nécessaire via l’API.

Bonne chasse et explorez bien les terres sauvages! 🌟
