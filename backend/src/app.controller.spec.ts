import { AppController } from './app.controller';

describe('AppController', () => {
  it('returns the health status', () => {
    const result = new AppController().health();

    expect(result.status).toBe('ok');
    expect(result.service).toBe('ai-order-assistant-api');
    expect(Date.parse(result.timestamp)).not.toBeNaN();
  });
});
