/**
 * Doi chieu con so tien khach VIET TAY tren giay voi gia trong danh muc.
 *
 * Day la bo phat hien sai sot re nhat va manh nhat cua ca pipeline, vi no bat
 * duoc CA HAI loai loi cung luc:
 *
 *   - Ghep nham san pham  -> gia danh muc lech han so khach viet.
 *   - Doc sai so luong    -> khi khach ghi thanh tien, quantity * gia se lech.
 *
 * Doc sai so luong la loai loi nguy hiem nhat trong toan he thong: ten dung,
 * gia dung, hoa don nhin hoan toan binh thuong - khong co dau hieu nao de
 * nguoi dung phat hien. Chu viet tay tieng Viet rat hay lan 1/7, 4/9, 0/6.
 *
 * Khach hang moi nguoi ghi mot kieu: co nguoi ghi don gia, co nguoi ghi thanh
 * tien ca dong. Ham nay chap nhan ca hai, nen khong bat nguoi dung phai ghi
 * theo mot chuan nao.
 */

export type WrittenPriceStatus =
  | 'no_data'
  | 'matches_unit_price'
  | 'matches_line_total'
  | 'conflict';

export interface WrittenPriceCheckInput {
  writtenPrice: number | null | undefined;
  catalogPrice: number;
  quantity: number | null | undefined;
}

export interface WrittenPriceCheckResult {
  status: WrittenPriceStatus;
  /** So tien ma danh muc suy ra, dung de hien thong bao cho nguoi dung. */
  expectedUnitPrice: number;
  expectedLineTotal: number | null;
}

/**
 * Sai so cho phep. Gia hang tap hoa la so tron (13.000, 150.000) nen bien do
 * nay chi de bo qua sai lech lam tron, khong phai de nuong tay.
 */
export const WRITTEN_PRICE_TOLERANCE = 0.02;

function isClose(left: number, right: number): boolean {
  if (right === 0) return left === 0;
  return Math.abs(left - right) / right <= WRITTEN_PRICE_TOLERANCE;
}

export function checkWrittenPrice(
  input: WrittenPriceCheckInput,
): WrittenPriceCheckResult {
  const { writtenPrice, catalogPrice, quantity } = input;
  const hasQuantity =
    quantity != null && Number.isFinite(quantity) && quantity > 0;
  const expectedLineTotal = hasQuantity
    ? Math.round(quantity * catalogPrice)
    : null;

  const base: Omit<WrittenPriceCheckResult, 'status'> = {
    expectedUnitPrice: catalogPrice,
    expectedLineTotal,
  };

  // Khach khong ghi gia - khong co gi de doi chieu, khong phai loi.
  if (writtenPrice == null || !Number.isFinite(writtenPrice)) {
    return { ...base, status: 'no_data' };
  }

  if (isClose(writtenPrice, catalogPrice)) {
    return { ...base, status: 'matches_unit_price' };
  }

  // Khach ghi thanh tien ca dong. Truong hop nay con xac nhan luon ca so
  // luong Vision doc duoc la dung.
  if (expectedLineTotal != null && isClose(writtenPrice, expectedLineTotal)) {
    return { ...base, status: 'matches_line_total' };
  }

  return { ...base, status: 'conflict' };
}

/** Dinh dang tien kieu Viet Nam: 150000 -> "150.000 d". */
export function formatVndPlain(value: number): string {
  return `${Math.round(value)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, '.')} đ`;
}

export function describeWrittenPriceConflict(
  writtenPrice: number,
  result: WrittenPriceCheckResult,
): string {
  const expected =
    result.expectedLineTotal != null &&
    result.expectedLineTotal !== result.expectedUnitPrice
      ? `${formatVndPlain(result.expectedUnitPrice)}/đơn vị (thành tiền ${formatVndPlain(result.expectedLineTotal)})`
      : formatVndPlain(result.expectedUnitPrice);

  return (
    `Số tiền trên giấy (${formatVndPlain(writtenPrice)}) không khớp danh mục ` +
    `(${expected}). Có thể nhầm sản phẩm hoặc sai số lượng — vui lòng kiểm tra.`
  );
}
