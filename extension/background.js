/****
 * dichthat - Background Service Worker (MV3)
 * - Context menu
 * - Hotkey (Alt+W)
 * - Get selected text
 * - Call translate API
 * - Inject tooltip UI into page
 */

const LANGS = ['vi', 'en'];

// Create context menu
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'translate',
    title: 'Translate with dichthat',
    contexts: ['selection'],
  });
});

// Right-click handler
chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (
    info.menuItemId === 'translate' &&
    info.selectionText &&
    info.selectionText.trim()
  ) {
    handleTranslate(info.selectionText, tab.id);
  }
});

// Hotkey handler (Alt + W)
chrome.commands.onCommand.addListener(async (command) => {
  if (command === 'translate-selection') {
    const [tab] = await chrome.tabs.query({
      active: true,
      currentWindow: true,
    });

    chrome.scripting.executeScript(
      {
        target: { tabId: tab.id },
        func: () => {
          const sel = window.getSelection();
          const text = sel ? sel.toString().trim() : '';
          return text;
        },
      },
      async (results) => {
        const text = results?.[0]?.result;
        if (!text) return; // no selection → do nothing
        handleTranslate(text, tab.id);
      },
    );
  }
});

chrome.action.onClicked.addListener(async () => {
  const current = await getCurrentLang();
  const next = current === 'vi' ? 'en' : 'vi';
  setCurrentLang(next);

  // show simple feedback via console (alert not supported in service worker)
  console.log('Switched language to:', next);

  // optional: update extension badge to show current lang
  chrome.action.setBadgeText({ text: next.toUpperCase() });
  chrome.action.setBadgeBackgroundColor({ color: '#000000' });
});

// Main translate flow
async function handleTranslate(text, tabId) {
  try {
    const lang = await getCurrentLang();
    const translated = await translate(text);
    const logoUrl = chrome.runtime.getURL('image/logo.png');

    chrome.scripting.executeScript({
      target: { tabId },
      func: showTooltip,
      args: [translated, lang, logoUrl],
    });
  } catch (e) {
    console.error('Translate error:', e);
  }
}

// Google translate (free endpoint)
async function getCurrentLang() {
  return new Promise((resolve) => {
    chrome.storage.local.get(['targetLang'], (res) => {
      resolve(res.targetLang || 'vi');
    });
  });
}

function setCurrentLang(lang) {
  chrome.storage.local.set({ targetLang: lang });
}

async function translate(text) {
  const lang = await getCurrentLang();
  const res = await fetch(
    `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${lang}&dt=t&q=${encodeURIComponent(
      text,
    )}`,
  );
  const data = await res.json();
  return data?.[0]?.[0]?.[0] || 'Không dịch được';
}

// Injected function (runs in page context)
function showTooltip(translatedText, lang, logoUrl) {
  // remove old
  const old = document.getElementById('dichthat-tooltip');
  if (old) old.remove();

  const currentLang = (lang || 'vi').toUpperCase();

  const selection = window.getSelection();
  if (!selection.rangeCount) return;

  const range = selection.getRangeAt(0);

  let rect = range.getBoundingClientRect();

  // nếu selection nhiều dòng → lấy rect đầu (gần user nhìn hơn)
  const rectList = Array.from(range.getClientRects());
  if (rectList.length > 1) {
    rect = rectList[0];
  }

  // fallback nếu rect lỗi (width = 0, ví dụ trong button/span)
  if (!rect || rect.width === 0) {
    const caretRange = range.cloneRange();
    caretRange.collapse(false);
    const caretRect = caretRange.getBoundingClientRect();

    if (caretRect && caretRect.width !== 0) {
      rect = caretRect;
    } else {
      const el = range.startContainer.parentElement;
      if (el) rect = el.getBoundingClientRect();
    }
  }

  const tooltip = document.createElement('div');
  tooltip.id = 'dichthat-tooltip';

  tooltip.innerHTML = `
    <div class="dt-wrap">
      <div class="dt-text">${translatedText}</div>
    </div>
  `;

  const centerX = rect.left + rect.width / 2;
  const spaceAbove = rect.top;
  const spaceBelow = window.innerHeight - rect.bottom;

  const showAbove = spaceAbove > 120 || spaceAbove > spaceBelow;

  Object.assign(tooltip.style, {
    position: 'fixed',
    top: showAbove ? `${rect.top - 6}px` : `${rect.bottom + 6}px`,
    left: `${Math.min(Math.max(centerX, 16), window.innerWidth - 16)}px`,
    zIndex: 2147483647,
    maxWidth: '500px',
    transform: showAbove ? 'translate(-50%, -100%)' : 'translate(-50%, 0)',
  });

  tooltip.style.pointerEvents = 'auto';
  tooltip.style.display = 'inline-block';
  tooltip.style.position = 'fixed';

  document.body.appendChild(tooltip);

  // adjust position after render to avoid overlap
  const tooltipRect = tooltip.getBoundingClientRect();

  const overlapTop =
    tooltipRect.bottom > rect.top && tooltipRect.top < rect.bottom;

  if (overlapTop) {
    // force move above if overlapping
    tooltip.style.top = `${rect.top - 6}px`;
    tooltip.style.transform = 'translate(-50%, -100%)';
  }

  try {
    // Replace color detection with fixed white background and black text
    tooltip.style.removeProperty('--dt-bg');
    tooltip.style.removeProperty('--dt-text');

    tooltip.style.setProperty('--dt-bg', 'rgba(255,255,255,0.96)');
    tooltip.style.setProperty('--dt-text', '#111');
  } catch (e) {}

  // inject style once
  if (!document.getElementById('dichthat-style')) {
    const style = document.createElement('style');
    style.id = 'dichthat-style';
    style.textContent = `
      .dt-wrap {
        background: var(--dt-bg, rgba(255,255,255,0.95));
        color: var(--dt-text, #111);
        padding: 8px 10px;
        border-radius: 6px;
        box-shadow: 0 8px 24px rgba(0,0,0,0.12);
        border: 1px solid rgba(0,0,0,0.2);
        backdrop-filter: blur(8px);
        font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
        animation: dt-fade-in 0.18s ease;
        position: relative;
        z-index: 1;
        overflow: visible;
      }

      .dt-text {
        font-size: 14px;
        line-height: 1.6;
        font-weight: 500;
        letter-spacing: 0.2px;
      }

      @keyframes dt-fade-in {
        from {
          opacity: 0;
          transform: translateY(6px);
        }
        to {
          opacity: 1;
          transform: translateY(0);
        }
      }
    `;
    document.head.appendChild(style);
  }

  // click outside → close
  const onClickOutside = (event) => {
    if (!tooltip.contains(event.target)) {
      tooltip.style.opacity = '0';
      setTimeout(() => tooltip.remove(), 200);
      document.removeEventListener('mousedown', onClickOutside);
    }
  };

  setTimeout(() => {
    document.addEventListener('mousedown', onClickOutside);
  }, 0);
}
