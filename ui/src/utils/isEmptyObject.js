// https://stackoverflow.com/a/34491966/3519951
export function isEmptyObject(obj) {
  for (var _ in obj) { return false; }
  return true;
}
