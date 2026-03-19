## MHW Geoguesser

Projet pour deviner des lieux liés à **Monster Hunter World** à partir d'indices (type Geoguessr).

### Installation

1. Assure-toi d'avoir **Git** et les dépendances nécessaires (par ex. Node, Python, etc. selon le projet).
2. Clone le dépôt une fois créé sur GitHub :
   ```bash
   git clone https://github.com/<ton-pseudo>/MHW_Geoguesser.git
   ```

### Développement

- Ajoute ici les commandes pour lancer le projet (par ex. `npm install`, `npm run dev`, etc.).

### Licence

Ajoute ici la licence de ton choix (MIT, GPL, etc.).
# ⚔️ Monster Hunter Wilds Geoguesser 🎯

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
  -F "location_id=1" \
  -F "actual_x=400" \
  -F "actual_y=300" \
  -F "difficulty=medium"
```

- **location_id** : ID de la localisation (voir `SELECT id, name FROM locations`)
- **actual_x, actual_y** : coordonnées réelles sur la carte de région (en pixels)
- **difficulty** : `easy`, `medium` ou `hard` (optionnel)

### Migration d'une base existante

Si vous aviez des captures avec `file_path`, exécutez :
```bash
mysql -u root monster_hunter_geoguesser < database_migration_screenshots_blob.sql
```
Puis ré-importez les captures via l'API ci-dessus.

Bonne chasse et explorez bien les terres sauvages! 🌟
