# targetNode

This was used for debugging for loops when implementing keyed diffs.

```js
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
```
