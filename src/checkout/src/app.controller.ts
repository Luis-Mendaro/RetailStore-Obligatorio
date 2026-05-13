import { Controller, Get } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Controller()
export class AppController {
  constructor(private configService: ConfigService) {}

  @Get('health')
  health() {
    return { status: 'ok' };
  }

  @Get('topology')
  topology() {
    const persistenceProvider = this.configService.get('persistence.provider');
    let databaseEndpoint = 'N/A';

    if (persistenceProvider === 'redis') {
      databaseEndpoint = this.configService.get('persistence.redis.url');
    }

    return { persistenceProvider, databaseEndpoint };
  }
}
