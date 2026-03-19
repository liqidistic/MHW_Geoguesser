<template>
  <div class="container">
    <!-- Écran d'accueil -->
    <div v-if="showWelcomeScreen" class="welcome-screen">
      <div class="welcome-content">
        <h1>⚔️ Monster Hunter Wilds 🎯 Geoguesser</h1>
        <p class="welcome-subtitle">
          Devinez où se trouve cette localisation sur la carte de Monster Hunter Wilds
        </p>
        <div class="welcome-info">
          <h2>Comment jouer ?</h2>
          <ul class="welcome-instructions">
            <li>📸 Observez l'image de gauche - c'est une capture d'écran de Monster Hunter Wilds</li>
            <li>🗺️ Cliquez sur une localisation (point doré) sur la carte principale pour voir sa carte détaillée</li>
            <li>📍 Placez votre marqueur sur la carte de région où vous pensez que la capture d'écran a été prise</li>
            <li>✅ Cliquez sur "Faire une supposition" pour valider votre choix</li>
            <li>🎯 Consultez le résultat et continuez pour les {{ CONFIG.totalRounds }} rounds !</li>
          </ul>
        </div>
        <button class="btn btn-primary welcome-start-btn" @click="startGame">
          Commencer la partie
        </button>
      </div>
    </div>

    <!-- Jeu principal -->
    <div v-else>
      <header>
        <h1>⚔️ Monster Hunter Wilds Geoguesser 🎯</h1>
        <p class="subtitle">
          Devinez où se trouve cette localisation sur la carte de Monster Hunter Wilds
        </p>
      </header>

      <div class="game-area">
      <div class="image-container">
        <div v-if="loading" class="loading">Chargement de l'image...</div>
        <div v-if="apiError" class="loading" style="color: #ff6b6b;">{{ apiError }}</div>
        <img 
          v-if="currentGameImage" 
          :src="currentGameImage" 
          alt="Localisation à deviner"
          class="location-image"
          :class="{ visible: !loading }"
          @load="loading = false"
        />
      </div>

      <div class="map-container">
        <!-- Vue carte principale -->
        <div v-show="showMainMap" class="map-view">
          <div
            class="map-zoom-wrapper"
            :style="{ transform: `scale(${mainMapZoom})` }"
          >
            <div style="position: relative; display: inline-block;">
              <img
                ref="mapImage"
                src="/map.png"
                alt="Carte de Monster Hunter Wilds"
                class="map-image"
                @load="onMapImageLoad"
              />
              <canvas 
                ref="mapOverlay"
                class="map-overlay-canvas"
                @click="handleMapClick"
              ></canvas>
            </div>
          </div>
          <div class="map-overlay-text">
            <p>Cliquez sur les localisations (points dorés) pour afficher leur carte et placer votre marqueur. Double-clic pour zoomer/dézoomer.</p>
          </div>
        </div>

        <!-- Vue carte de région -->
        <div v-show="!showMainMap" class="location-image-view">
          <div
            class="map-zoom-wrapper"
            :style="{ transform: `scale(${regionZoom})` }"
          >
            <div style="position: relative; display: inline-block;">
              <img 
                ref="locationDetailImage"
                :src="currentLocationImage"
                alt="Image de la localisation"
                class="location-detail-image"
                @load="onRegionImageLoad"
              />
              <canvas 
                ref="regionMapOverlay"
                class="region-map-overlay"
                @click="handleRegionMapClick"
              ></canvas>
              <div v-if="markerPlaced" class="coordinates-display">
                X: {{ Math.round(markerX) }}, Y: {{ Math.round(markerY) }}
              </div>
            </div>
          </div>
          <div class="region-controls-panel">
            <button 
              v-if="currentViewedLocation?.images.length > 1"
              class="control-card btn btn-secondary"
              @click="navigateLocationImage(-1)"
              :disabled="currentLocationImageIndex === 0"
            >
              <span class="control-icon">←</span>
              <span class="control-text">Précédent</span>
            </button>
            <button 
              v-if="currentViewedLocation?.images.length > 1"
              class="control-card btn btn-secondary"
              @click="navigateLocationImage(1)"
              :disabled="currentLocationImageIndex === currentViewedLocation?.images.length - 1"
            >
              <span class="control-icon">→</span>
              <span class="control-text">Suivant</span>
            </button>
            <button class="control-card btn btn-primary" @click="backToMap">
              <span class="control-icon">↶</span>
              <span class="control-text">Retour</span>
            </button>
            <div v-if="currentViewedLocation?.images.length > 1" class="image-counter-card">
              {{ currentLocationImageIndex + 1 }} / {{ currentViewedLocation?.images.length }}
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="controls">
      <div class="score-info">
        <div class="score-item">
          <span class="label">Round:</span>
          <span>{{ currentRound }}</span> / <span>{{ CONFIG.totalRounds }}</span>
        </div>
        <div class="score-item">
          <span class="label">Score:</span>
          <span>{{ totalScore }}</span>
        </div>
        <div class="score-item">
          <span class="label">Distance:</span>
          <span>{{ distance || '-' }}</span>
        </div>
      </div>

      <div class="buttons">
        <button 
          class="btn btn-primary" 
          :disabled="!markerPlaced"
          @click="makeGuess"
        >
          Faire une supposition
        </button>
        <button 
          v-if="markerPlaced && currentRound < CONFIG.totalRounds"
          class="btn btn-secondary"
          @click="nextRound"
        >
          Round suivant
        </button>
        <button 
          v-if="markerPlaced && currentRound >= CONFIG.totalRounds"
          class="btn btn-secondary"
          @click="endGame"
        >
          Terminer
        </button>
        <button 
          v-if="gameOver"
          class="btn btn-secondary"
          @click="startNewGame"
        >
          Nouvelle partie
        </button>
      </div>
    </div>

    <!-- Modal de résultat -->
    <div v-if="showResultModal" class="modal">
      <div class="modal-content">
        <h2>{{ resultTitle }}</h2>
        <p>{{ resultMessage }}</p>
        <div class="result-details">
          <div><strong>Distance:</strong> {{ (distance / 10).toFixed(1) }} unités</div>
          <div><strong>Score pour ce round:</strong> {{ lastRoundScore }} points</div>
          <div><strong>Score total:</strong> {{ totalScore }} points</div>
        </div>
        <button class="btn btn-primary" @click="closeResultModal">Continuer</button>
      </div>
    </div>

    <!-- Modal fin de partie -->
    <div v-if="showGameOverModal" class="modal">
      <div class="modal-content">
        <h2>🎮 Partie terminée!</h2>
        <p>Votre score final: <strong>{{ totalScore }}</strong> points</p>
        <div class="result-details">
          <h3>Résultats des rounds:</h3>
          <div 
            v-for="result in roundResults" 
            :key="result.round"
            class="round-result-item"
          >
            <span>Round {{ result.round }}: {{ result.location }}</span>
            <span>{{ result.score }} pts</span>
          </div>
        </div>
        <button class="btn btn-primary" @click="startNewGame">Rejouer</button>
      </div>
    </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue';

