# Cahier des charges — Monster Hunter Wilds Geoguesser

**Version** : alignée sur l’implémentation actuelle du dépôt  
**Document** : périmètre fonctionnel, technique et données du projet

---

## 1. Contexte et objectifs

### 1.1 Contexte

Le projet est une **application web** de type « géoguesser » : le joueur doit deviner l’emplacement d’une **capture d’écran** issue du jeu **Monster Hunter Wilds**, en s’aidant d’une **carte principale** et des **cartes de région** associées aux localisations du monde du jeu.

### 1.2 Objectifs principaux

- Offrir une **expérience de jeu** en plusieurs manches (**rounds**) avec une progression de score.
- S’appuyer sur une **base MySQL** pour les localisations, les cartes de région et les captures (stockage **BLOB** côté base).
- Exposer une **API REST** (Node.js) consommée par une interface **Vue 3** (Vite).
- Gérer un **classement** (highscores) limité aux **50 meilleurs** scores, avec enregistrement du **temps restant total** sur la partie.

### 1.3 Hors périmètre (tel que le code le laisse entendre)

- Compte utilisateur authentifié, profils, sessions serveur.
- Multijoueur temps réel.
- Application mobile native.

---

## 2. Périmètre fonctionnel

### 2.1 Profils / acteurs

| Acteur | Rôle |
|--------|------|
| **Joueur** | Lance une partie, sélectionne une région, place un marqueur, valide, consulte les résultats et éventuellement enregistre un highscore. |
| **Administrateur / contributeur** | Alimente la base (captures) via l’API d’upload ou un dump SQL ; maintient MySQL et les fichiers statiques des cartes. |

### 2.2 Parcours « partie »

1. Écran d’accueil avec lancement de la partie et accès aux highscores.
2. Pour chaque round :
   - Affichage d’une capture aléatoire (non réutilisée dans la même partie pour un même identifiant de capture, selon la logique `exclude`).
   - Affichage d’un **compte à rebours** de **30 secondes**, réinitialisé à chaque round.
   - Le joueur ouvre une localisation sur la carte principale (points dorés), accède à la carte de région, place un marqueur, valide.
   - **Expiration du temps** : fin de manche automatique avec **0 point**, affichage du résultat.
3. Après le dernier round : écran de fin de partie, liste des résultats par round, proposition d’enregistrer un pseudo si **éligible au top 50**.
4. Consultation d’un tableau des **highscores** (pseudo, score, temps restant total formaté, ordre de classement).

### 2.3 Règles de jeu (scoring)

- **Mauvaise région** (validation alors que la carte de région ouverte n’est pas celle de la capture) : **0 point** pour le round.
- **Bonne région** avec coordonnées de vérité disponibles :  
  - Calcul d’un **score de distance** à partir de l’écart en pixels entre le marqueur et `(actual_x, actual_y)` sur la carte de région.
  - **Bonus temps** : \( \text{temps\_restant en secondes} \times 50 \).  
  - **Score du round** = score_distance + bonus temps.
- **Temps écoulé** sans validation : **0 point** pour le round.
- Le **score total** est la somme des scores des rounds.

### 2.4 Highscores

- Conservation d’au plus **50** entrées « les meilleures », selon une politique de **score décroissant** puis dates / identifiants (voir implémentation serveur).
- Enregistrement d’une ligne avec au minimum : **pseudo**, **score**, **total_time_remaining_seconds** (somme des secondes restantes à chaque validation de round sur la partie), **horodatage**.
- Vérification d’**éligibilité** avant affichage du formulaire d’enregistrement (endpoint dédié).

### 2.5 Gestion du contenu (captures)

- Upload de captures via **POST /api/screenshots** en **multipart** (fichier image + rattachement à une `region_map` + coordonnées réelles).
- Formats image acceptés côté serveur : notamment `png`, `jpg`, `jpeg`, `webp`.

---

## 3. Exigences d’interface utilisateur

