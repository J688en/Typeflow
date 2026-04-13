/* ============================================
   TypeFlow — Website Scripts
   ============================================ */

(function () {
  'use strict';

  // ---- Theme Toggle ----
  const toggle = document.querySelector('[data-theme-toggle]');
  const root = document.documentElement;
  // Default to dark since it's a dev tool
  let theme = 'dark';
  root.setAttribute('data-theme', theme);

  if (toggle) {
    toggle.addEventListener('click', () => {
      theme = theme === 'dark' ? 'light' : 'dark';
      root.setAttribute('data-theme', theme);
      toggle.setAttribute('aria-label', 'Switch to ' + (theme === 'dark' ? 'light' : 'dark') + ' mode');
      toggle.innerHTML =
        theme === 'dark'
          ? '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>'
          : '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
    });
  }

  // ---- Header Scroll State ----
  const header = document.getElementById('header');
  let lastScroll = 0;
  window.addEventListener('scroll', () => {
    const scrollY = window.scrollY;
    if (scrollY > 50) {
      header.classList.add('header--scrolled');
    } else {
      header.classList.remove('header--scrolled');
    }
    lastScroll = scrollY;
  }, { passive: true });

  // ---- Mobile Nav ----
  const mobileBtn = document.querySelector('.mobile-menu-btn');
  const mobileNav = document.querySelector('.mobile-nav');
  if (mobileBtn && mobileNav) {
    mobileBtn.addEventListener('click', () => {
      const isOpen = mobileNav.getAttribute('aria-hidden') === 'false';
      mobileNav.setAttribute('aria-hidden', isOpen ? 'true' : 'false');
      mobileNav.hidden = isOpen;
      mobileBtn.setAttribute('aria-expanded', !isOpen);
      // Switch icon
      mobileBtn.innerHTML = !isOpen
        ? '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>'
        : '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="18" x2="21" y2="18"/></svg>';
    });

    // Close mobile nav on link click
    mobileNav.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        mobileNav.setAttribute('aria-hidden', 'true');
        mobileNav.hidden = true;
        mobileBtn.setAttribute('aria-expanded', 'false');
        mobileBtn.innerHTML = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="18" x2="21" y2="18"/></svg>';
      });
    });
  }

  // ---- Scroll Reveal (Intersection Observer) ----
  const observerOptions = {
    threshold: 0.15,
    rootMargin: '0px 0px -40px 0px'
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, observerOptions);

  document.querySelectorAll('.fade-in').forEach(el => {
    observer.observe(el);
  });

  // ---- Typing Demo ----
  const demoText = document.getElementById('demo-text');
  const demoCursor = document.getElementById('demo-cursor');
  const demoWpm = document.getElementById('demo-wpm');
  const demoChars = document.getElementById('demo-chars');
  const demoRestart = document.getElementById('demo-restart');

  const textToType = `The quick brown fox jumps over the lazy dog.
This sentence is being typed naturally by
TypeFlow — with realistic timing, random
pauses after punctuation, and the occasional
typo that gets quietly corrected.

Every keystroke feels authentically human.
No one can tell the difference.`;

  // Adjacent key map for realistic typos
  const adjacentKeys = {
    'a': ['s', 'q', 'w', 'z'],
    'b': ['v', 'g', 'h', 'n'],
    'c': ['x', 'd', 'f', 'v'],
    'd': ['s', 'e', 'r', 'f', 'c', 'x'],
    'e': ['w', 'r', 'd', 's'],
    'f': ['d', 'r', 't', 'g', 'v', 'c'],
    'g': ['f', 't', 'y', 'h', 'b', 'v'],
    'h': ['g', 'y', 'u', 'j', 'n', 'b'],
    'i': ['u', 'o', 'k', 'j'],
    'j': ['h', 'u', 'i', 'k', 'm', 'n'],
    'k': ['j', 'i', 'o', 'l', 'm'],
    'l': ['k', 'o', 'p'],
    'm': ['n', 'j', 'k'],
    'n': ['b', 'h', 'j', 'm'],
    'o': ['i', 'p', 'l', 'k'],
    'p': ['o', 'l'],
    'q': ['w', 'a'],
    'r': ['e', 't', 'f', 'd'],
    's': ['a', 'w', 'e', 'd', 'x', 'z'],
    't': ['r', 'y', 'g', 'f'],
    'u': ['y', 'i', 'j', 'h'],
    'v': ['c', 'f', 'g', 'b'],
    'w': ['q', 'e', 's', 'a'],
    'x': ['z', 's', 'd', 'c'],
    'y': ['t', 'u', 'h', 'g'],
    'z': ['a', 's', 'x']
  };

  let typingInterval = null;
  let charIndex = 0;
  let startTime = 0;
  let currentText = '';
  let isRunning = false;

  function getRandomDelay(char, nextChar) {
    // Base delay: 40-90ms (fast typist)
    let delay = 40 + Math.random() * 50;

    // After punctuation: longer pause
    if ('.!?'.includes(char)) {
      delay += 200 + Math.random() * 300;
    } else if (',;:'.includes(char)) {
      delay += 80 + Math.random() * 120;
    }

    // New line pause
    if (char === '\n') {
      delay += 150 + Math.random() * 200;
    }

    // After space, before long word: micro-hesitation
    if (char === ' ' && nextChar && /[a-zA-Z]/.test(nextChar)) {
      if (Math.random() < 0.15) {
        delay += 100 + Math.random() * 150;
      }
    }

    // Random micro-pauses (thinking)
    if (Math.random() < 0.03) {
      delay += 200 + Math.random() * 400;
    }

    return delay;
  }

  function shouldMakeTypo(char) {
    // Only typo on lowercase letters
    if (!/[a-z]/.test(char)) return false;
    // ~5% chance of typo
    return Math.random() < 0.05;
  }

  function getTypo(char) {
    const lower = char.toLowerCase();
    const keys = adjacentKeys[lower];
    if (keys && keys.length > 0) {
      return keys[Math.floor(Math.random() * keys.length)];
    }
    return char;
  }

  function updateStats() {
    const elapsed = (Date.now() - startTime) / 1000 / 60; // minutes
    const wordCount = currentText.split(/\s+/).filter(w => w.length > 0).length;
    const wpm = elapsed > 0 ? Math.round(wordCount / elapsed) : 0;
    if (demoWpm) demoWpm.textContent = wpm;
    if (demoChars) demoChars.textContent = currentText.length;
  }

  function typeNextChar() {
    if (charIndex >= textToType.length) {
      isRunning = false;
      return;
    }

    const char = textToType[charIndex];
    const nextChar = textToType[charIndex + 1];

    // Check for typo
    if (shouldMakeTypo(char)) {
      const typoChar = getTypo(char);
      // Type the wrong character
      currentText += typoChar;
      demoText.textContent = currentText;
      updateStats();

      // Brief pause, then backspace
      setTimeout(() => {
        currentText = currentText.slice(0, -1);
        demoText.textContent = currentText;

        // Small pause, then type correct character
        setTimeout(() => {
          currentText += char;
          demoText.textContent = currentText;
          charIndex++;
          updateStats();

          const delay = getRandomDelay(char, nextChar);
          typingInterval = setTimeout(typeNextChar, delay);
        }, 60 + Math.random() * 40);
      }, 100 + Math.random() * 80);
    } else {
      currentText += char;
      demoText.textContent = currentText;
      charIndex++;
      updateStats();

      const delay = getRandomDelay(char, nextChar);
      typingInterval = setTimeout(typeNextChar, delay);
    }
  }

  function startTypingDemo() {
    if (isRunning) return;

    // Reset
    charIndex = 0;
    currentText = '';
    demoText.textContent = '';
    if (demoWpm) demoWpm.textContent = '0';
    if (demoChars) demoChars.textContent = '0';
    startTime = Date.now();
    isRunning = true;

    // Small initial delay
    typingInterval = setTimeout(typeNextChar, 600);
  }

  function restartDemo() {
    isRunning = false;
    if (typingInterval) clearTimeout(typingInterval);
    charIndex = 0;
    currentText = '';
    demoText.textContent = '';
    if (demoWpm) demoWpm.textContent = '0';
    if (demoChars) demoChars.textContent = '0';

    setTimeout(startTypingDemo, 300);
  }

  if (demoRestart) {
    demoRestart.addEventListener('click', restartDemo);
  }

  // Start demo when it scrolls into view
  const demoSection = document.getElementById('demo');
  if (demoSection) {
    const demoObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && !isRunning && charIndex === 0) {
          startTypingDemo();
          demoObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.3 });

    demoObserver.observe(demoSection);
  }

  // ---- Hero Typing Effect on the word "Anywhere." ----
  const heroTyped = document.getElementById('hero-typed');
  const heroWords = ['Anywhere.', 'Naturally.', 'Seamlessly.', 'Effortlessly.'];
  let heroWordIndex = 0;
  let heroCharIndex = 0;
  let heroDeleting = false;
  let heroTimeout = null;

  function typeHeroWord() {
    const currentWord = heroWords[heroWordIndex];

    if (!heroDeleting) {
      // Typing forward
      heroCharIndex++;
      heroTyped.textContent = currentWord.substring(0, heroCharIndex);

      if (heroCharIndex === currentWord.length) {
        // Pause at full word
        heroTimeout = setTimeout(() => {
          heroDeleting = true;
          typeHeroWord();
        }, 2500);
        return;
      }
      heroTimeout = setTimeout(typeHeroWord, 80 + Math.random() * 40);
    } else {
      // Deleting
      heroCharIndex--;
      heroTyped.textContent = currentWord.substring(0, heroCharIndex);

      if (heroCharIndex === 0) {
        heroDeleting = false;
        heroWordIndex = (heroWordIndex + 1) % heroWords.length;
        heroTimeout = setTimeout(typeHeroWord, 400);
        return;
      }
      heroTimeout = setTimeout(typeHeroWord, 40 + Math.random() * 20);
    }
  }

  // Start hero typing after initial animation
  setTimeout(() => {
    if (heroTyped) {
      heroTyped.textContent = '';
      heroCharIndex = 0;
      typeHeroWord();
    }
  }, 1200);

  // ---- Smooth Scroll for Nav Links ----
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const href = this.getAttribute('href');
      if (href === '#') return;
      const target = document.querySelector(href);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth' });
      }
    });
  });

})();
