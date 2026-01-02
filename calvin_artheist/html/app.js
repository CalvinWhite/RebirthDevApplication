let current = null;

window.addEventListener("message", (event) => {
  const data = event.data;
  if (!data || data.action !== "play" || !data.sound) return;

  const file = `sounds/${data.sound}.mp3`;

  try {
    if (current) {
      current.pause();
      current.currentTime = 0;
    }

    current = new Audio(file);
    current.volume = 0.9;
    current.play().catch(() => {});
  } catch (e) {
    // fail silently
  }
});
