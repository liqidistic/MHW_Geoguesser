-- Requêtes SQL d'exemples qui correspondent aux requêtes réellement utilisées
-- dans le backend (voir server/index.js).

-- ==========================
-- API /api/locations
-- ==========================

-- GET /api/locations
SELECT *
FROM locations
ORDER BY name;

-- Récupération des cartes de région pour une location (appelée dans une boucle côté JS)
SELECT file_path, display_order
FROM region_maps
WHERE location_id = ?
ORDER BY display_order;

-- ==========================
-- API /api/locations/:id
-- ==========================

-- GET /api/locations/:id (infos location)
SELECT *
FROM locations
WHERE id = ?;

-- GET /api/locations/:id (cartes de région)
SELECT file_path, display_order
FROM region_maps
WHERE location_id = ?
ORDER BY display_order;

-- GET /api/locations/:id (IDs des captures disponibles)
SELECT id
FROM game_screenshots
WHERE location_id = ?
  AND image_data IS NOT NULL;

-- ==========================
-- API /api/locations/with-screenshots
-- ==========================

-- GET /api/locations/with-screenshots (liste des locations avec au moins une capture)
SELECT DISTINCT
  l.id,
  l.name,
  l.x,
  l.y,
  l.description
FROM locations l
INNER JOIN game_screenshots gs ON l.id = gs.location_id
ORDER BY l.name;

-- (ensuite côté JS : requêtes identiques à /api/locations/:id pour region_maps + screenshot ids)

-- ==========================
-- API /api/screenshots/:id/image
-- ==========================

-- GET /api/screenshots/:id/image (BLOB image)
SELECT image_data, image_type
FROM game_screenshots
WHERE id = ?;

-- ==========================
-- API /api/screenshots/random
-- ==========================

-- GET /api/screenshots/random (une capture aléatoire + info localisation + region_map associée)
SELECT
  gs.id AS screenshot_id,
  gs.actual_x,
  gs.actual_y,
  gs.difficulty,
  l.id AS location_id,
  l.name AS location_name,
  l.description,
  l.x AS map_x,
  l.y AS map_y,
  COALESCE(
    (SELECT rm2.id
     FROM region_maps rm2
     WHERE rm2.id = gs.region_map_id
     LIMIT 1),
    (SELECT rm2.id
     FROM region_maps rm2
     WHERE rm2.location_id = gs.location_id
     ORDER BY rm2.display_order
     LIMIT 1)
  ) AS resolved_region_map_id,
  COALESCE(
    (SELECT rm2.file_path
     FROM region_maps rm2
     WHERE rm2.id = gs.region_map_id
     LIMIT 1),
    (SELECT rm2.file_path
     FROM region_maps rm2
     WHERE rm2.location_id = gs.location_id
     ORDER BY rm2.display_order
     LIMIT 1)
  ) AS region_map_file_path
FROM game_screenshots gs
JOIN locations l ON gs.location_id = l.id
WHERE gs.image_data IS NOT NULL
ORDER BY RAND()
LIMIT 1;

-- ==========================
-- API /api/screenshots (upload)
-- ==========================

-- Résolution region_map_id (modèle "nouveau" : on part de region_map_id)
SELECT id, location_id
FROM region_maps
WHERE id = ?;

-- Résolution region_map_id (compatibilité : on part de location_id, display_order=1)
SELECT id, location_id
FROM region_maps
WHERE location_id = ?
ORDER BY display_order
LIMIT 1;

-- Insertion d'une capture
-- (image_data = BLOB fournie par l'API)
INSERT INTO game_screenshots
  (location_id, region_map_id, image_data, image_type, actual_x, actual_y, difficulty, notes)
VALUES
  (?, ?, ?, ?, ?, ?, ?, ?);

-- ==========================
-- Highscores (TOP 50)
-- ==========================

-- GET /api/highscores (Top 50)
SELECT pseudo, score, created_at
FROM high_scores
ORDER BY score DESC, created_at DESC, id DESC
LIMIT 50;

-- GET /api/highscores/eligible?score=...
SELECT
  (SELECT COUNT(*) FROM high_scores) AS total,
  (SELECT MIN(score) FROM (
     SELECT score
     FROM high_scores
     ORDER BY score DESC, created_at DESC, id DESC
     LIMIT 50
   ) t) AS cutoff_score;

-- POST /api/highscores (insertion)
INSERT INTO high_scores (pseudo, score)
VALUES (?, ?);

-- Nettoyage TOP 50 (côté application après insertion, pour éviter les problèmes de triggers)
DELETE FROM high_scores
WHERE id NOT IN (
  SELECT id FROM (
    SELECT id
    FROM high_scores
    ORDER BY score DESC, created_at DESC, id DESC
    LIMIT 50
  ) t
);
