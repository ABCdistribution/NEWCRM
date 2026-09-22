import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@crm/database';
import { ROLES_KEY } from '../decorators/roles.decorator';

/** Autorise la requête si l'utilisateur (req.user, posé par JwtAuthGuard) a l'un des rôles requis. */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(ctx: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<Role[] | undefined>(ROLES_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const { user } = ctx.switchToHttp().getRequest();
    if (user && required.includes(user.role)) return true;

    throw new ForbiddenException('Accès réservé : rôle insuffisant');
  }
}
