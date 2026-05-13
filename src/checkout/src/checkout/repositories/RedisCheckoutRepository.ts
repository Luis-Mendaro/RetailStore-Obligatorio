

import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { ICheckoutRepository } from './ICheckoutRepository';
import { Redis } from 'ioredis';

@Injectable()
export class RedisCheckoutRepository
  implements ICheckoutRepository, OnModuleDestroy
{
  private _client: Redis;
  private _readClient: Redis;

  constructor(
    private url: string,
    private readerUrl: string,
  ) {}

  private async buildClient(url: string) {
    return new Redis(url);
  }

  async client() {
    if (!this._client) {
      this._client = await this.buildClient(this.url);
    }
    return this._client;
  }

  async readClient() {
    if (!this._readClient) {
      this._readClient = await this.buildClient(this.readerUrl);
    }
    return this._readClient;
  }

  // Implement onModuleDestroy to clean up Redis connections
  async onModuleDestroy() {
    try {
      if (this._client) {
        await this._client.quit();
        this._client = null;
      }

      if (this._readClient) {
        await this._readClient.quit();
        this._readClient = null;
      }
    } catch (error) {
      console.error('Error closing Redis connections:', error);
      throw error;
    }
  }

  async get(key: string): Promise<string> {
    const client = await this.readClient();

    return client.get(key);
  }

  async set(key: string, value: string): Promise<string> {
    const client = await this.client();

    return client.set(key, value);
  }

  async remove(key: string): Promise<void> {
    const client = await this.client();
    await client.del(key);
    return Promise.resolve(null);
  }

  async health() {
    try {
      const client = await this.client();
      await client.ping();
      return true;
    } catch (error) {
      console.error('Redis health check failed:', error);
      return false;
    }
  }
}