- **Carte principale** : interaction clic / double-clic (zoom), points de localisation visibles.
- **Vue région** : placement du marqueur, pan / zoom selon implémentation, boutons Retour, Précédent/Suivant si plusieurs cartes.
- **Panneau de contrôle** : affichage **Score**, **Temps** (entre Round et Score côté disposition actuelle), **Round** courant / total.
- **Bouton de validation** désactivé si aucun marqueur ou si la manche est déjà résolue / expirée.
- **Modales** : résultat par round, fin de partie, highscores, prompt pseudo.
- **Adaptation** : réduction des espacements et hauteurs d’images sur **petites hauteurs de viewport** pour limiter le défilement vers les actions principales.
- Effet **confetti** optionnel en cas d’éligibilité au top 50 (expérience utilisateur).

---

## 4. Exigences non fonctionnelles

### 4.1 Performance et disponibilité

- Temps de réponse API raisonnable en usage local (pas de SLA formalisé dans le code ; dépend de la machine et de MySQL).
- Les images BLOB sont servies avec en-têtes limitant le cache navigateur lorsque c’est pertinent pour le développement.

### 4.2 Sécurité (niveau actuel du projet)

- Pas d’authentification forte sur les highscores : le pseudo est une chaîne contrôlée en longueur côté API.
- Connexion MySQL paramétrée dans la configuration serveur (mot de passe, hôte : à sécuriser en environnement réel).

### 4.3 Compatibilité

- Navigateur moderne (JavaScript ES modules, Vue 3).
- Stack locale : **Node.js**, **MySQL**, ports typiques **3000** (API) et **5173** (Vite dev).

---

## 5. Architecture technique

### 5.1 Frontend

- **Vue 3** (Composition API, script setup).
- **Vite** pour le build et le serveur de développement avec **proxy** vers `/api`.

### 5.2 Backend

- **Node.js**, **Express**.
- **mysql2** (pool de connexions).
- **multer** pour les uploads.
- Endpoints documentés dans **`USER_DOC.md`** (localisations, captures aléatoires, image BLOB, highscores, upload).

### 5.3 Base de données

Tables principales (schéma de référence : scripts SQL du dépôt) :

- **`locations`** : localisations sur la carte principale (coordonnées normalisées, etc.).
- **`region_maps`** : cartes de région liées à une localisation.
- **`game_screenshots`** : captures (BLOB, type MIME, lien `location_id` + `region_map_id`, coordonnées réelles, difficulté, notes).
- **`high_scores`** : classement (pseudo, score, `total_time_remaining_seconds`, date).

---

## 6. Contraintes et hypothèses

- Les fichiers cartographiques statiques (`public/map.png`, `public/maps/...`) doivent être **cohérents** avec les chemins stockés en base.
- La logique « **top 50** » suppose une **base** avec la colonne `total_time_remaining_seconds` sur `high_scores` ; une migration manuelle peut être nécessaire sur une base ancienne (voir `USER_DOC.md`).
- Le nombre de rounds (**5**) et la durée d’un round (**30 s**) sont des **constantes applicatives** modifiables dans le code frontend.

---

## 7. Livrables attendus (produit logiciel)

- Code source du frontend et du backend.
- Scripts SQL d’initialisation / référence (`monster_hunter_geoguesser.sql`, `monster_hunter_geoguesser_light.sql`, etc.).
- Documentation utilisateur **`USER_DOC.md`**.
- Possibilité de construire une version production du frontend via **`npm run build`**.

---

## 8. Critères d’acceptation (synthèse)

| ID | Critère |
|----|--------|
| A1 | Une partie complète de N rounds (N = valeur configurée) se déroule sans erreur bloquante avec une base peuplée de captures. |
| A2 | Le compte à rebours démarre à chaque round, s’affiche à l’écran et provoque une fin de manche à 0 avec score nul si aucune validation. |
| A3 | La validation sur la mauvaise région attribue 0 point ; la bonne région applique la formule distance + bonus temps. |
| A4 | Les highscores s’affichent avec score et temps total ; l’enregistrement envoie et persiste `total_time_remaining_seconds`. |
| A5 | L’upload d’une capture via l’API alimente la table `game_screenshots` et la capture est jouable dans `GET /api/screenshots/random`. |

---

## 9. Références internes au projet

- **`USER_DOC.md`** : installation, jeu, API, schéma, dépannage.
- **`MODIFICATIONS.md`** / **`EXPLICATIONS_MODIFICATIONS.md`** : historique et implications des évolutions récentes (timer, score, highscores, UI).
