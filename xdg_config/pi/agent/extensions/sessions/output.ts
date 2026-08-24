export const MODEL_OUTPUT_LIMIT = 16_000;
export const MODEL_FIELD_LIMIT = 2_000;

export function truncateModelText(text: string, limit = MODEL_OUTPUT_LIMIT): string {
  if (text.length <= limit) return text;
  let marker = "";
  let previous = "";
  do {
    previous = marker;
    const omitted = text.length - Math.max(0, limit - marker.length);
    marker = `\n[truncated: ${omitted} characters omitted]`;
  } while (marker !== previous);
  return `${text.slice(0, Math.max(0, limit - marker.length))}${marker.slice(0, limit)}`;
}

export type ModelProjection<T> = {
  items: T[];
  total: number;
  omitted: number;
  truncated: number;
};

/** Builds valid JSON under a hard budget, omitting records that do not fit. */
export function compactJsonProjection<T>(items: T[], limit = MODEL_OUTPUT_LIMIT, truncated = 0): string {
  const projection: ModelProjection<T> = { items: [], total: items.length, omitted: items.length, truncated };
  for (const item of items) {
    const candidate = { ...projection, items: [...projection.items, item], omitted: items.length - projection.items.length - 1 };
    const encoded = JSON.stringify(candidate);
    if (encoded.length > limit) break;
    projection.items.push(item);
    projection.omitted -= 1;
  }
  return JSON.stringify(projection);
}

export function truncateProjectionField(value: string, limit = MODEL_FIELD_LIMIT): { value: string; truncated: boolean } {
  return { value: truncateModelText(value, limit), truncated: value.length > limit };
}
