import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsNotEmpty, IsOptional, IsString, Matches, MaxLength, ValidateIf } from 'class-validator';
import { IMAGE_URL_REGEX } from './create-news.dto';

export class UpdateNewsDto {
  @ApiPropertyOptional({ maxLength: 200 })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  titre?: string;

  @ApiPropertyOptional({ maxLength: 20000 })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(20000)
  contenu?: string;

  @ApiPropertyOptional({ nullable: true, description: 'null = retirer l’image' })
  @ValidateIf((o: UpdateNewsDto) => o.imageUrl !== undefined && o.imageUrl !== null)
  @IsString()
  @MaxLength(500)
  @Matches(IMAGE_URL_REGEX, { message: 'imageUrl doit être une URL http(s) ou un chemin commençant par /' })
  imageUrl?: string | null;

  @ApiPropertyOptional({ description: 'true = publier, false = dépublier' })
  @IsOptional()
  @IsBoolean()
  publiee?: boolean;
}
