import { z } from 'zod';

export const orderExtractionSchema = z.object({
  items: z.array(
    z.object({
      rawText: z.string(),
      rawProductName: z.string(),
      quantity: z.number().nullable(),
      unit: z.string().nullable(),
      unitPrice: z.number().int().positive().nullable(),
      note: z.string().nullable(),
      needsReview: z.boolean(),
      uncertaintyReason: z.string().nullable(),
    }),
  ),
  imageQuality: z.enum(['good', 'readable', 'poor']),
  generalNote: z.string().nullable(),
});

export type OrderExtraction = z.infer<typeof orderExtractionSchema>;

export interface OrderExtractionResponse extends OrderExtraction {
  meta: {
    model: string;
    mimeType: string;
    sizeBytes: number;
  };
}
