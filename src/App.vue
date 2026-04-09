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
        <div class="welcome-actions">
          <button class="btn btn-primary welcome-start-btn" @click="startGame">
            Commencer la partie
          </button>
          <button class="btn btn-secondary welcome-start-btn" @click="openHighscores">
            Highscores
          </button>
        </div>
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
          :key="currentGameImage"
          :src="currentGameImage" 
          alt="Localisation à deviner"
          class="location-image"
          :class="{ visible: !loading }"
          @load="loading = false"
          @error="handleGameImageError"
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
              <div class="map-overlay-text">
                <p>Cliquez sur les localisations (points dorés) pour afficher leur carte et placer votre marqueur. Double-clic pour zoomer/dézoomer.</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Vue carte de région -->
        <div v-show="!showMainMap" class="location-image-view">
          <!-- Le panneau coordonnées est hors du transform (zoom/pan) : sinon overflow:hidden le rogne -->
          <div class="region-map-viewport">
            <div
              class="map-zoom-wrapper region-zoom-wrapper"
              :class="{ 'region-pan-active': regionIsPanning }"
              :style="{ transform: `translate(${regionPanX}px, ${regionPanY}px) scale(${regionZoom})` }"
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
                  @dblclick="handleRegionMapDoubleClick"
                  @pointerdown="handleRegionPointerDown"
                ></canvas>
              </div>
            </div>
            <div v-if="markerPlaced" class="coordinates-display">
              X: {{ Math.round(markerX) }}, Y: {{ Math.round(markerY) }}
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
          </div>
        </div>
      </div>
    </div>

    <div class="controls">
      <div class="score-info">
        <div class="score-item">
          <span class="label">Score:</span>
          <span>{{ totalScore }}</span>
        </div>
        <div class="score-item" :class="{ 'countdown-warning': roundCountdownSeconds <= 10 && !roundTimeExpired }">
          <span class="label">Temps:</span>
          <span>{{ roundCountdownSeconds }}s</span>
        </div>
        <div class="score-item">
          <span class="label">Round:</span>
          <span>{{ currentRound }}</span> / <span>{{ CONFIG.totalRounds }}</span>
        </div>
      </div>

      <div class="buttons">
        <button 
          class="btn btn-primary" 
          :disabled="!markerPlaced || roundResolved"
          @click="makeGuess"
        >
          Faire une supposition
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
          <div v-if="lastRoundIsCorrect">
            <strong>Distance:</strong> {{ (distance / 10).toFixed(1) }} unités
          </div>
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
        <div v-if="showHighscorePrompt" class="result-details" style="text-align: left;">
          <h3>Top 50 !</h3>
          <p
            v-if="highscoreFeedbackMessage"
            style="margin-bottom: 10px; color: #c0392b; font-size: 0.95rem;"
          >
            {{ highscoreFeedbackMessage }}
          </p>
         
          <p style="margin-bottom: 10px;">Ajoutez votre pseudo :</p>
          <input
            v-model="highscorePseudo"
            placeholder="Pseudo"
            maxlength="32"
            class="btn"
            style="width: 100%; padding: 12px; margin-bottom: 12px; text-transform: none;"
          />
          <div class="highscore-actions">
            <button
              class="btn btn-secondary"
              :disabled="highscoreSaving || !highscorePseudo.trim()"
              @click="saveHighscore"
            >
              {{ highscoreSaving ? 'Enregistrement...' : 'Enregistrer' }}
            </button>
            <button
              class="btn btn-primary"
              :disabled="highscoreSaving"
              @click="closeHighscorePrompt"
            >
              Pas maintenant
            </button>
          </div>
        </div>
        <div class="buttons">
          <button class="btn btn-secondary" @click="returnToAccueil">Retour à l'accueil</button>
          <button class="btn btn-primary" @click="startNewGame">Rejouer</button>
        </div>
      </div>
    </div>

    <!-- Modal Highscores -->
    <div v-if="showHighscoresModal" class="modal">
      <div class="modal-content">
        <h2>Highscores</h2>
        <div class="result-details">
          <div v-if="highScoresLoading">Chargement...</div>
          <div v-else>
            <div v-if="highScores.length === 0">Aucun highscore pour le moment.</div>
            <div v-else>
              <div
                v-for="(h, idx) in highScores"
                :key="h.id ?? idx"
                class="round-result-item"
              >
                <span>#{{ idx + 1 }} {{ h.pseudo }}</span>
                <span>{{ h.score }} pts</span>
                <span>{{ formatHighscoreTime(h.total_time_remaining_seconds) }}</span>
              </div>
            </div>
          </div>
        </div>
        <button class="btn btn-primary" @click="closeHighscoresModal">Fermer</button>
      </div>
    </div>
  </div>
  
  <canvas
    v-if="showConfetti"
    ref="confettiCanvas"
    class="confetti-canvas"
  ></canvas>
  <footer class="site-footer">
    Projet créer dans le cadre du BTS SIO Option Slam par C.Ramirez. <br />
    Copyright © {{ currentYear }}.
  </footer>
