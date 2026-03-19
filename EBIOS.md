# ÉBIOS - Expression des Besoins et Identification des Objectifs de Sécurité

## Monster Hunter Wilds Geoguesser

**Version:** 1.0  
**Date:** 6 février 2025  
**Statut:** Analyse de risques de sécurité

---

## 1. Contexte et périmètre

### 1.1 Description du projet

Monster Hunter Wilds Geoguesser est une application web de type jeu géolocalisation, inspirée de Geoguessr, adaptée à l'univers du jeu vidéo Monster Hunter Wilds. L'application permet aux utilisateurs de deviner la localisation de captures d'écran sur une carte virtuelle.

### 1.2 Périmètre fonctionnel

| Composant | Technologies | Description |
|-----------|--------------|-------------|
| Frontend | Vue 3, Vite, HTML5/CSS3, Canvas API | Interface utilisateur, affichage des cartes et du jeu |
| Backend | Express.js (Node.js) | API REST pour servir les données |
| Base de données | MySQL | Stockage des localisations, cartes et captures d'écran |
| Assets | Images PNG (cartes, captures) | Contenus multimédias du jeu |

### 1.3 Périmètre technique

- **Services exposés :** API REST sur port 3000, serveur de développement Vite
- **Données traitées :** Localisations, chemins d'images, coordonnées (pas de données personnelles identifiables)
- **Utilisateurs :** Joueurs anonymes (aucune authentification requise)

---

## 2. Actifs et valeur

### 2.1 Actifs informationnels

| Actif | Description | Criticité | Confidentialité |
|-------|-------------|-----------|-----------------|
| Base de données | Localisations, structure des cartes, métadonnées | Moyenne | Faible |
| Assets images | Cartes et captures d'écran | Moyenne | Nulle |
| Code source | Application complète | Élevée | Moyenne |

### 2.2 Actifs logiciels

| Actif | Description | Criticité |
|-------|-------------|-----------|
| Serveur API | Express.js exposant les endpoints | Élevée |
| Application frontend | Vue.js compilée | Moyenne |
| Configuration BDD | Identifiants de connexion MySQL | Élevée |

---

## 3. Besoins de sécurité

### 3.1 Identification des besoins

| Besoin | Description | Priorité |
|--------|-------------|----------|
| **Disponibilité** | L'application doit rester accessible pour permettre le jeu | Élevée |
| **Intégrité** | Les données (localisations, scores calculés) ne doivent pas être altérées de manière non autorisée | Moyenne |
| **Confidentialité** | Protection des éventuelles données de configuration sensibles (identifiants BDD) | Élevée |
| **Traçabilité** | Capacité à détecter et investiguer des incidents (logs) | Faible |

### 3.2 Niveau de sensibilité des données

- **Données à caractère personnel :** Aucune (jeu anonyme)
- **Données métier :** Données de jeu (localisations, images) — sensibilité faible
- **Données techniques :** Identifiants MySQL dans le code — sensibilité élevée si exposés

---

## 4. Objectifs de sécurité

### 4.1 Objectifs définis

| Objectif | Cible | Mesure associée |
|----------|-------|-----------------|
| OS-1 | Protéger les identifiants de la base de données | Variables d'environnement |
| OS-2 | Limiter les risques d'injection SQL | Requêtes paramétrées / ORM |
| OS-3 | Contrôler l'accès aux ressources API | Validation des entrées, CORS configuré |
| OS-4 | Assurer la disponibilité du service | Gestion des erreurs, monitoring |
| OS-5 | Sécuriser les échanges (en production) | HTTPS |

---

## 5. Menaces identifiées

### 5.1 Catalogue des menaces

| ID | Menace | Source | Criticité |
|----|--------|--------|-----------|
| M1 | Injection SQL | Utilisateur malveillant / script automatisé | Élevée |
| M2 | Exposition des identifiants BDD (password vide en dur) | Mauvaise configuration | Élevée |
| M3 | Requêtes non autorisées (CORS trop permissif) | Site tiers malveillant | Moyenne |
| M4 | Déni de service (DoS) sur l'API | Attaquant externe | Moyenne |
| M5 | Exposition d'informations sensibles dans les réponses d'erreur | Configuration de développement | Faible |
| M6 | Accès non autorisé aux fichiers (chemin traversal) | Requête API manipulée | Moyenne |
| M7 | Dépendances vulnérables (npm) | Bibliothèques tierces | Moyenne |

