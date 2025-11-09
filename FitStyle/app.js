(function () {
  const views = Array.from(document.querySelectorAll('.view'));
  const home = document.getElementById('home');
  const year = document.getElementById('year');
  if (year) year.textContent = String(new Date().getFullYear());

  function show(id) {
    views.forEach(v => v.classList.remove('active'));
    const target = document.getElementById(id) || home;
    target.classList.add('active');
    history.replaceState({}, '', `#${id}`);
  }

  document.addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-target]');
    if (!btn) return;
    const id = btn.getAttribute('data-target');
    show(id);
  });

  // Simple demo data hooks (placeholder)
  const form = document.getElementById('addItemForm');
  const suggestionsList = document.getElementById('suggestionsList');
  const savedList = document.getElementById('savedList');

  const wardrobe = [];
  const savedLooks = [];

  if (form) {
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const name = document.getElementById('itemName').value.trim();
      const category = document.getElementById('itemCategory').value;
      const color = document.getElementById('itemColor').value.trim();
      if (!name) return;
      wardrobe.push({ name, category, color });
      form.reset();
      alert('Item saved to wardrobe');
    });
  }

  // Very naive suggestion demo
  function generateSuggestions() {
    suggestionsList.innerHTML = '';
    if (wardrobe.length === 0) {
      suggestionsList.innerHTML = '<div class="card">Add items to see suggestions.</div>';
      return;
    }
    const picks = wardrobe.slice(0, 6);
    picks.forEach((item, idx) => {
      const card = document.createElement('div');
      card.className = 'card';
      card.innerHTML = `
        <strong>${item.name}</strong><br />
        <small>${item.category}${item.color ? ' • ' + item.color : ''}</small>
        <div class="row" style="margin-top:10px">
          <button class="btn primary">Save Look</button>
        </div>
      `;
      card.querySelector('button').addEventListener('click', () => {
        savedLooks.push({ ...item, id: Date.now() + '-' + idx });
        renderSaved();
        alert('Look saved');
      });
      suggestionsList.appendChild(card);
    });
  }

  function renderSaved() {
    savedList.innerHTML = '';
    if (savedLooks.length === 0) {
      savedList.innerHTML = '<div class="card">No saved looks yet.</div>';
      return;
    }
    savedLooks.forEach(look => {
      const card = document.createElement('div');
      card.className = 'card';
      card.innerHTML = `
        <strong>${look.name}</strong><br />
        <small>${look.category}${look.color ? ' • ' + look.color : ''}</small>
      `;
      savedList.appendChild(card);
    });
  }

  // Routing from hash
  function initFromHash() {
    const id = (location.hash || '#home').slice(1);
    show(id);
    if (id === 'suggestions') generateSuggestions();
    if (id === 'saved-looks') renderSaved();
  }
  window.addEventListener('hashchange', initFromHash);

  // First load
  initFromHash();
})();
