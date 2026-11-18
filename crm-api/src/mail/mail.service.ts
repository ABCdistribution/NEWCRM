import { BadGatewayException, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createTransport, Transporter } from 'nodemailer';

/**
 * Envoi de mails sortants par SMTP (nodemailer). Aucune valeur en dur : tout vient de l'environnement de l'API.
 * Variables lues : SMTP_HOST (obligatoire), SMTP_PORT (défaut 587), SMTP_USER et SMTP_PASS (facultatives : sans
 * SMTP_USER, pas d'authentification), SMTP_FROM (expéditeur ; à défaut SMTP_USER), SMTP_SECURE ("true" pour TLS direct,
 * typiquement port 465). Sans SMTP_HOST ou sans expéditeur, le service est « non configuré » : 503 en français.
 */
export interface MailASend {
  to: string;
  subject: string;
  html: string;
  text: string;
  replyTo?: string;
}

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transport: Transporter | null = null;

  constructor(private readonly config: ConfigService) {}

  private expediteur(): string | undefined {
    return this.config.get<string>('SMTP_FROM')?.trim() || this.config.get<string>('SMTP_USER')?.trim() || undefined;
  }

  estConfigure(): boolean {
    return Boolean(this.config.get<string>('SMTP_HOST')?.trim() && this.expediteur());
  }

  /** 503 explicite si le serveur n'a pas de SMTP : à appeler avant toute écriture en base. */
  exigerConfiguration(): void {
    if (!this.estConfigure()) {
      throw new ServiceUnavailableException("L'envoi de mail n'est pas configuré sur le serveur");
    }
  }

  private getTransport(): Transporter {
    if (!this.transport) {
      const user = this.config.get<string>('SMTP_USER')?.trim();
      const pass = this.config.get<string>('SMTP_PASS');
      this.transport = createTransport({
        host: this.config.get<string>('SMTP_HOST')!.trim(),
        port: Number(this.config.get<string>('SMTP_PORT') ?? 587),
        secure: this.config.get<string>('SMTP_SECURE')?.trim().toLowerCase() === 'true',
        auth: user ? { user, pass } : undefined,
        connectionTimeout: 10_000,
        greetingTimeout: 10_000,
        socketTimeout: 20_000,
      });
    }
    return this.transport;
  }

  async envoyer(mail: MailASend): Promise<void> {
    this.exigerConfiguration();
    try {
      await this.getTransport().sendMail({
        from: this.expediteur(),
        to: mail.to,
        replyTo: mail.replyTo,
        subject: mail.subject.replace(/[\r\n]+/g, ' '),
        html: mail.html,
        text: mail.text,
      });
    } catch (e) {
      // Le détail (hôte, identifiants éventuels) reste dans les logs serveur, jamais dans la réponse.
      this.logger.error(`Échec d'envoi SMTP : ${(e as Error).message}`);
      throw new BadGatewayException("L'envoi du mail a échoué, réessayez dans un instant");
    }
  }
}