</div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue';

const CONFIG = {
  totalRounds: 5,
};

const ROUND_TIME_SECONDS = 30;

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
const lastRoundIsCorrect = ref(true);
const lastRoundCorrectZoneName = ref('');
const showResultModal = ref(false);
const showGameOverModal = ref(false);
const gameOver = ref(false);
const showWelcomeScreen = ref(true);
const locations = ref([]);
const apiError = ref(null);

// Compte à rebours (réinitialisé à chaque round)
const roundCountdownSeconds = ref(ROUND_TIME_SECONDS);
const roundTimeExpired = ref(false);
const roundResolved = ref(false);
let roundCountdownIntervalId = null;
let roundCountdownEndsAtMs = 0;

// Total du temps restant (somme des secondes restantes lors de chaque validation de round)
const totalTimeRemainingSeconds = computed(() =>
  roundResults.value.reduce((sum, r) => sum + (r.timeRemainingSeconds ?? 0), 0)
);

// Captures déjà utilisées dans la partie en cours (évite les doublons)
const usedScreenshotIdsInGame = ref([]);

// Highscores
const showHighscoresModal = ref(false);
const highScores = ref([]);
const highScoresLoading = ref(false);
const showHighscorePrompt = ref(false);
const highscorePseudo = ref('');
const highscoreSaving = ref(false);
const highscoreFeedbackMessage = ref('');
const highscoreOpenedFromWelcome = ref(false);
const currentYear = new Date().getFullYear();

// Confetti (TOP 50)
const showConfetti = ref(false);
const confettiCanvas = ref(null);
let confettiRafId = null;
let confettiTimeoutId = null;

const mainMapZoom = ref(1);
const regionZoom = ref(1);
const ZOOM_LEVELS = [1, 2];

let mainMapClickTimeout = null;
let regionClickTimeout = null; // (gardé pour compat, mais n'est plus utilisé sur la région)

// Pan de la carte régionale (permet de voir les bords après zoom)
const regionPanX = ref(0);
const regionPanY = ref(0);
const regionIsPanning = ref(false);
const suppressRegionClick = ref(false);
const suppressNextMarker = ref(false);
// Seuil plus élevé pour éviter d'activer le pan à cause de micro-mouvements
// (important pour que le clic simple + double-clic fonctionnent).
const REGION_DRAG_THRESHOLD_PX = 12;
let regionPanStartX = 0;
let regionPanStartY = 0;
let regionPointerStartX = 0;
let regionPointerStartY = 0;

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
  // Si mauvaise région, on annonce explicitement la défaite.
  if (!lastRoundIsCorrect.value) return "Perdu !";
  if (lastRoundScore.value > 3000) return "Excellent!";
  if (lastRoundScore.value > 2000) return "Très bien!";
  if (lastRoundScore.value > 1000) return "Pas mal!";
  return "Continue!";
});

const resultMessage = computed(() => {
  // Si l'utilisateur a validé une mauvaise région, on ne parle pas de distance.
  if (!lastRoundIsCorrect.value) {
    return `Mauvaise région`;
  }
  return `Vous étiez à ${Math.round(distance.value)}px de la vraie localisation.`;
});

const formatHighscoreTime = (secondsRaw) => {
  const totalSeconds = Math.max(0, parseInt(secondsRaw ?? 0, 10) || 0);
  const m = Math.floor(totalSeconds / 60);
  const s = totalSeconds % 60;
  return `⏱ ${m}:${String(s).padStart(2, '0')}`;
};

// Fonctions utilitaires
const calculateDistance = (x1, y1, x2, y2) => {
  return Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2));
};

