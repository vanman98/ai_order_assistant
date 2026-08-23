export const ORDER_IMAGE_FIELD = 'image';
export const MAX_ORDER_IMAGE_BYTES = 8 * 1024 * 1024;

export const ORDER_IMAGE_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
] as const;

export type OrderImageMimeType = (typeof ORDER_IMAGE_MIME_TYPES)[number];
