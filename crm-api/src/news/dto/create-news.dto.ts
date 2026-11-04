import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsNotEmpty, IsOptional, IsString, Matches, MaxLength } from 'class-validator';

/** URL http(s) ou chemin absolu du site (pas de `//hote`, ni `/\hote`, pas de `javascript:`). */
export const IMAGE_URL_REGEX = /^(https?:\/\/\S+|\/(?![/\\])\S*)$/;

export class CreateNewsDto {
  @ApiProperty({ maxLength: 200 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  titre!: string;

  @ApiProperty({ description: 'Texte de la news', maxLength: 20000 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(20000)
  contenu!: string;

  @ApiPropertyOptional({ description: 'URL http(s) ou chemin commençant par /', maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  @Matches(IMAGE_URL_REGEX, { message: 'imageUrl doit être une URL http(s) ou un chemin commençant par /' })
  imageUrl?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  publiee?: boolean;
}
