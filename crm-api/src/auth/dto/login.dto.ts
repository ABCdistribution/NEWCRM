import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'jdupont', description: 'Identifiant AD (sAMAccountName)' })
  @IsString()
  @IsNotEmpty()
  username!: string;

  @ApiProperty({ example: 'motdepasse', description: 'Mot de passe Active Directory' })
  @IsString()
  @IsNotEmpty()
  password!: string;
}