const CONFIG = {
  totalRounds: 5,
};

// État réactif
const currentRound = ref(1);
const totalScore = ref(0);
const markerPlaced = ref(false);
const markerX = ref(0);
const markerY = ref(0);
const currentLocation = ref(null);
const roundResults = ref([]);
const currentLocationImageIndex = ref(0);
const currentViewedLocation = ref(null);
const loading = ref(false);
const currentGameImage = ref('');
const distance = ref(null);
const lastRoundScore = ref(0);
const showResultModal = ref(false);
const showGameOverModal = ref(false);
const gameOver = ref(false);
const showWelcomeScreen = ref(true);
const locations = ref([]);
const apiError = ref(null);

const mainMapZoom = ref(1);
const regionZoom = ref(1);
const ZOOM_LEVELS = [1, 2];

let mainMapClickTimeout = null;
let regionClickTimeout = null;

// Refs des éléments DOM
const mapImage = ref(null);
const mapOverlay = ref(null);
const locationDetailImage = ref(null);
const regionMapOverlay = ref(null);

// Computed
const showMainMap = computed(() => !currentViewedLocation.value);

const currentLocationImage = computed(() => {
  if (!currentViewedLocation.value?.images) return '';
  return currentViewedLocation.value.images[currentLocationImageIndex.value];
});

