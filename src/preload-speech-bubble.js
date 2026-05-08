const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("speechBubbleAPI", {
  reportSize: (w, h) => ipcRenderer.send("speech-size", w, h),
});
