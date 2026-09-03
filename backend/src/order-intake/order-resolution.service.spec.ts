import type { Product } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { OrderResolutionService } from './order-resolution.service';

function makeProduct(overrides: Partial<Product> & { id: string }): Product {
  return {
    name: 'Sản phẩm',
    normalizedName: 'san pham',
    unit: 'cái',
    normalizedUnit: 'cai',
    price: 10000,
    isArchived: false,
    createdAt: new Date('2026-08-18T00:00:00Z'),
    updatedAt: new Date('2026-08-18T00:00:00Z'),
    ...overrides,
  } as Product;
}

function makeItem(
  overrides: Partial<Parameters<OrderResolutionService['resolve']>[0]['items'][number]>,
) {
  return {
    rawText: '',
    rawProductName: '',
    quantity: 1,
    unit: null,
    note: null,
    needsReview: false,
    uncertaintyReason: null,
    ...overrides,
  };
}

describe('OrderResolutionService', () => {
  const boHuc = makeProduct({
    id: 'product-1',
    name: 'Bò Húc ít đường',
    normalizedName: 'bo huc it duong',
    unit: 'lon',
    normalizedUnit: 'lon',
    price: 13000,
  });

  function createService(products: Product[] = [boHuc]) {
    const prisma = {
      product: { findMany: jest.fn().mockResolvedValue(products) },
    } as unknown as PrismaService;
    return new OrderResolutionService(prisma);
  }

  async function resolveOne(
    item: ReturnType<typeof makeItem>,
    products: Product[] = [boHuc],
  ) {
    const result = await createService(products).resolve({
      items: [item],
      imageQuality: 'good',
      generalNote: null,
    });
    return result.items[0];
  }

  it('matches by normalized name and unit then calculates the invoice total', async () => {
    const result = await createService().resolve({
      items: [
        makeItem({
          rawText: '2 lon bò húc ít đường',
          rawProductName: 'bo huc it duong',
          quantity: 2,
          unit: 'lon',
        }),
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
    const item = await resolveOne(
      makeItem({
        rawText: '1 chai sản phẩm mới',
        rawProductName: 'Sản phẩm hoàn toàn lạ',
        quantity: 1,
        unit: 'chai',
      }),
    );

    expect(item).toMatchObject({
      matchStatus: 'missing',
      matchedProduct: null,
      candidates: [],
      lineTotal: null,
    });
  });

  it('requires confirmation when Vision marked an exact item uncertain', async () => {
    const item = await resolveOne(
      makeItem({
        rawText: '2 lon chữ hơi mờ',
        rawProductName: 'Bò Húc ít đường',
        quantity: 2,
        unit: 'lon',
        needsReview: true,
        uncertaintyReason: 'Chữ viết tay hơi mờ',
      }),
    );

    expect(item).toMatchObject({ matchStatus: 'review', lineTotal: 26000 });
  });

  describe('cổng tin cậy', () => {
    it('tự động ghép khi tên viết khác đôi chút nhưng điểm cao và không có đối thủ', async () => {
      // Truoc khi co cong tin cay, dong nay roi vao 'review' vi khong khop
      // chuoi tuyet doi -> nguoi dung phai bam tay tung dong.
      const item = await resolveOne(
        makeItem({
          rawText: '2 lon bo huc it duong',
          rawProductName: 'bo huc it duong ',
          quantity: 2,
          unit: 'lon',
        }),
      );

      expect(item.matchStatus).toBe('matched');
      expect(item.lineTotal).toBe(26000);
    });

    it('bắt xác nhận khi hai ứng viên quá sát nhau', async () => {
      const psTo = makeProduct({
        id: 'ps-to',
        name: 'Kem đánh răng P/S thường to',
        normalizedName: 'kem danh rang p s thuong to',
        unit: 'cái',
        normalizedUnit: 'cai',
        price: 32000,
      });
      const psNho = makeProduct({
        id: 'ps-nho',
        name: 'Kem đánh răng P/S thường nhỏ',
        normalizedName: 'kem danh rang p s thuong nho',
        unit: 'cái',
        normalizedUnit: 'cai',
        price: 18000,
      });

      const item = await resolveOne(
        makeItem({
          rawText: '10 cái kem đánh răng ps thường',
          rawProductName: 'kem danh rang p s thuong',
          quantity: 10,
          unit: 'cái',
        }),
        [psTo, psNho],
      );

      expect(item.matchStatus).toBe('review');
      expect(item.matchedProduct).toBeNull();
      expect(item.lineTotal).toBeNull();
      expect(item.uncertaintyReason).toContain('gần giống nhau');
    });

    it('không tự ghép khi mâu thuẫn biến thể dù điểm rất cao', async () => {
      const psNho = makeProduct({
        id: 'ps-nho',
        name: 'Kem P/S thường nhỏ',
        normalizedName: 'kem p s thuong nho',
        unit: 'cái',
        normalizedUnit: 'cai',
        price: 18000,
      });

      const item = await resolveOne(
        makeItem({
          rawText: '2 cái kem P/S thường to',
          rawProductName: 'Kem P/S thường to',
          quantity: 2,
          unit: 'cái',
        }),
        [psNho],
      );

      expect(item.matchStatus).toBe('review');
      expect(item.matchedProduct).toBeNull();
      expect(item.uncertaintyReason).toContain('kích cỡ');
    });

    it('tự ghép được khi khách viết thêm chữ thừa mà danh mục không có biến thể nào cạnh tranh', async () => {
      // Danh muc con it: chi co dung mot "Banh ca". Khach viet "banh ca to"
      // nhung khong ton tai ban nho nao de chon nham -> khong can hoi.
      const banhCa = makeProduct({
        id: 'banh-ca',
        name: 'Bánh cá',
        normalizedName: 'banh ca',
        unit: 'thùng',
        normalizedUnit: 'thung',
        price: 90000,
      });

      const item = await resolveOne(
        makeItem({
          rawText: '1 thùng bánh cá to',
          rawProductName: 'banh ca',
          quantity: 1,
          unit: 'thùng',
        }),
        [banhCa],
      );

      expect(item.matchStatus).toBe('matched');
      expect(item.lineTotal).toBe(90000);
    });

    it('thắt chặt trở lại ngay khi danh mục có thêm biến thể cạnh tranh', async () => {
      const banhCa = makeProduct({
        id: 'banh-ca',
        name: 'Bánh cá',
        normalizedName: 'banh ca',
        unit: 'thùng',
        normalizedUnit: 'thung',
        price: 90000,
      });
      const banhCaNho = makeProduct({
        id: 'banh-ca-nho',
        name: 'Bánh cá nhỏ',
        normalizedName: 'banh ca nho',
        unit: 'thùng',
        normalizedUnit: 'thung',
        price: 50000,
      });

      const item = await resolveOne(
        makeItem({
          rawText: '1 thùng bánh cá to',
          rawProductName: 'banh ca to',
          quantity: 1,
          unit: 'thùng',
        }),
        [banhCa, banhCaNho],
      );

      expect(item.matchStatus).toBe('review');
      expect(item.matchedProduct).toBeNull();
      // Dong nay bi chan boi nguong diem chu khong phai boi variant, nhung
      // van phai co ly do de nguoi dung biet dang phan van giua nhung gi.
      expect(item.uncertaintyReason).toContain('Bánh cá');
    });

    it('mọi dòng bị hỏi đều phải kèm lý do, không được để trống', async () => {
      const result = await createService().resolve({
        items: [
          makeItem({
            rawText: '3 lon nước gì đó hơi giống bò húc',
            rawProductName: 'nuoc gi do bo huc',
            quantity: 3,
            unit: 'lon',
          }),
        ],
        imageQuality: 'good',
        generalNote: null,
      });

      const item = result.items[0];
      if (item.matchStatus === 'review') {
        expect(item.uncertaintyReason).toBeTruthy();
      }
    });

    it('không tự ghép khi đơn vị trên giấy khác đơn vị danh mục', async () => {
      const thung = makeProduct({
        id: 'banh-thung',
        name: 'Bánh cá',
        normalizedName: 'banh ca',
        unit: 'thùng',
        normalizedUnit: 'thung',
        price: 90000,
      });

      const item = await resolveOne(
        makeItem({
          rawText: '1 gói bánh cá',
          rawProductName: 'banh ca',
          quantity: 1,
          unit: 'gói',
        }),
        [thung],
      );

      expect(item.matchStatus).toBe('review');
      expect(item.uncertaintyReason).toContain('Đơn vị');
    });

    it('không cho chuỗi con ngắn ăn điểm cao một cách vô lý', async () => {
      const keo = makeProduct({
        id: 'keo',
        name: 'Kẹo',
        normalizedName: 'keo',
        unit: 'gói',
        normalizedUnit: 'goi',
        price: 5000,
      });

      const item = await resolveOne(
        makeItem({
          rawText: '3 gói kẹo dâu sữa loại mới',
          rawProductName: 'keo dau sua loai moi',
          quantity: 3,
          unit: 'gói',
        }),
        [keo],
      );

      // "keo" nam trong "keo dau sua loai moi" nhung thieu qua nhieu thong tin
      // -> khong duoc phep tu dong ghep.
      expect(item.matchStatus).toBe('review');
      expect(item.matchedProduct).toBeNull();
    });
  });

  describe('đối chiếu giá viết tay', () => {
    it('bắt xác nhận khi giá trên giấy lệch hẳn giá danh mục, dù tên khớp tuyệt đối', async () => {
      const item = await resolveOne(
        makeItem({
          rawText: '1 lon bò húc ít đường 150.000',
          rawProductName: 'bo huc it duong',
          quantity: 1,
          unit: 'lon',
          unitPrice: 150000,
        }),
      );

      expect(item.matchStatus).toBe('review');
      expect(item.uncertaintyReason).toContain('150.000 đ');
      expect(item.uncertaintyReason).toContain('sai số lượng');
    });

    it('chấp nhận khi khách ghi thành tiền cả dòng thay vì đơn giá', async () => {
      const item = await resolveOne(
        makeItem({
          rawText: '2 lon bò húc ít đường 26.000',
          rawProductName: 'bo huc it duong',
          quantity: 2,
          unit: 'lon',
          unitPrice: 26000,
        }),
      );

      expect(item.matchStatus).toBe('matched');
      expect(item.lineTotal).toBe(26000);
    });

    it('phát hiện đọc sai số lượng khi khách có ghi thành tiền', async () => {
      // Giay ghi 2 lon = 26.000 nhung Vision doc so luong thanh 7.
      const item = await resolveOne(
        makeItem({
          rawText: '2 lon bò húc ít đường 26.000',
          rawProductName: 'bo huc it duong',
          quantity: 7,
          unit: 'lon',
          unitPrice: 26000,
        }),
      );

      expect(item.matchStatus).toBe('review');
      expect(item.uncertaintyReason).toContain('sai số lượng');
    });

    it('không phàn nàn khi khách không ghi giá', async () => {
      const item = await resolveOne(
        makeItem({
          rawText: '2 lon bò húc ít đường',
          rawProductName: 'bo huc it duong',
          quantity: 2,
          unit: 'lon',
          unitPrice: null,
        }),
      );

      expect(item.matchStatus).toBe('matched');
    });
  });

  it('luôn tin lựa chọn người dùng đã tự tay chọn', async () => {
    const item = await resolveOne(
      makeItem({
        rawText: 'dòng khách viết rất khó đọc',
        rawProductName: 'chu nguech ngoac',
        quantity: 2,
        unit: 'lon',
        unitPrice: 999999,
        selectedProductId: 'product-1',
      }),
    );

    expect(item.matchStatus).toBe('matched');
    expect(item.matchedProduct).toMatchObject({ id: 'product-1' });
    expect(item.lineTotal).toBe(26000);
  });
});
