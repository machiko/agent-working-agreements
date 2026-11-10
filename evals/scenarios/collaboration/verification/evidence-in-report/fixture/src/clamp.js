export function clamp(value, min, max) {
  if (value < min) return min;
  if (value > max) return value;
  return value;
}
