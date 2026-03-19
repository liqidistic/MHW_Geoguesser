-- Migration : stocker les captures d'écran dans la BDD (BLOB) au lieu de fichiers
-- À exécuter sur une base existante : mysql -u root monster_hunter_geoguesser < database_migration_screenshots_blob.sql

USE monster_hunter_geoguesser;

-- Ajouter les colonnes pour le stockage BLOB
ALTER TABLE game_screenshots
ADD COLUMN image_data LONGBLOB NULL AFTER file_path,
ADD COLUMN image_type VARCHAR(10) DEFAULT 'png' AFTER image_data;

-- Rendre file_path nullable (sera supprimé après migration des données)
ALTER TABLE game_screenshots MODIFY file_path VARCHAR(500) NULL;

-- Pour une nouvelle installation, utilisez database.sql qui inclut déjà image_data
