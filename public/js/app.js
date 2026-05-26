const btn = document.getElementById("getKeyBtn");
const status = document.getElementById("status");

function setStatus(text, type) {
  status.textContent = text;
  status.className = "status" + (type ? " " + type : "");
}

btn.addEventListener("click", async () => {
  btn.disabled = true;
  setStatus("Creating your link…");

  try {
    const res = await fetch("/api/get-link", { method: "POST" });
    const data = await res.json();

    if (!data.ok || !data.url) {
      throw new Error(data.error || "Could not create link.");
    }

    setStatus("Redirecting… complete all ad steps.", "ok");
    window.location.href = data.url;
  } catch (err) {
    setStatus(err.message || "Something went wrong.", "err");
    btn.disabled = false;
  }
});
