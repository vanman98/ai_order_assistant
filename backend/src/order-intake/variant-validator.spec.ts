import { compareVariants, extractVariantProfile } from './variant-validator';

describe('extractVariantProfile', () => {
  it('phân biệt được "nhỏ" (kích cỡ) và "nho" (hương vị) nhờ giữ nguyên dấu', () => {
    expect(extractVariantProfile('Kun nhỏ nho')).toMatchObject({
      size: 'small',
      flavors: ['nho'],
    });
    expect(extractVariantProfile('Kun nhỏ ổi')).toMatchObject({
      size: 'small',
      flavors: ['ổi'],
    });
  });

  it('không hiểu "trà xanh" thành màu xanh', () => {
    expect(extractVariantProfile('Trà xanh không độ')).toMatchObject({
      flavors: ['trà xanh'],
    });
  });

  it('quy đổi khối lượng về đơn vị chuẩn, chấp nhận cả dấu phẩy thập phân', () => {
    expect(extractVariantProfile('Omo Matic 3.6kg').measures).toEqual(['3600g']);
    expect(extractVariantProfile('Omo Matic 3,6kg').measures).toEqual(['3600g']);
    expect(extractVariantProfile('Nước xả Downy 2L').measures).toEqual([
      '2000ml',
    ]);
  });

  it('nhận diện độ ngọt', () => {
    expect(extractVariantProfile('Bò Húc ít đường').sugar).toBe('less');
    expect(extractVariantProfile('Sting không đường').sugar).toBe('none');
    expect(extractVariantProfile('Bò Húc').sugar).toBeNull();
  });
});

describe('compareVariants', () => {
  it('chặn ghép "P/S thường to" vào "P/S thường nhỏ" dù chuỗi rất giống nhau', () => {
    const result = compareVariants(
      'Kem đánh răng P/S thường to',
      'Kem đánh răng P/S thường nhỏ',
    );
    expect(result.hasConflict).toBe(true);
    expect(result.reason).toContain('kích cỡ');
  });

  it('chặn ghép hai hương vị khác nhau của cùng dòng sản phẩm', () => {
    const result = compareVariants('Kun nhỏ nho', 'Kun nhỏ ổi');
    expect(result.hasConflict).toBe(true);
    expect(result.reason).toContain('hương vị');
  });

  it('chặn ghép khi khối lượng khác nhau', () => {
    const result = compareVariants('Omo Matic 3.6kg', 'Omo Matic 1.5kg');
    expect(result.hasConflict).toBe(true);
    expect(result.reason).toContain('khối lượng');
  });

  it('mặc định (không biết gì về danh mục) thì lệch một chiều vẫn bị chặn', () => {
    expect(compareVariants('Kem P/S to', 'Kem P/S').hasConflict).toBe(true);
    expect(compareVariants('Kem P/S', 'Kem P/S to').hasConflict).toBe(true);
    expect(compareVariants('Kun nhỏ', 'Kun nhỏ ổi').hasConflict).toBe(true);
  });

  it('không báo mâu thuẫn khi hai tên cùng biến thể, khác cách viết hoa/dấu câu', () => {
    expect(
      compareVariants('bò húc ít đường', 'Bò Húc ít đường').hasConflict,
    ).toBe(false);
    expect(compareVariants('bánh nabati', 'Bánh Nabati').hasConflict).toBe(
      false,
    );
  });

  it('không báo mâu thuẫn cho tên không chứa dấu hiệu biến thể nào', () => {
    expect(
      compareVariants('mì omachi bò hầm', 'Mì Omachi bò hầm').hasConflict,
    ).toBe(false);
  });

  describe('tự thích nghi theo danh mục', () => {
    it('BỎ QUA lệch một chiều khi cả danh mục không hề phân biệt chiều đó', () => {
      // Danh muc chi co dung mot "Banh ca" - khong ton tai ban to/nho nao khac
      // de ma chon nham, nen bat xac nhan la lam phien vo ich.
      const result = compareVariants('bánh cá to', 'Bánh cá', ['Bánh cá']);
      expect(result.hasConflict).toBe(false);
    });

    it('VẪN CHẶN lệch một chiều khi danh mục thật sự có biến thể cạnh tranh', () => {
      const result = compareVariants('Kem P/S thường', 'Kem P/S thường to', [
        'Kem P/S thường to',
        'Kem P/S thường nhỏ',
      ]);
      expect(result.hasConflict).toBe(true);
      expect(result.reason).toContain('kích cỡ');
    });

    it('VẪN CHẶN mâu thuẫn trực diện dù danh mục chỉ có một sản phẩm', () => {
      // Khach viet ro "to", danh muc chi co ban "nho". Khong duoc phep tu dong
      // ban ban nho: khach da noi ro roi, day khong con la chuyen mo ho nua.
      const result = compareVariants('Kem P/S thường to', 'Kem P/S thường nhỏ', [
        'Kem P/S thường nhỏ',
      ]);
      expect(result.hasConflict).toBe(true);
      expect(result.reason).toContain('kích cỡ');
    });

    it('bỏ qua khi khách không ghi hương vị và danh mục chỉ có một hương vị', () => {
      expect(
        compareVariants('Kun nhỏ', 'Kun nhỏ ổi', ['Kun nhỏ ổi']).hasConflict,
      ).toBe(false);
    });

    it('vẫn chặn khi danh mục có hai hương vị của cùng dòng sản phẩm', () => {
      const result = compareVariants('Kun nhỏ', 'Kun nhỏ ổi', [
        'Kun nhỏ ổi',
        'Kun nhỏ nho',
      ]);
      expect(result.hasConflict).toBe(true);
      expect(result.reason).toContain('hương vị');
    });

    it('tự thắt chặt lại ngay khi chủ cửa hàng thêm biến thể mới vào danh mục', () => {
      const before = compareVariants('bánh cá to', 'Bánh cá', ['Bánh cá']);
      const after = compareVariants('bánh cá to', 'Bánh cá', [
        'Bánh cá',
        'Bánh cá nhỏ',
      ]);
      expect(before.hasConflict).toBe(false);
      expect(after.hasConflict).toBe(true);
    });
  });

  it('không nhầm đơn vị "lon" thành kích cỡ "lớn"', () => {
    // Ca hai deu khong co dau hieu kich co -> khong duoc bao mau thuan.
    const result = compareVariants('Bò Húc lon', 'Bò Húc lon');
    expect(result.hasConflict).toBe(false);
    expect(extractVariantProfile('Bò Húc lon').size).toBeNull();
  });
});
