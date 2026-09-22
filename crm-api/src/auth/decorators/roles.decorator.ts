import { SetMetadata } from '@nestjs/common';
import { Role } from '@crm/database';

export const ROLES_KEY = 'roles';

/** Restreint une route/contrôleur à un ou plusieurs rôles (utilisé avec RolesGuard). */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
