import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { OrdersService } from './orders.service';

describe('OrdersService', () => {
  const product = {
    id: 'product-1',
    name: 'Bò Húc ít đường',
    normalizedName: 'bo huc it duong',
    unit: 'lon',
    normalizedUnit: 'lon',
    price: 13000,
    isArchived: false,
    createdAt: new Date('2026-08-18T00:00:00Z'),
    updatedAt: new Date('2026-08-18T00:00:00Z'),
  };

  it('computes line totals and the order total from the current catalog price, ignoring client-sent prices', async () => {
    const createdOrder = { id: 'order-1', code: 'HD-1', items: [] };
    const prisma = {
      order: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue(createdOrder),
      },
      product: {
        findMany: jest.fn().mockResolvedValue([product]),
      },
    } as unknown as PrismaService;
    const service = new OrdersService(prisma);

    const result = await service.confirm({
      clientRequestId: 'req-1',
      items: [{ productId: 'product-1', quantity: 2, rawText: '2 lon' }],
    });

    expect(result).toBe(createdOrder);
    expect(prisma.order.findUnique).toHaveBeenCalledWith({
      where: { clientRequestId: 'req-1' },
      include: { items: true },
    });
    expect(prisma.order.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          clientRequestId: 'req-1',
          customerNameSnapshot: 'Khách lẻ',
          subtotal: 26000,
          total: 26000,
          items: {
            create: [
              {
                productId: 'product-1',
                nameSnapshot: 'Bò Húc ít đường',
                unitSnapshot: 'lon',
                unitPriceSnapshot: 13000,
                quantity: 2,
                lineTotal: 26000,
                rawText: '2 lon',
              },
            ],
          },
        }),
        include: { items: true },
      }),
    );
    const createArgs = (prisma.order.create as jest.Mock).mock.calls[0][0];
    expect(createArgs.data.id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
    );
    expect(createArgs.data.code).toMatch(/^HD\d{8}-[0-9A-F]{6}$/);
  });

  it('returns the existing order instead of creating a duplicate when clientRequestId repeats', async () => {
    const existingOrder = { id: 'order-1', clientRequestId: 'req-1' };
    const prisma = {
      order: {
        findUnique: jest.fn().mockResolvedValue(existingOrder),
        create: jest.fn(),
      },
      product: { findMany: jest.fn() },
    } as unknown as PrismaService;
    const service = new OrdersService(prisma);

    await expect(
      service.confirm({
        clientRequestId: 'req-1',
        items: [{ productId: 'product-1', quantity: 2 }],
      }),
    ).resolves.toBe(existingOrder);
    expect(prisma.order.create).not.toHaveBeenCalled();
    expect(prisma.product.findMany).not.toHaveBeenCalled();
  });

  it('rejects confirming when a referenced product no longer exists in the catalog', async () => {
    const prisma = {
      order: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
      product: { findMany: jest.fn().mockResolvedValue([]) },
    } as unknown as PrismaService;
    const service = new OrdersService(prisma);

    await expect(
      service.confirm({
        clientRequestId: 'req-1',
        items: [{ productId: 'missing-product', quantity: 1 }],
      }),
    ).rejects.toMatchObject({ status: 400 });
    expect(prisma.order.create).not.toHaveBeenCalled();
  });

  it('rejects an empty item list without hitting the catalog', async () => {
    const prisma = {
      order: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
      product: { findMany: jest.fn() },
    } as unknown as PrismaService;
    const service = new OrdersService(prisma);

    await expect(
      service.confirm({ clientRequestId: 'req-1', items: [] }),
    ).rejects.toMatchObject({ status: 400 });
    expect(prisma.product.findMany).not.toHaveBeenCalled();
  });

  it('replays the racing order instead of failing when two requests share a clientRequestId concurrently', async () => {
    const racedOrder = { id: 'order-1', clientRequestId: 'req-1' };
    const uniqueConstraintError = new Prisma.PrismaClientKnownRequestError(
      'Unique constraint failed',
      { code: 'P2002', clientVersion: '5.22.0' },
    );

    const findUnique = jest
      .fn()
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(racedOrder);
    const prisma = {
      order: {
        findUnique,
        create: jest.fn().mockRejectedValue(uniqueConstraintError),
      },
      product: { findMany: jest.fn().mockResolvedValue([product]) },
    } as unknown as PrismaService;
    const service = new OrdersService(prisma);

    await expect(
      service.confirm({
        clientRequestId: 'req-1',
        items: [{ productId: 'product-1', quantity: 1 }],
      }),
    ).resolves.toBe(racedOrder);
    expect(findUnique).toHaveBeenCalledTimes(2);
  });

  it("lists today's orders ordered from newest to oldest", async () => {
    const orders = [{ id: 'order-2' }, { id: 'order-1' }];
    const prisma = {
      order: {
        findMany: jest.fn().mockResolvedValue(orders),
      },
    } as unknown as PrismaService;
    const service = new OrdersService(prisma);

    await expect(service.findToday()).resolves.toBe(orders);
    const args = (prisma.order.findMany as jest.Mock).mock.calls[0][0];
    expect(args.orderBy).toEqual({ createdAt: 'desc' });
    expect(args.where.createdAt.gte).toBeInstanceOf(Date);
    expect(args.where.createdAt.lt).toBeInstanceOf(Date);
    expect(args.where.createdAt.lt.getTime()).toBeGreaterThan(
      args.where.createdAt.gte.getTime(),
    );
  });
});
