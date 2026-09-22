import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

/** Module global exposant PrismaService à toute l'application. */
@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
