import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UsersService } from './users.service';
import { QueryUsersDto } from './dto/query-users.dto';
import { UpdateUserDto } from './dto/update-user.dto';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
// L'administration des comptes est réservée aux ADMIN ; seule la liste (GET /)
// reste ouverte à l'encadrement (planification des tournées, scoping chef de secteur).
@Roles(Role.ADMIN)
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  @Roles(Role.ADMIN, Role.DIRECTION, Role.DIRECTEUR_REGIONAL, Role.CHEF_SECTEUR)
  @ApiOperation({
    summary: 'Liste paginée des utilisateurs — un chef de secteur ne voit que les membres de ses secteurs',
  })
  findAll(@Query() query: QueryUsersDto, @CurrentUser() me: User) {
    return this.users.findAll(query, me);
  }

  @Get(':id')
  @ApiOperation({ summary: "Détail d'un utilisateur (ADMIN)" })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.findOne(id);
  }

  @Patch(':id')
  @ApiOperation({ summary: "Modifier le rôle / l'activation d'un utilisateur (ADMIN)" })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateUserDto,
    @CurrentUser() me: User,
  ) {
    return this.users.update(id, dto, me.id);
  }
}
