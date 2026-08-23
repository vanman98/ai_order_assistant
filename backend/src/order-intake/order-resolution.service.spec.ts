import type { Product } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { OrderResolutionService } from './order-resolution.service';

describe('OrderResolutionService', () => {
  const products: Product[] = [
    {
      id: 'product-1',
      name: 'Bò Húc ít đường',
      normalizedName: 'bo huc it duong',
      unit: 'lon',
      normalizedUnit: 'lon',
      price: 13000,
      createdAt: new Date('2026-08-18T00:00:00Z'),
      updatedAt: new Date('2026-08-18T00:00:00Z'),
    },
  ];

  function createService() {
    const prisma = {
      product: { findMany: jest.fn().mockResolvedValue(products) },
    } as unknown as PrismaService;
    return new OrderResolutionService(prisma);
  }

  it('matches by normalized name and unit then calculates the invoice total', async () => {
    const result = await createService().resolve({
      items: [
        {
          rawText: '2 lon bò húc ít đường',
          rawProductName: 'bo huc it duong',
          quantity: 2,
          unit: 'lon',
          note: null,
          needsReview: false,
          uncertaintyReason: null,
        },
      ],
      imageQuality: 'good',
      generalNote: null,
    });

    expect(result.items[0]).toMatchObject({
      matchStatus: 'matched',
      lineTotal: 26000,
      matchedProduct: { id: 'product-1', unit: 'lon', price: 13000 },
    });
    expect(result.allMatched).toBe(true);
    expect(result.invoiceTotal).toBe(26000);
  });

  it('marks an unknown product as missing without inventing a price', async () => {
    const result = await createService().resolve({
      items: [
        {
          rawText: '1 chai sản phẩm mới',
          rawProductName: 'Sản phẩm mới',
          quantity: 1,
          unit: 'chai',
          note: null,
          needsReview: false,
          uncertaintyReason: null,
        },
      ],
      imageQuality: 'readable',
      generalNote: null,
    });

    expect(result.items[0]).toMatchObject({
      matchStatus: 'missing',
      matchedProduct: null,
      candidates: [],
      lineTotal: null,
    });
    expect(result.allMatched).toBe(false);
    expect(result.invoiceTotal).toBe(0);
  });

  it('requires confirmation when Vision marked an exact item uncertain', async () => {
    const result = await createService().resolve({
      items: [
        {
          rawText: '2 lon chữ hơi mờ',
          rawProductName: 'Bò Húc ít đường',
          quantity: 2,
          unit: 'lon',
          note: null,
          needsReview: true,
          uncertaintyReason: 'Chữ viết tay hơi mờ',
        },
      ],
      imageQuality: 'poor',
      generalNote: null,
    });

    expect(result.items[0]).toMatchObject({
      matchStatus: 'review',
      lineTotal: 26000,
    });
    expect(result.allMatched).toBe(false);
  });
});
