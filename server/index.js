import express from 'express';
import cors from 'cors';
import multer from 'multer';
import mysql from 'mysql2/promise';

const app = express();
const PORT = 3000;

// Multer : stockage en mémoire pour upload vers la BDD
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

app.use(cors());
app.use(express.json());

// Database connection
const db = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: '',
  database: 'monster_hunter_geoguesser',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Test database connection
db.getConnection()
  .then(connection => {
    console.log('✅ Connected to MySQL database');
    connection.release();
  })
  .catch(err => {
    console.error('❌ Database connection error:', err.message);
  });

// Get all locations with their region maps
app.get('/api/locations', async (req, res) => {
  try {
    const [locations] = await db.query('SELECT * FROM locations ORDER BY name');
    
    // Get region maps for each location
    for (const location of locations) {
      const [maps] = await db.query(
        'SELECT file_path, display_order FROM region_maps WHERE location_id = ? ORDER BY display_order',
        [location.id]
      );
      location.images = maps.map(m => m.file_path);
    }
    
    res.json(locations);
  } catch (error) {
    console.error('Error fetching locations:', error);
    res.status(500).json({ error: 'Failed to fetch locations' });
  }
});

// Récupère une image depuis la BDD (stockage BLOB)
app.get('/api/screenshots/:id/image', async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const [rows] = await db.query(
      'SELECT image_data, image_type FROM game_screenshots WHERE id = ?',
      [id]
    );
    if (rows.length === 0 || !rows[0].image_data) {
      return res.status(404).json({ error: 'Screenshot not found' });
    }
    const { image_data, image_type } = rows[0];
    const mimeTypes = { png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', webp: 'image/webp' };
    const contentType = mimeTypes[image_type] || 'image/png';
    res.set('Content-Type', contentType);
    // Les captures sont stockées en BDD (BLOB). On évite le cache navigateur
    // pour que l'UI reflète immédiatement les nouvelles importations.
    res.set('Cache-Control', 'no-store');
    res.send(image_data);
  } catch (error) {
    console.error('Error serving screenshot image:', error);
    res.status(500).json({ error: 'Failed to serve image' });
  }
});

// Récupère une capture aléatoire avec infos de localisation
// Query optionnelle : exclude=1,2,3 (IDs de captures déjà utilisées dans la partie)
app.get('/api/screenshots/random', async (req, res) => {
  try {
    const excludeRaw = req.query.exclude;
    let excludeIds = [];
    if (typeof excludeRaw === 'string' && excludeRaw.trim()) {
      excludeIds = excludeRaw
        .split(',')
        .map((s) => parseInt(s.trim(), 10))
        .filter((n) => Number.isInteger(n) && n > 0);
    }
    excludeIds = [...new Set(excludeIds)];

    const sql = `
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
        -- Résolution de la région (compat: fallback display_order=1 si besoin)
        COALESCE(
          (
            SELECT rm2.id
            FROM region_maps rm2
            WHERE rm2.id = gs.region_map_id
            LIMIT 1
          ),
          (
            SELECT rm2.id
            FROM region_maps rm2
            WHERE rm2.location_id = gs.location_id
            ORDER BY rm2.display_order
            LIMIT 1
          )
        ) AS resolved_region_map_id,
        COALESCE(
          (
            SELECT rm2.file_path
            FROM region_maps rm2
            WHERE rm2.id = gs.region_map_id
            LIMIT 1
          ),
          (
            SELECT rm2.file_path
            FROM region_maps rm2
            WHERE rm2.location_id = gs.location_id
            ORDER BY rm2.display_order
            LIMIT 1
          )
        ) AS region_map_file_path
      FROM game_screenshots gs
      JOIN locations l ON gs.location_id = l.id
      WHERE gs.image_data IS NOT NULL
      ${excludeIds.length > 0 ? `AND gs.id NOT IN (${excludeIds.map(() => '?').join(',')})` : ''}
      ORDER BY RAND()
      LIMIT 1
    `;

    const params = excludeIds.length > 0 ? excludeIds : [];
    const [screenshots] = await db.query(sql, params);

    if (screenshots.length === 0) {
      if (excludeIds.length > 0) {
        const [[{ total }]] = await db.query(
          'SELECT COUNT(*) AS total FROM game_screenshots WHERE image_data IS NOT NULL'
        );
        if (total === 0) {
          return res.status(404).json({ error: 'No screenshots available', code: 'no_screenshots' });
        }
        return res.status(404).json({
          error: 'All screenshots already used in this game',
          code: 'no_unused_screenshots',
        });
      }
      return res.status(404).json({ error: 'No screenshots available', code: 'no_screenshots' });
    }
    
    const screenshot = screenshots[0];
    screenshot.screenshot_path = `/api/screenshots/${screenshot.screenshot_id}/image`;

    // On renvoie uniquement la region_map associée à cette capture,
    // car les coordonnées actual_x/actual_y sont définies dans le repère de cette image.
    screenshot.region_maps = [screenshot.region_map_file_path];
    screenshot.region_map_id = screenshot.resolved_region_map_id;
    
    res.json(screenshot);
  } catch (error) {
    console.error('Error fetching random screenshot:', error);
    res.status(500).json({ error: 'Failed to fetch random screenshot' });
  }
});

