const params = new URLSearchParams(window.location.search);
const sid = params.get("sid");

const title = document.getElementById("title");
const subtitle = document.getElementById("subtitle");
const waiting = document.getElementById("waiting");
const success = document.getElementById("success");
const errorBox = document.getElementById("error");
const errorText = document.getElementById("errorText");
const keyBox = document.getElementById("keyBox");
const copyBtn = document.getElementById("copyBtn");

function show(el) {
  [waiting, success, errorBox].forEach((node) => node.classList.add("hidden"));
  el.classList.remove("hidden");
}

async function pollSession() {
  if (!sid) {
    title.textContent = "Invalid link";
    subtitle.textContent = "No session ID found. Go back and get a new key.";
    show(errorBox);
    errorText.textContent = "Missing session ID in URL.";
    return;
  }

  show(waiting);
  title.textContent = "Almost there…";
  subtitle.textContent = "Finish every ad step to receive your key.";

  let attempts = 0;
  const maxAttempts = 60;

  while (attempts < maxAttempts) {
    attempts += 1;

    try {
      const res = await fetch(`/api/session/${encodeURIComponent(sid)}`);
      const data = await res.json();

      if (!data.ok) {
        title.textContent = "Session not found";
        show(errorBox);
        errorText.textContent = data.error || "This session expired or never existed.";
        return;
      }

      if (data.completed && data.key) {
        title.textContent = "Your key is ready";
        subtitle.textContent = `Valid for ${data.expiresInHours || 24} hours · HWID locks on first use.`;
        keyBox.value = data.key;
        show(success);
        return;
      }
    } catch {
      /* retry */
    }

    await new Promise((r) => setTimeout(r, 2000));
  }

  title.textContent = "Still waiting…";
  subtitle.textContent = "Make sure you completed every ad step.";
  show(errorBox);
  errorText.textContent = "Postback not received yet. Go back, click Get Key again, and finish all tasks.";
}

copyBtn.addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText(keyBox.value);
    copyBtn.textContent = "Copied!";
    setTimeout(() => {
      copyBtn.textContent = "Copy";
    }, 2000);
  } catch {
    keyBox.select();
    document.execCommand("copy");
    copyBtn.textContent = "Copied!";
  }
});

pollSession();
