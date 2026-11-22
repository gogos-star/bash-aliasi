let isEnabled = true;

function updateBadge(state) {
  chrome.action.setBadgeText({ text: state ? "ON" : "OFF" });
  chrome.action.setBadgeBackgroundColor({ color: state ? "#2e7d32" : "#c62828" });
}

function sendToKGet(url) {
  chrome.runtime.sendNativeMessage("com.kget.capture", { url: url }, (response) => {
    if (chrome.runtime.lastError) {
      console.error("GREŠKA:", chrome.runtime.lastError.message);
    }
  });
}

chrome.storage.local.get(["enabled"], (res) => {
  isEnabled = res.enabled !== undefined ? res.enabled : true;
  updateBadge(isEnabled);
});

chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.local.set({ enabled: true });
  updateBadge(true);

  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: "send-to-kget",
      title: "Preuzmi preko KGet-a",
      contexts: ["link"]
    });
  });
});

chrome.action.onClicked.addListener(() => {
  isEnabled = !isEnabled;
  chrome.storage.local.set({ enabled: isEnabled });
  updateBadge(isEnabled);
});

chrome.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId === "send-to-kget" && info.linkUrl) {
    sendToKGet(info.linkUrl);
  }
});

chrome.downloads.onDeterminingFilename.addListener((item) => {
  chrome.storage.local.get(["enabled"], (res) => {
    const active = res.enabled !== undefined ? res.enabled : true;
    if (!active) return;

    const targetUrl = item.finalUrl || item.url;
    if (targetUrl && (targetUrl.startsWith("http://") || targetUrl.startsWith("https://"))) {
      chrome.downloads.cancel(item.id, () => {
        chrome.downloads.erase({ id: item.id });
      });
      sendToKGet(targetUrl);
    }
  });
});
