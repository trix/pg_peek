// pg_peek — no framework, no CDN, no import map. Three small behaviours.
(function () {
  "use strict";

  // Theme -------------------------------------------------------------------
  function applyTheme(theme) {
    document.documentElement.dataset.theme = theme;

    var meta = document.querySelector('meta[name="color-scheme"]');
    if (meta) meta.content = theme;

    document.querySelectorAll("[data-theme-toggle]").forEach(function (button) {
      button.textContent = "theme: " + theme;
    });
  }

  function storedTheme() {
    try {
      return localStorage.getItem("pg_peek.theme");
    } catch (error) {
      return null; // Private windows and blocked site data both throw.
    }
  }

  function toggleTheme() {
    var next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    applyTheme(next);
    try {
      localStorage.setItem("pg_peek.theme", next);
    } catch (error) {
      /* Nothing to do: the toggle still works for this page view. */
    }
  }

  function typing() {
    var el = document.activeElement;
    return el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA");
  }

  function initTheme() {
    var preferred = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    applyTheme(storedTheme() || preferred);

    document.querySelectorAll("[data-theme-toggle]").forEach(function (button) {
      button.addEventListener("click", function (event) {
        event.preventDefault();
        toggleTheme();
      });
    });

    document.addEventListener("keydown", function (event) {
      if (event.key === "t" && !typing() && !event.metaKey && !event.ctrlKey) toggleTheme();
    });
  }

  // Filtering ---------------------------------------------------------------
  function initFilter() {
    var input = document.querySelector("[data-filter-input]");
    if (!input) return;

    // Scoped to the nearest [data-filter] ancestor when there is one, so a
    // page with several report tables -- the overview, with endpoints, jobs,
    // queries and tables all on it -- filters only the one the input actually
    // belongs to, rather than every row on the page.
    var scope = input.closest("[data-filter]") || document;
    var items = Array.prototype.slice.call(scope.querySelectorAll("[data-filter-value]"));
    var count = scope.querySelector("[data-filter-count]");
    var empty = scope.querySelector("[data-filter-empty]");
    var noun = input.dataset.filterNoun || "row";
    var timer;

    function render() {
      var query = input.value.trim().toLowerCase();
      var matched = 0;

      items.forEach(function (item) {
        var hit = !query || item.dataset.filterValue.indexOf(query) !== -1;
        item.hidden = !hit;
        if (hit) matched++;
      });

      if (count) count.textContent = matched + " " + noun + (matched === 1 ? "" : "s");
      if (empty) empty.hidden = matched > 0;
    }

    input.addEventListener("input", function () {
      clearTimeout(timer);
      timer = setTimeout(render, 120);
    });

    document.addEventListener("keydown", function (event) {
      if (event.key === "/" && document.activeElement !== input) {
        event.preventDefault();
        input.focus();
      } else if (event.key === "Escape" && document.activeElement === input) {
        input.value = "";
        render();
      }
    });

    render();
  }

  // Confirmation ------------------------------------------------------------
  // Previously data-confirm, which needed rails-ujs the engine never shipped:
  // the reset button asked nothing and simply reset.
  function initConfirm() {
    document.querySelectorAll("form[data-confirm]").forEach(function (form) {
      form.addEventListener("submit", function (event) {
        if (!window.confirm(form.dataset.confirm)) event.preventDefault();
      });
    });
  }

  // Database switcher -------------------------------------------------------
  function initSwitcher() {
    document.querySelectorAll("[data-switcher]").forEach(function (select) {
      select.addEventListener("change", function () {
        window.location.assign(select.value);
      });
    });
  }

  // Reload ------------------------------------------------------------------
  // The activity page is a snapshot; "r" refreshes it the way top does.
  function initReload() {
    document.addEventListener("keydown", function (event) {
      if (event.key === "r" && !typing() && !event.metaKey && !event.ctrlKey && !event.altKey) {
        window.location.reload();
      }
    });
  }

  function init() {
    initTheme();
    initFilter();
    initConfirm();
    initSwitcher();
    initReload();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
