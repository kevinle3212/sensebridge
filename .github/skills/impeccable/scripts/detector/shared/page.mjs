/** Check if content looks like a full page (not a component/partial) */
function isFullPage(content) {
  // Strip to a fixed point so overlapping comment markers can't reassemble
  // into a marker after a single pass.
  let stripped = content;
  let previous;
  do {
    previous = stripped;
    stripped = stripped.replace(/<!--[\s\S]*?-->/g, "");
  } while (stripped !== previous);
  return /<!doctype\s|<html[\s>]|<head[\s>]/i.test(stripped);
}

export { isFullPage };
