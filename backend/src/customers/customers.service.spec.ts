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
