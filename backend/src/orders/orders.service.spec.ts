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
    const createdOrder = {
      id: 'order-1',
      code: 'HD-1',
      total: 26000,
      items: [],
      payments: [],
    };
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

    expect(result).toEqual({ ...createdOrder, paidTotal: 0, remaining: 26000 });
    expect(prisma.order.findUnique).toHaveBeenCalledWith({
      where: { clientRequestId: 'req-1' },
      include: { items: true, payments: true },
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
        include: { items: true, payments: true },
      }),
    );
    const createArgs = (prisma.order.create as jest.Mock).mock.calls[0][0];
    expect(createArgs.data.id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
    );
    expect(createArgs.data.code).toMatch(/^HD\d{8}-[0-9A-F]{6}$/);
  });

  it('returns the existing order instead of creating a duplicate when clientRequestId repeats', async () => {
    const existingOrder = {
      id: 'order-1',
      clientRequestId: 'req-1',
      total: 26000,
      payments: [],
    };
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
    ).resolves.toEqual({ ...existingOrder, paidTotal: 0, remaining: 26000 });
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
    const racedOrder = {
      id: 'order-1',
      clientRequestId: 'req-1',
      total: 13000,
      payments: [],
    };
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
    ).resolves.toEqual({ ...racedOrder, paidTotal: 0, remaining: 13000 });
    expect(findUnique).toHaveBeenCalledTimes(2);
  });

  it("lists today's orders ordered from newest to oldest, with paidTotal/remaining computed from payments", async () => {
    const orders = [
      { id: 'order-2', total: 50000, payments: [{ amount: 20000 }] },
      { id: 'order-1', total: 26000, payments: [] },
    ];
    const prisma = {
      order: {
        findMany: jest.fn().mockResolvedValue(orders),
      },
    } as unknown as PrismaService;
    const service = new OrdersService(prisma);

    await expect(service.findToday()).resolves.toEqual([
      { ...orders[0], paidTotal: 20000, remaining: 30000 },
      { ...orders[1], paidTotal: 0, remaining: 26000 },
    ]);
    const args = (prisma.order.findMany as jest.Mock).mock.calls[0][0];
    expect(args.orderBy).toEqual({ createdAt: 'desc' });
    expect(args.include).toEqual({ items: true, payments: true });
    expect(args.where.createdAt.gte).toBeInstanceOf(Date);
    expect(args.where.createdAt.lt).toBeInstanceOf(Date);
    expect(args.where.createdAt.lt.getTime()).toBeGreaterThan(
      args.where.createdAt.gte.getTime(),
    );
  });

  it('findOne sums multiple payments into paidTotal and subtracts them from remaining', async () => {
    const order = {
      id: 'order-1',
      total: 100000,
      payments: [{ amount: 30000 }, { amount: 25000 }],
    };
    const prisma = {
      order: {
        findUnique: jest.fn().mockResolvedValue(order),
      },
    } as unknown as PrismaService;
    const service = new OrdersService(prisma);

    await expect(service.findOne('order-1')).resolves.toEqual({
      ...order,
      paidTotal: 55000,
      remaining: 45000,
    });
  });

  it('findOne rejects when the order does not exist', async () => {
    const prisma = {
      order: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
    } as unknown as PrismaService;
    const service = new OrdersService(prisma);

    await expect(service.findOne('missing')).rejects.toMatchObject({
      status: 404,
    });
  });

  it('attaches an existing customer to the order and defaults customerNameSnapshot to the customer name', async () => {
    const customer = { id: 'customer-1', name: 'Chị Lan' };
    const createdOrder = {
      id: 'order-1',
      code: 'HD-1',
      total: 26000,
      items: [],
      payments: [],
    };
    const orderFindUnique = jest.fn().mockResolvedValue(null);
    const prisma = {
      order: {
        findUnique: orderFindUnique,
        create: jest.fn().mockResolvedValue(createdOrder),
      },
      customer: {
        findUnique: jest.fn().mockResolvedValue(customer),
      },
      product: {
        findMany: jest.fn().mockResolvedValue([product]),
      },
    } as unknown as PrismaService;
    const service = new OrdersService(prisma);

    await service.confirm({
      clientRequestId: 'req-1',
      items: [{ productId: 'product-1', quantity: 2 }],
      customerId: 'customer-1',
    });

    expect(prisma.customer.findUnique).toHaveBeenCalledWith({
      where: { id: 'customer-1' },
    });
    expect(prisma.order.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          customerId: 'customer-1',
          customerNameSnapshot: 'Chị Lan',
        }),
      }),
    );
  });

  it('rejects confirming with a customerId that does not exist', async () => {
    const prisma = {
      order: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
      customer: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
      product: {
        findMany: jest.fn().mockResolvedValue([product]),
      },
    } as unknown as PrismaService;
    const service = new OrdersService(prisma);

    await expect(
      service.confirm({
        clientRequestId: 'req-1',
        items: [{ productId: 'product-1', quantity: 2 }],
        customerId: 'missing-customer',
      }),
    ).rejects.toMatchObject({ status: 400 });
    expect(prisma.order.create).not.toHaveBeenCalled();
  });
});
