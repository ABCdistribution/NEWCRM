import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class TriggerImportDto {
  @ApiProperty({
    example: 'C:/minos/clients_20260729.txt',
    description: 'Chemin du fichier Minos (largeur fixe) à importer',
  })
  @IsString()
  @IsNotEmpty()
  filePath!: string;
}
