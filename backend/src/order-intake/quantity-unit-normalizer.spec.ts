import {
  normalizeQuantityUnit,
  normalizeUnitAbbreviation,
} from './quantity-unit-normalizer';

describe('normalizeUnitAbbreviation', () => {
  it('expands unambiguous abbreviations to their full Vietnamese form', () => {
    expect(normalizeUnitAbbreviation('th')).toEqual({
      unit: 'thùng',
      wasNormalized: true,
      ambiguous: false,
    });
    expect(normalizeUnitAbbreviation('l')).toEqual({
      unit: 'lít',
      wasNormalized: true,
      ambiguous: false,
    });
    expect(normalizeUnitAbbreviation('1 lit')).toEqual({
      unit: '1 lit',
      wasNormalized: false,
      ambiguous: false,
    });
  });

  it('leaves an already-full unit untouched', () => {
    expect(normalizeUnitAbbreviation('thùng')).toEqual({
      unit: 'thùng',
      wasNormalized: false,
      ambiguous: false,
    });
  });

  it('flags ambiguous abbreviations instead of guessing', () => {
    expect(normalizeUnitAbbreviation('b')).toEqual({
      unit: 'b',
      wasNormalized: false,
      ambiguous: true,
    });
  });

  it('passes through null and unknown units unchanged', () => {
    expect(normalizeUnitAbbreviation(null)).toEqual({
      unit: null,
      wasNormalized: false,
      ambiguous: false,
    });
    expect(normalizeUnitAbbreviation('cây')).toEqual({
      unit: 'cây',
      wasNormalized: false,
      ambiguous: false,
    });
  });
});

describe('normalizeQuantityUnit', () => {
  it('parses the "3k6" weight shorthand into 3.6 kg', () => {
    const result = normalizeQuantityUnit({
      quantity: null,
      unit: null,
      rawText: 'Thịt ba chỉ 3k6',
    });

    expect(result).toEqual({
      quantity: 3.6,
      unit: 'kg',
      wasNormalized: true,
      ambiguousUnit: false,
    });
  });

  it('does not override a quantity Vision already read from the image', () => {
    const result = normalizeQuantityUnit({
      quantity: 2,
      unit: 'lon',
      rawText: '2 lon Bò Húc',
    });

    expect(result).toEqual({
      quantity: 2,
      unit: 'lon',
      wasNormalized: false,
      ambiguousUnit: false,
    });
  });

  it('normalizes the unit abbreviation even when quantity is already known', () => {
    const result = normalizeQuantityUnit({
      quantity: 1,
      unit: 'th',
      rawText: '1 th nước mắm',
    });

    expect(result).toEqual({
      quantity: 1,
      unit: 'thùng',
      wasNormalized: true,
      ambiguousUnit: false,
    });
  });

  it('flags an ambiguous unit for review without guessing', () => {
    const result = normalizeQuantityUnit({
      quantity: 2,
      unit: 'b',
      rawText: '2 b bột giặt',
    });

    expect(result).toEqual({
      quantity: 2,
      unit: 'b',
      wasNormalized: false,
      ambiguousUnit: true,
    });
  });
});