const distanceToScore = (distance, maxDistance) => {
  if (distance === 0) return 5000;
  const normalizedDistance = distance / maxDistance;
  return Math.max(0, Math.round(5000 * (1 - normalizedDistance)));
};

const stopRoundCountdown = () => {
  if (roundCountdownIntervalId) {
    clearInterval(roundCountdownIntervalId);
    roundCountdownIntervalId = null;
  }
};

const prepareRoundCountdown = () => {
  stopRoundCountdown();
  roundTimeExpired.value = false;
  roundResolved.value = false;
  roundCountdownSeconds.value = ROUND_TIME_SECONDS;
  roundCountdownEndsAtMs = 0;
};

const handleRoundTimeUp = () => {
  // Sécurité anti-double déclenchement (race condition avec un clic utilisateur).
  if (roundResolved.value || showResultModal.value || gameOver.value) return;

  roundResolved.value = true;
  roundTimeExpired.value = true;
  stopRoundCountdown();

  // Verrouiller l'interaction "supposition" et compter 0 point.
  markerPlaced.value = false;
  distance.value = null;
  lastRoundIsCorrect.value = false;
  lastRoundCorrectZoneName.value = '';
  lastRoundScore.value = 0;

  roundResults.value.push({
    location: currentLocation.value?.name ?? 'Inconnu',
    distance: null,
    score: 0,
    timeRemainingSeconds: 0,
    round: currentRound.value,
  });

  // Afficher ce qui est disponible (la révélation complète est volontairement limitée
  // par showActualLocation, comme pour les mauvaises réponses).
  showActualLocation();
  showResultModal.value = true;
};

const startRoundCountdown = () => {
  stopRoundCountdown();
  roundCountdownEndsAtMs = Date.now() + ROUND_TIME_SECONDS * 1000;

  roundCountdownIntervalId = window.setInterval(() => {
    if (roundResolved.value) return;

    const msLeft = roundCountdownEndsAtMs - Date.now();
    const secondsLeft = Math.max(0, Math.ceil(msLeft / 1000));
    roundCountdownSeconds.value = secondsLeft;

    if (msLeft <= 0) {
      handleRoundTimeUp();
    }
  }, 250);
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

const resetRegionPan = () => {
  regionPanX.value = 0;
  regionPanY.value = 0;
};

// Zoom autour d'un point cliqué (coordonnées "locales" dans la carte région)
// On ajuste la translation pour garder le point sous la souris.
const zoomRegionAt = (xLocal, yLocal) => {
  const oldZoom = regionZoom.value;
  const idx = ZOOM_LEVELS.indexOf(oldZoom);
  const newZoom = ZOOM_LEVELS[(idx + 1) % ZOOM_LEVELS.length];
  if (newZoom === oldZoom) return;

  // Transform appliquée : translate(panX, panY) scale(zoom)
  // => la translation est "échelonnée" par le zoom.
  const ratio = oldZoom / newZoom;
  regionPanX.value = regionPanX.value * ratio + xLocal * (ratio - 1);
  regionPanY.value = regionPanY.value * ratio + yLocal * (ratio - 1);
  regionZoom.value = newZoom;
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
        // L'utilisateur doit pouvoir ouvrir n'importe quelle localisation (pas d'indice).
        displayLocationImage(locationData);
      } else {
        // Fallback sur les données locales si l'API échoue
        displayLocationImage(clickedLocation);
      }
    } catch (error) {
      console.error('Error loading location details:', error);
      displayLocationImage(clickedLocation);
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
  regionZoom.value = 1;
  resetRegionPan();
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
    resetRegionPan();
  });
};

// Retour à la carte principale
const backToMap = () => {
  currentViewedLocation.value = null;
  currentLocationImageIndex.value = 0;
  regionZoom.value = 1;
  resetRegionPan();
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
  // On ignore le clic si le dernier geste était un drag,
  // ou si on vient juste d'effectuer un dblclick.
  if (regionIsPanning.value || suppressRegionClick.value || suppressNextMarker.value) {
    suppressRegionClick.value = false;
    suppressNextMarker.value = false;
    return;
  }

  if (!regionMapOverlay.value || !currentLocation.value) return;
  const rect = regionMapOverlay.value.getBoundingClientRect();
  const x = (e.clientX - rect.left) / regionZoom.value;
  const y = (e.clientY - rect.top) / regionZoom.value;

  placeMarkerOnRegionMap(x, y);
};

