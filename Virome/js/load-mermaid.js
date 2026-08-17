document.addEventListener('DOMContentLoaded', async () => {
  const nodes = Array.from(document.querySelectorAll('.mermaid[data-mmd]'));
  if (nodes.length === 0) return;

  const config = {
    startOnLoad: false,
    theme: 'dark',
    themeVariables: { fontSize: '50px' },
    flowchart: { useMaxWidth: true, nodeSpacing: 30, rankSpacing: 50 }
  };
  if (window.mermaid && typeof window.mermaid.initialize === 'function') {
    mermaid.initialize(config);
  }

  const tasks = nodes.map(async (el) => {
    const mmdPath = el.dataset.mmd;
    try {
      const resp = await fetch(mmdPath);
      if (!resp.ok) throw new Error(`${resp.status} ${resp.statusText}`);
      const text = await resp.text();
      el.textContent = text;

      if (window.mermaid && typeof window.mermaid.init === 'function') {
        // render only this container
        mermaid.init(undefined, el);
      } else {
        console.warn('mermaid not available; diagram text inserted but not rendered.');
      }

      // make generated svg responsive & centered (if present)
      const svg = el.querySelector('svg');
      if (svg) {
        svg.removeAttribute('width');
        svg.removeAttribute('height');
        svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
        svg.style.display = 'inline-block';
        svg.style.margin = '0 auto';
        svg.style.maxWidth = '100%';
        svg.style.height = 'auto';
      }
    } catch (err) {
      el.textContent = 'Error loading diagram: ' + err;
      console.error(err);
    }
  });

  await Promise.allSettled(tasks);
});