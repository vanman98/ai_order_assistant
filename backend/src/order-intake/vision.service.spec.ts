import { ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { VisionService } from './vision.service';

describe('VisionService', () => {
  it('does not call OpenAI when the backend key is missing', async () => {
    const service = new VisionService(new ConfigService({}));

    await expect(
      service.extractOrder({
        buffer: Buffer.from([0xff, 0xd8, 0xff]),
        mimetype: 'image/jpeg',
        size: 3,
      } as Express.Multer.File),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});
