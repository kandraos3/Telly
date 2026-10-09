// The hero's playable duel (docs/design_system/05_WEBSITE.md §2).
// The page renders the first pair; this script makes the picks work, shows the
// result with example scores, and cycles through the pairs in `data-duel`.
// No library and no network: the page reads fully without it.
(function () {
  'use strict';

  var root = document.querySelector('.duel[data-duel]');
  if (!root) return;
  var card = root.querySelector('.duel__card');
  var data;
  try {
    data = JSON.parse(root.getAttribute('data-duel'));
  } catch (e) {
    return;
  }
  var pair = 0;

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text != null) node.textContent = text;
    return node;
  }

  function poster(item) {
    var img = el('img');
    img.src = item.poster;
    img.width = 342;
    img.height = 513;
    img.alt = '';
    img.decoding = 'async';
    return img;
  }

  function head(question, media) {
    var box = el('div', 'duel__head');
    var h = el('h2', 'duel__q', question);
    h.tabIndex = -1;
    box.appendChild(h);
    box.appendChild(el('span', 'duel__media', media));
    return box;
  }

  function showPick(focus) {
    var items = data.pairs[pair % data.pairs.length];
    card.textContent = '';
    card.appendChild(head('Which did you like more?', data.media + ' · Duel'));
    var row = el('div', 'duel__pair');
    items.forEach(function (item, i) {
      var button = el('button', 'duel__pick');
      button.type = 'button';
      button.setAttribute('data-pick', String(i));
      button.appendChild(poster(item));
      button.appendChild(el('span', 'duel__title', item.title));
      row.appendChild(button);
      if (i === 0) {
        var vs = el('span', 'duel__vs', 'vs');
        vs.setAttribute('aria-hidden', 'true');
        row.appendChild(vs);
      }
    });
    card.appendChild(row);
    var foot = el('div', 'duel__foot');
    foot.appendChild(el('span', 'duel__hint', 'Tap the one you liked more'));
    var tie = el('button', 'duel__tie', 'Too close to call');
    tie.type = 'button';
    tie.setAttribute('data-pick', 'tie');
    foot.appendChild(tie);
    card.appendChild(foot);
    if (focus) row.querySelector('button').focus();
  }

  function showResult(pick) {
    var items = data.pairs[pair % data.pairs.length];
    var tie = pick === 'tie';
    var win = tie ? items[0] : items[Number(pick)];
    var lose = tie ? items[1] : items[1 - Number(pick)];
    card.textContent = '';
    card.appendChild(head(tie ? 'Called it a tie' : win.title + ' takes the higher spot', data.media + ' · Result'));
    var list = el('ol', 'duel__ranking');
    [[win, 1, data.scores[0], true], [lose, tie ? 1 : 2, tie ? data.scores[0] : data.scores[1], tie]].forEach(function (row) {
      var li = el('li', row[3] ? 'is-top' : '');
      li.appendChild(el('span', 'duel__rank', '#' + row[1]));
      li.appendChild(poster(row[0]));
      li.appendChild(el('span', 'duel__name', row[0].title));
      li.appendChild(el('span', 'duel__score', row[2]));
      list.appendChild(li);
    });
    card.appendChild(list);
    var foot = el('div', 'duel__foot');
    foot.appendChild(el('span', 'duel__hint', data.label));
    var next = el('button', 'duel__next', 'Next duel');
    next.type = 'button';
    foot.appendChild(next);
    card.appendChild(foot);
    card.querySelector('.duel__q').focus();
  }

  card.addEventListener('click', function (event) {
    var button = event.target.closest('button');
    if (!button || !card.contains(button)) return;
    if (button.classList.contains('duel__next')) {
      pair += 1;
      showPick(true);
    } else if (button.hasAttribute('data-pick')) {
      showResult(button.getAttribute('data-pick'));
    }
  });
  root.classList.add('duel--live');
})();
