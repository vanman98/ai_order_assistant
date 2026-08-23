import {
  BadRequestException,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { MAX_ORDER_IMAGE_BYTES } from './order-intake.constants';
import { detectOrderImageMime, OrderImagePipe } from './order-image.pipe';

describe('order image validation', () => {
  it('detects supported image signatures', () => {
    expect(detectOrderImageMime(Buffer.from([0xff, 0xd8, 0xff, 0x00]))).toBe(
      'image/jpeg',
    );
    expect(
      detectOrderImageMime(
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      ),
    ).toBe('image/png');
    expect(
      detectOrderImageMime(Buffer.from('RIFF0000WEBP', 'ascii')),
    ).toBe('image/webp');
  });

  it('rejects a missing or empty file', () => {
    const pipe = new OrderImagePipe();
    expect(() => pipe.transform()).toThrow(BadRequestException);
    expect(() =>
      pipe.transform({ buffer: Buffer.alloc(0), size: 0 } as Express.Multer.File),
    ).toThrow(BadRequestException);
  });

  it('rejects content that only pretends to be an image', () => {
    const file = {
      buffer: Buffer.from('not-an-image'),
      size: 12,
      mimetype: 'image/jpeg',
    } as Express.Multer.File;

    expect(() => new OrderImagePipe().transform(file)).toThrow(
      UnsupportedMediaTypeException,
    );
  });

  it('uses magic bytes as the trusted MIME type', () => {
    const buffer = Buffer.from([0xff, 0xd8, 0xff, 0x00]);
    const file = {
      buffer,
      size: buffer.length,
      mimetype: 'image/png',
    } as Express.Multer.File;

    expect(new OrderImagePipe().transform(file).mimetype).toBe('image/jpeg');
  });

  it('rejects content larger than 8 MB', () => {
    const buffer = Buffer.alloc(MAX_ORDER_IMAGE_BYTES + 1, 0);
    buffer.set([0xff, 0xd8, 0xff]);
    const file = { buffer, size: buffer.length } as Express.Multer.File;

    expect(() => new OrderImagePipe().transform(file)).toThrow(
      PayloadTooLargeException,
    );
  });
});
