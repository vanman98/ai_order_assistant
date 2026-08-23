import { PrismaService } from '../prisma/prisma.service';
import { ProductsService } from './products.service';

describe('ProductsService', () => {
  it('permanently deletes a product instead of updating a status flag', async () => {
    const product = {
      id: 'product-1',
      name: 'Bánh ChocoPie',
      normalizedName: 'banh chocopie',
      unit: 'hộp',
      normalizedUnit: 'hop',
      price: 45000,
      createdAt: new Date('2026-08-22T00:00:00Z'),
      updatedAt: new Date('2026-08-22T00:00:00Z'),
    };
    const prisma = {
      product: {
        findUnique: jest.fn().mockResolvedValue(product),
        delete: jest.fn().mockResolvedValue(product),
      },
    } as unknown as PrismaService;
    const service = new ProductsService(prisma);

    await expect(service.remove(product.id)).resolves.toEqual(product);
    expect(prisma.product.delete).toHaveBeenCalledWith({
      where: { id: product.id },
    });
  });

  it('creates scanned products in one transaction after checking duplicates', async () => {
    const created = [
      {
        id: 'product-2',
        name: 'Dầu Meizan 1 lít',
        normalizedName: 'dau meizan 1 lit',
        unit: 'thùng',
        normalizedUnit: 'thung',
        price: 420000,
      },
    ];
    const prisma = {
      product: {
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn().mockReturnValue('create-operation'),
      },
      $transaction: jest.fn().mockResolvedValue(created),
    } as unknown as PrismaService;
    const service = new ProductsService(prisma);

    await expect(
      service.createMany([
        { name: ' Dầu Meizan 1 lít ', unit: ' thùng ', price: 420000 },
      ]),
    ).resolves.toEqual(created);
    expect(prisma.product.findMany).toHaveBeenCalledWith({
      where: {
        OR: [
          {
            normalizedName: 'dau meizan 1 lit',
            normalizedUnit: 'thung',
          },
        ],
      },
      select: { name: true, unit: true },
    });
    expect(prisma.$transaction).toHaveBeenCalledWith(['create-operation']);
  });

  it('rejects duplicate scanned products before writing', async () => {
    const prisma = {
      product: { findMany: jest.fn(), create: jest.fn() },
      $transaction: jest.fn(),
    } as unknown as PrismaService;
    const service = new ProductsService(prisma);

    await expect(
      service.createMany([
        { name: 'Coca lon', unit: 'lon', price: 12000 },
        { name: 'coca-lon', unit: 'lon', price: 13000 },
      ]),
    ).rejects.toMatchObject({ status: 409 });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});
