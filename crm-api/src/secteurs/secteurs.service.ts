import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const secteurSelect = {
  id: true,
  code: true,
  nom: true,
  manager: { select: { id: true, displayName: true, role: true } },
  _count: { select: { membres: true, clients: true } },
} as const;

@Injectable()
export class SecteursService {
  constructor(private readonly prisma: PrismaService) {}

  list() {
    return this.prisma.secteur.findMany({ orderBy: { nom: 'asc' }, select: secteurSelect });
  }

  async create(code: string, nom: string, managerId: string | null) {
    const existe = await this.prisma.secteur.findUnique({ where: { code } });
    if (existe) throw new ConflictException(`Le code secteur « ${code} » existe déjà`);
    return this.prisma.secteur.create({ data: { code, nom, managerId }, select: secteurSelect });
  }

  async update(id: string, data: { nom?: string; managerId?: string | null }) {
    const secteur = await this.prisma.secteur.findUnique({ where: { id } });
    if (!secteur) throw new NotFoundException('Secteur introuvable');
    return this.prisma.secteur.update({
      where: { id },
      data: {
        ...(data.nom !== undefined ? { nom: data.nom } : {}),
        ...(data.managerId !== undefined ? { managerId: data.managerId } : {}),
      },
      select: secteurSelect,
    });
  }
}
