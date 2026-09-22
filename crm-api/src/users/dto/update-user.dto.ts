import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsEnum, IsOptional, IsUUID, ValidateIf } from 'class-validator';
import { Role } from '@crm/database';

export class UpdateUserDto {
  @ApiPropertyOptional({ enum: Role, description: 'Rôle applicatif (RBAC)' })
  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @ApiPropertyOptional({ description: 'Compte actif (false = accès révoqué)' })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional({
    description: "UUID du secteur de rattachement (null pour détacher)",
    nullable: true,
  })
  @IsOptional()
  @ValidateIf((o: UpdateUserDto) => o.secteurId !== null)
  @IsUUID()
  secteurId?: string | null;
}