// Zoom sur double-clic (séparé du clic simple)
const handleRegionMapDoubleClick = (e) => {
  if (!regionMapOverlay.value || !currentLocation.value) return;
  if (regionIsPanning.value) return;

  // Empêche un marqueur sur le clic qui précède/suit le dblclick.
  suppressNextMarker.value = true;
  suppressRegionClick.value = false;

  e.preventDefault();
  e.stopPropagation();

  const rect = regionMapOverlay.value.getBoundingClientRect();
  const x = (e.clientX - rect.left) / regionZoom.value;
  const y = (e.clientY - rect.top) / regionZoom.value;
  zoomRegionAt(x, y);
};

// Pan de la carte régionale : clic maintenu + glisser
const handleRegionPointerDown = (e) => {
  if (!regionMapOverlay.value) return;

  const isMouse = e.pointerType === 'mouse';

  // Souris : on ne panner que si bouton gauche
  if (isMouse && e.button !== 0) return;

  // Sur souris, ne pas bloquer le comportement (sinon click/dblclick peuvent casser)
  // Sur tactile, on bloque pour éviter scroll/zoom navigateur.
  if (!isMouse) e.preventDefault();

  // Tant qu'on n'a pas réellement commencé à "dragger", on ne bloque pas les clics.
  regionIsPanning.value = false;
  suppressRegionClick.value = false;

  regionPanStartX = regionPanX.value;
  regionPanStartY = regionPanY.value;
  regionPointerStartX = e.clientX;
  regionPointerStartY = e.clientY;

  let panEnabled = false;
  let allowPan = false;
  let holdTimeoutId = null;

  const PAN_ACTIVATION_DELAY_MS = isMouse ? 250 : 0;
  if (PAN_ACTIVATION_DELAY_MS > 0) {
    holdTimeoutId = window.setTimeout(() => {
      allowPan = true;
    }, PAN_ACTIVATION_DELAY_MS);
  } else {
    allowPan = true;
  }

  const onPointerMove = (ev) => {
    const dx = ev.clientX - regionPointerStartX;
    const dy = ev.clientY - regionPointerStartY;

    const dist = Math.sqrt(dx * dx + dy * dy);

    if (!panEnabled && allowPan && dist > REGION_DRAG_THRESHOLD_PX) {
      panEnabled = true;
      regionIsPanning.value = true;
      suppressRegionClick.value = true;
    }

    if (panEnabled) {
      regionPanX.value = regionPanStartX + dx;
      regionPanY.value = regionPanStartY + dy;
    }
  };

  const onPointerUp = () => {
    if (holdTimeoutId) clearTimeout(holdTimeoutId);
    holdTimeoutId = null;

    regionIsPanning.value = false;
    window.removeEventListener('pointermove', onPointerMove);
    window.removeEventListener('pointerup', onPointerUp);
    window.removeEventListener('pointercancel', onPointerUp);

    // Si drag => on évite un clic parasite quelques ms
    if (panEnabled) {
      suppressRegionClick.value = true;
      setTimeout(() => {
        suppressRegionClick.value = false;
      }, 50);
    } else {
      suppressRegionClick.value = false;
    }
  };

  window.addEventListener('pointermove', onPointerMove);
  window.addEventListener('pointerup', onPointerUp);
  window.addEventListener('pointercancel', onPointerUp);
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
    // Curseur : rond rouge en anneau (sans remplissage)
    const radius = 8;
    ctx.strokeStyle = "#ff6b6b";
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.stroke();

    // Bord extérieur blanc pour la lisibilité
    ctx.strokeStyle = "#ffffff";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
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

  // Ne dévoiler la vérité (marqueur vert / ligne) que si la bonne localisation a été choisie.
  const selectedLocationId = currentViewedLocation.value?.id;
  const actualLocationId = currentLocation.value?.id;
  if (selectedLocationId != null && actualLocationId != null && selectedLocationId !== actualLocationId) {
    return;
  }

  if (currentLocation.value.actual_x == null || currentLocation.value.actual_y == null) return;
  const ctx = regionMapOverlay.value.getContext('2d');

  // Coordonnées réelles depuis la base de données (dans le repère de la region_map liée à la capture).
  const actualX = currentLocation.value.actual_x;
  const actualY = currentLocation.value.actual_y;

  // Curseur utilisateur : anneau rouge
  const radius = 8;
  ctx.strokeStyle = "#ff6b6b";
  ctx.lineWidth = 6;
  ctx.beginPath();
  ctx.arc(markerX.value, markerY.value, radius, 0, Math.PI * 2);
  ctx.stroke();

  ctx.strokeStyle = "#ffffff";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(markerX.value, markerY.value, radius, 0, Math.PI * 2);
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
  if (roundResolved.value) return;
  if (!markerPlaced.value || !currentLocation.value || !regionMapOverlay.value) return;

  // Verrouiller le round dès que l'utilisateur valide.
  roundResolved.value = true;
  roundTimeExpired.value = false;
  stopRoundCountdown();

  // Temps restant au moment où le joueur valide sa réponse.
  const temps_restant = Math.max(0, roundCountdownSeconds.value);

  const maxDistance = Math.sqrt(
    Math.pow(regionMapOverlay.value.width, 2) +
    Math.pow(regionMapOverlay.value.height, 2)
  );

  // Si l'utilisateur a choisi une mauvaise localisation,
  // on pénalise fortement (dist = maxDistance) car la région affichée n'est pas celle de la capture.
  const selectedLocationId = currentViewedLocation.value?.id;
  const actualLocationId = currentLocation.value?.id;
  const isCorrectLocation =
    selectedLocationId != null &&
    actualLocationId != null &&
    selectedLocationId === actualLocationId;

  lastRoundIsCorrect.value = isCorrectLocation;
  lastRoundCorrectZoneName.value = currentLocation.value?.name || '';

  let dist = maxDistance;
  let score = 0;

  // Règle demandée : si l'utilisateur valide sur une région incorrecte => 0 points.
  if (isCorrectLocation && currentLocation.value?.actual_x != null && currentLocation.value?.actual_y != null) {
    dist = calculateDistance(
      markerX.value,
      markerY.value,
      currentLocation.value.actual_x,
      currentLocation.value.actual_y
    );
    const score_distance = distanceToScore(dist, maxDistance);
    score = score_distance + (temps_restant * 50);
  }
  
  totalScore.value += score;
  distance.value = Math.round(dist);
  lastRoundScore.value = score;

  roundResults.value.push({
    location: currentLocation.value.name,
    distance: Math.round(dist),
    score: score,
    timeRemainingSeconds: temps_restant,
    round: currentRound.value,
  });

  showActualLocation();
  showResultModal.value = true;
};

