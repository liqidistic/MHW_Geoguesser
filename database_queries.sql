-- Exemples de requêtes SQL pour Monster Hunter Wilds Geoguesser

-- ==========================================
-- REQUÊTES DE SÉLECTION
-- ==========================================

-- Récupérer toutes les localisations avec le nombre de cartes et captures d'écran
SELECT 
    l.id,
    l.name,
    l.x,
    l.y,
    l.description,
    COUNT(DISTINCT rm.id) AS map_count,
    COUNT(DISTINCT gs.id) AS screenshot_count
FROM locations l
LEFT JOIN region_maps rm ON l.id = rm.location_id
LEFT JOIN game_screenshots gs ON l.id = gs.location_id
GROUP BY l.id, l.name, l.x, l.y, l.description
ORDER BY l.name;

-- Récupérer une capture d'écran aléatoire avec toutes les informations nécessaires pour le jeu
SELECT 
    gs.id AS screenshot_id,
    gs.file_path AS screenshot_path,
    gs.actual_x,
    gs.actual_y,
    gs.difficulty,
    l.id AS location_id,
    l.name AS location_name,
    l.description,
    l.x AS map_x,
    l.y AS map_y,
    -- Récupérer les cartes de région associées
    (SELECT GROUP_CONCAT(rm.file_path ORDER BY rm.display_order SEPARATOR '|')
     FROM region_maps rm 
     WHERE rm.location_id = l.id) AS region_maps
FROM game_screenshots gs
JOIN locations l ON gs.location_id = l.id
ORDER BY RAND()
LIMIT 1;

-- Récupérer toutes les cartes de région pour une localisation donnée
SELECT 
    rm.id,
    rm.file_path,
    rm.display_order,
    l.name AS location_name
FROM region_maps rm
JOIN locations l ON rm.location_id = l.id
WHERE l.name = 'Ruins of Wyveria'
ORDER BY rm.display_order;

-- Get all screenshots for a given location
SELECT 
    gs.id,
    gs.file_path,
    gs.actual_x,
    gs.actual_y,
    gs.difficulty,
    gs.notes
FROM game_screenshots gs
JOIN locations l ON gs.location_id = l.id
WHERE l.name = 'Ruins of Wyveria'
ORDER BY gs.difficulty, gs.id;

-- Récupérer les localisations qui ont au moins une 
capture d'écran (pour le jeu)
SELECT 
    l.id,
    l.name,
    l.x,
    l.y,
    l.description,
    COUNT(gs.id) AS screenshot_count
FROM locations l
INNER JOIN game_screenshots gs ON l.id = gs.location_id
GROUP BY l.id, l.name, l.x, l.y, l.description
HAVING screenshot_count > 0
ORDER BY l.name;

-- ==========================================
-- INSERT QUERIES
-- ==========================================

-- Add a new screenshot
-- Example: for an 800x600px map, center would be (400, 300)
-- INSERT INTO game_screenshots (location_id, file_path, actual_x, actual_y, difficulty, notes)
-- VALUES (
--     (SELECT id FROM locations WHERE name = 'Ruins of Wyveria'),
--     '/screenshots/ruins_wyveria_01.png',
--     400,
--     300,
--     'medium',
--     'Screenshot taken in the central area of the ruins'
-- );

-- Ajouter plusieurs captures d'écran en une seule requête
-- INSERT INTO game_screenshots (location_id, file_path, actual_x, actual_y, difficulty) VALUES
-- ((SELECT id FROM locations WHERE name = 'Iceshard Cliffs'), '/screenshots/iceshard_01.png', 400, 300, 'easy'),
-- ((SELECT id FROM locations WHERE name = 'Iceshard Cliffs'), '/screenshots/iceshard_02.png', 500, 350, 'medium'),
-- ((SELECT id FROM locations WHERE name = 'Iceshard Cliffs'), '/screenshots/iceshard_03.png', 350, 250, 'hard');

-- ==========================================
-- UPDATE QUERIES
-- ==========================================

-- Update actual coordinates of a screenshot
-- UPDATE game_screenshots 
-- SET actual_x = 450, actual_y = 320
-- WHERE id = 1;

-- Mettre à jour la difficulté d'une capture d'écran
-- UPDATE game_screenshots 
-- SET difficulty = 'hard'
-- WHERE id = 1;

-- ==========================================
-- STATISTICS QUERIES
-- ==========================================

-- Statistics by location
SELECT 
    l.name AS location,
    COUNT(DISTINCT rm.id) AS map_count,
    COUNT(DISTINCT gs.id) AS screenshot_count,
    COUNT(DISTINCT CASE WHEN gs.difficulty = 'easy' THEN gs.id END) AS easy_screenshots,
    COUNT(DISTINCT CASE WHEN gs.difficulty = 'medium' THEN gs.id END) AS medium_screenshots,
    COUNT(DISTINCT CASE WHEN gs.difficulty = 'hard' THEN gs.id END) AS hard_screenshots
FROM locations l
LEFT JOIN region_maps rm ON l.id = rm.location_id
LEFT JOIN game_screenshots gs ON l.id = gs.location_id
GROUP BY l.id, l.name
ORDER BY screenshot_count DESC;

-- Statistiques globales
SELECT 
    COUNT(DISTINCT l.id) AS total_locations,
    COUNT(DISTINCT rm.id) AS total_region_maps,
    COUNT(DISTINCT gs.id) AS total_screenshots,
    COUNT(DISTINCT CASE WHEN gs.difficulty = 'easy' THEN gs.id END) AS total_easy,
    COUNT(DISTINCT CASE WHEN gs.difficulty = 'medium' THEN gs.id END) AS total_medium,
    COUNT(DISTINCT CASE WHEN gs.difficulty = 'hard' THEN gs.id END) AS total_hard
FROM locations l
LEFT JOIN region_maps rm ON l.id = rm.location_id
LEFT JOIN game_screenshots gs ON l.id = gs.location_id;

-- ==========================================
-- DELETE QUERIES
-- ==========================================

-- Delete a specific screenshot
-- DELETE FROM game_screenshots WHERE id = 1;

-- Delete all screenshots from a location
-- DELETE FROM game_screenshots 
-- WHERE location_id = (SELECT id FROM locations WHERE name = 'Ruins of Wyveria');

-- Supprimer une localisation et toutes ses données associées (grâce à CASCADE)
-- DELETE FROM locations WHERE name = 'Location Name';
