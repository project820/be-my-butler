/* ═══════════════════════════════════════════════
   BMB — Be My Butler · Shared JavaScript
   Extracted from index.html + mobile/i18n additions
   ═══════════════════════════════════════════════ */

// ─── Mermaid Initialization ────────────────────
if (typeof mermaid !== 'undefined') {
  mermaid.initialize({
    theme: 'dark',
    themeVariables: {
      primaryColor: '#1a2234',
      primaryBorderColor: '#3b82f6',
      primaryTextColor: '#e8edf5',
      lineColor: '#3b82f6',
      secondaryColor: '#1a2234',
      tertiaryColor: '#111827',
      noteBkgColor: '#1a2234',
      noteTextColor: '#e8edf5',
      noteBorderColor: '#1e3a5f',
      actorBkg: '#111827',
      actorBorder: '#3b82f6',
      actorTextColor: '#e8edf5',
      signalColor: '#60a5fa',
      signalTextColor: '#e8edf5',
      labelBoxBkgColor: '#1a2234',
      labelBoxBorderColor: '#1e3a5f',
      labelTextColor: '#e8edf5',
      loopTextColor: '#8494a7',
      activationBorderColor: '#3b82f6',
      activationBkgColor: '#243049',
      sequenceNumberColor: '#e8edf5',
      sectionBkgColor: '#111827',
      sectionBkgColor2: '#1a2234',
      altSectionBkgColor: '#111827',
      gridColor: '#1e3a5f',
      taskBkgColor: '#3b82f6',
      taskBorderColor: '#1e3a5f',
      taskTextColor: '#e8edf5',
      taskTextLightColor: '#e8edf5',
      activeTaskBkgColor: '#22c55e',
      activeTaskBorderColor: '#16a34a',
      doneTaskBkgColor: '#243049',
      doneTaskBorderColor: '#1e3a5f',
      critBkgColor: '#f59e0b',
      critBorderColor: '#d97706',
      todayLineColor: '#ef4444'
    },
    flowchart: { curve: 'basis', padding: 20 },
    gantt: { fontSize: 11, barHeight: 20, topPadding: 30, sectionFontSize: 12 },
    sequence: { actorMargin: 50, messageMargin: 40 }
  });
}

// ─── Accordion toggle ──────────────────────────
function toggleAccordion(header) {
  var item = header.parentElement;
  item.classList.toggle('open');
}

