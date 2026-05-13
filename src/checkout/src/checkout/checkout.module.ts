

import { Logger, Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { CheckoutController } from './checkout.controller';
import { CheckoutService } from './checkout.service';
import { MockOrdersService, HttpOrdersService } from './orders';
import {
  InMemoryCheckoutRepository,
  ICheckoutRepository,
  RedisCheckoutRepository,
} from './repositories';
import { MockShippingService } from './shipping';

const orderServiceProvider = {
  provide: 'OrdersService',
  useFactory: (configService: ConfigService) => {
    const ordersEndpoint = configService.get('endpoints.orders');
    if (ordersEndpoint) {
      return new HttpOrdersService(ordersEndpoint);
    }
    return new MockOrdersService();
  },
  inject: [ConfigService],
};

const shippingServiceProvider = {
  provide: 'ShippingService',
  useFactory: (configService: ConfigService) => {
    return new MockShippingService(configService.get('shipping.prefix'));
  },
  inject: [ConfigService],
};

const repositoryProvider = {
  provide: 'CheckoutRepository',
  useFactory: (configService: ConfigService) => {
    const persistenceProvider = configService.get('persistence.provider');
    const redisUrl = configService.get('persistence.redis.url');
    let redisReaderUrl = configService.get('persistence.redis.reader.url');

    if (!redisReaderUrl) {
      redisReaderUrl = redisUrl;
    }

    let repository: ICheckoutRepository;
    const logger = new Logger();

    if (persistenceProvider === 'redis') {
      let tls = '';
      if (redisReaderUrl.startsWith('rediss://')) {
        tls = ' with TLS';
      }
      logger.log('Using redis persistence' + tls);
      repository = new RedisCheckoutRepository(redisUrl, redisReaderUrl);
    } else {
      logger.log('Using in-memory persistence');
      repository = new InMemoryCheckoutRepository();
    }

    return repository;
  },
  inject: [ConfigService],
};

@Module({
  imports: [ConfigModule],
  controllers: [CheckoutController],
  providers: [
    orderServiceProvider,
    shippingServiceProvider,
    repositoryProvider,
    CheckoutService,
  ],
})
export class CheckoutModule {}
