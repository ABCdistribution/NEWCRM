import { PartialType } from '@nestjs/swagger';
import { CreateClientDto } from './create-client.dto';

/** Tous les champs de création, mais optionnels. */
export class UpdateClientDto extends PartialType(CreateClientDto) {}