// Passe au round suivant
const nextRound = async () => {
  if (currentRound.value >= CONFIG.totalRounds) {
    endGame();
    return;
  }

  currentRound.value++;
  resetMarker();
  showResultModal.value = false;
  backToMap();

  prepareRoundCountdown();
  await loadRandomLocation();

  if (currentLocation.value) {
    startRoundCountdown();
  }
};

// Termine le jeu
const endGame = async () => {
  stopRoundCountdown();
  showResultModal.value = false;
  showGameOverModal.value = true;
  gameOver.value = true;

  // Vérifier si le score est dans le TOP 50
  showHighscorePrompt.value = false;
  highscorePseudo.value = '';
  highscoreSaving.value = false;
  highscoreFeedbackMessage.value = '';

  try {
    const response = await fetch(`/api/highscores/eligible?score=${totalScore.value}`);
    if (response.ok) {
      const data = await response.json();
      showHighscorePrompt.value = !!data.eligible;
      if (data.eligible) {
        // Confetti lorsque le score rentre dans le TOP 50
        // On déclenche après le render via showConfetti canvas.
        setTimeout(() => startConfetti(), 50);
      }
    }
  } catch (error) {
    console.error('Error checking highscore eligibility:', error);
    showHighscorePrompt.value = false;
  }
};

