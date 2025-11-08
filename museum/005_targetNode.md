# targetNode

These were used for debugging the implementation of keyed diffs.

```js
// --- Basic MutationObserver demo ---
// This minimal observer just watches for any attribute or child changes
// on the #symbols element. It’s useful for verifying that the DOM
// is mutating at all during render or diff operations, without tracking
// specific node identities.

const targetNode = document.getElementById("symbols");
if (!targetNode) {
  console.warn("list not ready yet");
} else {
  const config = { attributes: true, childList: true, subtree: true };
  const observer = new MutationObserver((mutationList) => {
    for (const mutation of mutationList) {
      if (mutation.type === "childList") {
        console.log("A child node has been added or removed.");
      } else if (mutation.type === "attributes") {
        console.log(`The ${mutation.attributeName} attribute was modified.`);
      }
    }
  });

  observer.observe(targetNode, config);
}

// --- Identity-tagging MutationObserver ---
// This version tags each <li> under #symbols with a numeric data-instance ID
// so we can tell whether elements are *moved* or *recreated* when the DOM changes.
// If a node with the same data-instance reappears, it means the keyed diff
// reused that DOM element rather than destroying and rebuilding it.

const target = document.getElementById("symbols");
if (!target) {
  console.warn("todo list not mounted yet");
} else {
  // one-time tagging so we can track identity
  let counter = 1;
  target.querySelectorAll(":scope > li").forEach((li) => {
    if (!li.dataset.instance) li.dataset.instance = String(counter++);
  });

  const obs = new MutationObserver((list) => {
    for (const m of list) {
      if (m.type !== "childList") continue;

      [...m.removedNodes]
        .filter((n) => n.nodeType === 1 && n.tagName === "LI")
        .forEach((n) => console.log("removed instance", n.dataset.instance, n));

      [...m.addedNodes]
        .filter((n) => n.nodeType === 1 && n.tagName === "LI")
        .forEach((n) => console.log("added instance", n.dataset.instance, n));
    }
  });

  obs.observe(target, { childList: true });

  console.log(
    "MutationObserver ready; remove the first todo and watch instance ids."
  );
}

// --- Full DOM diff observer ---
// This is the most detailed observer. It:
//   • Tags <li> nodes with data-instance IDs to track identity
//   • Logs added and removed <li> elements
//   • Logs text updates (characterData changes inside <li>s)
//   • Logs attribute updates (class, value, checked, title)
// Together, these logs visualize exactly how the keyed diff system
// manipulates the DOM: moves, in-place patches, or full re-renders.

const target = document.getElementById("symbols");
if (!target) throw new Error("missing #symbols");

const tagOnce = () => {
  let i = 1;
  target.querySelectorAll(":scope > li").forEach((li) => {
    if (!li.dataset.instance) li.dataset.instance = String(i++);
  });
};
tagOnce();

const obs = new MutationObserver((muts) => {
  for (const m of muts) {
    if (m.type === "childList") {
      [...m.removedNodes].forEach((n) => {
        if (n.nodeType === 1 && n.tagName === "LI") {
          console.log("REMOVED li", n.dataset.instance || "(new/unknown)", n);
        }
      });
      [...m.addedNodes].forEach((n) => {
        if (n.nodeType === 1 && n.tagName === "LI") {
          console.log("ADDED   li", n.dataset.instance || "(new/unknown)", n);
        }
      });
    }
    if (m.type === "characterData") {
      const li = m.target.parentElement?.closest("li");
      if (li)
        console.log(
          "PATCH text in li",
          li.dataset.instance,
          "->",
          m.target.data
        );
    }
    if (m.type === "attributes") {
      const li = m.target.closest("li");
      if (li) {
        console.log(
          "PATCH attr",
          m.attributeName,
          "on li",
          li.dataset.instance,
          "old:",
          m.oldValue,
          "new:",
          m.target.getAttribute(m.attributeName)
        );
      }
    }
  }
});

obs.observe(target, {
  childList: true,
  subtree: true, // see text nodes inside <li>
  characterData: true,
  characterDataOldValue: true,
  attributes: true,
  attributeOldValue: true,
  attributeFilter: ["class", "value", "checked", "title"],
});

console.log("Observer ready.");

// --- Dynamic DOM diff observer ---
// Same as the one above, but it dynamically and tracks data-instance IDs for new nodes

const target = document.getElementById("symbols");
if (!target) throw new Error("missing #symbols");

let counter = 1;

// Tag any untagged <li> elements right away
function tagNode(li) {
  if (!li.dataset.instance) li.dataset.instance = String(counter++);
}

function tagExisting() {
  target.querySelectorAll(":scope > li").forEach(tagNode);
}

tagExisting();

const obs = new MutationObserver((mutations) => {
  for (const m of mutations) {
    if (m.type === "childList") {
      // Tag and log added nodes
      [...m.addedNodes].forEach((n) => {
        if (n.nodeType === 1 && n.tagName === "LI") {
          tagNode(n);
          console.log("ADDED   li", n.dataset.instance, n);
        }
      });

      // Log removed nodes
      [...m.removedNodes].forEach((n) => {
        if (n.nodeType === 1 && n.tagName === "LI") {
          console.log("REMOVED li", n.dataset.instance || "(untagged)", n);
        }
      });
    }

    if (m.type === "characterData") {
      const li = m.target.parentElement?.closest("li");
      if (li)
        console.log(
          "PATCH text in li",
          li.dataset.instance,
          "->",
          m.target.data
        );
    }

    if (m.type === "attributes") {
      const li = m.target.closest("li");
      if (li)
        console.log(
          "PATCH attr",
          m.attributeName,
          "on li",
          li.dataset.instance,
          "old:",
          m.oldValue,
          "new:",
          m.target.getAttribute(m.attributeName)
        );
    }
  }
});

obs.observe(target, {
  childList: true,
  subtree: true,
  characterData: true,
  characterDataOldValue: true,
  attributes: true,
  attributeOldValue: true,
  attributeFilter: ["class", "value", "checked", "title"],
});

console.log("Observer ready; all <li> nodes will auto-tag when added.");
```
