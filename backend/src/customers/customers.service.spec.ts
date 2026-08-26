import { PrismaService } from '../prisma/prisma.service';
import { CustomersService } from './customers.service';

describe('CustomersService', () => {
  it('creates a customer with a normalized name and trimmed phone/note', async () => {
    const createdCustomer = { id: 'customer-1', name: 'Chị Lan' };
    const prisma = {
      customer: {
        create: jest.fn().mockResolvedValue(createdCustomer),
      },
    } as unknown as PrismaService;
    const service = new CustomersService(prisma);

    const result = await service.create({
      name: '  Chị Lan  ',
      phone: '  0901234567  ',
      note: '  khách quen  ',
    });

    expect(result).toBe(createdCustomer);
    expect(prisma.customer.create).toHaveBeenCalledWith({
      data: {
        name: 'Chị Lan',
        normalizedName: 'chi lan',
        phone: '0901234567',
        note: 'khách quen',
      },
    });
  });

  it('rejects a customer name with no searchable characters', async () => {
    const prisma = {
      customer: { create: jest.fn() },
    } as unknown as PrismaService;
    const service = new CustomersService(prisma);

    await expect(
      service.create({ name: '   ', phone: undefined, note: undefined }),
    ).rejects.toMatchObject({ status: 400 });
    expect(prisma.customer.create).not.toHaveBeenCalled();
  });

  it('searches by name, normalized name, and phone', async () => {
    const customers = [{ id: 'customer-1' }];
    const prisma = {
      customer: {
        findMany: jest.fn().mockResolvedValue(customers),
      },
    } as unknown as PrismaService;
    const service = new CustomersService(prisma);

    await expect(service.findAll('Lan')).resolves.toBe(customers);
    const args = (prisma.customer.findMany as jest.Mock).mock.calls[0][0];
    expect(args.where.OR).toHaveLength(3);
    expect(args.orderBy).toEqual({ name: 'asc' });
  });

  it('updates an existing customer, keeping untouched fields as-is', async () => {
    const existing = {
      id: 'customer-1',
      name: 'Chị Lan',
      normalizedName: 'chi lan',
      phone: '0901234567',
      note: null,
    };
    const updated = { ...existing, phone: '0909999999' };
    const prisma = {
      customer: {
        findUnique: jest.fn().mockResolvedValue(existing),
        update: jest.fn().mockResolvedValue(updated),
      },
    } as unknown as PrismaService;
    const service = new CustomersService(prisma);

    const result = await service.update('customer-1', {
      phone: '0909999999',
    });

    expect(result).toBe(updated);
    expect(prisma.customer.update).toHaveBeenCalledWith({
      where: { id: 'customer-1' },
      data: {
        name: 'Chị Lan',
        normalizedName: 'chi lan',
        phone: '0909999999',
      },
    });
  });

  it('rejects updating a customer that does not exist', async () => {
    const prisma = {
      customer: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
    } as unknown as PrismaService;
    const service = new CustomersService(prisma);

    await expect(
      service.update('missing', { name: 'A' }),
    ).rejects.toMatchObject({ status: 404 });
  });

  it('groups debt by customer, excluding fully paid orders and sorting by largest debt', async () => {
    const orders = [
      {
        id: 'order-1',
        code: 'HD-1',
        total: 100000,
        createdAt: new Date('2026-08-24T10:00:00Z'),
        customerId: 'customer-1',
        customerNameSnapshot: 'Chị Lan',
        customer: { id: 'customer-1', name: 'Chị Lan', phone: '0901' },
        payments: [{ amount: 30000 }],
      },
      {
        id: 'order-2',
        code: 'HD-2',
        total: 50000,
        createdAt: new Date('2026-08-23T10:00:00Z'),
        customerId: 'customer-1',
        customerNameSnapshot: 'Chị Lan',
        customer: { id: 'customer-1', name: 'Chị Lan', phone: '0901' },
        payments: [],
      },
      {
        // Da tra du -> khong duoc tinh vao cong no.
        id: 'order-3',
        code: 'HD-3',
        total: 20000,
        createdAt: new Date('2026-08-22T10:00:00Z'),
        customerId: 'customer-2',
        customerNameSnapshot: 'Anh Nam',
        customer: { id: 'customer-2', name: 'Anh Nam', phone: null },
        payments: [{ amount: 20000 }],
      },
      {
        id: 'order-4',
        code: 'HD-4',
        total: 15000,
        createdAt: new Date('2026-08-21T10:00:00Z'),
        customerId: 'customer-2',
        customerNameSnapshot: 'Anh Nam',
        customer: { id: 'customer-2', name: 'Anh Nam', phone: null },
        payments: [],
      },
    ];
    const prisma = {
      customer: {},
      order: { findMany: jest.fn().mockResolvedValue(orders) },
    } as unknown as PrismaService;
    const service = new CustomersService(prisma);

    const debts = await service.findDebts();

    expect(debts).toHaveLength(2);
    // Chi Lan no 70000 + 50000 = 120000, dung dau vi no nhieu nhat.
    expect(debts[0]).toMatchObject({
      customerId: 'customer-1',
      customerName: 'Chị Lan',
      phone: '0901',
      totalDebt: 120000,
      unpaidOrderCount: 2,
    });
    expect(debts[0].orders).toHaveLength(2);
    expect(debts[0].orders[0]).toMatchObject({
      code: 'HD-1',
      total: 100000,
      paidTotal: 30000,
      remaining: 70000,
    });
    // Anh Nam chi con don HD-4 chua tra; HD-3 da tra du nen bi loai.
    expect(debts[1]).toMatchObject({
      customerId: 'customer-2',
      totalDebt: 15000,
      unpaidOrderCount: 1,
    });
    expect(debts[1].orders.map((order) => order.code)).toEqual(['HD-4']);

    const args = (prisma.order.findMany as jest.Mock).mock.calls[0][0];
    expect(args.where).toEqual({ customerId: { not: null } });
  });

  it('falls back to the order name snapshot when the customer record was deleted', async () => {
    const prisma = {
      customer: {},
      order: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'order-1',
            code: 'HD-1',
            total: 40000,
            createdAt: new Date('2026-08-24T10:00:00Z'),
            customerId: 'deleted-customer',
            customerNameSnapshot: 'Chị Lan',
            customer: null,
            payments: [],
          },
        ]),
      },
    } as unknown as PrismaService;
    const service = new CustomersService(prisma);

    const debts = await service.findDebts();

    expect(debts[0]).toMatchObject({
      customerName: 'Chị Lan',
      phone: null,
      totalDebt: 40000,
    });
  });

  it('treats an overpaid order as no debt rather than negative debt', async () => {
    const prisma = {
      customer: {},
      order: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'order-1',
            code: 'HD-1',
            total: 30000,
            createdAt: new Date('2026-08-24T10:00:00Z'),
            customerId: 'customer-1',
            customerNameSnapshot: 'Chị Lan',
            customer: { id: 'customer-1', name: 'Chị Lan', phone: null },
            payments: [{ amount: 50000 }],
          },
        ]),
      },
    } as unknown as PrismaService;
    const service = new CustomersService(prisma);

    await expect(service.findDebts()).resolves.toEqual([]);
  });

  it('deletes a customer without checking for existing orders (SetNull keeps order history intact)', async () => {
    const existing = { id: 'customer-1', name: 'Chị Lan' };
    const prisma = {
      customer: {
        findUnique: jest.fn().mockResolvedValue(existing),
        delete: jest.fn().mockResolvedValue(existing),
      },
    } as unknown as PrismaService;
    const service = new CustomersService(prisma);

    await expect(service.remove('customer-1')).resolves.toBe(existing);
    expect(prisma.customer.delete).toHaveBeenCalledWith({
      where: { id: 'customer-1' },
    });
  });
});