// Ferme le modal de résultat
const closeResultModal = async () => {
  showResultModal.value = false;
  if (currentRound.value >= CONFIG.totalRounds) {
    await endGame();
    return;
  }
  await nextRound();
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
    const params = new URLSearchParams();
    if (usedScreenshotIdsInGame.value.length > 0) {
      params.set('exclude', usedScreenshotIdsInGame.value.join(','));
    }
    const qs = params.toString();
    const response = await fetch(`/api/screenshots/random${qs ? `?${qs}` : ''}`);

    if (!response.ok) {
      if (response.status === 404) {
        currentGameImage.value = '';
        loading.value = false;
        let errBody = {};
        try {
          errBody = await response.json();
        } catch {
          /* ignore */
        }
        if (errBody.code === 'no_unused_screenshots') {
          apiError.value =
            'Plus assez de captures distinctes pour continuer la partie (toutes ont déjà été utilisées). Ajoutez des captures ou réduisez le nombre de rounds.';
        } else {
          apiError.value = 'Aucune capture d\'écran disponible dans la base de données';
        }
        // On ne met pas de "placeholder" : l'interface doit simplement afficher l'erreur.
        currentLocation.value = null;
        return;
      }
      throw new Error('Failed to load random screenshot');
    }

    const data = await response.json();

    if (data.screenshot_id != null) {
      usedScreenshotIdsInGame.value = [...usedScreenshotIdsInGame.value, data.screenshot_id];
    }

    // Transformer les données de l'API en format compatible avec l'app
    currentLocation.value = {
      screenshot_id: data.screenshot_id,
      id: data.location_id,
      name: data.location_name,
      x: data.map_x,
      y: data.map_y,
      description: data.description,
      images: data.region_maps || [],
      region_map_id: data.region_map_id ?? null,
      region_map_file_path: Array.isArray(data.region_maps) && data.region_maps.length > 0 ? data.region_maps[0] : '',
      gameImages: [data.screenshot_path],
      actual_x: data.actual_x,
      actual_y: data.actual_y,
    };

    // Important : au début du round, on reste sur la carte générale.
    // La vue région (currentViewedLocation) ne sera activée que lorsque l'utilisateur clique
    // sur un point doré.
    
    currentGameImage.value = data.screenshot_path;
    loading.value = false;
  } catch (error) {
    console.error('Error loading random location:', error);
    apiError.value = 'Erreur lors du chargement de la localisation';
    loading.value = false;
    currentGameImage.value = '';
  }
};

// ============================
// Highscores
// ============================

const loadHighscores = async () => {
  try {
    highScoresLoading.value = true;
    const response = await fetch('/api/highscores');
    if (!response.ok) throw new Error('Failed to load highscores');
    highScores.value = await response.json();
  } catch (error) {
    console.error('Error loading highscores:', error);
    highScores.value = [];
  } finally {
    highScoresLoading.value = false;
  }
};

const openHighscores = async () => {
  highscoreOpenedFromWelcome.value = showWelcomeScreen.value;
  // La modal Highscores est rendue dans la partie `v-else`, donc on doit
  // passer en mode jeu sans démarrer la partie.
  if (highscoreOpenedFromWelcome.value) {
    showWelcomeScreen.value = false;
  }
  showHighscoresModal.value = true;
  await loadHighscores();
};

const closeHighscoresModal = () => {
  showHighscoresModal.value = false;
  if (highscoreOpenedFromWelcome.value) {
    showWelcomeScreen.value = true;
  }
  highscoreOpenedFromWelcome.value = false;
};

const closeHighscorePrompt = () => {
  showHighscorePrompt.value = false;
  highscorePseudo.value = '';
  highscoreFeedbackMessage.value = '';
};

const saveHighscore = async () => {
  const pseudo = highscorePseudo.value.trim();
  if (!pseudo) return;

  highscoreSaving.value = true;
  highscoreFeedbackMessage.value = '';
  try {
    const response = await fetch('/api/highscores', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        pseudo,
        score: totalScore.value,
        totalTimeRemainingSeconds: totalTimeRemainingSeconds.value,
      }),
    });
    let data = {};
    try {
      data = await response.json();
    } catch {
      data = {};
    }
    if (response.ok && data.inserted) {
      closeHighscorePrompt();
      await loadHighscores();
      showHighscoresModal.value = true;
    } else if (response.ok && data.inserted === false) {
      highscoreFeedbackMessage.value =
        'Votre score ne rentre pas dans le top 50 (classement déjà plein ou score trop bas).';
    } else {
      highscoreFeedbackMessage.value =
        data.detail || data.error || `Erreur serveur (${response.status}). Réessaie plus tard.`;
    }
  } catch (error) {
    console.error('Error saving highscore:', error);
    highscoreFeedbackMessage.value = 'Impossible de contacter le serveur. Vérifie ta connexion.';
  } finally {
    highscoreSaving.value = false;
  }
};

// Démarre le jeu depuis l'écran d'accueil
const startGame = () => {
  showWelcomeScreen.value = false;
  startNewGame();
};

