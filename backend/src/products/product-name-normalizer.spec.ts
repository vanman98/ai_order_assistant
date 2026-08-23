import { normalizeProductName } from './product-name-normalizer';

describe('normalizeProductName', () => {
  it('normalizes Vietnamese accents and whitespace', () => {
    expect(normalizeProductName('  Cà phê   G7 Đen  ')).toBe('ca phe g7 den');
  });

  it('keeps product size searchable', () => {
    expect(normalizeProductName('Omo Matic 3.6kg')).toBe('omo matic 3 6kg');
  });
});
