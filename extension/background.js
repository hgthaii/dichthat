chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "translate",
    title: "Dịch với dichthat",
    contexts: ["selection"]
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId === "translate") {
    const text = info.selectionText;

    const translated = await translate(text);

    chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: showPopup,
      args: [translated]
    });
  }
});

// call API (mock trước)
// async function translate(text) {
//   return "👉 " + text; // tạm fake
// }

async function translate(text) {
  const res = await fetch(
    `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=vi&dt=t&q=${encodeURIComponent(text)}`
  );

  const data = await res.json();
  return data[0][0][0];
}

// inject UI
function showPopup(translatedText) {
  const div = document.createElement("div");
  div.innerText = translatedText;

  div.style.position = "fixed";
  div.style.bottom = "20px";
  div.style.right = "20px";
  div.style.background = "#111";
  div.style.color = "#fff";
  div.style.padding = "10px 14px";
  div.style.borderRadius = "8px";
  div.style.zIndex = 999999;

  document.body.appendChild(div);

  setTimeout(() => div.remove(), 3000);
}