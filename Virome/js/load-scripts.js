document.addEventListener('DOMContentLoaded', () => {
  const nodes = document.querySelectorAll('pre code[data-script]');
  nodes.forEach(async (el) => {
    const name = el.dataset.script;
    const path = el.dataset.path || `scripts/${name}.sh`;
    try {
      const resp = await fetch(path);
      if (!resp.ok) throw new Error(`${resp.status} ${resp.statusText}`);
      const txt = await resp.text();
      el.textContent = txt;
      if (window.Prism) Prism.highlightElement(el);
    } catch (err) {
      el.textContent = `Error loading ${path}: ${err}`;
      console.error(err);
    }
  });
});