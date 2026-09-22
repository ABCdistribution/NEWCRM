import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { LdapService } from './ldap.service';
import { AdSyncService } from './ad-sync.service';
import { SyncController } from './sync.controller';
import { JwtStrategy } from './strategies/jwt.strategy';

@Module({
  imports: [
    PassportModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
        // `as any` : la valeur (ex. "8h") vient de l'env, le type strict de ms attend un littéral.
        signOptions: { expiresIn: (config.get<string>('JWT_EXPIRES_IN') ?? '8h') as any },
      }),
    }),
  ],
  controllers: [AuthController, SyncController],
  providers: [AuthService, LdapService, AdSyncService, JwtStrategy],
})
export class AuthModule {}
