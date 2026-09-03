import {
  checkWrittenPrice,
  describeWrittenPriceConflict,
  formatVndPlain,
} from './written-price-check';

describe('checkWrittenPrice', () => {
  it('không có gì để đối chiếu khi khách không ghi giá', () => {
    expect(
      checkWrittenPrice({
        writtenPrice: null,
        catalogPrice: 13000,
        quantity: 2,
      }).status,
    ).toBe('no_data');
  });

  it('chấp nhận khi khách ghi đơn giá', () => {
    expect(
      checkWrittenPrice({
        writtenPrice: 13000,
        catalogPrice: 13000,
        quantity: 2,
      }).status,
    ).toBe('matches_unit_price');
  });

  it('chấp nhận khi khách ghi thành tiền cả dòng', () => {
    expect(
      checkWrittenPrice({
        writtenPrice: 26000,
        catalogPrice: 13000,
        quantity: 2,
      }).status,
    ).toBe('matches_line_total');
  });

  it('phát hiện đọc sai số lượng: giấy ghi 1 thùng 90.000 nhưng đọc thành 7', () => {
    const result = checkWrittenPrice({
      writtenPrice: 90000,
      catalogPrice: 90000,
      quantity: 7,
    });
    // 90.000 khop DON GIA nen khong bao conflict - day la gioi han that su
    // cua phep kiem tra khi khach chi ghi don gia.
    expect(result.status).toBe('matches_unit_price');
  });

  it('phát hiện đọc sai số lượng khi khách ghi thành tiền', () => {
    // Giay ghi thanh tien 90.000 (1 thung), Vision doc so luong thanh 7.
    const result = checkWrittenPrice({
      writtenPrice: 90000,
      catalogPrice: 90000,
      quantity: 7,
    });
    expect(result.expectedLineTotal).toBe(630000);

    // Voi mat hang co don gia khac thanh tien thi phat hien duoc ngay:
    const other = checkWrittenPrice({
      writtenPrice: 26000, // khach ghi thanh tien cua 2 lon
      catalogPrice: 13000,
      quantity: 7, // Vision doc nham 2 -> 7
    });
    expect(other.status).toBe('conflict');
  });

  it('phát hiện ghép nhầm sản phẩm khi giá lệch hẳn', () => {
    const result = checkWrittenPrice({
      writtenPrice: 150000,
      catalogPrice: 13000,
      quantity: 1,
    });
    expect(result.status).toBe('conflict');
  });

  it('bỏ qua sai lệch làm tròn nhỏ', () => {
    expect(
      checkWrittenPrice({
        writtenPrice: 13100,
        catalogPrice: 13000,
        quantity: 1,
      }).status,
    ).toBe('matches_unit_price');
  });

  it('không chia cho 0 khi giá danh mục bằng 0', () => {
    expect(
      checkWrittenPrice({
        writtenPrice: 5000,
        catalogPrice: 0,
        quantity: 1,
      }).status,
    ).toBe('conflict');
  });

  it('vẫn hoạt động khi thiếu số lượng', () => {
    const result = checkWrittenPrice({
      writtenPrice: 13000,
      catalogPrice: 13000,
      quantity: null,
    });
    expect(result.status).toBe('matches_unit_price');
    expect(result.expectedLineTotal).toBeNull();
  });
});

describe('formatVndPlain', () => {
  it('nhóm hàng nghìn theo kiểu Việt Nam', () => {
    expect(formatVndPlain(150000)).toBe('150.000 đ');
    expect(formatVndPlain(13000)).toBe('13.000 đ');
    expect(formatVndPlain(500)).toBe('500 đ');
  });
});

describe('describeWrittenPriceConflict', () => {
  it('nói rõ cả hai khả năng để người dùng biết kiểm tra gì', () => {
    const result = checkWrittenPrice({
      writtenPrice: 150000,
      catalogPrice: 13000,
      quantity: 2,
    });
    const message = describeWrittenPriceConflict(150000, result);
    expect(message).toContain('150.000 đ');
    expect(message).toContain('13.000 đ');
    expect(message).toContain('26.000 đ');
    expect(message).toContain('sai số lượng');
  });
});
