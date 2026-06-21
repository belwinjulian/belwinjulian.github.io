/**
 * brain-dump.js — reusable active-recall widget
 *
 * Usage in a lesson:
 *   <div class="brain-dump" id="bd1"
 *        data-prompt="Your question here"
 *        data-points='["Point 1","Point 2","Point 3"]'>
 *   </div>
 *   <script src="../assets/brain-dump.js"></script>
 *
 * The widget renders itself, handles reveal, and lets the user
 * mark each key point as "got it" or "missed".
 */
(function () {
  function buildWidget(el) {
    const prompt = el.dataset.prompt || 'Brain dump: write everything you remember.';
    const points = JSON.parse(el.dataset.points || '[]');
    const id = el.id || ('bd-' + Math.random().toString(36).slice(2, 7));

    el.innerHTML = `
      <div class="brain-dump-header">✏ Brain Dump — Active Recall</div>
      <p class="brain-dump-prompt">${prompt}</p>
      <textarea id="${id}-text" placeholder="Write freely — no peeking. Aim to recall everything you just learned..."></textarea>
      <div class="brain-dump-actions">
        <button class="btn btn-primary" onclick="revealBD('${id}')">Reveal key points</button>
        <button class="btn btn-secondary" onclick="clearBD('${id}')">Clear</button>
      </div>
      <div class="answer-panel" id="${id}-panel">
        <h3>Key points to check</h3>
        <p style="font-size:0.88em;color:#5a5a5a;margin-bottom:0.8rem;font-family:-apple-system,sans-serif;">
          Mark each one: did you get it?
        </p>
        <ul class="key-points" id="${id}-list">
          ${points.map((p, i) => `
            <li id="${id}-pt${i}">
              <span>${p}</span>
              <span style="float:right;font-family:-apple-system,sans-serif;font-size:0.8em;display:flex;gap:0.4rem;margin-top:0.1rem;">
                <button class="btn btn-secondary" style="padding:0.2rem 0.6rem;font-size:0.75rem;" onclick="markBD('${id}',${i},'got')">✓ Got it</button>
                <button class="btn btn-secondary" style="padding:0.2rem 0.6rem;font-size:0.75rem;" onclick="markBD('${id}',${i},'miss')">✗ Missed</button>
              </span>
            </li>
          `).join('')}
        </ul>
        <div class="gap-note" id="${id}-gap" style="display:none"></div>
      </div>
    `;
  }

  window.revealBD = function (id) {
    document.getElementById(id + '-panel').classList.add('visible');
    const ta = document.getElementById(id + '-text');
    if (ta) ta.setAttribute('readonly', true);
  };

  window.clearBD = function (id) {
    const ta = document.getElementById(id + '-text');
    if (ta) { ta.removeAttribute('readonly'); ta.value = ''; ta.focus(); }
    const panel = document.getElementById(id + '-panel');
    if (panel) panel.classList.remove('visible');
    const gap = document.getElementById(id + '-gap');
    if (gap) { gap.style.display = 'none'; gap.textContent = ''; }
    document.querySelectorAll(`[id^="${id}-pt"]`).forEach(li => {
      li.classList.remove('got-it', 'missed');
    });
  };

  window.markBD = function (id, i, verdict) {
    const li = document.getElementById(id + '-pt' + i);
    if (!li) return;
    li.classList.remove('got-it', 'missed');
    li.classList.add(verdict === 'got' ? 'got-it' : 'missed');
    updateGap(id);
  };

  function updateGap(id) {
    const missed = document.querySelectorAll(`[id^="${id}-pt"].missed`);
    const gap = document.getElementById(id + '-gap');
    if (!gap) return;
    if (missed.length === 0) {
      gap.style.display = 'none';
      return;
    }
    const labels = Array.from(missed).map(li => li.querySelector('span').textContent.trim());
    gap.style.display = 'block';
    gap.innerHTML = `<strong>Gaps to revisit:</strong> ${labels.join(' · ')} — ask your teacher to go deeper on these.`;
  }

  document.querySelectorAll('.brain-dump[data-points]').forEach(buildWidget);
})();