### 5.2 Scénarios de menaces

**Scénario S1 – Compromission de la base de données**  
- M1 + M2 → Un attaquant exploite une injection SQL ou récupère les identifiants BDD  
- Impact : modification/suppression des données, accès non autorisé

**Scénario S2 – Indisponibilité du service**  
- M4 → Saturation de l’API ou du serveur MySQL  
- Impact : jeu indisponible

**Scénario S3 – Fuite d’informations**  
- M5 + M6 → Erreurs détaillées ou accès à des fichiers non prévus  
- Impact : divulgation d’informations sur l’architecture

---

## 6. Risques

### 6.1 Matrice des risques

| Risque | Probabilité | Impact | Niveau | Acceptabilité |
|--------|-------------|--------|--------|---------------|
| R1 : Compromission BDD (identifiants/ injection) | Moyenne | Élevé | Élevé | Non accepté |
| R2 : Indisponibilité du service | Faible | Moyen | Moyen | À réduire |
| R3 : Fuite d’informations techniques | Moyenne | Faible | Faible | Acceptable sous conditions |
| R4 : Vulnérabilités des dépendances | Moyenne | Moyen | Moyen | À surveiller |

---

## 7. Mesures de sécurité recommandées

### 7.1 Mesures prioritaires

| Mesure | Menace(s) ciblée(s) | Type | Difficulté |
|--------|---------------------|------|------------|
| Utiliser des variables d'environnement pour MySQL (host, user, password) | M2 | Préventif | Faible |
| Valider et sanitiser toutes les entrées utilisateur (ID, paramètres) | M1, M6 | Préventif | Moyenne |
| Configurer CORS de manière restrictive (origines autorisées uniquement) | M3 | Préventif | Faible |
| Vérifier régulièrement les vulnérabilités npm (`npm audit`) | M7 | Préventif | Faible |

### 7.2 Mesures complémentaires

| Mesure | Description |
|--------|-------------|
| Rate limiting | Limiter le nombre de requêtes par IP pour réduire les risques de DoS |
| Logging | Logger les erreurs et les accès suspects sans exposer de détails sensibles |
| HTTPS | Activer HTTPS en production (reverse proxy, certificat) |
| Headers de sécurité | Ajouter des headers HTTP (X-Content-Type-Options, etc.) |
| Validation des types | S’assurer que les paramètres (ex. `location_id`) sont bien des entiers |

### 7.3 Plan d’action suggéré

1. **Court terme** : Externaliser les identifiants BDD vers des variables d’environnement.
2. **Court terme** : Restreindre la configuration CORS.
3. **Moyen terme** : Ajouter rate limiting et validation stricte des entrées.
4. **Récurrent** : Exécuter `npm audit` et mettre à jour les dépendances vulnérables.

---

## 8. Synthèse et conclusions

### 8.1 Synthèse des risques

Le projet Monster Hunter Wilds Geoguesser présente un **profil de risque modéré** :  
- Aucune donnée personnelle n’est traitée.  
- Les principaux risques concernent l’exposition des identifiants de base de données et les attaques par injection SQL.  
- La disponibilité du service et l’intégrité des données de jeu constituent des objectifs de sécurité secondaires mais importants.

### 8.2 Niveau de maturité actuel

- **Identifiants BDD** : Faible (stockage en dur dans le code)
- **Gestion des entrées** : Moyen (requêtes paramétrées déjà utilisées)
- **CORS** : Faible (configuration actuelle trop permissive)
- **Dépendances** : À évaluer (pas de processus formalisé de mise à jour)

### 8.3 Recommandation

Mettre en œuvre les mesures prioritaires (variables d’environnement, CORS, validation des entrées) avant tout déploiement en production. Les mesures complémentaires peuvent être planifiées en fonction de l’environnement cible (hébergement, exposition publique).

---

*Document ÉBIOS – Méthodologie ANSSI – Adapté au projet Monster Hunter Wilds Geoguesser*
