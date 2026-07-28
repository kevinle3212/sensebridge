/* SenseBridge docs — vanilla ES2020, no dependencies, no build step.
   Every feature here enhances markup that already works without it. */
"use strict";

(function () {
  function prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  /* Theme ------------------------------------------------------------ */
  function initTheme() {
    var root = document.documentElement;
    var status = document.getElementById("theme-status");
    var radios = document.querySelectorAll('input[name="theme"]');
    if (!radios.length) return;

    var stored = "system";
    try {
      stored = localStorage.getItem("sb-theme") || "system";
    } catch (e) {}
    radios.forEach(function (radio) {
      radio.checked = radio.value === stored;
    });

    function apply(value) {
      if (value === "dark" || value === "light") {
        root.setAttribute("data-theme", value);
      } else {
        root.removeAttribute("data-theme");
      }
      try {
        localStorage.setItem("sb-theme", value);
      } catch (e) {}
      if (status) status.textContent = "Theme set to " + value + ".";
    }

    radios.forEach(function (radio) {
      radio.addEventListener("change", function () {
        if (radio.checked) apply(radio.value);
      });
    });
  }

  /* Reading progress --------------------------------------------------- */
  function initReadingProgress() {
    var bar = document.getElementById("reading-progress");
    if (!bar) return;
    function update() {
      var doc = document.documentElement;
      var scrollable = doc.scrollHeight - doc.clientHeight;
      bar.style.width = (scrollable > 0 ? (window.scrollY / scrollable) * 100 : 0) + "%";
    }
    document.addEventListener("scroll", update, { passive: true });
    window.addEventListener("resize", update);
    update();
  }

  /* Heading permalinks --------------------------------------------------- */
  function initHeadingAnchors() {
    document.querySelectorAll("main h2[id], main h3[id]").forEach(function (heading) {
      var anchor = document.createElement("a");
      anchor.href = "#" + heading.id;
      anchor.className = "heading-anchor";
      anchor.setAttribute("aria-label", "Link to this section: " + heading.textContent.trim());
      anchor.textContent = "#";
      heading.appendChild(anchor);
    });
  }

  /* Table of contents + scroll spy --------------------------------------- */
  function initToc() {
    var toc = document.getElementById("toc");
    var list = document.getElementById("toc-list");
    if (!toc || !list) return;
    var indicator = toc.querySelector(".toc__indicator");
    var headings = Array.prototype.slice.call(document.querySelectorAll("main h2[id], main h3[id]"));
    if (!headings.length) return;

    var entries = headings.map(function (heading) {
      var item = document.createElement("li");
      if (heading.tagName === "H3") item.style.paddingLeft = "16px";
      var link = document.createElement("a");
      link.href = "#" + heading.id;
      link.textContent = heading.textContent.replace(/#$/, "").trim();
      item.appendChild(link);
      list.appendChild(item);
      return { id: heading.id, el: heading, link: link };
    });
    toc.hidden = false;

    function setActive(id) {
      entries.forEach(function (entry) {
        if (entry.id === id) {
          entry.link.setAttribute("aria-current", "true");
          if (indicator) {
            indicator.style.transform = "translateY(" + entry.link.offsetTop + "px)";
            indicator.classList.add("is-active");
          }
        } else {
          entry.link.removeAttribute("aria-current");
        }
      });
    }

    if (!("IntersectionObserver" in window)) {
      setActive(headings[0].id);
      return;
    }
    var observer = new IntersectionObserver(
      function (records) {
        records.forEach(function (record) {
          if (record.isIntersecting) setActive(record.target.id);
        });
      },
      { rootMargin: "0px 0px -70% 0px" }
    );
    headings.forEach(function (heading) {
      observer.observe(heading);
    });
  }

  /* Copy-code buttons --------------------------------------------------- */
  function initCopyCode() {
    var blocks = document.querySelectorAll("main pre");
    if (!blocks.length) return;
    var live = document.createElement("div");
    live.className = "visually-hidden";
    live.setAttribute("role", "status");
    live.setAttribute("aria-live", "polite");
    document.body.appendChild(live);

    blocks.forEach(function (pre) {
      var code = pre.querySelector("code");
      if (!code) return;
      var wrapper = document.createElement("div");
      wrapper.className = "code-block";
      pre.parentNode.insertBefore(wrapper, pre);
      wrapper.appendChild(pre);

      var button = document.createElement("button");
      button.type = "button";
      button.className = "copy-code";
      button.textContent = "Copy";
      wrapper.appendChild(button);

      button.addEventListener("click", function () {
        navigator.clipboard.writeText(code.textContent).then(function () {
          button.textContent = "Copied";
          live.textContent = "Copied to clipboard.";
          setTimeout(function () {
            button.textContent = "Copy";
          }, 2000);
        });
      });
    });
  }

  /* Table wrappers -------------------------------------------------------- */
  function initTableWrappers() {
    document.querySelectorAll("main table").forEach(function (table) {
      if (table.closest(".table-wrapper")) return;
      var wrapper = document.createElement("div");
      wrapper.className = "table-wrapper";
      table.parentNode.insertBefore(wrapper, table);
      wrapper.appendChild(table);
      if (table.scrollWidth > wrapper.clientWidth) {
        wrapper.classList.add("is-scrollable");
        wrapper.setAttribute("role", "region");
        wrapper.setAttribute("tabindex", "0");
        var heading = table.previousElementSibling;
        var hasHeadingText = heading && /^H[2-4]$/.test(heading.tagName);
        wrapper.setAttribute("aria-label", hasHeadingText ? "Scrollable table: " + heading.textContent : "Scrollable table");
      }
    });
  }

  /* Callouts — blockquotes whose first line is a bold "Note", "Warning",
     "Important", or "Doctrine" lead-in; markdownlint permits no HTML here, so
     classing happens at runtime instead of via a Kramdown attribute. ------- */
  function initCallouts() {
    var keywords = ["Note", "Warning", "Important", "Doctrine"];
    document.querySelectorAll("main blockquote").forEach(function (blockquote) {
      var strong = blockquote.querySelector("p:first-child > strong:first-child");
      if (!strong) return;
      var word = strong.textContent.replace(/:$/, "").trim();
      if (keywords.indexOf(word) === -1) return;
      blockquote.classList.add("callout", "callout-" + word.toLowerCase());
    });
  }

  /* Section reveal — skipped entirely for content already in the first
     viewport, and for reduced-motion users (CSS also gates the transition,
     this just avoids the class churn). ------------------------------------ */
  function initReveal() {
    if (prefersReducedMotion() || !("IntersectionObserver" in window)) return;
    var viewportHeight = window.innerHeight;
    var toObserve = [];
    Array.prototype.slice.call(document.querySelectorAll("main > *")).forEach(function (el) {
      if (el.getBoundingClientRect().top < viewportHeight) return;
      el.classList.add("reveal");
      toObserve.push(el);
    });
    if (!toObserve.length) return;
    var observer = new IntersectionObserver(
      function (records, obs) {
        records.forEach(function (record, i) {
          if (!record.isIntersecting) return;
          record.target.style.transitionDelay = (i % 4) * 60 + "ms";
          record.target.classList.add("in-view");
          obs.unobserve(record.target);
        });
      },
      { threshold: 0.1 }
    );
    toObserve.forEach(function (el) {
      observer.observe(el);
    });
  }

  /* Anchor navigation moves focus to the target heading -------------------- */
  function initAnchorFocus() {
    document.addEventListener("click", function (event) {
      var link = event.target.closest('a[href^="#"]');
      if (!link) return;
      var id = link.getAttribute("href").slice(1);
      if (!id) return;
      var target = document.getElementById(id);
      if (!target) return;
      event.preventDefault();
      target.scrollIntoView({ behavior: prefersReducedMotion() ? "auto" : "smooth", block: "start" });
      target.setAttribute("tabindex", "-1");
      target.focus({ preventScroll: true });
      history.pushState(null, "", "#" + id);
    });
  }

  /* Search palette — full ARIA combobox pattern ---------------------------- */
  function initSearch() {
    var trigger = document.getElementById("search-trigger");
    if (!trigger) return;
    var searchSrc = trigger.getAttribute("data-search-src") || "/search.json";

    var overlay, input, listbox, status, index, activeIndex;
    activeIndex = -1;

    function buildPanel() {
      overlay = document.createElement("div");
      overlay.className = "search-overlay";
      overlay.hidden = true;

      var panel = document.createElement("div");
      panel.className = "search-panel";
      panel.setAttribute("role", "dialog");
      panel.setAttribute("aria-modal", "true");
      panel.setAttribute("aria-label", "Search documentation");

      var label = document.createElement("label");
      label.className = "visually-hidden";
      label.id = "search-panel-label";
      label.setAttribute("for", "search-panel-input");
      label.textContent = "Search documentation";

      input = document.createElement("input");
      input.type = "text";
      input.id = "search-panel-input";
      input.className = "search-panel__input";
      input.autocomplete = "off";
      input.setAttribute("role", "combobox");
      input.setAttribute("aria-expanded", "false");
      input.setAttribute("aria-controls", "search-panel-listbox");
      input.setAttribute("aria-autocomplete", "list");
      input.setAttribute("aria-labelledby", "search-panel-label");

      listbox = document.createElement("ul");
      listbox.id = "search-panel-listbox";
      listbox.className = "search-panel__list";
      listbox.setAttribute("role", "listbox");

      status = document.createElement("div");
      status.className = "visually-hidden";
      status.setAttribute("role", "status");
      status.setAttribute("aria-live", "polite");

      panel.appendChild(label);
      panel.appendChild(input);
      panel.appendChild(listbox);
      panel.appendChild(status);
      overlay.appendChild(panel);
      document.body.appendChild(overlay);

      overlay.addEventListener("click", function (event) {
        if (event.target === overlay) close();
      });
      input.addEventListener("input", function () {
        renderResults(input.value);
      });
      input.addEventListener("keydown", onKeydown);
    }

    function loadIndex() {
      if (index) return Promise.resolve(index);
      return fetch(searchSrc)
        .then(function (response) {
          if (!response.ok) throw new Error("search index fetch failed: " + response.status);
          return response.json();
        })
        .then(function (data) {
          index = data;
          return index;
        })
        .catch(function () {
          index = [];
          return index;
        });
    }

    var SNIPPET_RADIUS = 40;

    // A window of plain text around the first match, so a content-only hit
    // shows why it matched instead of just a bare title.
    function buildSnippet(content, matchIndex) {
      var start = Math.max(0, matchIndex - SNIPPET_RADIUS);
      var end = Math.min(content.length, matchIndex + SNIPPET_RADIUS);
      var snippet = content.slice(start, end).trim();
      if (start > 0) snippet = "…" + snippet;
      if (end < content.length) snippet += "…";
      return snippet;
    }

    function renderResults(query) {
      listbox.innerHTML = "";
      activeIndex = -1;
      input.removeAttribute("aria-activedescendant");
      if (!index || !query.trim()) {
        status.textContent = "";
        input.setAttribute("aria-expanded", "false");
        return;
      }
      var q = query.trim().toLowerCase();
      var matches = [];
      for (var m = 0; m < index.length; m++) {
        var item = index[m];
        var titleIndex = item.title.toLowerCase().indexOf(q);
        var contentIndex = item.content.toLowerCase().indexOf(q);
        if (titleIndex !== -1 || contentIndex !== -1) {
          matches.push({ item: item, titleIndex: titleIndex, contentIndex: contentIndex });
        }
      }
      // Title matches rank above content-only matches, so a query that names
      // a page lands it first instead of wherever it falls in site.pages order.
      var results = matches
        .sort(function (a, b) {
          return (a.titleIndex !== -1 ? 0 : 1) - (b.titleIndex !== -1 ? 0 : 1);
        })
        .slice(0, 10);

      results.forEach(function (match, i) {
        var item = match.item;
        var option = document.createElement("li");
        option.id = "search-option-" + i;
        option.setAttribute("role", "option");
        var link = document.createElement("a");
        link.className = "search-panel__option";
        link.href = item.url;
        var title = document.createElement("span");
        title.className = "search-panel__option-title";
        title.textContent = item.title;
        link.appendChild(title);
        if (match.titleIndex === -1 && match.contentIndex !== -1) {
          var snippet = document.createElement("span");
          snippet.className = "search-panel__option-snippet";
          snippet.textContent = buildSnippet(item.content, match.contentIndex);
          link.appendChild(snippet);
        }
        option.appendChild(link);
        option.addEventListener("mouseenter", function () {
          setActive(i);
        });
        listbox.appendChild(option);
      });

      status.textContent = results.length + (results.length === 1 ? " result" : " results") + " found.";
      input.setAttribute("aria-expanded", results.length > 0 ? "true" : "false");
    }

    function setActive(i) {
      var options = listbox.querySelectorAll('[role="option"]');
      options.forEach(function (option) {
        option.removeAttribute("aria-selected");
      });
      activeIndex = i;
      if (i >= 0 && options[i]) {
        options[i].setAttribute("aria-selected", "true");
        input.setAttribute("aria-activedescendant", options[i].id);
      } else {
        input.removeAttribute("aria-activedescendant");
      }
    }

    function onKeydown(event) {
      var options = listbox.querySelectorAll('[role="option"]');
      if (event.key === "ArrowDown") {
        event.preventDefault();
        setActive(Math.min(activeIndex + 1, options.length - 1));
      } else if (event.key === "ArrowUp") {
        event.preventDefault();
        setActive(Math.max(activeIndex - 1, 0));
      } else if (event.key === "Enter") {
        if (activeIndex >= 0 && options[activeIndex]) {
          var link = options[activeIndex].querySelector("a");
          if (link) window.location.href = link.href;
        }
      } else if (event.key === "Escape") {
        close();
      }
    }

    function open() {
      if (!overlay) buildPanel();
      overlay.hidden = false;
      input.value = "";
      listbox.innerHTML = "";
      status.textContent = "";
      input.setAttribute("aria-expanded", "false");
      input.focus();
      loadIndex();
    }

    function close() {
      if (!overlay || overlay.hidden) return;
      overlay.hidden = true;
      trigger.focus();
    }

    trigger.addEventListener("click", open);
    document.addEventListener("keydown", function (event) {
      var isShortcut = (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k";
      if (isShortcut) {
        event.preventDefault();
        open();
      }
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    initTheme();
    initReadingProgress();
    initHeadingAnchors();
    initToc();
    initCopyCode();
    initTableWrappers();
    initCallouts();
    initReveal();
    initAnchorFocus();
    initSearch();
  });
})();
