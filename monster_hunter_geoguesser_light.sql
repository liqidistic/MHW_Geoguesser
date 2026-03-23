-- Base de données pour Monster Hunter Wilds Geoguesser (version légère, sans BLOB dans game_screenshots)
CREATE DATABASE IF NOT EXISTS `monster_hunter_geoguesser` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE monster_hunter_geoguesser;

-- Table des localisations
CREATE TABLE locations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL UNIQUE,
    x DECIMAL(5,2) NOT NULL COMMENT 'Coordonnée X sur la carte principale (0-100)',
    y DECIMAL(5,2) NOT NULL COMMENT 'Coordonnée Y sur la carte principale (0-100)',
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name),
    INDEX idx_coordinates (x, y)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des cartes de région
CREATE TABLE region_maps (
    id INT PRIMARY KEY AUTO_INCREMENT,
    location_id INT NOT NULL,
    file_path VARCHAR(500) NOT NULL COMMENT 'Chemin relatif vers l\'image de la carte',
    display_order INT NOT NULL DEFAULT 1 COMMENT 'Ordre d\'affichage (1, 2, 3, etc.)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE,
    UNIQUE KEY unique_location_map (location_id, display_order),
    INDEX idx_location (location_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des captures d'écran du jeu (images stockées en BDD uniquement)
CREATE TABLE game_screenshots (
    id INT PRIMARY KEY AUTO_INCREMENT,
    location_id INT NOT NULL,
    region_map_id INT NOT NULL COMMENT 'ID de la region_map correspondante (définit le repère des coordonnées)',
    image_data LONGBLOB NOT NULL COMMENT 'Données binaires de l\'image',
    image_type VARCHAR(10) DEFAULT 'png' COMMENT 'Format: png, jpg, jpeg, webp',
    actual_x INT NOT NULL COMMENT 'Coordonnée X réelle sur la région_map (en pixels)',
    actual_y INT NOT NULL COMMENT 'Coordonnée Y réelle sur la région_map (en pixels)',
    difficulty ENUM('easy', 'medium', 'hard') DEFAULT 'medium' COMMENT 'Niveau de difficulté',
    notes TEXT COMMENT 'Notes additionnelles',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE,
    FOREIGN KEY (region_map_id) REFERENCES region_maps(id) ON DELETE CASCADE,
    INDEX idx_location (location_id),
    INDEX idx_region_map (region_map_id),
    INDEX idx_difficulty (difficulty)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertion des localisations existantes
INSERT INTO locations (name, x, y, description) VALUES
('Ruins of Wyveria', 69.00, 20.20, 'Remnants of an ancient wyveria civilization'),
('Grand Hub', 88.20, 26.70, 'The central hub for hunters'),
('Iceshard Cliffs', 59.50, 40.00, 'Steep ice cliffs'),
('Wounded Hollow', 85.50, 42.00, 'Deep and mysterious valley'),
('Scarlet Forest', 24.11, 43.00, 'Dense forest with scarlet foliage'),
('Oilwell Basin', 52.00, 64.00, 'Area rich in natural resources'),
('Suja, Peaks of Accord', 84.00, 56.50, 'The sacred peaks of Suja'),
('Training Area', 15.30, 72.00, 'Training area for hunters'),
('Windward Plains', 30.30, 85.00, 'Vast plains battered by winds');

-- Insertion des cartes de région existantes
INSERT INTO region_maps (location_id, file_path, display_order) VALUES
((SELECT id FROM locations WHERE name = 'Ruins of Wyveria'), '/maps/Ruins of Wyveria map 1.png', 1),
((SELECT id FROM locations WHERE name = 'Ruins of Wyveria'), '/maps/Ruins of Wyveria map 2.png', 2),
((SELECT id FROM locations WHERE name = 'Ruins of Wyveria'), '/maps/Ruins of Wyveria map 3.png', 3),
((SELECT id FROM locations WHERE name = 'Ruins of Wyveria'), '/maps/Ruins of Wyveria map 4.png', 4),
((SELECT id FROM locations WHERE name = 'Iceshard Cliffs'), '/maps/Iceshard Cliffs map 1.png', 1),
((SELECT id FROM locations WHERE name = 'Iceshard Cliffs'), '/maps/Iceshard Cliffs map 2.png', 2),
((SELECT id FROM locations WHERE name = 'Iceshard Cliffs'), '/maps/Iceshard Cliffs map 3.png', 3),
((SELECT id FROM locations WHERE name = 'Wounded Hollow'), '/maps/Wounded Hollow map 1.png', 1),
((SELECT id FROM locations WHERE name = 'Scarlet Forest'), '/maps/Scarlet Forest map 1.png', 1),
((SELECT id FROM locations WHERE name = 'Scarlet Forest'), '/maps/Scarlet Forest map 2.png', 2),
((SELECT id FROM locations WHERE name = 'Oilwell Basin'), '/maps/Oilwell Bassin map 1.png', 1),
((SELECT id FROM locations WHERE name = 'Oilwell Basin'), '/maps/Oilwell Bassin map 2.png', 2),
((SELECT id FROM locations WHERE name = 'Oilwell Basin'), '/maps/Oilwell Bassin map 3.png', 3),
((SELECT id FROM locations WHERE name = 'Suja, Peaks of Accord'), '/maps/Suja, Peaks of Accord map 1.png', 1),
((SELECT id FROM locations WHERE name = 'Windward Plains'), '/maps/Windward Plains map 1.png', 1),
((SELECT id FROM locations WHERE name = 'Windward Plains'), '/maps/Windward Plains map 2.png', 2);

-- Les captures d'écran s'ajoutent via l'API POST /api/screenshots (upload de fichier)

-- Vue pour récupérer les localisations avec leurs cartes de région
CREATE VIEW v_locations_with_maps AS
SELECT 
    l.id,
    l.name,
    l.x,
    l.y,
    l.description,
    COUNT(rm.id) AS map_count,
    GROUP_CONCAT(rm.file_path ORDER BY rm.display_order SEPARATOR ',') AS map_paths
FROM locations l
LEFT JOIN region_maps rm ON l.id = rm.location_id
GROUP BY l.id, l.name, l.x, l.y, l.description;

-- View to get locations with their screenshots
CREATE VIEW v_locations_with_screenshots AS
SELECT 
    l.id,
    l.name,
    l.x,
    l.y,
    l.description,
    COUNT(gs.id) AS screenshot_count
FROM locations l
LEFT JOIN game_screenshots gs ON l.id = gs.location_id
GROUP BY l.id, l.name, l.x, l.y, l.description;

-- Table Highscores (TOP 50 conservé côté application)
CREATE TABLE IF NOT EXISTS high_scores (
    id INT PRIMARY KEY AUTO_INCREMENT,
    pseudo VARCHAR(32) NOT NULL,
    score INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_score_created (score, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Requête exemple pour récupérer une capture d'écran aléatoire avec sa localisation
-- SELECT 
--     gs.id AS screenshot_id,
--     gs.file_path,
--     gs.actual_x,
--     gs.actual_y,
--     gs.difficulty,
--     l.id AS location_id,
--     l.name AS location_name,
--     l.description,
--     l.x AS location_x,
--     l.y AS location_y
-- FROM game_screenshots gs
-- JOIN locations l ON gs.location_id = l.id
-- ORDER BY RAND()
-- LIMIT 1;