// Démarre une nouvelle partie
const startNewGame = async () => {
  usedScreenshotIdsInGame.value = [];
  currentRound.value = 1;
  totalScore.value = 0;
  roundResults.value = [];
  gameOver.value = false;
  showGameOverModal.value = false;
  showResultModal.value = false;
  prepareRoundCountdown();
  showHighscorePrompt.value = false;
  highscorePseudo.value = '';
  showHighscoresModal.value = false;
  resetMarker();
  backToMap();
  await loadRandomLocation();
  if (currentLocation.value) {
    startRoundCountdown();
  }
};

const returnToAccueil = () => {
  usedScreenshotIdsInGame.value = [];
  // Réaffiche l'écran d'accueil et ferme tout état de fin de partie
  showWelcomeScreen.value = true;
  showGameOverModal.value = false;
  showResultModal.value = false;
  showHighscorePrompt.value = false;
  showHighscoresModal.value = false;
  gameOver.value = false;
  highscorePseudo.value = '';

  stopRoundCountdown();
  roundTimeExpired.value = false;
  roundResolved.value = false;
  roundCountdownSeconds.value = ROUND_TIME_SECONDS;

  // Stop confetti si actif
  if (confettiRafId) cancelAnimationFrame(confettiRafId);
  if (confettiTimeoutId) clearTimeout(confettiTimeoutId);
  confettiRafId = null;
  confettiTimeoutId = null;
  showConfetti.value = false;
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

const handleGameImageError = () => {
  // Si le chargement du BLOB image échoue côté navigateur,
  // on évite de rester bloqué sur l'état "loading".
  loading.value = false;
  apiError.value = 'Impossible de charger l\'image de la capture';
  currentGameImage.value = '';
};

const startConfetti = async () => {
  // Nettoyage si on relance
  if (confettiRafId) cancelAnimationFrame(confettiRafId);
  if (confettiTimeoutId) clearTimeout(confettiTimeoutId);

  showConfetti.value = true;
  // Attendre le render du <canvas> (sinon ref peut être null)
  await nextTick();

  const canvas = confettiCanvas.value;
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  const dpr = window.devicePixelRatio || 1;
  const resize = () => {
    const w = window.innerWidth;
    const h = window.innerHeight;
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  resize();

  const colors = ['#ff6b6b', '#feca57', '#4ecdc4', '#5c7cfa', '#b197fc', '#22b8cf', '#51cf66'];

  // Particules
  const count = 220;
  const particles = Array.from({ length: count }, () => {
    const x = Math.random() * window.innerWidth;
    return {
      x,
      y: -Math.random() * window.innerHeight * 0.2,
      vx: (Math.random() - 0.5) * 5,
      vy: 2 + Math.random() * 6,
      w: 6 + Math.random() * 8,
      h: 6 + Math.random() * 8,
      rot: Math.random() * Math.PI,
      vr: (Math.random() - 0.5) * 0.25,
      color: colors[Math.floor(Math.random() * colors.length)],
      alpha: 1,
    };
  });

  const start = performance.now();
  const durationMs = 3000;

  const tick = (now) => {
    const elapsed = now - start;
    // Effacer
    ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);

    // Update/draw
    for (const p of particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.03; // gravité légère
      p.rot += p.vr;

      // Fade progressif
      p.alpha = Math.max(0, 1 - elapsed / durationMs);
      ctx.globalAlpha = p.alpha;
      ctx.fillStyle = p.color;

      // Rectangle rotaté
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate(p.rot);
      ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
      ctx.restore();
    }

    ctx.globalAlpha = 1;

    if (elapsed < durationMs) {
      confettiRafId = requestAnimationFrame(tick);
    } else {
      showConfetti.value = false;
      ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);
      confettiRafId = null;
    }
  };

  confettiRafId = requestAnimationFrame(tick);

  // Sécurité : arrêt forcé
  confettiTimeoutId = window.setTimeout(() => {
    showConfetti.value = false;
    if (confettiRafId) cancelAnimationFrame(confettiRafId);
    confettiRafId = null;
  }, durationMs + 200);
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

  if (confettiRafId) cancelAnimationFrame(confettiRafId);
  if (confettiTimeoutId) clearTimeout(confettiTimeoutId);

  stopRoundCountdown();
});

// Watch pour réinitialiser le marqueur quand on change de localisation
watch(() => currentLocationImageIndex.value, () => {
  resetMarker();
});
</script>
