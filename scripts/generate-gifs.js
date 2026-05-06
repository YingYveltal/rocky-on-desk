#!/usr/bin/env node
// Render animated SVGs to GIFs using Electron offscreen rendering
const { app, BrowserWindow } = require("electron");
const fs = require("fs");
const path = require("path");
const { PNG } = require("pngjs");
const GIFEncoder = require("gif-encoder-2");

const THEME_DIR = path.resolve(__dirname, "..", "themes", "rocky");
const ASSETS_DIR = path.join(THEME_DIR, "assets");
const OUT_DIR = path.join(__dirname, "..", "assets", "gif");

const W = 160, H = 160, SCALE = 2;
const FRAMES = 24, DELAY = 100; // ms

async function captureSvg(win, svgPath, outputPath) {
  const svg = fs.readFileSync(svgPath, "utf-8");
  const html = `<!DOCTYPE html><html><head><style>
    body{margin:0;background:transparent;display:flex;align-items:center;justify-content:center;width:${W}px;height:${H}px;overflow:hidden}
    svg{width:${W}px;height:${H}px}
  </style></head><body>${svg}</body></html>`;

  const tmp = path.join(__dirname, "_render.html");
  fs.writeFileSync(tmp, html);
  await win.loadFile(tmp);

  // Let CSS animations start
  await sleep(400);

  const encoder = new GIFEncoder(W * SCALE, H * SCALE, "neuquant", true);
  encoder.setDelay(Math.round(DELAY / 10));
  encoder.setRepeat(0);
  encoder.start();

  for (let i = 0; i < FRAMES; i++) {
    const img = await win.webContents.capturePage({
      x: 0, y: 0, width: W * SCALE, height: H * SCALE,
    });
    const png = PNG.sync.read(img.toPNG());
    encoder.addFrame(png.data);
    await sleep(DELAY);
  }

  encoder.finish();
  fs.writeFileSync(outputPath, encoder.out.getData());
  fs.unlinkSync(tmp);
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

app.whenReady().then(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const svgs = fs.readdirSync(ASSETS_DIR).filter(f =>
    f.endsWith(".svg") && f !== "rocky-static-base.svg"
  );

  const win = new BrowserWindow({
    width: W * SCALE, height: H * SCALE,
    transparent: true, frame: false, show: false,
    webPreferences: { offscreen: true },
  });

  console.log(`Generating ${svgs.length} GIFs...\n`);

  for (const svgFile of svgs) {
    const svgPath = path.join(ASSETS_DIR, svgFile);
    const gifName = svgFile.replace(".svg", ".gif");
    const gifPath = path.join(OUT_DIR, gifName);
    try {
      await captureSvg(win, svgPath, gifPath);
      console.log(`  ${gifName}`);
    } catch (e) {
      console.error(`  FAIL ${svgFile}: ${e.message}`);
    }
  }

  win.close();
  console.log(`\nDone → ${OUT_DIR}`);
  app.quit();
});