const markerStyle = computed(() => {
  if (!locationDetailImage.value || !markerPlaced.value) return {};
  const rect = locationDetailImage.value.getBoundingClientRect();
  const container = locationDetailImage.value.parentElement;
  const containerRect = container.getBoundingClientRect();
  return {
    left: `${rect.left - containerRect.left + markerX.value}px`,
    top: `${rect.top - containerRect.top + markerY.value}px`,
  };
});

const resultTitle = computed(() => {
  if (lastRoundScore.value > 3000) return "Excellent!";
  if (lastRoundScore.value > 2000) return "Très bien!";
  if (lastRoundScore.value > 1000) return "Pas mal!";
  return "Continue!";
});

const resultMessage = computed(() => {
  return `Vous étiez à ${Math.round(distance.value)}px de la vraie localisation.`;
});

// Fonctions utilitaires
const calculateDistance = (x1, y1, x2, y2) => {
  return Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2));
};

const distanceToScore = (distance, maxDistance) => {
  if (distance === 0) return 5000;
  const normalizedDistance = distance / maxDistance;
  return Math.max(0, Math.round(5000 * (1 - normalizedDistance)));
};

// Dessine les localisations sur la carte
const drawLocationsOnMap = () => {
  if (!mapOverlay.value || !locations.value || locations.value.length === 0) return;
  const ctx = mapOverlay.value.getContext('2d');
  const toleranceRadius = 25;
  const offsetY = -25;

  locations.value.forEach((location) => {
    const x = (location.x / 100) * mapOverlay.value.width;
    const y = (location.y / 100) * mapOverlay.value.height + offsetY;

    ctx.fillStyle = "rgba(255, 215, 0, 0.15)";
    ctx.beginPath();
    ctx.arc(x, y, toleranceRadius, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = "rgba(255, 215, 0, 0.4)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(x, y, toleranceRadius, 0, Math.PI * 2);
    ctx.stroke();

    ctx.fillStyle = "rgba(255, 215, 0, 0.9)";
    ctx.beginPath();
    ctx.arc(x, y, 6, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = "rgba(255, 215, 0, 1)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(x, y, 8, 0, Math.PI * 2);
    ctx.stroke();
  });
};

// Trouve la localisation à un point
const findLocationAtPoint = (clickX, clickY) => {
  if (!mapOverlay.value || !locations.value || locations.value.length === 0) return null;
  const toleranceRadius = 25;
  const offsetY = -25;
  let closestLocation = null;
  let minDistance = toleranceRadius;

  locations.value.forEach((location) => {
    const locX = (location.x / 100) * mapOverlay.value.width;
    const locY = (location.y / 100) * mapOverlay.value.height + offsetY;

    const dist = calculateDistance(clickX, clickY, locX, locY);
    if (dist < minDistance) {
      minDistance = dist;
      closestLocation = location;
    }
  });

  return closestLocation;
};

const toggleMainMapZoom = () => {
  const idx = ZOOM_LEVELS.indexOf(mainMapZoom.value);
  mainMapZoom.value = ZOOM_LEVELS[(idx + 1) % ZOOM_LEVELS.length];
};

const toggleRegionZoom = () => {
  const idx = ZOOM_LEVELS.indexOf(regionZoom.value);
  regionZoom.value = ZOOM_LEVELS[(idx + 1) % ZOOM_LEVELS.length];
};

// Gestion du clic sur la carte principale (double-clic = zoom, simple clic = sélection)
const handleMapClick = async (e) => {
  if (!mapOverlay.value) return;
  const rect = mapOverlay.value.getBoundingClientRect();
  const x = (e.clientX - rect.left) / mainMapZoom.value;
  const y = (e.clientY - rect.top) / mainMapZoom.value;

  if (mainMapClickTimeout) {
    clearTimeout(mainMapClickTimeout);
    mainMapClickTimeout = null;
    toggleMainMapZoom();
    return;
  }
  mainMapClickTimeout = setTimeout(async () => {
    mainMapClickTimeout = null;
    const clickedLocation = findLocationAtPoint(x, y);
    if (clickedLocation) {
    // Charger les détails complets de la localisation depuis l'API
    try {
      const response = await fetch(`/api/locations/${clickedLocation.id}`);
      if (response.ok) {
        const locationData = await response.json();
        displayLocationImage(locationData);
        currentLocation.value = locationData;
      } else {
        // Fallback sur les données locales si l'API échoue
        displayLocationImage(clickedLocation);
        currentLocation.value = clickedLocation;
      }
    } catch (error) {
      console.error('Error loading location details:', error);
      displayLocationImage(clickedLocation);
      currentLocation.value = clickedLocation;
    }
  }
  }, 250);
};

// Affiche l'image de localisation
const displayLocationImage = (location) => {
  if (!location.images || location.images.length === 0) {
    alert("Aucune image disponible pour " + location.name);
    return;
  }

  currentViewedLocation.value = location;
  currentLocationImageIndex.value = 0;
  currentLocation.value = location;
  regionZoom.value = 1;
};

// Navigation entre images de localisation
const navigateLocationImage = (direction) => {
  if (!currentViewedLocation.value) return;
  const totalImages = currentViewedLocation.value.images.length;
  let newIndex = currentLocationImageIndex.value + direction;

  if (newIndex < 0) newIndex = 0;
  if (newIndex >= totalImages) newIndex = totalImages - 1;

  currentLocationImageIndex.value = newIndex;
  nextTick(() => {
    setupRegionMapOverlay();
    resetMarker();
  });
};

// Retour à la carte principale
const backToMap = () => {
  currentViewedLocation.value = null;
  currentLocationImageIndex.value = 0;
  regionZoom.value = 1;
  resetMarker();
};

// Configuration du canvas overlay de la carte principale
const resizeMapOverlay = () => {
  if (!mapOverlay.value || !mapImage.value) return;
  
  // Utiliser les dimensions naturelles de l'image
  const imgWidth = mapImage.value.naturalWidth || mapImage.value.width;
  const imgHeight = mapImage.value.naturalHeight || mapImage.value.height;
  const rect = mapImage.value.getBoundingClientRect();
  
  // Ajuster le canvas aux dimensions réelles affichées
  mapOverlay.value.width = rect.width;
  mapOverlay.value.height = rect.height;
  mapOverlay.value.style.width = rect.width + 'px';
  mapOverlay.value.style.height = rect.height + 'px';
  mapOverlay.value.style.position = 'absolute';
  mapOverlay.value.style.top = '0';
  mapOverlay.value.style.left = '0';

  drawLocationsOnMap();
};

// Configuration du canvas overlay de la région
const setupRegionMapOverlay = () => {
  if (!regionMapOverlay.value || !locationDetailImage.value) return;

  const setup = () => {
    const rect = locationDetailImage.value.getBoundingClientRect();
    regionMapOverlay.value.width = rect.width;
    regionMapOverlay.value.height = rect.height;
    regionMapOverlay.value.style.width = rect.width + 'px';
    regionMapOverlay.value.style.height = rect.height + 'px';
  };

  if (locationDetailImage.value.complete) {
    setup();
  } else {
    locationDetailImage.value.onload = setup;
  }
};

// Gestion du clic sur la carte de région (double-clic = zoom, simple clic = marqueur)
const handleRegionMapClick = (e) => {
  if (!regionMapOverlay.value || !currentLocation.value) return;
  const rect = regionMapOverlay.value.getBoundingClientRect();
  const x = (e.clientX - rect.left) / regionZoom.value;
  const y = (e.clientY - rect.top) / regionZoom.value;

  if (regionClickTimeout) {
    clearTimeout(regionClickTimeout);
    regionClickTimeout = null;
    toggleRegionZoom();
    return;
  }
  regionClickTimeout = setTimeout(() => {
    regionClickTimeout = null;
    placeMarkerOnRegionMap(x, y);
  }, 250);
};

// Place un marqueur sur la carte de région
const placeMarkerOnRegionMap = (x, y) => {
  markerX.value = x;
  markerY.value = y;
  markerPlaced.value = true;

  nextTick(() => {
    if (!regionMapOverlay.value) return;
    const ctx = regionMapOverlay.value.getContext('2d');
    ctx.clearRect(0, 0, regionMapOverlay.value.width, regionMapOverlay.value.height);
    ctx.fillStyle = "#ff6b6b";
    ctx.beginPath();
    ctx.arc(x, y, 6, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#ffffff";
    ctx.lineWidth = 2;
    ctx.stroke();
  });
};

// Réinitialise le marqueur
const resetMarker = () => {
  markerPlaced.value = false;
  markerX.value = 0;
  markerY.value = 0;
  distance.value = null;
  if (regionMapOverlay.value) {
    const ctx = regionMapOverlay.value.getContext('2d');
    ctx.clearRect(0, 0, regionMapOverlay.value.width, regionMapOverlay.value.height);
  }
};

// Affiche la vraie localisation sur la carte
const showActualLocation = () => {
  if (!regionMapOverlay.value || !currentLocation.value) return;
  const ctx = regionMapOverlay.value.getContext('2d');
  
  // Utiliser les coordonnées réelles depuis la base de données si disponibles
  const actualX = currentLocation.value.actual_x || regionMapOverlay.value.width / 2;
  const actualY = currentLocation.value.actual_y || regionMapOverlay.value.height / 2;

  ctx.fillStyle = "#ff6b6b";
  ctx.beginPath();
  ctx.arc(markerX.value, markerY.value, 6, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "#ffffff";
  ctx.lineWidth = 2;
  ctx.stroke();

  ctx.fillStyle = "#51cf66";
  ctx.beginPath();
  ctx.arc(actualX, actualY, 8, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = "#51cf66";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(actualX, actualY, 12, 0, Math.PI * 2);
  ctx.stroke();

  ctx.strokeStyle = "rgba(255, 255, 255, 0.5)";
  ctx.lineWidth = 2;
  ctx.setLineDash([5, 5]);
  ctx.beginPath();
  ctx.moveTo(markerX.value, markerY.value);
  ctx.lineTo(actualX, actualY);
  ctx.stroke();
  ctx.setLineDash([]);
};

// Fait une supposition
const makeGuess = () => {
  if (!markerPlaced.value || !currentLocation.value || !regionMapOverlay.value) return;

  const maxDistance = Math.sqrt(
    Math.pow(regionMapOverlay.value.width, 2) +
    Math.pow(regionMapOverlay.value.height, 2)
  );

  // Utiliser les coordonnées réelles depuis la base de données si disponibles
  const actualX = currentLocation.value?.actual_x || regionMapOverlay.value.width / 2;
  const actualY = currentLocation.value?.actual_y || regionMapOverlay.value.height / 2;

  const dist = calculateDistance(markerX.value, markerY.value, actualX, actualY);
  const score = distanceToScore(dist, maxDistance);
  
  totalScore.value += score;
  distance.value = Math.round(dist);
  lastRoundScore.value = score;

  roundResults.value.push({
    location: currentLocation.value.name,
    distance: Math.round(dist),
    score: score,
    round: currentRound.value,
  });

  showActualLocation();
  showResultModal.value = true;
};

// Passe au round suivant
const nextRound = () => {
  if (currentRound.value >= CONFIG.totalRounds) {
    endGame();
    return;
  }

  currentRound.value++;
  resetMarker();
  showResultModal.value = false;
  backToMap();
  loadRandomLocation();
};

// Termine le jeu
const endGame = () => {
  showResultModal.value = false;
  showGameOverModal.value = true;
  gameOver.value = true;
};

// Ferme le modal de résultat
const closeResultModal = () => {
  showResultModal.value = false;
  if (currentRound.value >= CONFIG.totalRounds) {
    endGame();
  }
};

// Localisations de secours si l'API est indisponible
const FALLBACK_LOCATIONS = [
  { id: 1, name: "Ruins of Wyveria", x: 69, y: 20.2, images: ["/maps/Ruins of Wyveria map 1.png", "/maps/Ruins of Wyveria map 2.png", "/maps/Ruins of Wyveria map 3.png", "/maps/Ruins of Wyveria map 4.png"] },
  { id: 2, name: "Grand Hub", x: 88.2, y: 26.7, images: [] },
  { id: 3, name: "Iceshard Cliffs", x: 59.5, y: 40, images: ["/maps/Iceshard Cliffs map 1.png", "/maps/Iceshard Cliffs map 2.png", "/maps/Iceshard Cliffs map 3.png"] },
  { id: 4, name: "Wounded Hollow", x: 85.5, y: 42, images: ["/maps/Wounded Hollow map 1.png"] },
  { id: 5, name: "Scarlet Forest", x: 24.11, y: 43, images: ["/maps/Scarlet Forest map 1.png", "/maps/Scarlet Forest map 2.png"] },
  { id: 6, name: "Oilwell Basin", x: 52, y: 64, images: ["/maps/Oilwell Bassin map 1.png", "/maps/Oilwell Bassin map 2.png", "/maps/Oilwell Bassin map 3.png"] },
  { id: 7, name: "Suja, Peaks of Accord", x: 84, y: 56.5, images: ["/maps/Suja, Peaks of Accord map 1.png"] },
  { id: 8, name: "Training Area", x: 15.3, y: 72, images: [] },
  { id: 9, name: "Windward Plains", x: 30.3, y: 85, images: ["/maps/Windward Plains map 1.png", "/maps/Windward Plains map 2.png"] },
];

// Charge les localisations depuis l'API
const loadLocations = async () => {
  try {
    apiError.value = null;
    const response = await fetch('/api/locations');
    if (!response.ok) throw new Error('Failed to load locations');
    locations.value = await response.json();
  } catch (error) {
    console.error('Error loading locations:', error);
    apiError.value = 'Impossible de charger les localisations depuis la base de données';
    locations.value = [...FALLBACK_LOCATIONS];
  }
};

// Charge une localisation aléatoire depuis l'API
const loadRandomLocation = async () => {
  try {
    apiError.value = null;
    loading.value = true;
    const response = await fetch('/api/screenshots/random');
    
    if (!response.ok) {
      if (response.status === 404) {
        currentGameImage.value = '';
        loading.value = false;
        apiError.value = 'Aucune capture d\'écran disponible dans la base de données';
        return;
      }
      throw new Error('Failed to load random screenshot');
    }
    
    const data = await response.json();
    
    // Transformer les données de l'API en format compatible avec l'app
    currentLocation.value = {
      id: data.location_id,
      name: data.location_name,
      x: data.map_x,
      y: data.map_y,
      description: data.description,
      images: data.region_maps || [],
      gameImages: [data.screenshot_path],
      actual_x: data.actual_x,
      actual_y: data.actual_y,
    };
    
    // Mettre à jour currentViewedLocation si nécessaire
    if (currentViewedLocation.value && currentViewedLocation.value.id === data.location_id) {
      // Si on est déjà sur cette localisation, ne rien faire
    } else {
      currentViewedLocation.value = {
        id: data.location_id,
        name: data.location_name,
        images: data.region_maps || [],
      };
      currentLocationImageIndex.value = 0;
    }
    
    currentGameImage.value = data.screenshot_path;
    loading.value = false;
  } catch (error) {
    console.error('Error loading random location:', error);
    apiError.value = 'Erreur lors du chargement de la localisation';
    loading.value = false;
    currentGameImage.value = '';
  }
};

// Démarre le jeu depuis l'écran d'accueil
const startGame = () => {
  showWelcomeScreen.value = false;
  startNewGame();
};

// Démarre une nouvelle partie
const startNewGame = () => {
  currentRound.value = 1;
  totalScore.value = 0;
  roundResults.value = [];
  gameOver.value = false;
  showGameOverModal.value = false;
  showResultModal.value = false;
  resetMarker();
  backToMap();
  loadRandomLocation();
};

// Gestionnaires d'événements
const onMapImageLoad = () => {
  nextTick(() => {
    resizeMapOverlay();
  });
};

const onRegionImageLoad = () => {
  nextTick(() => {
    setupRegionMapOverlay();
    resetMarker();
  });
};

const handleResize = () => {
  resizeMapOverlay();
  if (currentViewedLocation.value) {
    setupRegionMapOverlay();
  }
};

// Lifecycle hooks
onMounted(async () => {
  window.addEventListener('resize', handleResize);
  // Charger les localisations au démarrage
  await loadLocations();
  
  if (!showWelcomeScreen.value) {
    nextTick(() => {
      resizeMapOverlay();
      loadRandomLocation();
    });
  }
});

onUnmounted(() => {
  window.removeEventListener('resize', handleResize);
});

// Watch pour réinitialiser le marqueur quand on change de localisation
watch(() => currentLocationImageIndex.value, () => {
  resetMarker();
});
</script>