// Upload d'une nouvelle capture d'écran
app.post('/api/screenshots', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Image file required' });
    }
    const { region_map_id, location_id, actual_x, actual_y, difficulty } = req.body;
    if (actual_x === undefined || actual_y === undefined) {
      return res.status(400).json({ error: 'actual_x, actual_y required' });
    }
    const ext = (req.file.originalname.split('.').pop() || 'png').toLowerCase();
    const imageType = ['png','jpg','jpeg','webp'].includes(ext) ? ext : 'png';

    let resolvedLocationId = null;
    let resolvedRegionMapId = null;

    // Priorité à region_map_id (nouveau modèle)
    if (region_map_id) {
      const [rows] = await db.query(
        'SELECT id, location_id FROM region_maps WHERE id = ?',
        [parseInt(region_map_id)]
      );
      if (rows.length === 0) {
        return res.status(400).json({ error: 'region_map_id not found' });
      }
      resolvedRegionMapId = rows[0].id;
      resolvedLocationId = rows[0].location_id;
    } else {
      // Compatibilité : si on n’a que location_id, on prend la region_map display_order=1
      if (!location_id) {
        return res.status(400).json({ error: 'region_map_id or location_id required' });
      }
      const [rows] = await db.query(
        'SELECT id, location_id FROM region_maps WHERE location_id = ? ORDER BY display_order LIMIT 1',
        [parseInt(location_id)]
      );
      if (rows.length === 0) {
        return res.status(400).json({ error: 'No region_map found for given location_id' });
      }
      resolvedRegionMapId = rows[0].id;
      resolvedLocationId = rows[0].location_id;
    }

    const [result] = await db.query(
      `INSERT INTO game_screenshots (location_id, region_map_id, image_data, image_type, actual_x, actual_y, difficulty, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        parseInt(resolvedLocationId),
        parseInt(resolvedRegionMapId),
        req.file.buffer,
        imageType,
        parseInt(actual_x),
        parseInt(actual_y),
        difficulty || 'medium',
        req.body.notes || null
      ]
    );
    res.status(201).json({ id: result.insertId, message: 'Screenshot added' });
  } catch (error) {
    console.error('Error uploading screenshot:', error);
    res.status(500).json({ error: 'Failed to upload screenshot' });
  }
});

// ============================
// Highscores (TOP 50)
// ============================

app.get('/api/highscores', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT pseudo, score, created_at FROM high_scores ORDER BY score DESC, created_at DESC, id DESC LIMIT 50'
    );
    res.json(rows);
  } catch (error) {
    console.error('Error fetching highscores:', error);
    res.status(500).json({ error: 'Failed to fetch highscores' });
  }
});

app.get('/api/highscores/eligible', async (req, res) => {
  try {
    const score = parseInt(req.query.score, 10);
    if (Number.isNaN(score)) {
      return res.status(400).json({ error: 'score must be an integer' });
    }

    const [rows] = await db.query(`
      SELECT
        (SELECT COUNT(*) FROM high_scores) AS total,
        (SELECT MIN(score) FROM (
          SELECT score
          FROM high_scores
          ORDER BY score DESC, created_at DESC, id DESC
          LIMIT 50
        ) t) AS cutoff_score
    `);

    const total = rows[0].total || 0;
    const cutoffScore = rows[0].cutoff_score;
    const eligible = total < 50 || cutoffScore == null || score >= cutoffScore;

    res.json({ eligible, total, cutoff_score: cutoffScore });
  } catch (error) {
    console.error('Error checking highscore eligibility:', error);
    res.status(500).json({ error: 'Failed to check eligibility' });
  }
});

app.post('/api/highscores', async (req, res) => {
  try {
    const pseudoRaw = req.body?.pseudo;
    const scoreRaw = req.body?.score;
    const pseudo = typeof pseudoRaw === 'string' ? pseudoRaw.trim() : '';
    const score = parseInt(scoreRaw, 10);

    if (!pseudo || pseudo.length < 1) {
      return res.status(400).json({ error: 'pseudo is required' });
    }
    if (pseudo.length > 32) {
      return res.status(400).json({ error: 'pseudo must be <= 32 chars' });
    }
    if (Number.isNaN(score)) {
      return res.status(400).json({ error: 'score must be an integer' });
    }

    const [rows] = await db.query(`
      SELECT
        (SELECT COUNT(*) FROM high_scores) AS total,
        (SELECT MIN(score) FROM (
          SELECT score
          FROM high_scores
          ORDER BY score DESC, created_at DESC, id DESC
          LIMIT 50
        ) t) AS cutoff_score
    `);

    const total = rows[0].total || 0;
    const cutoffScore = rows[0].cutoff_score;
    const eligible = total < 50 || cutoffScore == null || score >= cutoffScore;

    if (!eligible) {
      return res.json({ inserted: false, eligible: false });
    }

    const [result] = await db.query(
      'INSERT INTO high_scores (pseudo, score) VALUES (?, ?)',
      [pseudo, score]
    );

    // Nettoyage TOP 50 côté application pour éviter les contraintes MySQL liées aux triggers.
    // On garde les 50 meilleurs (score desc, puis created_at desc, puis id desc).
    await db.query(`
      DELETE FROM high_scores
      WHERE id NOT IN (
        SELECT id FROM (
          SELECT id
          FROM high_scores
          ORDER BY score DESC, created_at DESC, id DESC
          LIMIT 50
        ) t
      )
    `);

    res.json({ inserted: true, eligible: true, id: result.insertId });
  } catch (error) {
    console.error('Error saving highscore:', error);
    res.status(500).json({ error: 'Failed to save highscore' });
  }
});

// Get location by ID with all its data
app.get('/api/locations/:id', async (req, res) => {
  try {
    const locationId = parseInt(req.params.id);
    
    const [locations] = await db.query('SELECT * FROM locations WHERE id = ?', [locationId]);
    
    if (locations.length === 0) {
      return res.status(404).json({ error: 'Location not found' });
    }
    
    const location = locations[0];
    
    // Get region maps
    const [maps] = await db.query(
      'SELECT file_path, display_order FROM region_maps WHERE location_id = ? ORDER BY display_order',
      [locationId]
    );
    location.images = maps.map(m => m.file_path);
    
    // Get screenshots (URLs vers l'API)
    const [screenshots] = await db.query(
      'SELECT id FROM game_screenshots WHERE location_id = ? AND image_data IS NOT NULL',
      [locationId]
    );
    location.gameImages = screenshots.map(s => `/api/screenshots/${s.id}/image`);
    
    res.json(location);
  } catch (error) {
    console.error('Error fetching location:', error);
    res.status(500).json({ error: 'Failed to fetch location' });
  }
});

// Get locations that have screenshots
app.get('/api/locations/with-screenshots', async (req, res) => {
  try {
    const [locations] = await db.query(`
      SELECT DISTINCT
        l.id,
        l.name,
        l.x,
        l.y,
        l.description
      FROM locations l
      INNER JOIN game_screenshots gs ON l.id = gs.location_id
      ORDER BY l.name
    `);
    
    // Get region maps for each location
    for (const location of locations) {
      const [maps] = await db.query(
        'SELECT file_path, display_order FROM region_maps WHERE location_id = ? ORDER BY display_order',
        [location.id]
      );
      location.images = maps.map(m => m.file_path);
      
      const [screenshots] = await db.query(
        'SELECT id FROM game_screenshots WHERE location_id = ? AND image_data IS NOT NULL',
        [location.id]
      );
      location.gameImages = screenshots.map(s => `/api/screenshots/${s.id}/image`);
    }
    
    res.json(locations);
  } catch (error) {
    console.error('Error fetching locations with screenshots:', error);
    res.status(500).json({ error: 'Failed to fetch locations' });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});
