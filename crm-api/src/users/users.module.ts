import { Module } from '@nestjs/common';
import { UsersController } from './users.controller';
import { UserPhotoController } from './user-photo.controller';
import { UsersService } from './users.service';

@Module({
  controllers: [UsersController, UserPhotoController],
  providers: [UsersService],
})
export class UsersModule {}
