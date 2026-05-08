// src/speech-bubble.js — Rocky's speech bubble (comic-style dialogue above pet)
const { BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const { pickPhrase, pickAmbient, getPhraseSound } = require("./phrases-rocky");

const MIN_INTERVAL_MS = 8000;
const SHOW_PROBABILITY = 0.45;
const MS_PER_CHAR = 70;
const MIN_DURATION_MS = 2000;
const MAX_DURATION_MS = 5000;

// Ambient timer — fires during stable states for idle quips
const AMBIENT_MIN_MS = 20000;
const AMBIENT_MAX_MS = 45000;
const AMBIENT_THROTTLE_MS = 15000;
const AMBIENT_PROBABILITY = 0.50;

const isWin = process.platform === "win32";
const isMac = process.platform === "darwin";
const isLinux = process.platform === "linux";

function computeDuration(text) {
  return Math.min(Math.max(text.length * MS_PER_CHAR, MIN_DURATION_MS), MAX_DURATION_MS);
}

module.exports = function initSpeechBubble(ctx) {
  let bubbleWin = null;
  let lastShownAt = 0;
  let lastAmbientAt = 0;
  let bubbleWidth = 0;
  let bubbleHeight = 0;
  let loaded = false;
  let currentState = "idle";
  let ambientTimer = null;

  function getBubbleWindow() {
    if (bubbleWin && !bubbleWin.isDestroyed()) return bubbleWin;

    bubbleWin = new BrowserWindow({
      width: 340,
      height: 90,
      show: false,
      frame: false,
      transparent: true,
      alwaysOnTop: true,
      resizable: false,
      skipTaskbar: true,
      hasShadow: false,
      focusable: false,
      ...(isLinux ? { type: "toolbar" } : {}),
      ...(isMac ? { type: "panel" } : {}),
      webPreferences: {
        preload: path.join(__dirname, "preload-speech-bubble.js"),
        nodeIntegration: false,
        contextIsolation: true,
      },
    });

    if (isWin) {
      bubbleWin.setAlwaysOnTop(true, "pop-up-menu");
    }

    bubbleWin.loadFile(path.join(__dirname, "speech-bubble.html"));

    bubbleWin.webContents.once("did-finish-load", () => {
      loaded = true;
      if (bubbleWin._pendingShow) {
        const p = bubbleWin._pendingShow;
        bubbleWin._pendingShow = null;
        _doShow(p.text, p.durationMs);
      }
    });

    bubbleWin.on("closed", () => {
      bubbleWin = null;
      loaded = false;
    });

    return bubbleWin;
  }

  function repositionBubble() {
    if (!bubbleWin || bubbleWin.isDestroyed()) return;
    if (!ctx || typeof ctx.getPetWindowBounds !== "function") return;

    const pet = ctx.getPetWindowBounds();
    if (!pet || pet.width <= 0) return;

    const bw = bubbleWidth > 0 ? bubbleWidth : 200;
    const bh = bubbleHeight > 0 ? bubbleHeight : 40;
    const gap = 8;

    const x = Math.round(pet.x + pet.width / 2 - bw / 2);
    const y = Math.round(pet.y - bh - gap);

    bubbleWin.setBounds({ x, y, width: bw, height: bh });
  }

  function _doShow(text, durationMs) {
    if (!bubbleWin || bubbleWin.isDestroyed()) return;
    repositionBubble();
    bubbleWin.showInactive();
    bubbleWin.webContents.executeJavaScript(
      `_showBubble(${JSON.stringify(text)}, ${durationMs})`
    );
    if (ctx && typeof ctx.guardAlwaysOnTop === "function") {
      ctx.guardAlwaysOnTop(bubbleWin);
    }
  }

  function showPhrase(text, { ambient = false } = {}) {
    const win = getBubbleWindow();
    const dur = computeDuration(text);
    _playVoice(text, ambient);
    if (!loaded) {
      win._pendingShow = { text, durationMs: dur };
      return;
    }
    _doShow(text, dur);
  }

  function _playVoice(text, ambient) {
    const sound = getPhraseSound(text);
    if (sound && ctx && typeof ctx.playSpeechSound === "function") {
      ctx.playSpeechSound(sound, ambient);
    }
  }

  function hideSpeechBubble() {
    if (!bubbleWin || bubbleWin.isDestroyed()) return;
    bubbleWin.webContents.executeJavaScript("_hideBubble()");
  }

  function trySpeechBubble(state) {
    if (ctx && ctx.doNotDisturb) return;

    const phrase = pickPhrase(state);
    if (!phrase) return;

    const now = Date.now();
    if (now - lastShownAt < MIN_INTERVAL_MS) return;

    if (Math.random() > SHOW_PROBABILITY) return;

    lastShownAt = now;
    showPhrase(phrase);
  }

  // ── Ambient timer ──

  function _ambientTick() {
    ambientTimer = null;
    if (ctx && ctx.doNotDisturb) {
      _scheduleAmbient();
      return;
    }

    const phrase = pickAmbient(currentState);
    if (!phrase) {
      _scheduleAmbient();
      return;
    }

    const now = Date.now();
    // Respect the global throttle so ambient doesn't fire right after a transition phrase
    if (now - lastShownAt < MIN_INTERVAL_MS || now - lastAmbientAt < AMBIENT_THROTTLE_MS) {
      _scheduleAmbient();
      return;
    }

    if (Math.random() > AMBIENT_PROBABILITY) {
      _scheduleAmbient();
      return;
    }

    lastAmbientAt = now;
    lastShownAt = now;
    showPhrase(phrase, { ambient: true });
    _scheduleAmbient();
  }

  function _scheduleAmbient() {
    if (ambientTimer) clearTimeout(ambientTimer);
    const delay = AMBIENT_MIN_MS + Math.random() * (AMBIENT_MAX_MS - AMBIENT_MIN_MS);
    ambientTimer = setTimeout(_ambientTick, delay);
  }

  function setCurrentState(state) {
    currentState = state;
    // Start ambient timer on first state set (if not already running)
    if (!ambientTimer) _scheduleAmbient();
  }

  function handleSpeechSize(w, h) {
    bubbleWidth = Math.ceil(w);
    bubbleHeight = Math.ceil(h);
    repositionBubble();
  }

  function destroyBubble() {
    if (ambientTimer) { clearTimeout(ambientTimer); ambientTimer = null; }
    if (bubbleWin && !bubbleWin.isDestroyed()) {
      bubbleWin.close();
    }
    bubbleWin = null;
    loaded = false;
  }

  return {
    getBubbleWindow,
    showPhrase,
    hideSpeechBubble,
    trySpeechBubble,
    setCurrentState,
    destroyBubble,
    repositionBubble,
    handleSpeechSize,
  };
};