// ─── Intersection Observer for fade-in ─────────
if ('IntersectionObserver' in window) {
  var observer = new IntersectionObserver(function(entries) {
    entries.forEach(function(entry) {
      if (entry.isIntersecting) {
        entry.target.style.animationPlayState = 'running';
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.1 });

  document.querySelectorAll('.fade-in').forEach(function(el) {
    el.style.animationPlayState = 'paused';
    observer.observe(el);
  });
}

// ─── Active nav link (scroll spy) ──────────────
var sections = document.querySelectorAll('section[id]');
var navLinks = document.querySelectorAll('.nav a');

function setActiveNav(activeId) {
  navLinks.forEach(function(link) {
    var isActive = link.getAttribute('href') === '#' + activeId;
    link.style.color = isActive ? 'var(--accent-light)' : '';
    link.style.background = isActive ? 'rgba(59,130,246,0.08)' : '';
  });
}

if (!document.body.classList.contains('mobile-landing')) {
  window.addEventListener('scroll', function() {
    if (document.body.classList.contains('slide-mode')) return;
    var current = '';
    sections.forEach(function(section) {
      if (window.scrollY >= section.offsetTop - 100) {
        current = section.getAttribute('id');
      }
    });
    setActiveNav(current);
  });
}

// ─── Slide Mode ────────────────────────────────
var slideMode = false;
var currentSlide = 0;
var slides = [];

function getSlides() {
  return [document.querySelector('.hero')].concat(
    Array.from(document.querySelectorAll('section[id]'))
  );
}

function updateIndicator() {
  var indicator = document.querySelector('.slide-indicator');
  if (indicator) indicator.textContent = (currentSlide + 1) + ' / ' + slides.length;
}

function updateDots() {
  var dots = document.querySelectorAll('.slide-dots .dot');
  dots.forEach(function(dot, i) {
    dot.classList.toggle('active', i === currentSlide);
  });
}

function updateNavHighlight() {
  var activeId = slides[currentSlide] && slides[currentSlide].getAttribute('id');
  setActiveNav(activeId);
  // Also update drawer nav links
  document.querySelectorAll('.drawer-nav a').forEach(function(link) {
    link.classList.toggle('active', link.getAttribute('href') === '#' + activeId);
  });
}

function goToSlide(index, direction) {
  if (index < 0 || index >= slides.length) return;
  var prev = slides[currentSlide];
  prev.classList.remove('active-slide');
  prev.classList.remove('slide-enter-left', 'slide-enter-right');
  currentSlide = index;
  var next = slides[currentSlide];
  // Apply directional animation class
  if (direction === 'left') {
    next.classList.add('slide-enter-right');
  } else if (direction === 'right') {
    next.classList.add('slide-enter-left');
  }
  next.classList.add('active-slide');
  updateIndicator();
  updateDots();
  updateNavHighlight();
  // Re-render mermaid in newly visible slide
  var mermaidEls = next.querySelectorAll('.mermaid[data-processed]');
  if (mermaidEls.length === 0) {
    var unprocessed = next.querySelectorAll('.mermaid:not([data-processed])');
    if (unprocessed.length > 0 && typeof mermaid !== 'undefined') {
      mermaid.run({ nodes: Array.from(unprocessed) });
    }
  }
  // Clean up animation classes after transition
  setTimeout(function() {
    next.classList.remove('slide-enter-left', 'slide-enter-right');
  }, 350);
}

function buildDots() {
  var container = document.querySelector('.slide-dots');
  if (!container) return;
  container.innerHTML = '';
  slides.forEach(function(_, i) {
    var dot = document.createElement('span');
    dot.className = 'dot' + (i === currentSlide ? ' active' : '');
    dot.addEventListener('click', function() { goToSlide(i); });
    container.appendChild(dot);
  });
}

function toggleSlideMode() {
  slideMode = !slideMode;
  var btn = document.querySelector('.slide-toggle');

  if (slideMode) {
    slides = getSlides();
    // Find which section is currently most visible
    var bestIndex = 0;
    var scrollY = window.scrollY + window.innerHeight / 2;
    slides.forEach(function(s, i) {
      if (s.offsetTop <= scrollY) bestIndex = i;
    });
    currentSlide = bestIndex;

    document.body.classList.add('slide-mode');
    slides[currentSlide].classList.add('active-slide');
    updateIndicator();
    updateNavHighlight();
    buildDots();
    if (btn) btn.textContent = 'Scroll Mode';
  } else {
    exitSlideMode();
  }
}

function exitSlideMode() {
  if (!slideMode) return;
  slideMode = false;
  var activeSlide = slides[currentSlide];
  slides.forEach(function(s) { s.classList.remove('active-slide', 'slide-enter-left', 'slide-enter-right'); });
  document.body.classList.remove('slide-mode');
  var btn = document.querySelector('.slide-toggle');
  if (btn) btn.textContent = 'Slide Mode';
  // Scroll to the section that was active
  if (activeSlide) {
    activeSlide.scrollIntoView({ behavior: 'instant' });
  }
}

// Keyboard navigation
document.addEventListener('keydown', function(e) {
  if (!slideMode) return;
  if (e.key === 'ArrowRight' || e.key === 'j' || e.key === 'J') {
    e.preventDefault();
    goToSlide(currentSlide + 1, 'left');
  } else if (e.key === 'ArrowLeft' || e.key === 'k' || e.key === 'K') {
    e.preventDefault();
    goToSlide(currentSlide - 1, 'right');
  } else if (e.key === 'Escape') {
    e.preventDefault();
    exitSlideMode();
  }
});

function findSlideIndex(targetId) {
  var idx = -1;
  slides.forEach(function(s, i) {
    if (s.getAttribute && s.getAttribute('id') === targetId) idx = i;
  });
  return idx;
}

// Nav click jumps to slide in slide mode
navLinks.forEach(function(link) {
  link.addEventListener('click', function(e) {
    if (!slideMode) return;
    e.preventDefault();
    var idx = findSlideIndex(link.getAttribute('href').slice(1));
    if (idx >= 0) goToSlide(idx);
  });
});

// ─── Touch Swipe (mobile) ──────────────────────
var touchStartX = 0;
var touchStartY = 0;
var touchStartTime = 0;
var SWIPE_THRESHOLD = 50;

document.addEventListener('touchstart', function(e) {
  if (!slideMode) return;
  touchStartX = e.changedTouches[0].screenX;
  touchStartY = e.changedTouches[0].screenY;
  touchStartTime = Date.now();
}, { passive: true });

document.addEventListener('touchend', function(e) {
  if (!slideMode) return;
  var deltaX = e.changedTouches[0].screenX - touchStartX;
  var deltaY = e.changedTouches[0].screenY - touchStartY;
  var elapsed = Date.now() - touchStartTime;

  // Only recognize horizontal swipes: |deltaX| > threshold AND |deltaX| > |deltaY|
  if (Math.abs(deltaX) > SWIPE_THRESHOLD && Math.abs(deltaX) > Math.abs(deltaY) && elapsed < 800) {
    if (deltaX < 0) {
      // Swipe left → next slide
      goToSlide(currentSlide + 1, 'left');
    } else {
      // Swipe right → previous slide
      goToSlide(currentSlide - 1, 'right');
    }
  }
}, { passive: true });

// ─── Mobile: No auto slide mode ────────────────
// Mobile uses vertical scroll (separate layout via CSS).
// Slide mode is desktop-only (toggled manually).

// ─── Hamburger Menu + Drawer ───────────────────
(function() {
  var hamburger = document.querySelector('.hamburger');
  var drawer = document.querySelector('.drawer');
  var overlay = document.querySelector('.drawer-overlay');
  if (!hamburger || !drawer || !overlay) return;

  function openDrawer() {
    hamburger.classList.add('active');
    drawer.classList.add('open');
    overlay.classList.add('open');
  }
  function closeDrawer() {
    hamburger.classList.remove('active');
    drawer.classList.remove('open');
    overlay.classList.remove('open');
  }

  hamburger.addEventListener('click', function() {
    if (drawer.classList.contains('open')) {
      closeDrawer();
    } else {
      openDrawer();
    }
  });

  overlay.addEventListener('click', closeDrawer);

  // Drawer nav links → go to slide + close drawer
  drawer.querySelectorAll('.drawer-nav a').forEach(function(link) {
    link.addEventListener('click', function(e) {
      if (slideMode) {
        e.preventDefault();
        var idx = findSlideIndex(link.getAttribute('href').slice(1));
        if (idx >= 0) goToSlide(idx);
      }
      closeDrawer();
    });
  });
})();

// ─── Language Switcher (desktop dropdown) ───────
(function() {
  var langBtn = document.querySelector('.lang-btn');
  var langDropdown = document.querySelector('.lang-dropdown');
  if (!langBtn || !langDropdown) return;

  langBtn.addEventListener('click', function(e) {
    e.stopPropagation();
    langDropdown.classList.toggle('open');
  });

  document.addEventListener('click', function() {
    langDropdown.classList.remove('open');
  });
})();

// ─── Browser Language Detection Banner ─────────
(function() {
  // Determine page family: 'index' or 'mobile'
  var pageFamily = document.body.getAttribute('data-page-family') || 'index';
  var prefix = pageFamily === 'mobile' ? 'm' : 'index';

  var langMap = {
    'ko': {
      file: prefix + '.ko.html',
      label: '한국어 버전이 있습니다',
      btn: '한국어로 보기'
    },
    'ja': {
      file: prefix + '.ja.html',
      label: '日本語版があります',
      btn: '日本語で見る'
    },
    'zh': {
      file: prefix + '.zh-TW.html',
      label: '繁體中文版本可用',
      btn: '切換繁體中文'
    }
  };

  // Only show on English page
  var htmlLang = document.documentElement.lang;
  if (htmlLang !== 'en') return;

  // Check browser language
  var browserLang = (navigator.language || '').toLowerCase();
  var match = null;
  if (browserLang.startsWith('ko')) match = langMap['ko'];
  else if (browserLang.startsWith('ja')) match = langMap['ja'];
  else if (browserLang.startsWith('zh')) match = langMap['zh'];

  if (!match) return;

  // Check if already on the right page or dismissed
  var currentPage = location.pathname.split('/').pop() || 'index.html';
  if (currentPage === match.file) return;
  if (sessionStorage.getItem('bmb-lang-dismissed')) return;

  // Create banner
  var banner = document.createElement('div');
  banner.className = 'lang-banner';
  banner.innerHTML = '<span>' + match.label + '</span>' +
    '<a href="' + match.file + '" class="lang-banner-btn">' + match.btn + '</a>' +
    '<button class="lang-banner-close" aria-label="Close">&times;</button>';
  document.body.appendChild(banner);

  banner.querySelector('.lang-banner-close').addEventListener('click', function() {
    banner.remove();
    sessionStorage.setItem('bmb-lang-dismissed', '1');
  });
})();

// ─── Mobile Landing: Card IntersectionObserver ──
(function() {
  if (!document.body.classList.contains('mobile-landing')) return;
  if (!('IntersectionObserver' in window)) {
    // Fallback: show all cards immediately
    document.querySelectorAll('.ml-card').forEach(function(c) {
      c.classList.add('ml-visible');
    });
    return;
  }

  var counterEl = document.querySelector('.ml-counter-current');
  var cards = document.querySelectorAll('.ml-card');

  var revealObserver = new IntersectionObserver(function(entries) {
    entries.forEach(function(entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add('ml-visible');
      }
    });
  }, { threshold: 0.15 });

  var counterObserver = new IntersectionObserver(function(entries) {
    entries.forEach(function(entry) {
      if (entry.isIntersecting && counterEl) {
        counterEl.textContent = entry.target.getAttribute('data-card') || '1';
      }
    });
  }, { threshold: 0.5 });

  cards.forEach(function(card) {
    revealObserver.observe(card);
    counterObserver.observe(card);
  });
})();
