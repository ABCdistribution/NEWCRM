import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ClientsModule } from './clients/clients.module';
import { ArticlesModule } from './articles/articles.module';
import { CommandesModule } from './commandes/commandes.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { PerformancesModule } from './performances/performances.module';
import { ObjectifsModule } from './objectifs/objectifs.module';
import { PlanningsModule } from './plannings/plannings.module';
import { NotificationsModule } from './notifications/notifications.module';
import { SecteursModule } from './secteurs/secteurs.module';
import { VisitesModule } from './visites/visites.module';
import { QuestionnaireModule } from './questionnaire/questionnaire.module';
import { PromosModule } from './promos/promos.module';
import { ImportModule } from './import/import.module';
import { ProspectionModule } from './prospection/prospection.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        connection: {
          host: config.get<string>('REDIS_HOST') ?? 'localhost',
          port: Number(config.get<string>('REDIS_PORT') ?? 6379),
        },
      }),
    }),
    PrismaModule,
    AuthModule,
    UsersModule,
    ClientsModule,
    ArticlesModule,
    CommandesModule,
    DashboardModule,
    PerformancesModule,
    ObjectifsModule,
    PlanningsModule,
    NotificationsModule,
    SecteursModule,
    VisitesModule,
    QuestionnaireModule,
    PromosModule,
    ProspectionModule,
    ImportModule,
    HealthModule,
  ],
})
export class AppModule {}
