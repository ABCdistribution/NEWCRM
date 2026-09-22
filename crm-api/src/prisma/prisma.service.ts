import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@crm/database';
import { PrismaPg } from '@prisma/adapter-pg';

/**
 * Client Prisma injectable dans NestJS.
 * Prisma 7 ne lit plus l'URL depuis le schéma : on passe un driver adapter (pg)
 * construit à partir de DATABASE_URL.
 */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  constructor() {
    super({
      adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
    });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
