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
    res.set('Cache-Control', 'public, max-age=86400');
    res.send(image_data);
  } catch (error) {
    console.error('Error serving screenshot image:', error);
    res.status(500).json({ error: 'Failed to serve image' });
  }
});

// Récupère une capture aléatoire avec infos de localisation
app.get('/api/screenshots/random', async (req, res) => {
  try {
    const [screenshots] = await db.query(`
      SELECT 
        gs.id AS screenshot_id,
        gs.actual_x,
        gs.actual_y,
        gs.difficulty,
        l.id AS location_id,
        l.name AS location_name,
        l.description,
        l.x AS map_x,
        l.y AS map_y
      FROM game_screenshots gs
      JOIN locations l ON gs.location_id = l.id
      WHERE gs.image_data IS NOT NULL
      ORDER BY RAND()
      LIMIT 1
    `);
    
    if (screenshots.length === 0) {
      return res.status(404).json({ error: 'No screenshots available' });
    }
    
    const screenshot = screenshots[0];
    screenshot.screenshot_path = `/api/screenshots/${screenshot.screenshot_id}/image`;
    
    const [maps] = await db.query(
      'SELECT file_path, display_order FROM region_maps WHERE location_id = ? ORDER BY display_order',
      [screenshot.location_id]
    );
    screenshot.region_maps = maps.map(m => m.file_path);
    
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
    const { location_id, actual_x, actual_y, difficulty } = req.body;
    if (!location_id || actual_x === undefined || actual_y === undefined) {
      return res.status(400).json({ error: 'location_id, actual_x, actual_y required' });
    }
    const ext = (req.file.originalname.split('.').pop() || 'png').toLowerCase();
    const imageType = ['png','jpg','jpeg','webp'].includes(ext) ? ext : 'png';
    const [result] = await db.query(
      `INSERT INTO game_screenshots (location_id, image_data, image_type, actual_x, actual_y, difficulty, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        parseInt(location_id),
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
