import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from './payments.service';

describe('PaymentsService', () => {
  it('creates a payment when the amount does not exceed what is still owed', async () => {
    const order = { id: 'order-1', total: 100000, payments: [{ amount: 30000 }] };
    const createdPayment = {
      id: 'payment-1',
      orderId: 'order-1',
      clientRequestId: 'req-1',
      amount: 40000,
      method: 'CASH',
      note: null,
    };
    const prisma = {
      payment: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue(createdPayment),
      },
      order: {
        findUnique: jest.fn().mockResolvedValue(order),
      },
    } as unknown as PrismaService;
    const service = new PaymentsService(prisma);

    const result = await service.create('order-1', {
      clientRequestId: 'req-1',
      amount: 40000,
    });

    expect(result).toBe(createdPayment);
    expect(prisma.payment.create).toHaveBeenCalledWith({
      data: {
        orderId: 'order-1',
        clientRequestId: 'req-1',
        amount: 40000,
        method: 'CASH',
        note: null,
      },
    });
  });

  it('rejects a payment that would exceed the remaining amount owed', async () => {
    const order = { id: 'order-1', total: 100000, payments: [{ amount: 80000 }] };
    const prisma = {
      payment: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
      order: {
        findUnique: jest.fn().mockResolvedValue(order),
      },
    } as unknown as PrismaService;
    const service = new PaymentsService(prisma);

    await expect(
      service.create('order-1', { clientRequestId: 'req-1', amount: 25000 }),
    ).rejects.toMatchObject({ status: 400 });
    expect(prisma.payment.create).not.toHaveBeenCalled();
  });

  it('rejects when the order does not exist', async () => {
    const prisma = {
      payment: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
      order: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
    } as unknown as PrismaService;
    const service = new PaymentsService(prisma);

    await expect(
      service.create('missing-order', { clientRequestId: 'req-1', amount: 1000 }),
    ).rejects.toMatchObject({ status: 404 });
  });

  it('returns the existing payment instead of creating a duplicate when clientRequestId repeats for the same order', async () => {
    const existingPayment = {
      id: 'payment-1',
      orderId: 'order-1',
      clientRequestId: 'req-1',
      amount: 40000,
    };
    const prisma = {
      payment: {
        findUnique: jest.fn().mockResolvedValue(existingPayment),
        create: jest.fn(),
      },
      order: { findUnique: jest.fn() },
    } as unknown as PrismaService;
    const service = new PaymentsService(prisma);

    await expect(
      service.create('order-1', { clientRequestId: 'req-1', amount: 40000 }),
    ).resolves.toBe(existingPayment);
    expect(prisma.order.findUnique).not.toHaveBeenCalled();
    expect(prisma.payment.create).not.toHaveBeenCalled();
  });

  it('rejects reusing a clientRequestId that already belongs to a different order', async () => {
    const existingPayment = {
      id: 'payment-1',
      orderId: 'order-OTHER',
      clientRequestId: 'req-1',
      amount: 40000,
    };
    const prisma = {
      payment: {
        findUnique: jest.fn().mockResolvedValue(existingPayment),
        create: jest.fn(),
      },
      order: { findUnique: jest.fn() },
    } as unknown as PrismaService;
    const service = new PaymentsService(prisma);

    await expect(
      service.create('order-1', { clientRequestId: 'req-1', amount: 40000 }),
    ).rejects.toMatchObject({ status: 409 });
    expect(prisma.payment.create).not.toHaveBeenCalled();
  });

  it('replays the racing payment instead of failing when two requests share a clientRequestId concurrently', async () => {
    const order = { id: 'order-1', total: 100000, payments: [] };
    const racedPayment = {
      id: 'payment-1',
      orderId: 'order-1',
      clientRequestId: 'req-1',
      amount: 40000,
    };
    const uniqueConstraintError = new Prisma.PrismaClientKnownRequestError(
      'Unique constraint failed',
      { code: 'P2002', clientVersion: '5.22.0' },
    );

    const findUnique = jest
      .fn()
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(racedPayment);
    const prisma = {
      payment: {
        findUnique,
        create: jest.fn().mockRejectedValue(uniqueConstraintError),
      },
      order: { findUnique: jest.fn().mockResolvedValue(order) },
    } as unknown as PrismaService;
    const service = new PaymentsService(prisma);

    await expect(
      service.create('order-1', { clientRequestId: 'req-1', amount: 40000 }),
    ).resolves.toBe(racedPayment);
    expect(findUnique).toHaveBeenCalledTimes(2);
  });

  it('lists payments for an order oldest first', async () => {
    const payments = [{ id: 'payment-1' }, { id: 'payment-2' }];
    const prisma = {
      payment: {
        findMany: jest.fn().mockResolvedValue(payments),
      },
    } as unknown as PrismaService;
    const service = new PaymentsService(prisma);

    await expect(service.listForOrder('order-1')).resolves.toBe(payments);
    expect(prisma.payment.findMany).toHaveBeenCalledWith({
      where: { orderId: 'order-1' },
      orderBy: { createdAt: 'asc' },
    });
  });
});
