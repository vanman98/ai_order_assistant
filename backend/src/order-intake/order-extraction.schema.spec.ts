import { orderExtractionSchema } from './order-extraction.schema';

describe('order extraction schema', () => {
  it('accepts nullable uncertain fields while keeping every key explicit', () => {
    const result = orderExtractionSchema.parse({
      items: [
        {
          rawText: 'Omo 3k6 x 2',
          rawProductName: 'Omo 3k6',
          quantity: 2,
          unit: null,
          unitPrice: null,
          note: null,
          needsReview: true,
          uncertaintyReason: 'Đơn vị không xuất hiện rõ trong ảnh.',
        },
      ],
      imageQuality: 'readable',
      generalNote: null,
    });

    expect(result.items[0].quantity).toBe(2);
    expect(result.items[0].unit).toBeNull();
    expect(result.items[0].unitPrice).toBeNull();
  });

  it('rejects an item missing review metadata', () => {
    expect(() =>
      orderExtractionSchema.parse({
        items: [
          {
            rawText: 'Omo',
            rawProductName: 'Omo',
            quantity: 1,
            unit: 'gói',
            unitPrice: null,
            note: null,
          },
        ],
        imageQuality: 'good',
        generalNote: null,
      }),
    ).toThrow();
  });
});
